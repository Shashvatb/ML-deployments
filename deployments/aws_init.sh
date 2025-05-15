#!/bin/bash

# install aws cli
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "deployments/aws/awscliv2.zip"
unzip deployments/aws/awscliv2.zip -d deployments/aws/
sudo deployments/aws/aws/install

# configure aws. get info: https://console.aws.amazon.com/iam/home#/security_credentials
aws configure

# create repository -> repository uri: <your_account_id>.dkr.ecr.eu-central-1.amazonaws.com/ml-api
aws ecr create-repository \
  --repository-name ml-api \
  --region eu-central-1

# Authenticate docker with AWS
aws ecr get-login-password --region eu-central-1 | docker login \
  --username AWS \
  --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com

# create project directly on AWS using code build ($$$)
aws codebuild create-project \
    --name your-codebuild-project \
    --source type=GITHUB,location=https://github.com/your-username/your-repo \
    --artifacts type=NO_ARTIFACTS \
    --environment type=LINUX_CONTAINER,computeType=BUILD_GENERAL1_SMALL,image=aws/codebuild/standard:4.0 \
    --service-role arn:aws:iam::<your_account_id>:role/your-codebuild-service-role
aws codebuild start-build --project-name your-codebuild-project

# building docker on local (free)
docker build -t ml-api .
docker tag ml-api:latest $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com/ml-api:latest
docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com/ml-api:latest


# create ECS cluster
aws ecs create-cluster --cluster-name my-cluster --region eu-central-1

# creat IAM role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy



# register this task to ecs
aws ecs register-task-definition \
  --family my-task \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu "256" \
  --memory "1024" \
  --execution-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole \
  --container-definitions "[
    {
      \"name\": \"my-container\",
      \"image\": \"$(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com/ml-api:latest\",
      \"essential\": true,
      \"portMappings\": [
        {
          \"containerPort\": 8080,
          \"hostPort\": 8080,
          \"protocol\": \"tcp\"
        }
      ]
    }
  ]"

# get subnet ID
aws ec2 describe-subnets --query "Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" --output table

# get security group id
aws ec2 describe-security-groups \
  --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" \
  --output table


# run the container
aws ecs create-service \
  --cluster my-cluster \
  --service-name my-service \
  --task-definition my-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --desired-count 1

# get endpoint
## get task id 
aws ecs list-tasks --cluster  my-cluster
## get network interface id -> attachments > details > networkInterfaceId
aws ecs describe-tasks --cluster  my-cluster --tasks  <task_id>
## get public ip -> Association > PublicIp
aws ec2 describe-network-interfaces --network-interface-ids eni-xxxxxxxxxxxxxxxxx

# allow inbound requests with public ip
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

# now the API is ready to be served

# stop cluster
aws ecs update-service --cluster my-cluster --service my-service --desired-count 0 --region eu-central-1

# delete everything
aws ecs delete-service --cluster my-cluster --service my-service --region eu-central-1
aws ecs delete-cluster --cluster my-cluster --region eu-central-1
aws ecr delete-repository --repository-name ml-api --region eu-central-1 --force



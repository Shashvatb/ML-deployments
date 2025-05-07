#!/bin/bash
sudo apt install curl -y

# installing the sdk
curl -sSL https://sdk.cloud.google.com | bash
# enter the path to install the sdk when prompted
# when asked to enter the path of the rc file say no

# manually adding the rc files because we have multiple
echo 'source "./deployments/gcp/google-cloud-sdk/path.bash.inc"' >> ~/.bashrc
echo 'source "./deployments/gcp/google-cloud-sdk/completion.bash.inc"' >> ~/.bashrc
source ~/.bashrc
exec -l $SHELL

# login to your gcp account
gcloud init
# gcloud projects list

# set your project as active project
gcloud config set project deploy1-shashvat
# gcloud projects list

# enable the cloud run, cloud build and artifactregistry apis in GCP. Make sure you have a billing account linked to it
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# create repository
gcloud artifacts repositories create ml-deployments --repository-format=docker --location=europe-west3 --description="deployment for simple ML model"

#configure the docker
gcloud auth configure-docker europe-west3-docker.pkg.dev

# build your docker. make sure you have a role as "storage access viewer". can create a .gcloudignore file (similar to gitignore) to make the size of it much smaller
gcloud builds submit --tag europe-west3-docker.pkg.dev/deploy1-shashvat/ml-deployments/ml-deployment-image:v1
# the image will appear in the artifacts

# deploy the image 
gcloud run deploy ml-deployment-service --image europe-west3-docker.pkg.dev/deploy1-shashvat/ml-deployments/ml-deployment-image:v1 --platform managed --region europe-west3 --allow-unauthenticated  --memory 1Gi --cpu 1 --max-instances 1 --timeout 10m

# delete the service
gcloud run services delete ml-deployment-service --region europe-west3





#!/bin/bash

# install azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az version

# login to azure. uncomment --use-device-code if you cannot access a browser from the machine (for example WSL)
az login # --use-device-code

# create resource group
az group create --name ml-deploy-rg --location westeurope

# enable acr registry for the subscription
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerInstance


# create azure container registry
az acr create --resource-group ml-deploy-rg --name mlregistryshashvat --sku Basic --admin-enabled true

# build docker image. THIS DOES NOT WORK WITH FREE ACCOUNTS
az acr build --file Dockerfile . --registry mlregistryshashvat --image ml-api:latest --build-arg no_cache=true

# for free accounts
## Log in to your ACR
az acr login --name mlregistryshashvat
## Tag the image
docker build -t mlregistryshashvat.azurecr.io/ml-deployment-image:v1 .
docker push mlregistryshashvat.azurecr.io/ml-deployment-image:v1

# create container with the image (instead of using app service and webapp $$$)
az container create \
  --resource-group ml-deploy-rg \
  --name ml-api-instance \
  --image mlregistryshashvat.azurecr.io/ml-deployment-image:v1 \
  --registry-login-server mlregistryshashvat.azurecr.io \
  --registry-username $(az acr credential show --name mlregistryshashvat --query username -o tsv) \
  --registry-password $(az acr credential show --name mlregistryshashvat --query passwords[0].value -o tsv) \
  --dns-name-label ml-shashvat --ports 8080 --os-type Linux --cpu 1 --memory 1

  # app available at http://ml-shashvat.westeurope.azurecontainer.io -> can have issues with DNS resolving

# stop container
az container stop --name ml-api-instance --resource-group ml-deploy-rg

# delete container
az container delete --name ml-api-instance --resource-group  ml-deploy-rg --yes




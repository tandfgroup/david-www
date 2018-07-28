#!/bin/bash

set -e

PACKAGE_VERSION=$(node -p "require('./package.json').version")
echo $PACKAGE_VERSION

gcloud --quiet config set project fine-ring-208513
gcloud --quiet config set container/cluster knowledge-ai
gcloud --quiet config set compute/zone us-east1-b
# deploy
gcloud --quiet container clusters get-credentials knowledge-ai
kubectl config view
kubectl config current-context
kubectl apply -f k8s
kubectl set image deployment/david-frontend-prod david=gcr.io/fine-ring-208513/david:$PACKAGE_VERSION


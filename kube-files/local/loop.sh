#!/bin/bash
service=$1
cd ~/mysrc/donut-dagger/${service}
kubectl delete deploy/${service}
docker build -t ${service}:mine .
cd ~/mysrc/donut-dagger/kube-files/local
kubectl apply -f ${service}-deploy_secret.yml

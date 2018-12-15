#! /bin/bash

kubectl delete -f cellar-deploy_secret.yml
kubectl delete -f dagger-deploy_secret.yml
kubectl delete -f users-deploy_secret.yml
kubectl delete -f cellar-svc.yml
kubectl delete -f dagger-svc.yml
kubectl delete -f users-svc.yml
kubectl delete -f etcd.yml
kubectl delete -f nfs-deploy.yml
kubectl delete -f nfs-svc.yml
kubectl delete secret/kubeconfig
kubectl delete -f ssl-cert-dusty_secret.yml
kubectl delete -f redis-deploy.yml
kubectl delete -f redis-svc.yml
kubectl delete -f users-rake_secret.yml
kubectl delete -f dagger-rake_secret.yml
kubectl delete -f cellar-rake_secret.yml
kubectl delete -f postgres-deploy.yml
kubectl delete -f postgres-svc.yml

sudo sed -i '' '/dustysarcophagus/d' /etc/hosts

minikube stop

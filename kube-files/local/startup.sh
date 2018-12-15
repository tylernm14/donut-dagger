#!/bin/bash

minikube start --vm-driver hyperkit --cpus 4 --memory 8192

users_loc=~/mysrc/donut-dagger/users
dagger_loc=~/mysrc/donut-dagger/dagger
cellar_loc=~/mysrc/donut-dagger/cellar
wrapper_loc=~/mysrc/donut-dagger/wrapper/pythond

deploy_loc=~/mysrc/donut-dagger/kube-files/local

eval $(minikube docker-env)

cd ${users_loc}
docker build -t users:mine .
cd ${dagger_loc}
docker build -t dagger:mine .
docker build -t kubectl:1.10.11 -f Dockerfile-kubectl .
cd ${cellar_loc}
docker build -t cellar:mine .
cd ${wrapper_loc}
make build
cd ${deploy_loc}

kubectl label nodes minikube cpu_usage=blue
minikube addons enable ingress
kubectl apply -f postgres-deploy.yml
kubectl apply -f postgres-svc.yml
kubectl apply -f nfs-deploy.yml
kubectl apply -f nfs-svc.yml
sleep 60
kubectl apply -f etcd.yml
./make-kube-config.sh
kubectl create secret generic kubeconfig --from-file=./kubeconfig
kubectl apply -f ssl-cert-dusty_secret.yml
kubectl apply -f redis-deploy.yml
kubectl apply -f redis-svc.yml
kubectl apply -f users-svc.yml
kubectl apply -f dagger-svc.yml
kubectl apply -f cellar-svc.yml

# might want to do the below manually...
kubectl apply -f users-rake_secret.yml
kubectl apply -f dagger-rake_secret.yml
kubectl apply -f cellar-rake_secret.yml
sleep 30

# might want to do the below manually as well...
kubectl apply -f users-deploy_secret.yml
kubectl apply -f dagger-deploy_secret.yml
kubectl apply -f cellar-deploy_secret.yml

ip=`minikube ip | tr -d '\n'` && echo "${ip} www.dustysarcophagus.com" | sudo tee -a /etc/hosts

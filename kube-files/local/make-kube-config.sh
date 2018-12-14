#!/bin/bash

ca_cert_loc=~/.minikube/ca.crt
client_cert_loc=~/.minikube/client.crt
client_key_loc=~/.minikube/client.key

ca_cert=`cat ${ca_cert_loc} | base64`
client_cert=`cat ${client_cert_loc} | base64`
client_key=`cat ${client_key_loc}| base64`


orig_kubeconfig=~/.kube/config
kubeconfig=~/mysrc/donut-dagger/kube-files/local/kubeconfig
cp ${orig_kubeconfig} ${kubeconfig}

sed -i '' 's/certificate-authority/certificate-authority-data/' ${kubeconfig}
sed -i '' 's/client-certificate/client-certificate-data/' ${kubeconfig}
sed -i '' 's/client-key/client-key-data/' ${kubeconfig}

sed -i '' "s:${ca_cert_loc}:${ca_cert}:" ${kubeconfig}
sed -i '' "s:${client_cert_loc}:${client_cert}:" ${kubeconfig}
sed -i '' "s:${client_key_loc}:${client_key}:" ${kubeconfig}




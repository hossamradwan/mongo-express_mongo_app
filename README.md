# mongo-express_mongo_app
This a simple mongo-express mongo database app where a mongodb client (mongo-express ) can communicate and edit a mongo database. <br />
The project uses Terraform, AWS EKS, Helm, bitnami sealed secrets & OAuth2 Proxy. The project is created using the following steps.
## Creating the kubernetes cluster
1- Go to terraform folder. <br />
2- Run the following commands. <br />
```
terraform init
terraform apply
```
Notes: <br />
1- terrafrom uses the aws credential stored in ~/.aws/credentials. <br />
2- If you don't want to use terraform remote state, comment lines 1:9 in terraform/providers.tf <br />
<br />
To connect to the cluster:<br />
```
aws eks update-kubeconfig --name mongo-eks-cluster --region eu-west-1
```

## Encrypting secrets
1- Install kubeseal tool.<br />
```
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.22.0/kubeseal-0.22.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.22.0-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

```
2- Install sealed-secrets controller.<br />
```
kubectl apply --filename https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.22.0/controller.yaml
```
3- Encrypt kubernetes secrets.<br />
  * Encrypt mongo db secret.
  * The following command encrypts the mongodb secret using kubeseal tool. kubeseal connect to the sealed secret controller, encrypt the secret values (mongo-root-username=username, mongo-root-password=password), and save the encrypted values in app/app-values/mongodb-values.yaml.
```
enc=$(kubectl --namespace default create secret generic mongodb-secret --dry-run=client --from-literal mongo-root-username=username --from-literal mongo-root-password=password --output json | kubeseal | jq -r '.spec.encryptedData') \
&& enc_user=$(echo $enc | jq -r '.["mongo-root-username"]') \
&& enc_pass=$(echo $enc | jq -r '.["mongo-root-password"]') \
&& sed -i 's|^mongoRootUsername:.*|mongoRootUsername: '"$enc_user"'|'  app/app-values/mongo/values.yaml \
&& sed -i 's|^mongoRootPassword:.*|mongoRootPassword: '"$enc_pass"'|'  app/app-values/mongo/values.yaml
```
  * Encrypt mongo-express secret.
  * The following command encrypts the mongo-express secret using kubeseal tool. kubeseal connect to the sealed secret controller, encrypt the secret values (mongo-root-username=username, mongo-root-password=password), and save the encrypted values in app/app-values/mongo-express-values.yaml.
```
enc=$(kubectl --namespace default create secret generic mongo-express-secret --dry-run=client --from-literal mongo-root-username=username --from-literal mongo-root-password=password --output json | kubeseal | jq -r '.spec.encryptedData') \
&& enc_user=$(echo $enc | jq -r '.["mongo-root-username"]') \
&& enc_pass=$(echo $enc | jq -r '.["mongo-root-password"]') \
&& sed -i 's|^mongoRootUsername:.*|mongoRootUsername: '"$enc_user"'|'  app/app-values/mongo-express/values.yaml \
&& sed -i 's|^mongoRootPassword:.*|mongoRootPassword: '"$enc_pass"'|'  app/app-values/mongo-express/values.yaml
```

## Installing ArgoCD
ArgoCD is installed using the installation file in argocd/manifests/install <br />
This is version 2.8.4 of ArgoCD with cluster installation which gives ArgoCD access to the whole cluster.<br />
```
kubectl create ns argocd
kubectl -n argocd apply -f argocd/manifests/install.yaml
```
The "argocd/manifests/base" contains all the ArgoCD files separated by each component in case an edit is needed in a spcific component.<br />
The "argocd/config" contains the files needed to deploy the helm charts.<br />
1- "project.yaml" to create a project in ArgoCD.<br />
2- "applicationset.yaml" to deploy MongoDB and Mongo Express charts. <br />
3- "application.yaml" to deploy oauth2-proxy charts. <br />
<br />
To access ArgoCd UI use: 
```
kubectl -n argocd port-forward service/argocd-server 9099:80
```
To Login to ArgoCD use the following credentials: <br />
Username: admin <br />
Password: is found in secret "argocd-initial-admin-secret" <br />
An SSO using GitHub is also possible with dex integration.<br />
<br />
The installation files are taken from ArgoCD repo "https://github.com/argoproj/argo-cd/tree/v2.8.4"

## Deploying app
No changes in the app files. only a change in the structure of directory "app/app-values".<br />
Instead of using helm to deploy the app
```
helm install -f app/app-values/mongo/values.yaml mongodb app/app-chart
helm install -f app/app-values/mongo-express/values.yaml mongo-express app/app-chart
```
ArgoCD files are used: <br />
```
kubectl apply -f argocd/config/applicationset.yaml
```
Applying the above file directs ArgoCD to use the "app-chart" and the values file in "app-values" to create the MongoDB and Mongo Express charts.
## Allowing public access
1- Install ingress nginx controller
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```
2- Connect host url to the load balancer associated with the ingress using Route 53
## Authentication
1- Create OAuth app on github. <br />
2- Copy the Client ID from githup and paste it as a value of OAUTH2_PROXY_CLIENT_ID in oauth2-proxy-chart/values.yaml <br />
3- Create a Client secret from the github OAuth app and copy it & use the following command which encrypts Client secret value & add it as a value of OAUTH2_PROXY_CLIENT_SECRET in oauth2-proxy-chart/values.yaml
```
enc=$(kubectl --namespace default create secret generic oauth2-proxy-secret --dry-run=client --from-literal OAUTH2_PROXY_CLIENT_SECRET=<client secret value> --output json | kubeseal | jq -r '.spec.encryptedData') \
&& enc_client_sec=$(echo $enc | jq -r '.["OAUTH2_PROXY_CLIENT_SECRET"]') \
&& sed -i 's|^OAUTH2_PROXY_CLIENT_SECRET:.*|OAUTH2_PROXY_CLIENT_SECRET: '"$enc_client_sec"'|'  oauth2-proxy-chart/values.yaml
```
4- Deploy OAuth2 Proxy
```
helm install oauth2-proxy oauth2-proxy-chart
```
or using ArgoCD
```
kubectl apply -f argocd/config/application.yaml
```
## Refrences
https://hub.docker.com/_/mongo-express <br />
https://hub.docker.com/_/mongo <br />
https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest <br />
https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest <br />
https://github.com/bitnami-labs/sealed-secrets <br />
https://kubernetes.github.io/ingress-nginx/deploy/ <br />
https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/ <br />
https://github.com/argoproj/argo-cd/tree/v2.8.4 <br />


# RH-SSO MAS Cluster scripts

## Creating the cluster
The script to be used is the `create_cluster.sh`.

To create a cluster, the script will require the following data:
* The OCM token: you can get it at https://qaprodauth.cloud.redhat.com/openshift/token.
  The token can be provided to the script either by setting the `OCM_TOKEN` environment variable or by
  using the `-t|--ocm-token` parameter. 
* The name of the cluster you want to create. This name can be provided either by setting the `CLUSTER_NAME`
  environment variable or using the `-n|--cluster-name` parameter.
* The AWS account id. This can be specified either by setting the `AWS_ACCESS_KEY_ID` environment variable
  or by specifying the `-i--aws-account-id` parameter.
* The AWS access key id. This can be specified either by setting the `AWS_ACCESS_KEY_ID` environment variable
  or by specifying the `-k|--aws-access-key-id` parameter.
* The AWS access key secret. This can be specified either by setting the `AWS_ACCESS_KEY_SECRET` environment variable
  or by specifying the `-s|--aws-access-key-secret` parameter.

Finally, if you want RH-SSO to be deployed as soon as the cluster is ready, pass the `-d|--deploy-rh-sso <namespace>`
parameter.

If any of the required parameter is not specified, the script prompt for a value.

An example invocation could be:
```bash
./create_cluster.sh -n mas-cluster-2 -i 12342345 -k AHGFAHFSFAS6JHGS -s 76n3i2938GHKJHKJH&kjhskjdh8271kas -t $MY_TOKEN

**********************************************
CLUSTER NAMED mas-cluster-2 HAS BEEN CREATED
API URL: https://api.yourcluster.api.url
CONSOLE URL: https://console.yourcluster.console.url
USER: kubeadm
PASSWORD: sdfkjh^hs!**Jhksd
**********************************************
```

## Deploy RH-SSO
The script to be used is the `deploy_rhsso.sh`.

To deply RH-SSO, the script will require the following data:
* The OCM token: you can get it at https://qaprodauth.cloud.redhat.com/openshift/token.
  The token can be provided to the script either by setting the `OCM_TOKEN` environment variable or by
  using the `-t|--ocm-token` parameter. 
* The name of the cluster where you want to deploy. This name can be provided either by setting the `CLUSTER_NAME`
  environment variable or using the `-n|--cluster-name` parameter.
* The NAMESPACE where you want to deploy it. This can be specified either by setting the `NAMESPACE` environment variable
  or by specifying the `-N|--namespace` parameter.

If any of the required parameter is not specified, the script will prompt for the value.

An example invocation could be:
```bash
./deploy_rhsso.sh -n mas-cluster-2 -N test -t $MY_TOKEN
```

#!/bin/bash

KC_OPERATOR_FOLDER="/tmp/keycloak-operator"

set -e
CMD=$(basename "$0")

if ! [ -x "$(command -v git)" ]; then
  echo 'Error: git is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v ocm)" ]; then
  echo 'Error: ocm is not installed.' >&2
  echo 'Download from https://github.com/openshift-online/ocm-cli/releases and put it into your PATH' >&2
  exit 1
fi

if ! [ -x "$(command -v oc)" ]; then
  echo 'Error: oc is not installed.' >&2
  echo 'Download from https://cloud.redhat.com/openshift/install/aws/installer-provisioned and put it into your PATH' >&2
  exit 1
fi

function print_usage {
  printf "usage: '%s' %s\n%s\n\n" \
    "$CMD" \
     "[-t | --ocm-token <TOKEN>] [-n | --cluster-name]" \
     "                           [-i | --aws-account-id] [-N | --namespace"

  printf "[-t|--ocm-token] the token to be used to access ocm. You can copy it from\n%s\n%s\n" \
    "                 https://qaprodauth.cloud.redhat.com/openshift/token" \
    "                 ENV VAR: OCM_TOKEN"
  printf "[-n|--cluster-name] the name of the cluster to be created.\n%s\n" \
    "                 ENV VAR: CLUSTER_NAME"
  printf "[-N | --namespace] Target namespace for RS-SSO deployment.\n%s\n" \
    "                 ENV VAR: NAMESPACE"
}

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--ocm-token") set -- "$@" "-t" ;;
    "--cluster-name")   set -- "$@" "-n" ;;
    "--namespace")   set -- "$@" "-N" ;;
    *)        set -- "$@" "$arg"
  esac
done

OPTIND=1
while getopts ht:n:N: opt
do
  case "$opt" in
    "h") print_usage; exit 0 ;;
    "t") OCM_TOKEN=${OPTARG} ;;
    "n") CLUSTER_NAME=${OPTARG} ;;
    "N") NAMESPACE=${OPTARG} ;;
    "?") print_usage >&2; exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1)

if [ -z "${OCM_TOKEN}" ]; then
  printf "OCM TOKEN CAN BE FOUND HERE: https://qaprodauth.cloud.redhat.com/openshift/token\n"
  printf "OCM TOKEN: "
  read -r OCM_TOKEN
fi

[ -z "${CLUSTER_NAME}" ] && printf "CLUSTER NAME: " && read -r CLUSTER_NAME

[ -z "${NAMESPACE}" ] && printf "NAMESPACE: " && read -r NAMESPACE

ocm login --url=https://api.stage.openshift.com/ --token=$OCM_TOKEN

CLUSTER_ID=$(ocm list clusters | grep "$CLUSTER_NAME" | awk '{print $1}')
API_URL=$(ocm describe cluster $CLUSTER_ID | grep 'API URL' | awk '{print $3}')
OC_USER=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | grep '"user"' | awk '{print $2}' | sed -e 's/[\",]//g')
OC_PASSWD=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | grep '"password"' | awk '{print $2}' | sed -e 's/[\",]//g')

oc login $API_URL  -u $OC_USER -p $OC_PASSWD

# cloning keycloak operator
[ -d "$KC_OPERATOR_FOLDER" ] || git clone https://github.com/keycloak/keycloak-operator "$KC_OPERATOR_FOLDER"
cd "$KC_OPERATOR_FOLDER"

# Install all required custom resource definitions:
oc create -f "$KC_OPERATOR_FOLDER/deploy/crds/"

# Create a new namespace (or reuse an existing one) such as the namespace $NAMESPACE:
oc create namespace "$NAMESPACE"

# Deploy a role, role binding, and service account for the Operator:
oc create -f "$KC_OPERATOR_FOLDER/deploy/role.yaml" -n "$NAMESPACE"
oc create -f "$KC_OPERATOR_FOLDER/deploy/role_binding.yaml" -n "$NAMESPACE"
oc create -f "$KC_OPERATOR_FOLDER/deploy/service_account.yaml" -n "$NAMESPACE"

# Deploy the Operator:
oc create -f "$KC_OPERATOR_FOLDER/deploy/operator.yaml" -n "$NAMESPACE"

# Confirm that the Operator is running:
oc get deployment keycloak-operator -n "$NAMESPACE"

STATUS="0/1"
while [ "$STATUS" != "1/1" ]
do
  STATUS="$(oc get deployment keycloak-operator -n "$NAMESPACE" | tail -1 | awk '{print $2}')"
	for s in / - \\ \|; do
		printf "\r$s Waiting for the operator to be ready (current status: %s)" "$STATUS"
		sleep .1
	done
done

printf "\nDEPLOYING RH_SSO\n"
oc create -f "$KC_OPERATOR_FOLDER/deploy/examples/keycloak/rhsso.yaml" -n "$NAMESPACE"

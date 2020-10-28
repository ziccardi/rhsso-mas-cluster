#!/bin/bash

# --cluster-name|n xxx --ocm-token|t xxx --aws-account-id|i xxx --aws-access-key-id|k xxx --aws-access-key-secret|s xxx
set -e
CMD=$(basename "$0")

function print_usage {
  printf "usage: '%s' %s\n%s\n%s\n\n" \
    "$CMD" \
     "[-t | --ocm-token <TOKEN>] [-n | --cluster-name]" \
     "                           [-i | --aws-account-id] [-k | --aws-access-key-id]" \
     "                           [-s | --aws-access-key-secret]"

  printf "[-t|--ocm-token] the token to be used to access ocm. You can copy it from\n%s\n%s\n" \
    "                 https://qaprodauth.cloud.redhat.com/openshift/token" \
    "                 ENV VAR: OCM_TOKEN"
  printf "[-n|--cluster-name] the name of the cluster to be created.\n%s\n" \
    "                 ENV VAR: CLUSTER_NAME"
  printf "[-i | --aws-account-id] the AWS account id.\n%s\n" \
    "                 ENV VAR: AWS_ACCOUNT_ID"
  printf "[-k | --aws-access-key-id] the AWS access key id.\n%s\n" \
    "                 ENV VAR: AWS_ACCESS_KEY_ID"
  printf "[-s | --aws-access-key-secret] the AWS access key secret.\n%s\n" \
    "                 ENV VAR: AWS_ACCESS_KEY_SECRET"

}

for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--ocm-token") set -- "$@" "-t" ;;
    "--cluster-name")   set -- "$@" "-n" ;;
    "--aws-account-id")   set -- "$@" "-i" ;;
    "--aws-access-key-id")   set -- "$@" "-k" ;;
    "--aws-access-key-secret")   set -- "$@" "-s" ;;
    *)        set -- "$@" "$arg"
  esac
done

OPTIND=1
while getopts ht:n:i:k:s: opt
do
  case "$opt" in
    "h") print_usage; exit 0 ;;
    "t") OCM_TOKEN=${OPTARG} ;;
    "n") CLUSTER_NAME=${OPTARG} ;;
    "i") AWS_ACCOUNT_ID=${OPTARG} ;;
    "k") AWS_ACCESS_KEY_ID=${OPTARG} ;;
    "s") AWS_ACCESS_KEY_SECRET=${OPTARG} ;;
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

[ -z "${AWS_ACCOUNT_ID}" ] && printf "AWS ACCOUNT ID: " && read -r  AWS_ACCOUNT_ID
[ -z "${AWS_ACCESS_KEY_ID}" ] && printf "AWS ACCESS KEY ID: " && read -r AWS_ACCESS_KEY_ID
[ -z "${AWS_ACCESS_KEY_SECRET}" ] && printf "AWS ACCESS KEY SECRET: " && read -r AWS_ACCESS_KEY_SECRET

# Login to the OCM
ocm login --url=https://api.stage.openshift.com/ --token="$OCM_TOKEN"
CLUSTER_VERSION=$(ocm list versions | tail -1)

# Create the cluster
printf "%s\n" "{\
    \"byoc\": true,\
    \"name\": \"$CLUSTER_NAME\",\
    \"managed\": true,\
    \"multi_az\": false,\
    \"aws\":{\
        \"access_key_id\":\"$AWS_ACCESS_KEY_ID\",\
        \"secret_access_key\":\"$AWS_ACCESS_KEY_SECRET\",\
        \"account_id\":\"$AWS_ACCOUNT_ID\"\
     },\
    \"region\": {\
        \"id\": \"eu-west-1\",\
        \"display_name\": \"eu-west-1\",\
        \"name\": \"eu-west-1\"\
    },\
    \"nodes\": {\
        \"compute\": 4,\
        \"compute_machine_type\": {\
            \"id\": \"m5.xlarge\"\
        }\
    },\
    \"version\": {\
        \"id\": \"openshift-v$CLUSTER_VERSION\"\
    }\
}" | ocm post /api/clusters_mgmt/v1/clusters


STATUS="pending"
while [ "$STATUS" != "ready" ]
do
  STATUS="$(ocm list clusters | tail -1 | awk '{print $8}')"
	for s in / - \\ \|; do
		printf "\r$s Waiting for the cluster to start (current status: %s)" "$STATUS"
		sleep .1
	done
done

CLUSTER_ID=$(ocm list clusters | grep "$CLUSTER_NAME" | awk '{print $1}')
API_URL=$(ocm describe cluster "$CLUSTER_ID" | grep 'API URL' | awk '{print $3}')
CONSOLE_URL=$(ocm describe cluster "$CLUSTER_ID" | grep 'Console URL' | awk '{print $3}')
OC_USER=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | grep '"user"' | awk '{print $2}' | sed -e 's/[\",]//g')
OC_PASSWD=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | grep '"password"' | awk '{print $2}' | sed -e 's/[\",]//g')

echo "**********************************************"
echo "CLUSTER NAMED <$CLUSTER_NAME> HAS BEEN CREATED"
echo "API URL: $API_URL"
echo "CONSOLE URL: $CONSOLE_URL"
echo "USER: $OC_USER"
echo "PASSWORD: $OC_PASSWD"
echo "**********************************************"
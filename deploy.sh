#!/bin/bash

export KUBE_NAMESPACE=${ENVIRONMENT}
export KUBE_SERVER=${KUBE_SERVER}

if [[ -z ${VERSION} ]] ; then
    export VERSION=${IMAGE_VERSION}
fi
if [[ -z ${DOMAIN} ]] ; then
    export DOMAIN="cs"
fi
export DOMAIN=${DOMAIN}

export IP_WHITELIST=${POISE_WHITELIST}

if [[ ${KUBE_NAMESPACE} == "cs-prod" ]] ; then
    echo "deploy ${VERSION} to PROD namespace, using HOCS_FRONTEND_PROD_CS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_PROD_CS}
    export DNS_PREFIX=www.cs
    export NOTPROD=0
elif [[ ${KUBE_NAMESPACE} == "wcs-prod" ]] ; then
    echo "deploy ${VERSION} to PROD namespace, using HOCS_FRONTEND_PROD_WCS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_PROD_WCS}
    export NOTPROD=0
    export DNS_PREFIX=www.wcs
else
  export NOTPROD="true"
fi
if [[ ${KUBE_NAMESPACE} == "cs-qa" ]] ; then
    echo "deploy ${VERSION} to QA namespace, using HOCS_FRONTEND_QA_CS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_QA_CS}
    export DNS_PREFIX=qa.internal.cs-notprod
elif [[ ${KUBE_NAMESPACE} == "wcs-qa" ]] ; then
    echo "deploy ${VERSION} to QA namespace, using HOCS_FRONTEND_QA_WCS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_QA_WCS}
    export DNS_PREFIX=qa.wcs-notprod
elif [[ ${KUBE_NAMESPACE} == "cs-demo" ]] ; then
    echo "deploy ${VERSION} to DEMO namespace, HOCS_FRONTEND_DEMO_CS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_DEMO_CS}
    export DNS_PREFIX=demo.cs-notprod
elif [[ ${KUBE_NAMESPACE} == "wcs-demo" ]] ; then
    echo "deploy ${VERSION} to DEMO namespace, HOCS_FRONTEND_DEMO_WCS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_DEMO_WCS}
    export DNS_PREFIX=demo.wcs-notprod
elif [[ ${KUBE_NAMESPACE} == "cs-dev" ]] ; then
    echo "deploy ${VERSION} to DEV namespace, HOCS_FRONTEND_DEV_CS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_DEV_CS}
    export DNS_PREFIX=dev.internal.cs-notprod
elif [[ ${KUBE_NAMESPACE} == "wcs-dev" ]] ; then
    echo "deploy ${VERSION} to DEV namespace, HOCS_FRONTEND_DEV_WCS drone secret"
    export KUBE_TOKEN=${HOCS_FRONTEND_DEV_WCS}
    export DNS_PREFIX=dev.wcs-notprod
    export REPLICAS="1"
else
    1>&2 echo "Unable to find environment: ${ENVIRONMENT}"
    exit 1
fi

if [[ -z ${KUBE_TOKEN} ]] ; then
    1>&2  echo "Failed to find a value for KUBE_TOKEN - exiting"
    exit 1
fi

if [[ $NOTPROD == "true" ]]; then
  export KC_REALM=https://sso-dev.notprod.homeoffice.gov.uk
  export REPLICAS="1"
  export CLUSTER_NAME="acp-notprod"
else
  export KC_REALM=https://sso.digital.homeoffice.gov.uk/auth/realms/HOCS
  export REPLICAS="2"
  export CLUSTER_NAME="acp-prod"
fi

export DNS_SUFFIX=.homeoffice.gov.uk
export DOMAIN_NAME=${DNS_PREFIX}${DNS_SUFFIX}

if [[ $DNS_PREFIX == *"internal"* ]]; then
  export INGRESS_TYPE="internal"
else
  export INGRESS_TYPE="external"
fi

echo
echo "Deploying hocs-frontend to ${ENVIRONMENT}"
echo "Keycloak realm: ${KC_REALM}"
echo "Keycloak domain: ${KC_DOMAIN}"
echo "${INGRESS_TYPE} domain: ${DOMAIN_NAME}"
echo

cd kd || exit 1

export KUBE_CERTIFICATE_AUTHORITY=/tmp/acp.crt
if ! curl --silent --fail --retry 5 \
    https://raw.githubusercontent.com/UKHomeOffice/acp-ca/master/$CLUSTER_NAME.crt -o $KUBE_CERTIFICATE_AUTHORITY; then
  1>&2 echo "[error] failed to download ca for kube api"
  exit 1
fi

kd \
   --timeout 10m \
    -f ingress-${INGRESS_TYPE}.yaml \
    -f converter-configmap.yaml \
    -f configmap.yaml \
    -f deployment.yaml \
    -f service.yaml \
    -f autoscale.yaml

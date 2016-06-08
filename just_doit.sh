#!/bin/bash
# Run from project root directory

###############################################################################
# ca-key.pem ca.pem
###############################################################################
echo ""

if [ -e ./certs/ca-key.pem ]; then
  echo "ca-key.pem already exists not creating again ..."
else
  echo "Creating ca-key.pem, ca.pem ca.csr ..."

  rm -rf certs
  mkdir -p certs

  cd certs
  cfssl gencert -initca ../ca-csr.json | cfssljson -bare ca -
  cd ..
  echo "Created ca-key.pem, ca.pem in ./certs directory"
fi

echo ""

###############################################################################
# cluster configs
###############################################################################
echo ""

if [ -e ./cluster_config ]; then
  echo "cluster_config already exists using existing values ..."
  source ./cluster_config
else

  # !IMPORTANT
  # SET DEFAULT VALUES HERE

  ETCD_CLUSTER_SIZE=2
  MASTER_CLUSTER_SIZE=1
  MINION_CLUSTER_SIZE=2
  # Flannel range for docker containers
  POD_NETWORK='10.2.0.0/16'
  SERVICE_IP_RANGE='10.3.0.0/24'
  KUBERNETES_SERVICE_IP='10.3.0.1'
  DNS_SERVICE_IP='10.3.0.10'

  echo "Getting new discovery token..."
  _ETCD_DISCOVERY_URL=$(curl -s https://discovery.etcd.io/new?size=$ETCD_CLUSTER_SIZE)
  ETCD_DISCOVERY_TOKEN=${_ETCD_DISCOVERY_URL##*/}
  echo "Discovery token is ${ETCD_DISCOVERY_TOKEN}"

  echo "Getting kubernetes stable version..."
  K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
  echo "Kubernetes Stable Version is ${K8S_VERSION}"
  echo ""

  PARAMS="{
    \"ETCD_CLUSTER_SIZE\": \"$ETCD_CLUSTER_SIZE\",
    \"MASTER_CLUSTER_SIZE\": \"$MASTER_CLUSTER_SIZE\",
    \"MINION_CLUSTER_SIZE\": \"$MINION_CLUSTER_SIZE\",
    \"POD_NETWORK\": \"$POD_NETWORK\",
    \"SERVICE_IP_RANGE\": \"$SERVICE_IP_RANGE\",
    \"KUBERNETES_SERVICE_IP\": \"$KUBERNETES_SERVICE_IP\",
    \"DNS_SERVICE_IP\": \"$DNS_SERVICE_IP\",
    \"ETCD_DISCOVERY_TOKEN\": \"$ETCD_DISCOVERY_TOKEN\",
    \"K8S_VERSION\": \"$K8S_VERSION\"
  }"

  echo ""
  echo "Generating cluster_config file with following values ..."
  echo ""
  echo "$PARAMS"
  hbs-templater compile --params "$PARAMS" \
    --input ./cluster_config_tpl \
    --output . \
    -l --overwrite

fi

echo ""

###############################################################################
# clean slate
###############################################################################
echo ""

echo "Running Terraform ..."

terraform plan \
  -var "etcd_discovery_token=$ETCD_DISCOVERY_TOKEN" \
  -var "etcd_count=$ETCD_CLUSTER_SIZE" \
  -var "k8s_version=$K8S_VERSION" \
  -var "k8s_service_ip=$KUBERNETES_SERVICE_IP" \
  -var "pod_network=$POD_NETWORK"

terraform apply \
  -var "etcd_discovery_token=$ETCD_DISCOVERY_TOKEN" \
  -var "etcd_count=$ETCD_CLUSTER_SIZE" \
  -var "k8s_version=$K8S_VERSION" \
  -var "k8s_service_ip=$KUBERNETES_SERVICE_IP" \
  -var "pod_network=$POD_NETWORK"

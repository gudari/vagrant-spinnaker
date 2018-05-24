#! /bin/bash

HAL_USER='spinnaker'
HAL_VERSION='1.7.5'
PUBLIC_URL='spinnaker.vagrant.local'
DOCKER_REGISTRY='dockerhub'
DOCKER_REGISTRY_URL='index.docker.io'
DOCKER_REPOSITORIES='library/nginx'
KUBERNETES_ACCOUNT='minikube'
KUBE_CONFIG_FILE="/home/$HAL_USER/config"
KUBE_CA_FILE="/home/$HAL_USER/ca.crt"
KUBE_CLIENT_CRT_FILE="/home/$HAL_USER/client.crt"
KUBE_CLIENT_KEY_FILE="/home/$HAL_USER/client.key"

function install_halyard {
  if [ ! $(which hal) ]; then
    curl -o /InstallHalyard.sh https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh
    useradd -g users -d /home/$HAL_USER -s /bin/bash $HAL_USER
    export HAL_USER=$HAL_USER
    chmod 777 /InstallHalyard.sh
    /InstallHalyard.sh
  else
    update-halyard
    hal -v
  fi
}

function configure_halyard {
  hal config deploy edit --type localdebian
  hal config version edit --version $HAL_VERSION

  apt-get install -y jq
  ACCESS_KEY=$(sed -e 's/^"//' -e 's/"$//' <<<"$(cat /home/minio/.minio/config.json | jq '.credential.accessKey')")
  SECRET_KEY=$(sed -e 's/^"//' -e 's/"$//' <<<"$(cat /home/minio/.minio/config.json | jq '.credential.secretKey')")
  echo $SECRET_KEY | hal config storage s3 edit --endpoint http://localhost:9001 --access-key-id $ACCESS_KEY --secret-access-key
  hal config storage edit --type s3

  cp /minikube/ca.crt $KUBE_CA_FILE && chmod 777 $KUBE_CA_FILE
  cp /minikube/client.crt $KUBE_CLIENT_CRT_FILE && chmod 777 $KUBE_CLIENT_CRT_FILE
  cp /minikube/client.key $KUBE_CLIENT_KEY_FILE && chmod 777 $KUBE_CLIENT_KEY_FILE

  cat > $KUBE_CONFIG_FILE <<EOFCONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority: $KUBE_CA_FILE
    server: https://192.168.99.101:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: $KUBE_CLIENT_CRT_FILE
    client-key: $KUBE_CLIENT_KEY_FILE
EOFCONFIG

  hal config provider docker-registry account add $DOCKER_REGISTRY \
    --address $DOCKER_REGISTRY_URL
  hal config provider docker-registry account edit $DOCKER_REGISTRY --add-repository $DOCKER_REPOSITORIES

  hal config provider docker-registry enable
  hal config provider kubernetes account add $KUBERNETES_ACCOUNT \
    --kubeconfig-file $KUBE_CONFIG_FILE \
    --provider-version v2

  hal config provider kubernetes enable

  hal config security ui edit \
    --override-base-url http://$PUBLIC_URL:9000

  hal config security api edit \
    --override-base-url http://$PUBLIC_URL:8084

  apt-get update && apt-get install -y apt-transport-https
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
  apt-get update
  apt-get install -y kubectl

  hal config canary enable

  hal deploy apply

  cat > /home/$HAL_USER/.hal/default/service-settings/gate.yml <<EOFGATE
port: 8084
host: 192.168.33.10
EOFGATE

  cat > /home/$HAL_USER/.hal/default/service-settings/deck.yml <<EOFDECK
port: 9000
host: 192.168.33.10
EOFDECK

  cat > /home/$HAL_USER/.hal/default/profiles/front50-local.yml <<EOFFRONT50
spinnaker.s3.versioning: false
EOFFRONT50

}

function deploy_halyard () {
  hal deploy apply
  systemctl daemon-reload
}

install_halyard
configure_halyard
deploy_halyard

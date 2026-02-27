#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd $SCRIPT_DIR

export $(grep -v '^#' .env | xargs)

k3d cluster create ${CLUSTER} \
  --agents 2 \
  --port ${HTTP_PORT}:80@loadbalancer \
  --port ${HTTPS_PORT}:443@loadbalancer \
  --k3s-arg "--disable=traefik@server:0" \
  --volume /etc/ssl/certs:/etc/ssl/certs

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT
mkcert -cert-file $WORK_DIR/cert.pem -key-file $WORK_DIR/key.pem  "*.${DOMAIN}"
kubectl create secret tls traefik-tls --key $WORK_DIR/key.pem --cert $WORK_DIR/cert.pem --namespace kube-system
rm -rf $WORK_DIR
trap - EXIT

cat helm/traefik-values.yaml | envsubst | \
  helm install traefik traefik/traefik --namespace kube-system -f - --wait
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Dashboard is available via HTTP at: http://traefik.${DOMAIN}:${HTTP_PORT}/dashboard/"
else
  echo "Dashboard is available via HTTP at: http://traefik.${DOMAIN}/dashboard/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Dashboard is available via HTTPS at: https://traefik.${DOMAIN}:${HTTPS_PORT}/dashboard/"
else
  echo "Dashboard is available via HTTPS at: https://traefik.${DOMAIN}/dashboard/"
fi
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

kubectl create namespace ingress-demo
cat manifest/whoami.yaml | envsubst | \
  kubectl apply -n ingress-demo -f -
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Whoami service is available via HTTP at: http://whoami.${DOMAIN}:${HTTP_PORT}/"
else
  echo "Whoami service is available via HTTP at: http://whoami.${DOMAIN}/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Whoami service is available via HTTPS at: https://whoami.${DOMAIN}:${HTTPS_PORT}/"
else
  echo "Whoami service is available via HTTPS at: https://whoami.${DOMAIN}/"
fi
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

cat helm/kite-values.yaml | envsubst | \
  helm install kite kite/kite --namespace kube-system -f - --wait
cat traefik/kite-ingress.yaml | envsubst | \
  kubectl apply -n kube-system -f -
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Kite dashboard is available via HTTP at: http://kite.${DOMAIN}:${HTTP_PORT}/"
else
  echo "Kite dashboard is available via HTTP at: http://kite.${DOMAIN}/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Kite dashboard is available via HTTPS at: https://kite.${DOMAIN}:${HTTPS_PORT}/"
else
  echo "Kite dashboard is available via HTTPS at: https://kite.${DOMAIN}/"
fi
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

cat helm/headlamp-values.yaml | envsubst | \
  helm install headlamp headlamp/headlamp --namespace kube-system -f - --wait
cat traefik/headlamp-ingress.yaml | envsubst | \
  kubectl apply -n kube-system -f -
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Headlamp dashboard is available via HTTP at: http://headlamp.${DOMAIN}:${HTTP_PORT}/"
else
  echo "Headlamp dashboard is available via HTTP at: http://headlamp.${DOMAIN}/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Headlamp dashboard is available via HTTPS at: https://headlamp.${DOMAIN}:${HTTPS_PORT}/"
else
  echo "Headlamp dashboard is available via HTTPS at: https://headlamp.${DOMAIN}/"
fi
echo "You can login to headlamp dashboard with token: $(kubectl -n kube-system create token headlamp --duration 24h)"
echo "$(tput setaf 2)===================================================================$(tput sgr0)"


cat helm/argocd-values.yaml | envsubst | \
  helm install argocd argo/argo-cd --namespace argocd --create-namespace -f - --wait
cat traefik/argocd-ingress.yaml | envsubst | \
  kubectl apply -n argocd -f -
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Argo CD dashboard is available via HTTP at: http://argocd.${DOMAIN}:${HTTP_PORT}/"
else
  echo "Argo CD dashboard is available via HTTP at: http://argocd.${DOMAIN}/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Argo CD dashboard is available via HTTPS at: https://argocd.${DOMAIN}:${HTTPS_PORT}/"
else
  echo "Argo CD dashboard is available via HTTPS at: https://argocd.${DOMAIN}/"
fi
echo "You can login to argo cd dashboard with username: admin and password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)"
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

export RANDOM_PASSWORD=$(openssl rand -base64 12)
cat helm/gitea-values.yaml | envsubst | \
  helm install gitea gitea-charts/gitea --namespace gitea --create-namespace -f - --wait
cat traefik/gitea-ingress.yaml | envsubst | \
  kubectl apply -n gitea -f -
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
if [ "${HTTP_PORT}" -ne 80 ]
then
  echo "Gitea dashboard is available via HTTP at: http://gitea.${DOMAIN}:${HTTP_PORT}/"
else
  echo "Gitea dashboard is available via HTTP at: http://gitea.${DOMAIN}/"
fi
if [ "${HTTPS_PORT}" -ne 443 ]
then
  echo "Gitea dashboard is available via HTTPS at: https://gitea.${DOMAIN}:${HTTPS_PORT}/"
else
  echo "Gitea dashboard is available via HTTPS at: https://gitea.${DOMAIN}/"
fi
echo "You can login to gitea dashboard with username: admin and password: ${RANDOM_PASSWORD}"
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

echo "$(tput setaf 2)===================================================================$(tput sgr0)"
echo "All setup is done! Enjoy your development environment! 🚀"
echo "You can set automatic completion for the CLI tools with the following commands:"
echo "$(tput setaf 2)===================================================================$(tput sgr0)"
echo "  source <(k3d completion bash)"
echo "  source <(kubectl completion bash)"
echo "  source <(kustomize completion bash)"
echo "  source <(helm completion bash)"
echo "  source <(argocd completion bash)"
echo "$(tput setaf 2)===================================================================$(tput sgr0)"

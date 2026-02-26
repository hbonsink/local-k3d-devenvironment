#!/bin/bash
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd $SCRIPT_DIR

export $(grep -v '^#' .env | xargs)

# install k3d
if ! command -v k3d &> /dev/null
then
    echo "k3d could not be found, installing..."
    DownloadUrl=$(curl -s https://api.github.com/repos/k3d-io/k3d/releases/latest | jq .assets[].browser_download_url | grep linux-amd64 | tr -d \")
    curl -sSL -o k3d "$DownloadUrl"
    chmod +x k3d
    mv k3d ~/.local/bin/
fi

# install kustomize
if ! command -v kustomize &> /dev/null
then
    echo "kustomize could not be found, installing..."
    DownloadUrl=$(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq .assets[].browser_download_url | grep linux_amd64 | tr -d \")
    curl -sSL -o kustomize.tar.gz "$DownloadUrl"
    tar -xzf kustomize.tar.gz
    mv kustomize ~/.local/bin/
    rm kustomize.tar.gz
fi

# install kubectl
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found, installing..."
    curl -sSL -o kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl ~/.local/bin/
fi

# install helm
if ! command -v helm &> /dev/null
then
    echo "helm could not be found, installing..."
    helmVersion=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq .tag_name | tr -d \")
    curl -sSL -o helm.tar.gz "https://get.helm.sh/helm-${helmVersion}-linux-amd64.tar.gz"
    tar -xzf helm.tar.gz
    mv linux-amd64/helm ~/.local/bin/
    rm -rf linux-amd64 helm.tar.gz
fi

# install argocd cli
if ! command -v argocd &> /dev/null
then
    echo "argocd cli could not be found, installing..."
    argocdVersion=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq .tag_name | tr -d \")
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${argocdVersion}/argocd-linux-amd64"
    chmod +x argocd
    mv argocd ~/.local/bin/
fi
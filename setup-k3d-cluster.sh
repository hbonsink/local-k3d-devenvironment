#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd $SCRIPT_DIR

export $(grep -v '^#' .env | envsubst | xargs)

# Default flags - install everything by default
INSTALL_TOOLS=true
INSTALL_SERVICE_MESH=true
INSTALL_INGRESS_DEMO=true
INSTALL_KITE=true
INSTALL_HEADLAMP=true
INSTALL_ARGOCD=true
INSTALL_GITEA=true
FORCE_TOOLS=false
SERVICE_MESH_TYPE=traefik-mesh  # Options: linkerd, traefik-mesh

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Sets up a local k3d development environment with various tools and services.

OPTIONS:
  -t, --tools           Install CLI tools (k3d, kubectl, helm, etc.)
  -s, --service-mesh    Install service mesh (use --mesh-type to select: linkerd or traefik-mesh)
  -i, --ingress-demo    Install ingress demo (whoami service)
  -k, --kite            Install Kite dashboard
  -h, --headlamp        Install Headlamp dashboard
  -a, --argocd          Install ArgoCD
  -g, --gitea           Install Gitea
  -A, --all             Install all components (default)
  -n, --none            Install only cluster, certificates, and Traefik
  -f, --force-tools     Force reinstall tools even if already present (latest versions)
  -c, --check-tools     Check if all required tools are available (dry-run)
  -m, --mesh-type TYPE  Select service mesh type: traefik-mesh (default) or linkerd
      --help            Show this help message

EXAMPLES:
  $0                    # Install everything (default)
  $0 --all              # Install everything
  $0 --none             # Install only basic cluster setup
  $0 -t -s -a           # Install tools, service mesh, and ArgoCD only
  $0 --tools --argocd   # Install tools and ArgoCD only
  $0 --force-tools      # Force reinstall all tools to latest versions
  $0 --check-tools      # Check if all required tools are available
  $0 --service-mesh --mesh-type linkerd  # Install with Linkerd instead of default Traefik Mesh

NOTE: Cluster creation, certificate setup, and Traefik are always installed.
      Service mesh defaults to Traefik Mesh unless --mesh-type is specified.
EOF
}

install_tools() {
  if [ "$FORCE_TOOLS" = true ]; then
    echo "Force installing latest versions of all required tools..."
  else
    echo "Checking and installing required tools..."
  fi
  
  # install k3d
  if [ "$FORCE_TOOLS" = true ] || ! command -v k3d &> /dev/null
  then
      echo "Installing k3d..."
      DownloadUrl=$(curl -s https://api.github.com/repos/k3d-io/k3d/releases/latest | jq .assets[].browser_download_url | grep linux-amd64 | tr -d \")
      curl -sSL -o k3d "$DownloadUrl"
      chmod +x k3d
      mv k3d ~/.local/bin/
  fi

  # install kustomize
  if [ "$FORCE_TOOLS" = true ] || ! command -v kustomize &> /dev/null
  then
      echo "Installing kustomize..."
      DownloadUrl=$(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq .assets[].browser_download_url | grep linux_amd64 | tr -d \")
      curl -sSL -o kustomize.tar.gz "$DownloadUrl"
      tar -xzf kustomize.tar.gz
      mv kustomize ~/.local/bin/
      rm kustomize.tar.gz
  fi

  # install kubectl
  if [ "$FORCE_TOOLS" = true ] || ! command -v kubectl &> /dev/null
  then
      echo "Installing kubectl..."
      curl -sSL -o kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      mv kubectl ~/.local/bin/
  fi

  # install helm
  if [ "$FORCE_TOOLS" = true ] || ! command -v helm &> /dev/null
  then
      echo "Installing helm..."
      helmVersion=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq .tag_name | tr -d \")
      curl -sSL -o helm.tar.gz "https://get.helm.sh/helm-${helmVersion}-linux-amd64.tar.gz"
      tar -xzf helm.tar.gz
      mv linux-amd64/helm ~/.local/bin/
      rm -rf linux-amd64 helm.tar.gz
  fi

  # install argocd cli
  if [ "$FORCE_TOOLS" = true ] || ! command -v argocd &> /dev/null
  then
      echo "Installing argocd cli..."
      argocdVersion=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq .tag_name | tr -d \")
      curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${argocdVersion}/argocd-linux-amd64"
      chmod +x argocd
      mv argocd ~/.local/bin/
  fi

  # install linkerd2 cli
  if [ "$FORCE_TOOLS" = true ] || ! command -v linkerd &> /dev/null
  then
      echo "Installing linkerd2 cli..."
      DownloadUrl=$(curl -s https://api.github.com/repos/linkerd/linkerd2/releases/latest | jq .assets[].browser_download_url | grep linux-amd64 | tr -d \")
      curl -sSL -o linkerd "$DownloadUrl"
      chmod +x linkerd
      mv linkerd ~/.local/bin/
  fi

  # install step cli
  if [ "$FORCE_TOOLS" = true ] || ! command -v step &> /dev/null
  then
      echo "Installing step cli..."
      stepVersion=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | jq .tag_name | tr -d \")
      curl -sSL -o step.tar.gz "https://github.com/smallstep/cli/releases/download/${stepVersion}/step_linux_amd64.tar.gz"
      tar -xzf step.tar.gz --strip-components=2 step_linux_amd64/bin/step
      chmod +x step
      mv step ~/.local/bin/
      rm -rf step.tar.gz
  fi
  
  echo "All tools are installed and ready!"
}

add_helm_repos() {
  echo "Configuring required Helm repositories..."
  
  # Array of repository name and URL pairs
  local repos=(
    "traefik|https://traefik.github.io/charts"
    "linkerd-edge|https://helm.linkerd.io/edge"
    "kite|https://kite-sh.github.io/helm-charts"
    "headlamp|https://headlamp-k8s.github.io/headlamp"
    "argo|https://argoproj.github.io/argo-helm"
    "gitea-charts|https://dl.gitea.com/charts"
  )
  
  for repo_pair in "${repos[@]}"; do
    IFS='|' read -r repo_name repo_url <<< "$repo_pair"
    
    # Check if repo already exists
    if helm repo list 2>/dev/null | grep -q "^${repo_name}[[:space:]]"; then
      echo "  ✓ ${repo_name} repository already configured"
    else
      echo "  + Adding ${repo_name} repository: ${repo_url}"
      if helm repo add "$repo_name" "$repo_url"; then
        echo "    ✓ Successfully added ${repo_name} repository"
      else
        echo "    ✗ Failed to add ${repo_name} repository"
        exit 1
      fi
    fi
  done
  
  # Update repository information
  echo "  Updating repository information..."
  if helm repo update; then
    echo "  ✓ Repository information updated successfully"
  else
    echo "  ✗ Failed to update repository information"
    exit 1
  fi
  
  echo "Helm repositories configured successfully!"
}

check_tools() {
  echo "Checking for required tools..."
  local missing_tools=()
  local missing_optional_tools=()
  
  # Required system tools (always needed)
  local required_tools=(
    "curl"     # For downloading tools and API calls
    "jq"       # For parsing JSON from GitHub API
    "envsubst" # For environment variable substitution in configs
    "tar"      # For extracting downloaded archives
    "grep"     # For filtering environment files
    "base64"   # For password decoding
    "openssl"  # For generating random passwords
    "tput"     # For colorized output
  )
  
  # Kubernetes/Container tools (may be installed by install_tools function)
  local k8s_tools=(
    "k3d"       # Creates k3s clusters in Docker
    "kubectl"   # Kubernetes CLI
    "helm"      # Package manager for Kubernetes
    "kustomize" # Kubernetes configuration management
    "step"      # Certificate management (smallstep CLI)
  )
  
  # Optional tools (only needed if specific components are enabled)
  local optional_tools=(
    "linkerd"   # Service mesh CLI (only if service mesh enabled)
    "argocd"    # ArgoCD CLI (only if ArgoCD enabled)
  )
  
  # Check required system tools
  echo "  Checking required system tools..."
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
    else
      echo "    ✓ $tool"
    fi
  done
  
  # Check Kubernetes tools
  echo "  Checking Kubernetes tools..."
  for tool in "${k8s_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      if [ "$INSTALL_TOOLS" = true ]; then
        echo "    ⚠ $tool (will be installed by script)"
      else
        missing_tools+=("$tool")
      fi
    else
      echo "    ✓ $tool"
    fi
  done
  
  # Check optional tools
  echo "  Checking optional tools..."
  for tool in "${optional_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      case "$tool" in
        "linkerd")
          if [ "$INSTALL_SERVICE_MESH" = true ] && [ "$SERVICE_MESH_TYPE" = "linkerd" ]; then
            if [ "$INSTALL_TOOLS" = true ]; then
              echo "    ⚠ $tool (will be installed by script)"
            else
              missing_optional_tools+=("$tool")
            fi
          else
            if [ "$INSTALL_SERVICE_MESH" = true ] && [ "$SERVICE_MESH_TYPE" = "traefik-mesh" ]; then
              echo "    - $tool (not needed - using Traefik Mesh)"
            else
              echo "    - $tool (not needed - service mesh disabled)"
            fi
          fi
          ;;
        "argocd")
          if [ "$INSTALL_ARGOCD" = true ]; then
            if [ "$INSTALL_TOOLS" = true ]; then
              echo "    ⚠ $tool (will be installed by script)"
            else
              missing_optional_tools+=("$tool")
            fi
          else
            echo "    - $tool (not needed - ArgoCD disabled)"
          fi
          ;;
      esac
    else
      echo "    ✓ $tool"
    fi
  done
  
  # Check Docker (required for k3d but not called directly by script)
  echo "  Checking Docker (required for k3d)..."
  if ! command -v docker &> /dev/null; then
    echo "    ✗ docker (required for k3d to work)"
    missing_tools+=("docker")
  elif ! docker info &> /dev/null; then
    echo "    ✗ docker (installed but not running or accessible)"
    missing_tools+=("docker-access")
  else
    echo "    ✓ docker"
  fi
  
  # Report results
  echo
  if [ ${#missing_tools[@]} -eq 0 ] && [ ${#missing_optional_tools[@]} -eq 0 ]; then
    echo "✅ All required tools are available!"
    return 0
  else
    echo "❌ Some tools are missing:"
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
      echo "  Required tools missing:"
      for tool in "${missing_tools[@]}"; do
        case "$tool" in
          "docker")
            echo "    - $tool: Install Docker Desktop or Docker Engine"
            ;;
          "docker-access")
            echo "    - docker access: Start Docker daemon or add user to docker group"
            ;;
          "jq")
            echo "    - $tool: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)"
            ;;
          "envsubst")
            echo "    - $tool: sudo apt install gettext-base (Ubuntu/Debian)"
            ;;
          *)
            echo "    - $tool: Check your system package manager"
            ;;
        esac
      done
    fi
    
    if [ ${#missing_optional_tools[@]} -gt 0 ]; then
      echo "  Optional tools missing (needed for enabled features):"
      for tool in "${missing_optional_tools[@]}"; do
        echo "    - $tool: Enable --tools option to auto-install"
      done
    fi
    
    echo
    echo "💡 To install missing Kubernetes tools automatically, use: $0 --tools"
    echo "💡 For system tools, install them using your system package manager"
    return 1
  fi
}

parse_options() {
  # If --none is specified, disable all optional components
  if [[ " $* " =~ " --none " ]] || [[ " $* " =~ " -n " ]]; then
    INSTALL_TOOLS=false
    INSTALL_SERVICE_MESH=false
    INSTALL_INGRESS_DEMO=false
    INSTALL_KITE=false
    INSTALL_HEADLAMP=false
    INSTALL_ARGOCD=false
    INSTALL_GITEA=false
  fi

  # If specific options are provided (and not --all), disable all first then enable selected
  if [[ $# -gt 0 ]] && [[ ! " $* " =~ " --all " ]] && [[ ! " $* " =~ " -A " ]] && [[ ! " $* " =~ " --none " ]] && [[ ! " $* " =~ " -n " ]] && [[ ! " $* " =~ " --help " ]]; then
    INSTALL_TOOLS=false
    INSTALL_SERVICE_MESH=false
    INSTALL_INGRESS_DEMO=false
    INSTALL_KITE=false
    INSTALL_HEADLAMP=false
    INSTALL_ARGOCD=false
    INSTALL_GITEA=false
  fi

  while [[ $# -gt 0 ]]; do
    case $1 in
      -t|--tools)
        INSTALL_TOOLS=true
        shift
        ;;
      -s|--service-mesh)
        INSTALL_SERVICE_MESH=true
        shift
        ;;
      -i|--ingress-demo)
        INSTALL_INGRESS_DEMO=true
        shift
        ;;
      -k|--kite)
        INSTALL_KITE=true
        shift
        ;;
      -h|--headlamp)
        INSTALL_HEADLAMP=true
        shift
        ;;
      -a|--argocd)
        INSTALL_ARGOCD=true
        shift
        ;;
      -g|--gitea)
        INSTALL_GITEA=true
        shift
        ;;
      -f|--force-tools)
        FORCE_TOOLS=true
        INSTALL_TOOLS=true
        shift
        ;;
      -c|--check-tools)
        check_tools
        exit $?
        ;;
      -m|--mesh-type)
        if [[ -n $2 && $2 != -* ]]; then
          if [[ "$2" == "linkerd" || "$2" == "traefik-mesh" ]]; then
            SERVICE_MESH_TYPE="$2"
            shift 2
          else
            echo "Error: Invalid mesh type '$2'. Valid options: linkerd, traefik-mesh"
            exit 1
          fi
        else
          echo "Error: --mesh-type requires a value (linkerd or traefik-mesh)"
          exit 1
        fi
        ;;
      -A|--all)
        INSTALL_TOOLS=true
        INSTALL_SERVICE_MESH=true
        INSTALL_INGRESS_DEMO=true
        INSTALL_KITE=true
        INSTALL_HEADLAMP=true
        INSTALL_ARGOCD=true
        INSTALL_GITEA=true
        shift
        ;;
      -n|--none)
        # Already handled above
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

create_cluster() {
  echo "Creating k3d cluster..."
  k3d cluster create ${CLUSTER} \
    --agents 2 \
    --port ${HTTP_PORT}:80@loadbalancer \
    --port ${HTTPS_PORT}:443@loadbalancer \
    --k3s-arg "--disable=traefik@server:0" \
    --volume /etc/ssl/certs:/etc/ssl/certs \
    --runtime-ulimit "nofile=32768:65536" \
    --wait
}

create_certificates() {
  echo "Creating certificates..."
  # Create persistent CA directory if it doesn't exist
  if [ ! -d "$CA_DIR" ]; then
    echo "Creating CA directory at $CA_DIR..."
    mkdir -p $CA_DIR
  fi

  # Create root CA if it doesn't exist
  if [ ! -f "$CA_DIR/ca.crt" ] || [ ! -f "$CA_DIR/ca.key" ]; then
    echo "Creating new root CA in $CA_DIR..."
    step certificate create "Local Development Root CA" $CA_DIR/ca.crt $CA_DIR/ca.key \
      --profile root-ca --no-password --insecure
  else
    echo "Using existing root CA from $CA_DIR"
  fi

  WORK_DIR=$(mktemp -d)
  trap "rm -rf $WORK_DIR" EXIT
  # Create wildcard certificate for the domain
  step certificate create "Traefik Local Dev TLS termination" $WORK_DIR/cert.pem $WORK_DIR/key.pem \
    --profile leaf --not-after 8760h --no-password --insecure \
    --ca $CA_DIR/ca.crt --ca-key $CA_DIR/ca.key \
    --san "*.${DOMAIN}" --san "${DOMAIN}" --san "127.0.0.1"
  kubectl create namespace traefik
  kubectl create secret tls traefik-tls --key $WORK_DIR/key.pem --cert $WORK_DIR/cert.pem --namespace traefik
  rm -rf $WORK_DIR
  trap - EXIT
}

install_traefik() {
  echo "Installing Traefik..."
  cat helm/traefik-values.yaml | envsubst | \
    helm install traefik traefik/traefik --namespace traefik -f - --wait
  cat nginx/ingress-class.yaml | envsubst | \
    kubectl apply -n traefik -f -
  
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
}

install_service_mesh() {
  echo "Installing ${SERVICE_MESH_TYPE} service mesh..."
  
  case "${SERVICE_MESH_TYPE}" in
    "linkerd")
      install_linkerd_mesh
      ;;
    "traefik-mesh")
      install_traefik_mesh
      ;;
    *)
      echo "Error: Unknown service mesh type '${SERVICE_MESH_TYPE}'"
      echo "Supported types: linkerd, traefik-mesh"
      exit 1
      ;;
  esac
}

install_linkerd_mesh() {
  echo "Installing Linkerd service mesh..."
  export WORK_DIR=$(mktemp -d)
  trap "rm -rf $WORK_DIR" EXIT
  step certificate create identity.linkerd.cluster.local $WORK_DIR/issuer.crt $WORK_DIR/issuer.key \
    --profile intermediate-ca --not-after 8760h --no-password --insecure \
    --ca $CA_DIR/ca.crt --ca-key $CA_DIR/ca.key
  helm install linkerd-crds linkerd-edge/linkerd-crds -n linkerd --create-namespace --wait
  helm install linkerd-control-plane linkerd-edge/linkerd-control-plane --namespace linkerd --wait \
    --set-file identityTrustAnchorsPEM=$CA_DIR/ca.crt \
    --set-file identity.issuer.tls.crtPEM=$WORK_DIR/issuer.crt \
    --set-file identity.issuer.tls.keyPEM=$WORK_DIR/issuer.key \
    --set disableHeartBeat=true
  helm install linkerd-viz linkerd-edge/linkerd-viz --namespace linkerd-viz --create-namespace --wait
  cat gw-api/linkerd-viz-httproute.yaml | envsubst | \
    kubectl apply -n linkerd-viz -f -
  rm -rf $WORK_DIR
  trap - EXIT
  
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
  if [ "${HTTP_PORT}" -ne 80 ]
  then
    echo "Linkerd Viz dashboard is available via HTTP at: http://linkerd-viz.${DOMAIN}:${HTTP_PORT}/"
  else
    echo "Linkerd Viz dashboard is available via HTTP at: http://linkerd-viz.${DOMAIN}/"
  fi
  if [ "${HTTPS_PORT}" -ne 443 ]
  then
    echo "Linkerd Viz dashboard is available via HTTPS at: https://linkerd-viz.${DOMAIN}:${HTTPS_PORT}/"
  else
    echo "Linkerd Viz dashboard is available via HTTPS at: https://linkerd-viz.${DOMAIN}/"
  fi
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
}

install_traefik_mesh() {
  echo "Installing Traefik Mesh service mesh..."
  
  # Install Traefik Mesh using Helm
  helm install traefik-mesh traefik/traefik-mesh \
    --namespace traefik-mesh \
    --create-namespace \
    --set controller.logLevel=INFO \
    --set metrics.prometheus.enabled=true \
    --set tracing.jaeger.enabled=false \
    --wait
  
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
  echo "Traefik Mesh installed successfully!"
  echo "To view mesh status, use: kubectl get pods -n traefik-mesh"
  echo "To enable mesh for a namespace, use: kubectl label namespace <namespace> mesh.traefik.io/traffic-type=http"
  if [ "${HTTP_PORT}" -ne 80 ]
  then
    echo "Traefik Mesh API is available via HTTP at: http://traefik-mesh-api.${DOMAIN}:${HTTP_PORT}/"
  else
    echo "Traefik Mesh API is available via HTTP at: http://traefik-mesh-api.${DOMAIN}/"
  fi
  if [ "${HTTPS_PORT}" -ne 443 ]
  then
    echo "Traefik Mesh API is available via HTTPS at: https://traefik-mesh-api.${DOMAIN}:${HTTPS_PORT}/"
  else
    echo "Traefik Mesh API is available via HTTPS at: https://traefik-mesh-api.${DOMAIN}/"
  fi
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
}

install_ingress_demo() {
  echo "Installing ingress demo (whoami service)..."
  kubectl create namespace ingress-demo
  cat manifest/whoami.yaml | envsubst | \
    kubectl apply -n ingress-demo -f -
  cat traefik/whoami-ingress.yaml | envsubst | \
    kubectl apply -n ingress-demo -f -
  cat nginx/whoami-ingress.yaml | envsubst | \
    kubectl apply -n ingress-demo -f -
  cat gw-api/whoami-httproute.yaml | envsubst | \
    kubectl apply -n ingress-demo -f -
  
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
  if [ "${HTTP_PORT}" -ne 80 ]
  then
    echo "Whoami service is available via Traefik ingress HTTP at: http://whoami-traefik.${DOMAIN}:${HTTP_PORT}/"
    echo "Whoami service is available via Nginx ingress HTTP at: http://whoami-nginx.${DOMAIN}:${HTTP_PORT}/"
    echo "Whoami service is available via Gateway API HTTP at: http://whoami-httproute.${DOMAIN}:${HTTP_PORT}/"
  else
    echo "Whoami service is available via Traefik ingress HTTP at: http://whoami-traefik.${DOMAIN}/"
    echo "Whoami service is available via Nginx ingress HTTP at: http://whoami-nginx.${DOMAIN}/"
    echo "Whoami service is available via Gateway API HTTP at: http://whoami-httproute.${DOMAIN}/"
  fi
  if [ "${HTTPS_PORT}" -ne 443 ]
  then
    echo "Whoami service is available via Traefik ingress HTTPS at: https://whoami-traefik.${DOMAIN}:${HTTPS_PORT}/"
    echo "Whoami service is available via Nginx ingress HTTPS at: https://whoami-nginx.${DOMAIN}:${HTTPS_PORT}/"
    echo "Whoami service is available via Gateway API HTTPS at: https://whoami-httproute.${DOMAIN}:${HTTPS_PORT}/"
  else
    echo "Whoami service is available via Traefik ingress HTTPS at: https://whoami-traefik.${DOMAIN}/"
    echo "Whoami service is available via Nginx ingress HTTPS at: https://whoami-nginx.${DOMAIN}/"
    echo "Whoami service is available via Gateway API HTTPS at: https://whoami-httproute.${DOMAIN}/"
  fi
  echo "$(tput setaf 2)===================================================================$(tput sgr0)"
}

install_kite() {
  echo "Installing Kite dashboard..."
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
}

install_headlamp() {
  echo "Installing Headlamp dashboard..."
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
}

install_argocd() {
  echo "Installing ArgoCD..."
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
}

install_gitea() {
  echo "Installing Gitea..."
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
}

output_completion_messages() {
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
}

# Main execution
parse_options "$@"

# Check tools availability before starting setup
echo "Pre-flight check..."
if ! check_tools; then
  echo
  echo "❌ Setup cannot continue due to missing required tools."
  echo "💡 Install missing system tools, then re-run this script."
  echo "💡 Kubernetes tools can be auto-installed with --tools option."
  exit 1
fi
echo

if [ "$INSTALL_TOOLS" = true ]; then
  install_tools
fi

# Configure Helm repositories
add_helm_repos

# Always install core components
create_cluster
create_certificates
install_traefik

# Optional components based on flags
if [ "$INSTALL_SERVICE_MESH" = true ]; then
  install_service_mesh
fi

if [ "$INSTALL_INGRESS_DEMO" = true ]; then
  install_ingress_demo
fi

if [ "$INSTALL_KITE" = true ]; then
  install_kite
fi

if [ "$INSTALL_HEADLAMP" = true ]; then
  install_headlamp
fi

if [ "$INSTALL_ARGOCD" = true ]; then
  install_argocd
fi

if [ "$INSTALL_GITEA" = true ]; then
  install_gitea
fi

output_completion_messages

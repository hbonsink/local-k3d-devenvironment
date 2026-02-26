# Local k3d Development Environment

A comprehensive local Kubernetes development environment setup using [k3d](https://k3d.io/) with essential development tools and services pre-configured for rapid development and testing.

## Overview

This repository provides an automated setup for a complete local Kubernetes development environment featuring:

- **k3d cluster** - Lightweight Kubernetes distribution running in Docker
- **Traefik** - Modern reverse proxy and load balancer with web dashboard
- **Kite** - Kubernetes IDE for cluster management and development
- **Headlamp** - Kubernetes dashboard for monitoring and management
- **ArgoCD** - GitOps continuous deployment platform
- **Gitea** - Self-hosted Git service with web interface
- **Whoami service** - Simple test application for ingress validation

## System Requirements

- **Operating System**: Linux (tested on WSL2 with Ubuntu environment)
- **Docker**: Required for k3d to run Kubernetes nodes
- **Required packages**: `jq`, `curl`, `envsubst` (gettext-base)
- **Internet connection**: Required for downloading tools and images

### Install Required Packages on Ubuntu

```bash
sudo apt update
sudo apt install -y jq curl gettext-base
```

## Quick Start

### 1. Install Required Tools (Optional)

If you don't have the required CLI tools installed, run the tool installer:

```bash
./get-tools.sh
```

This script will automatically install:
- k3d
- kubectl
- kustomize
- helm
- argocd CLI

### 2. Configure Environment

The setup uses a `.env` file for configuration. First, copy the sample configuration file:

```bash
cp .env_sample .env
```

Then modify the values in `.env` according to your needs:

```bash
# Default configuration in .env_sample
DOMAIN=127.0.0.1.sslip.io    # Base domain for all services
HTTP_PORT=8001               # HTTP port for accessing services
HTTPS_PORT=443              # HTTPS port (if SSL is configured)
CLUSTER=dev-cluster         # Name of the k3d cluster
```

**Note**: The default configuration uses `sslip.io` which provides wildcard DNS for IP addresses, making local development easier without needing to modify `/etc/hosts`.

### 3. Deploy the Development Environment

Run the main setup script to create your complete development environment:

```bash
./setup-k3d-cluster.sh
```

This script will:
1. Create a k3d cluster with 2 agent nodes
2. Install and configure Traefik as ingress controller
3. Deploy all development tools with proper ingress routing
4. Display access information for all services

## Available Services

After successful deployment, the following services will be available:

| Service | URL | Purpose | Credentials |
|---------|-----|---------|-------------|
| **Traefik Dashboard** | `http://traefik.127.0.0.1.sslip.io:8001/dashboard/` | Load balancer and routing management | No auth required |
| **Whoami Service** | `http://whoami.127.0.0.1.sslip.io:8001/` | Test service for ingress validation | No auth required |
| **Kite Dashboard** | `http://kite.127.0.0.1.sslip.io:8001/` | Kubernetes IDE and development tools | Admin account can be created at first login |
| **Headlamp Dashboard** | `http://headlamp.127.0.0.1.sslip.io:8001/` | Kubernetes cluster monitoring | Token provided by setup script |
| **ArgoCD** | `http://argocd.127.0.0.1.sslip.io:8001/` | GitOps continuous deployment | Username: `admin`, Password: shown by setup script |
| **Gitea** | `http://gitea.127.0.0.1.sslip.io:8001/` | Git repository management | Username: `admin`, Password: shown by setup script |

## Customization

### Helm Values

Each service can be customized by modifying the corresponding Helm values file in the [helm/](helm/) directory:

- `traefik-values.yaml` - Traefik configuration
- `kite-values.yaml` - Kite IDE settings
- `headlamp-values.yaml` - Headlamp dashboard configuration
- `argocd-values.yaml` - ArgoCD GitOps platform settings
- `gitea-values.yaml` - Gitea Git service configuration

### Ingress Routes

Ingress configurations are stored in the [traefik/](traefik/) directory and use environment variable substitution for flexible domain and port configuration.

## CLI Autocompletion

The setup script provides commands to enable autocompletion for all installed CLI tools:

```bash
source <(k3d completion bash)
source <(kubectl completion bash)
source <(kustomize completion bash)
source <(helm completion bash)
source <(argocd completion bash)
```

## Cleanup

To remove the development environment:

```bash
k3d cluster delete dev-cluster
```

## Testing Environment

This setup has been thoroughly tested on:
- **WSL2** with **Ubuntu** environment

## Troubleshooting

### Port Conflicts
If port 8001 is already in use, modify the `HTTP_PORT` value in the `.env` file before running the setup.

### DNS Resolution
The setup uses `sslip.io` for DNS resolution. If you experience DNS issues:
1. Ensure your system can resolve external DNS
2. Consider using `127.0.0.1.nip.io` as an alternative in the `.env` file

### Tool Installation Issues
If the `get-tools.sh` script fails, ensure:
- You have write permissions to `~/.local/bin/`
- `curl`, `jq`, and `tar` are available on your system

## Contributing

Feel free to submit issues and feature requests or contribute improvements to this development environment setup.

## License

See [LICENSE](LICENSE) file for details.
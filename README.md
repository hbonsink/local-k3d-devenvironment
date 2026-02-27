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
- **Required packages**: `jq`, `curl`, `envsubst` (gettext-base), `mkcert` (for SSL certificates)
- **Internet connection**: Required for downloading tools and images

### Install Required Packages on Ubuntu

```bash
sudo apt update
sudo apt install -y jq curl gettext-base mkcert

# Install the local CA in the system trust store
mkcert -install
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
2. Generate self-signed SSL certificates using mkcert for the configured domain
3. Install and configure Traefik as ingress controller with SSL support
4. Deploy all development tools with proper ingress routing
5. Display access information for all services (both HTTP and HTTPS)

## Available Services

After successful deployment, the following services will be available:

| Service | HTTP URL | HTTPS URL | Purpose | Credentials |
|---------|----------|-----------|---------|-------------|
| **Traefik Dashboard** | `http://traefik.127.0.0.1.sslip.io:8001/dashboard/` | `https://traefik.127.0.0.1.sslip.io/dashboard/` | Load balancer and routing management | No auth required |
| **Whoami Service** | `http://whoami.127.0.0.1.sslip.io:8001/` | `https://whoami.127.0.0.1.sslip.io/` | Test service for ingress validation | No auth required |
| **Kite Dashboard** | `http://kite.127.0.0.1.sslip.io:8001/` | `https://kite.127.0.0.1.sslip.io/` | Kubernetes IDE and development tools | Admin account can be created at first login |
| **Headlamp Dashboard** | `http://headlamp.127.0.0.1.sslip.io:8001/` | `https://headlamp.127.0.0.1.sslip.io/` | Kubernetes cluster monitoring | Token provided by setup script |
| **ArgoCD** | `http://argocd.127.0.0.1.sslip.io:8001/` | `https://argocd.127.0.0.1.sslip.io/` | GitOps continuous deployment | Username: `admin`, Password: shown by setup script |
| **Gitea** | `http://gitea.127.0.0.1.sslip.io:8001/` | `https://gitea.127.0.0.1.sslip.io/` | Git repository management | Username: `admin`, Password: shown by setup script |

## SSL/TLS Configuration

This setup automatically generates and configures self-signed SSL certificates using [mkcert](https://github.com/FiloSottile/mkcert) for secure HTTPS access to all services.

### Certificate Details

- **Certificate Authority**: Local CA created by mkcert
- **Certificate Scope**: Wildcard certificate for `*.{DOMAIN}` (e.g., `*.127.0.0.1.sslip.io`)
- **Storage**: Certificate is stored as a Kubernetes secret `traefik-tls` in the `kube-system` namespace
- **Validity**: Certificates are automatically trusted by browsers when mkcert CA is installed

### Accessing Services Securely

All services are available via both HTTP and HTTPS:
- **HTTP**: Uses the configured `HTTP_PORT` (default: 8001)
- **HTTPS**: Uses the configured `HTTPS_PORT` (default: 443)

**Note**: When using non-standard ports (not 80/443), only the HTTP URLs will include the port number in the output.

### Manual Certificate Installation (Windows with WSL2)

If you're using WSL2 and need to manually install the CA certificate in Microsoft Edge on Windows:

1. **Locate the certificate**: The mkcert CA certificate is stored in `$HOME/.local/share/mkcert/` on your WSL2 Linux distribution
2. **Access WSL2 filesystem from Windows**: Navigate to `\\wsl.localhost\<WSL Distribution Name>` (e.g., `\\wsl.localhost\Ubuntu-22.04`)
3. **Find the CA file**: Go to `home\<username>\.local\share\mkcert\` and copy the `rootCA.pem` file
4. **Install in Edge**:
   - Open Microsoft Edge
   - Go to Settings → Privacy, search, and services → Security → Manage certificates
   - Click on "Trusted Root Certification Authorities" tab
   - Click "Import..." and follow the wizard to import the `rootCA.pem` file
   - Restart Microsoft Edge

After installation, all HTTPS services will show as secure in Microsoft Edge.

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

### SSL Certificate Issues
If you encounter SSL certificate warnings:
1. Ensure mkcert is installed and the local CA is installed: `mkcert -install`
2. Verify the certificate was created successfully during cluster setup
3. Check that the `traefik-tls` secret exists: `kubectl get secret traefik-tls -n kube-system`
4. Restart your browser after installing the mkcert CA

### Tool Installation Issues
If the `get-tools.sh` script fails, ensure:
- You have write permissions to `~/.local/bin/`
- `curl`, `jq`, and `tar` are available on your system

If mkcert installation fails:
- Update your package list: `sudo apt update`
- Ensure you have appropriate permissions to install packages
- On older Ubuntu versions, mkcert might not be available in default repositories

## Contributing

Feel free to submit issues and feature requests or contribute improvements to this development environment setup.

## License

See [LICENSE](LICENSE) file for details.
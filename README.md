# Local k3d Development Environment

A comprehensive local Kubernetes development environment setup using [k3d](https://k3d.io/) with essential development tools and services pre-configured for rapid development and testing.

## Overview

This repository provides an automated setup for a complete local Kubernetes development environment featuring:

- **k3d cluster** - Lightweight Kubernetes distribution running in Docker
- **Traefik** - Modern reverse proxy and load balancer with web dashboard
- **Service Mesh** - Choice of Traefik Mesh (default) or Linkerd for microservice communication
- **Kite** - Kubernetes IDE for cluster management and development
- **Headlamp** - Kubernetes dashboard for monitoring and management
- **ArgoCD** - GitOps continuous deployment platform
- **Gitea** - Self-hosted Git service with web interface
- **Whoami service** - Simple test application for ingress validation

## System Requirements

- **Operating System**: Linux (tested on WSL2 with Ubuntu environment)
- **Docker**: Required for k3d to run Kubernetes nodes
- **Required packages**: `jq`, `curl`, `envsubst` (gettext-base), `step` (smallstep CLI for SSL certificates)
- **Internet connection**: Required for downloading tools and images

### Install Required Packages on Ubuntu

```bash
sudo apt update
sudo apt install -y tar grep coreutils ncurses-bin curl jq gettext-base openssl
# tar -> /usr/bin/tar
# grep -> /usr/bin/grep
# coreutils -> /usr/bin/base64
# ncurses-bin -> /usr/bin/tput
# curl -> /usr/bin/curl
# jq -> /usr/bin/jq
# gettext-base -> /usr/bin/envsubst
# openssl -> /usr/bin/openssl
```

## Quick Start

### 1. Configure Environment

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

### 2. Deploy the Development Environment

Run the main setup script to create your complete development environment:

```bash
./setup-k3d-cluster.sh
```

#### Command Line Options

The setup script supports various options for customized installations:

```bash
# Install everything (default behavior)
./setup-k3d-cluster.sh

# Install only basic cluster setup (cluster + Traefik)
./setup-k3d-cluster.sh --none

# Install specific components only
./setup-k3d-cluster.sh --tools --service-mesh --argocd

# Install with Linkerd service mesh instead of default Traefik Mesh
./setup-k3d-cluster.sh --service-mesh --mesh-type linkerd

# Force reinstall tools to latest versions
./setup-k3d-cluster.sh --force-tools

# Check if all required tools are available (dry-run)
./setup-k3d-cluster.sh --check-tools

# Show help with all available options
./setup-k3d-cluster.sh --help
```

#### Available Options:
- `--tools` - Install CLI tools (k3d, kubectl, helm, etc.)
- `--service-mesh` - Install service mesh (Traefik Mesh by default)
- `--mesh-type TYPE` - Select service mesh type: traefik-mesh (default) or linkerd
- `--ingress-demo` - Install ingress demo (whoami service)
- `--kite` - Install Kite dashboard
- `--headlamp` - Install Headlamp dashboard
- `--argocd` - Install ArgoCD
- `--gitea` - Install Gitea
- `--all` - Install all components (default)
- `--none` - Install only cluster, certificates, and Traefik
- `--force-tools` - Force reinstall tools even if already present
- `--check-tools` - Check if all required tools are available

### 3. What the Script Does

The setup script automatically handles the entire environment setup:

1. **Pre-flight Check**: Validates all required tools are available
2. **Tool Installation**: Automatically installs missing CLI tools (k3d, kubectl, helm, etc.)
3. **Helm Repository Configuration**: Adds and updates all required Helm repositories
4. **Cluster Creation**: Creates a k3d cluster with 2 agent nodes
5. **Certificate Setup**: Generates self-signed SSL certificates using smallstep CLI
6. **Traefik Installation**: Installs and configures Traefik as ingress controller with SSL support
7. **Service Mesh Setup**: Installs selected service mesh (Traefik Mesh by default, Linkerd optional)
8. **Service Deployment**: Deploys selected development tools with proper ingress routing
9. **Access Information**: Displays access URLs and credentials for all services

## Available Services

After successful deployment, the following services will be available:

| Service | HTTP URL | HTTPS URL | Purpose | Credentials |
|---------|----------|-----------|---------|-------------|
| **Traefik Dashboard** | `http://traefik.127.0.0.1.sslip.io:8001/dashboard/` | `https://traefik.127.0.0.1.sslip.io/dashboard/` | Load balancer and routing management | No auth required |
| **Linkerd Viz** | `http://linkerd-viz.127.0.0.1.sslip.io:8001/` | `https://linkerd-viz.127.0.0.1.sslip.io/` | Service mesh observability dashboard (Linkerd only) | No auth required |
| **Whoami Service** | `http://whoami.127.0.0.1.sslip.io:8001/` | `https://whoami.127.0.0.1.sslip.io/` | Test service for ingress validation | No auth required |
| **Kite Dashboard** | `http://kite.127.0.0.1.sslip.io:8001/` | `https://kite.127.0.0.1.sslip.io/` | Kubernetes IDE and development tools | Admin account can be created at first login |
| **Headlamp Dashboard** | `http://headlamp.127.0.0.1.sslip.io:8001/` | `https://headlamp.127.0.0.1.sslip.io/` | Kubernetes cluster monitoring | Token provided by setup script |
| **ArgoCD** | `http://argocd.127.0.0.1.sslip.io:8001/` | `https://argocd.127.0.0.1.sslip.io/` | GitOps continuous deployment | Username: `admin`, Password: shown by setup script |
| **Gitea** | `http://gitea.127.0.0.1.sslip.io:8001/` | `https://gitea.127.0.0.1.sslip.io/` | Git repository management | Username: `admin`, Password: shown by setup script |

**Note**: Linkerd Viz dashboard is only available when using Linkerd service mesh (`--mesh-type linkerd`). Traefik Mesh provides observability through Prometheus metrics and Traefik dashboard.

## Service Mesh Configuration

The setup supports two service mesh options to enable secure communication between microservices:

### Traefik Mesh (Default)
- **Lightweight**: Minimal overhead and resource usage
- **Integrated**: Works seamlessly with existing Traefik ingress
- **Observability**: Prometheus metrics and Traefik dashboard integration
- **Automatic**: Zero-configuration service mesh for HTTP traffic
- **Namespace Enable**: Use `kubectl label namespace <namespace> mesh.traefik.io/traffic-type=http`

```bash
# Install with Traefik Mesh (default)
./setup-k3d-cluster.sh --service-mesh
```

### Linkerd
- **Full-featured**: Complete service mesh with advanced features
- **mTLS**: Automatic mutual TLS between all meshed services
- **Observability**: Dedicated Linkerd Viz dashboard with detailed metrics
- **Policy Engine**: Fine-grained traffic policies and access control
- **Traffic Management**: Advanced routing, load balancing, and fault injection

```bash
# Install with Linkerd service mesh
./setup-k3d-cluster.sh --service-mesh --mesh-type linkerd
```

### Choosing a Service Mesh

**Use Traefik Mesh when**:
- You want minimal resource overhead
- Simple HTTP service communication is sufficient
- You prefer lightweight, integrated solutions
- You're already using Traefik for ingress

**Use Linkerd when**:
- You need comprehensive observability and metrics
- You require advanced security features (mTLS, policies)
- You want sophisticated traffic management capabilities
- You're building complex microservice architectures

## SSL/TLS Configuration

This setup automatically generates and configures self-signed SSL certificates using [smallstep step CLI](https://github.com/smallstep/cli) for secure HTTPS access to all services.

The setup creates a persistent Certificate Authority (CA) that is reused across cluster recreations, ensuring consistent certificate trust.

### Certificate Details

- **Certificate Authority**: Persistent local CA stored in `$HOME/.local/ca/` created by smallstep
- **Certificate Scope**: Wildcard certificate for `*.{DOMAIN}` (e.g., `*.127.0.0.1.sslip.io`)
- **Storage**: Certificate is stored as a Kubernetes secret `traefik-tls` in the `traefik` namespace
- **Validity**: Certificates are valid for 1 year and created using a persistent smallstep CA
- **Persistence**: The CA persists across cluster recreations, maintaining browser trust once installed

### Benefits of Persistent CA

- **One-time browser setup**: Install the CA certificate once and trust persists across cluster recreations
- **Consistent certificates**: Same CA is used for all development environments
- **No certificate warnings**: After initial CA installation, all services show as secure in browsers
- **Professional workflow**: Mimics production certificate management practices

### Accessing Services Securely

All services are available via both HTTP and HTTPS:
- **HTTP**: Uses the configured `HTTP_PORT` (default: 8001)
- **HTTPS**: Uses the configured `HTTPS_PORT` (default: 443)

**Note**: When using non-standard ports (not 80/443), only the HTTP URLs will include the port number in the output.

### Manual Certificate Installation (Windows with WSL2)

If you're using WSL2 and need to manually install the CA certificate in Microsoft Edge on Windows:

1. **Locate the certificate**: The smallstep CA certificate is stored in `$HOME/.local/ca/ca.crt` on your WSL2 Linux distribution
2. **Access WSL2 filesystem from Windows**: Navigate to `\\wsl.localhost\<WSL Distribution Name>` (e.g., `\\wsl.localhost\Ubuntu-22.04`)
3. **Find the CA file**: Go to `home\<username>\.local\ca\` and copy the `ca.crt` file
4. **Install in Edge**:
   - Open Microsoft Edge
   - Go to Settings → Privacy, search, and services → Security → Manage certificates
   - Click on "Trusted Root Certification Authorities" tab
   - Click "Import..." and follow the wizard to import the `ca.crt` file
   - Restart Microsoft Edge

After installation, all HTTPS services will show as secure in Microsoft Edge.

**Note**: The CA certificate persists across cluster recreations, so you only need to install it once in your browser.

### Manual Certificate Installation (Linux)

To install the smallstep CA certificate in your system trust store and browsers on Linux:

#### System Trust Store Installation

1. **Locate the certificate**: The smallstep CA certificate is stored in `$HOME/.local/ca/ca.crt`

2. **Install using step CLI** (recommended):
   ```bash
   # Install CA certificate into system trust store using step CLI
   step certificate install $HOME/.local/ca/ca.crt
   ```
   
   This command automatically:
   - Copies the certificate to the appropriate system location
   - Updates the system certificate store 
   - Makes the certificate trusted system-wide

3. **Alternative manual installation**:
   ```bash
   # Manual method if step certificate install doesn't work
   sudo cp $HOME/.local/ca/ca.crt /usr/local/share/ca-certificates/local-dev-ca.crt
   sudo update-ca-certificates
   ```

4. **Verify installation**:
   ```bash
   # Check if certificate is now trusted
   step certificate verify $HOME/.local/ca/ca.crt --roots $HOME/.local/ca/ca.crt
   ```

#### Browser-Specific Installation

**Firefox**:
1. Open Firefox and go to `about:preferences#privacy`
2. Scroll down to "Certificates" and click "View Certificates"
3. Go to "Authorities" tab
4. Click "Import..." and select `$HOME/.local/ca/ca.crt`
5. Check "Trust this CA to identify websites" and click OK

**Chrome/Chromium**:
After installing the certificate in the system trust store using `step certificate install`, Chrome should automatically trust the certificate. If manual installation is needed:
1. Open Chrome and go to `chrome://settings/certificates`
2. Click on "Authorities" tab
3. Click "Import" and select `$HOME/.local/ca/ca.crt`
4. Check "Trust this certificate for identifying websites" and click OK

After installation, all HTTPS services will show as secure in your browsers without certificate warnings.

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
1. Ensure step-cli is installed: `step version`
2. Verify the certificate was created successfully during cluster setup
3. Check that the `traefik-tls` secret exists: `kubectl get secret traefik-tls -n traefik`
4. Install the CA certificate in your browser (see Manual Certificate Installation section above)
5. Restart your browser after installing the CA certificate

### Tool Installation Issues

The setup script automatically handles tool installation, but if you encounter issues:

- Ensure you have write permissions to `~/.local/bin/`
- Check that `curl`, `jq`, and `tar` are available on your system
- Use `./setup-k3d-cluster.sh --check-tools` to verify tool availability
- Use `./setup-k3d-cluster.sh --force-tools` to reinstall tools to latest versions

For system tools (curl, jq, envsubst), install them manually:
```bash
sudo apt update
sudo apt install -y jq curl gettext-base
```

If step-cli installation fails:
- Update your package list: `sudo apt update`
- Install manually from releases: https://github.com/smallstep/cli/releases
- Ensure you have appropriate permissions to install packages
- On older Ubuntu versions, use the manual installation method

## Contributing

Feel free to submit issues and feature requests or contribute improvements to this development environment setup.

## License

See [LICENSE](LICENSE) file for details.
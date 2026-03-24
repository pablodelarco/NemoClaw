#!/usr/bin/env bash
set -o errexit -o pipefail

# --------------------------------------------------------------------------- #
# NemoClaw OpenNebula Marketplace Appliance
# --------------------------------------------------------------------------- #
# Lifecycle script following the one-apps service convention.
# - service_install()   : Packer build time (bake dependencies into image)
# - service_configure() : Every boot (read CONTEXT, write config files)
# - service_bootstrap() : First boot only (create sandbox, start services)
# - service_cleanup()   : Reconfigure (tear down before re-configure)
# --------------------------------------------------------------------------- #

# ========================== Constants ====================================== #

# Directories
NEMOCLAW_DATA_DIR="/opt/nemoclaw"
ONE_SERVICE_SETUP_DIR="/opt/one-appliance"

# Versions (pinned for alpha stability, per D-04)
NEMOCLAW_INSTALL_URL="https://www.nvidia.com/nemoclaw.sh"
NVIDIA_DRIVER_BRANCH="550-server"
NODEJS_MAJOR="22"

# Docker log rotation defaults
DOCKER_LOG_MAX_SIZE="10m"
DOCKER_LOG_MAX_FILE="3"

# ========================== Metadata ======================================= #

ONE_SERVICE_NAME='NemoClaw'
ONE_SERVICE_VERSION='0.1.0'
ONE_SERVICE_RECONFIGURABLE=true    # per LIFE-05
ONE_SERVICE_SHORTSTARTMSG='NemoClaw appliance is starting...'
ONE_SERVICE_STARTMSG='All set and ready to serve'

# ========================== Parameters ===================================== #
# ONE_SERVICE_PARAMS defines contextualization variables exposed in Sunstone.
# Format: 'VARIABLE_NAME' 'stage' 'description' 'M|O|type'
# per LIFE-04, CTX-01, CTX-02, CTX-03, D-12

ONE_SERVICE_PARAMS=(
    'ONEAPP_NEMOCLAW_API_KEY'        'configure' 'NVIDIA API key from build.nvidia.com for inference'                     'M|password'
    'ONEAPP_NEMOCLAW_MODEL'          'configure' 'Nemotron model for inference (nemotron-3-super-120b, nemotron-ultra-253b, nemotron-super-49b, nemotron-3-nano-30b)'  'O|text'
    'ONEAPP_NEMOCLAW_SANDBOX_NAME'   'configure' 'Sandbox instance name (lowercase alphanumeric and hyphens)'             'O|text'
)

# ========================== service_install() ============================== #
# Runs during Packer build. Installs all runtime dependencies into the image
# so nothing needs downloading at first boot.
# per LIFE-01, D-01, D-02

service_install()
{
    # ---------------------------------------------------------------------- #
    # 1. Install prerequisites
    # ---------------------------------------------------------------------- #
    msg info "Installing prerequisite packages..."
    apt-get update
    apt-get install -y \
        curl wget jq ca-certificates gnupg lsb-release network-manager

    # ---------------------------------------------------------------------- #
    # 2. Install Docker Engine from official repo (per D-11, STACK.md)
    # ---------------------------------------------------------------------- #
    msg info "Installing Docker Engine from official repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    # ---------------------------------------------------------------------- #
    # 3. Configure Docker log rotation (per PITFALLS.md performance traps)
    # ---------------------------------------------------------------------- #
    msg info "Configuring Docker log rotation..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<DOCKER_EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "${DOCKER_LOG_MAX_SIZE}",
    "max-file": "${DOCKER_LOG_MAX_FILE}"
  }
}
DOCKER_EOF

    # ---------------------------------------------------------------------- #
    # 4. Start Docker and enable at boot
    # ---------------------------------------------------------------------- #
    msg info "Enabling and starting Docker..."
    systemctl enable docker
    systemctl start docker

    # ---------------------------------------------------------------------- #
    # 5. Install NVIDIA driver 550-server (per STACK.md)
    # ---------------------------------------------------------------------- #
    msg info "Installing NVIDIA driver ${NVIDIA_DRIVER_BRANCH}..."
    apt-get install -y "nvidia-driver-${NVIDIA_DRIVER_BRANCH}"

    # ---------------------------------------------------------------------- #
    # 6. Install NVIDIA Container Toolkit (per STACK.md)
    # ---------------------------------------------------------------------- #
    msg info "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        > /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker

    # ---------------------------------------------------------------------- #
    # 7. Install Node.js 22 LTS (per STACK.md)
    # ---------------------------------------------------------------------- #
    msg info "Installing Node.js ${NODEJS_MAJOR} LTS..."
    curl -fsSL "https://deb.nodesource.com/setup_${NODEJS_MAJOR}.x" | bash -
    apt-get install -y nodejs

    # ---------------------------------------------------------------------- #
    # 8. Install NemoClaw non-interactively (per D-01, D-03, STACK.md)
    # ---------------------------------------------------------------------- #
    msg info "Installing NemoClaw (non-interactive)..."
    curl -fsSL "${NEMOCLAW_INSTALL_URL}" -o /tmp/nemoclaw-install.sh
    sed -i 's/^ *run_onboard$/ # run_onboard (skipped for appliance build)/' /tmp/nemoclaw-install.sh
    bash /tmp/nemoclaw-install.sh
    rm -f /tmp/nemoclaw-install.sh

    # ---------------------------------------------------------------------- #
    # 9. Pre-pull NemoClaw sandbox container image (per D-02)
    #    Avoids a ~2.4GB download at first boot.
    # ---------------------------------------------------------------------- #
    if command -v nemoclaw &>/dev/null; then
        msg info "Pre-pulling NemoClaw sandbox container image (~2.4GB)..."
        nemoclaw sandbox-image pull 2>/dev/null \
            || docker pull ghcr.io/nvidia/openshell:latest \
            || msg warning "Could not pre-pull sandbox image; will download at first boot"
    fi

    # ---------------------------------------------------------------------- #
    # 10. Disable systemd-networkd-wait-online (per PITFALLS.md, one-apps #134)
    # ---------------------------------------------------------------------- #
    msg info "Disabling systemd-networkd-wait-online service..."
    systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true

    # ---------------------------------------------------------------------- #
    # 11. Configure swap (per PITFALLS.md, prevent OOM)
    # ---------------------------------------------------------------------- #
    msg info "Configuring 4G swap space..."
    if [ ! -f /swapfile ]; then
        fallocate -l 4G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # ---------------------------------------------------------------------- #
    # 12. Cleanup (per D-11, postinstall_cleanup pattern)
    # ---------------------------------------------------------------------- #
    msg info "Running post-install cleanup..."
    postinstall_cleanup
}

# ========================== Stub Functions ================================= #
# Implemented in subsequent plans (01-02, 01-03).

service_configure()
{
    # Implemented in Plan 02
    :
}

service_bootstrap()
{
    # Implemented in Plan 03
    :
}

service_cleanup()
{
    :
}

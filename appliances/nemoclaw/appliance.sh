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

    # Remove any pre-existing nvidia repo entries (nvidia-driver may add unsigned ones)
    rm -f /etc/apt/sources.list.d/nvidia*.list 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/nvidia*.sources 2>/dev/null || true

    # Import GPG key using apt-key compatible method for reliability
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    chmod 644 /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    # Add repo in DEB822 format (Ubuntu 24.04 native)
    cat > /etc/apt/sources.list.d/nvidia-container-toolkit.sources <<'NCTK_EOF'
Types: deb
URIs: https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)
Suites: /
Signed-By: /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
NCTK_EOF

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
    # Run official installer with --non-interactive. Onboarding will fail
    # (no API key at build time) but the CLI and runtime get installed.
    # Onboarding happens at first boot via service_bootstrap.
    curl -fsSL "${NEMOCLAW_INSTALL_URL}" -o /tmp/nemoclaw-install.sh
    bash /tmp/nemoclaw-install.sh --non-interactive || msg warning "NemoClaw onboard skipped (expected during build - runs at first boot)"
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
    export DEBIAN_FRONTEND=noninteractive
    apt-get autoremove -y 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
    rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true
    sync
}

# ========================== GPU Detection ================================== #
# GPU_DETECTED is set by detect_gpu() and used by service_configure/service_bootstrap

GPU_DETECTED=false
GPU_MODEL=""
GPU_MEMORY=""

detect_gpu()
{
    msg info "Detecting NVIDIA GPU presence..."

    # Check for NVIDIA GPU via lspci
    if lspci 2>/dev/null | grep -qi 'nvidia'; then
        msg info "NVIDIA GPU found via lspci"

        # Check for device nodes
        if [ -e /dev/nvidia0 ] || [ -e /dev/nvidiactl ]; then
            msg info "NVIDIA device nodes present"

            # Validate with nvidia-smi (per GPU-02, D-10)
            if command -v nvidia-smi &>/dev/null; then
                if nvidia-smi &>/dev/null; then
                    GPU_DETECTED=true
                    GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")
                    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")
                    msg info "GPU validated: ${GPU_MODEL} (${GPU_MEMORY})"

                    # Regenerate CDI spec for container GPU access (per PITFALLS.md Pitfall 1)
                    if command -v nvidia-ctk &>/dev/null; then
                        msg info "Regenerating NVIDIA CDI spec..."
                        nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null || \
                            msg warning "CDI spec generation failed; GPU may not be available in containers"
                    fi
                    return 0
                else
                    msg warning "nvidia-smi failed; GPU device may not be properly initialized"
                fi
            else
                msg warning "nvidia-smi not found; cannot validate GPU"
            fi
        else
            msg warning "NVIDIA GPU detected via lspci but no device nodes found"
        fi
    fi

    # GPU not detected or not functional (per GPU-04, D-09)
    GPU_DETECTED=false
    msg warning "No functional NVIDIA GPU detected. NemoClaw will use remote NVIDIA Endpoints inference only."
    msg warning "To use local GPU inference, ensure GPU passthrough is configured on the OpenNebula host."
    return 0
}

# ========================== MOTD Helper ==================================== #

write_motd()
{
    local _motd_file="/etc/motd"
    local _nemoclaw_version=""

    # Get NemoClaw version if available
    if command -v nemoclaw &>/dev/null; then
        _nemoclaw_version=$(nemoclaw --version 2>/dev/null || echo "unknown")
    fi

    cat > "${_motd_file}" <<MOTD_EOF
============================================================
  NemoClaw Appliance v${ONE_SERVICE_VERSION}
  NemoClaw: ${_nemoclaw_version:-not installed}
============================================================

  Sandbox:  ${ONEAPP_NEMOCLAW_SANDBOX_NAME:-nemoclaw}
  Model:    ${ONEAPP_NEMOCLAW_MODEL:-nemotron-3-super-120b}
  GPU:      $(if [ "${GPU_DETECTED}" = "true" ]; then echo "YES - ${GPU_MODEL} (${GPU_MEMORY})"; else echo "NO - Remote inference only"; fi)

  Quick Start:
    nemoclaw ${ONEAPP_NEMOCLAW_SANDBOX_NAME:-nemoclaw} connect   # Enter sandbox
    nemoclaw ${ONEAPP_NEMOCLAW_SANDBOX_NAME:-nemoclaw} status    # Check status

  WARNING: NemoClaw is alpha software. APIs may change.
============================================================
MOTD_EOF

    chmod 644 "${_motd_file}"
}

# ========================== API Key Storage ================================ #
# per D-05, D-06, PITFALLS.md Pitfall 6

NEMOCLAW_CREDENTIALS_DIR="/etc/nemoclaw"
NEMOCLAW_API_KEY_FILE="${NEMOCLAW_CREDENTIALS_DIR}/api_key"

store_api_key()
{
    local _api_key="${1}"

    if [ -z "${_api_key}" ]; then
        msg error "NVIDIA API key is required but not provided."
        msg error "Set ONEAPP_NEMOCLAW_API_KEY via OpenNebula contextualization (Sunstone VM template)."
        msg error "You can add it via recontext without redeploying (ONE_SERVICE_RECONFIGURABLE=true)."
        return 1
    fi

    # Create secure credentials directory
    install -d -m 0700 "${NEMOCLAW_CREDENTIALS_DIR}"

    # Write API key to restricted file (per D-05, 0600 permissions)
    echo "${_api_key}" > "${NEMOCLAW_API_KEY_FILE}"
    chmod 0600 "${NEMOCLAW_API_KEY_FILE}"
    chown root:root "${NEMOCLAW_API_KEY_FILE}"

    msg info "NVIDIA API key stored securely at ${NEMOCLAW_API_KEY_FILE} (mode 0600)"

    # Clear from environment to reduce exposure (per PITFALLS.md Pitfall 6)
    unset ONEAPP_NEMOCLAW_API_KEY

    return 0
}

# ========================== service_configure() ============================ #
# Runs at every boot via contextualization. Reads CONTEXT variables,
# writes config files, detects GPU presence.
# per LIFE-02, D-07

service_configure()
{
    msg info "Configuring NemoClaw appliance..."

    # --- Read CONTEXT variables with defaults (per CTX-01, CTX-02, CTX-03) ---

    # ONEAPP_NEMOCLAW_API_KEY is mandatory (per CTX-01, D-05)
    # Variable is set by OpenNebula contextualization from ONE_SERVICE_PARAMS

    # ONEAPP_NEMOCLAW_MODEL defaults to nemotron-3-super-120b (per CTX-02)
    export ONEAPP_NEMOCLAW_MODEL="${ONEAPP_NEMOCLAW_MODEL:-nemotron-3-super-120b}"

    # ONEAPP_NEMOCLAW_SANDBOX_NAME defaults to "nemoclaw" (per CTX-03, D-08)
    export ONEAPP_NEMOCLAW_SANDBOX_NAME="${ONEAPP_NEMOCLAW_SANDBOX_NAME:-nemoclaw}"

    msg info "Configuration:"
    msg info "  Model:        ${ONEAPP_NEMOCLAW_MODEL}"
    msg info "  Sandbox name: ${ONEAPP_NEMOCLAW_SANDBOX_NAME}"
    msg info "  API key:      [provided=$([ -n \"${ONEAPP_NEMOCLAW_API_KEY}\" ] && echo 'yes' || echo 'NO')]"

    # --- Store API key securely (per D-05, D-06) ---
    store_api_key "${ONEAPP_NEMOCLAW_API_KEY}" || {
        # API key missing -- write error to MOTD and return failure
        cat > /etc/motd <<'MOTD_ERR'
============================================================
  NemoClaw Appliance - CONFIGURATION ERROR

  NVIDIA API key is REQUIRED but was not provided.

  To fix: Add ONEAPP_NEMOCLAW_API_KEY to the VM context
  in Sunstone and recontext the VM.

  Get your key at: https://build.nvidia.com
============================================================
MOTD_ERR
        return 1
    }

    # --- Detect GPU (per GPU-02, GPU-04, D-09, D-10) ---
    detect_gpu

    # --- Ensure Docker is running ---
    if ! systemctl is-active --quiet docker; then
        msg info "Starting Docker daemon..."
        systemctl start docker
    fi

    # --- Write NemoClaw config for service_bootstrap ---
    # Store configuration for bootstrap phase to consume
    install -d -m 0755 "${ONE_SERVICE_SETUP_DIR}"
    cat > "${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf" <<CONF_EOF
# Generated by service_configure - $(date -Iseconds)
NEMOCLAW_API_KEY_FILE="${NEMOCLAW_API_KEY_FILE}"
NEMOCLAW_MODEL="${ONEAPP_NEMOCLAW_MODEL}"
NEMOCLAW_SANDBOX_NAME="${ONEAPP_NEMOCLAW_SANDBOX_NAME}"
NEMOCLAW_GPU_DETECTED="${GPU_DETECTED}"
NEMOCLAW_GPU_MODEL="${GPU_MODEL}"
NEMOCLAW_GPU_MEMORY="${GPU_MEMORY}"
CONF_EOF
    chmod 0600 "${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf"

    msg info "Configuration complete. Ready for bootstrap."

    # --- Write initial MOTD (will be updated after bootstrap) ---
    write_motd

    # --- CTX-04 and CTX-05 note ---
    # SSH key-based access (CTX-04) is handled automatically by the OpenNebula
    # context agent via $USER[SSH_PUBLIC_KEY]. No custom code needed.
    # Network auto-configuration (CTX-05) is handled by the addon-context-linux
    # package and NetworkManager. No custom code needed.

    return 0
}

check_nemoclaw_health()
{
    local _sandbox_name="${1:-nemoclaw}"
    local _max_retries=30
    local _retry_interval=10
    local _attempt=0

    msg info "Validating NemoClaw sandbox health (timeout: $((${_max_retries} * ${_retry_interval}))s)..."

    while [ ${_attempt} -lt ${_max_retries} ]; do
        _attempt=$((_attempt + 1))

        # Check Docker is running
        if ! docker info &>/dev/null; then
            msg warning "Docker not responding (attempt ${_attempt}/${_max_retries})"
            sleep ${_retry_interval}
            continue
        fi

        # Check NemoClaw sandbox status
        if command -v nemoclaw &>/dev/null; then
            local _status
            _status=$(nemoclaw "${_sandbox_name}" status 2>/dev/null || echo "unknown")

            if echo "${_status}" | grep -qi 'running\|healthy\|ready'; then
                msg info "NemoClaw sandbox '${_sandbox_name}' is healthy"
                return 0
            fi

            msg info "Sandbox status: ${_status} (attempt ${_attempt}/${_max_retries})"
        else
            msg warning "nemoclaw CLI not found (attempt ${_attempt}/${_max_retries})"
        fi

        sleep ${_retry_interval}
    done

    msg error "NemoClaw sandbox '${_sandbox_name}' failed health check after ${_max_retries} attempts"
    return 1
}

# ========================== service_bootstrap() ============================= #
# Runs at first boot after service_configure(). Creates the NemoClaw sandbox,
# runs NemoClaw onboard non-interactively, validates health, and updates MOTD.
# per LIFE-03, D-03, D-07, D-08

service_bootstrap()
{
    msg info "Bootstrapping NemoClaw appliance..."

    # --- Load configuration from service_configure ---
    if [ -f "${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf" ]; then
        . "${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf"
    else
        msg error "Configuration file not found at ${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf"
        msg error "service_configure must run before service_bootstrap"
        return 1
    fi

    local _sandbox_name="${NEMOCLAW_SANDBOX_NAME:-nemoclaw}"
    local _model="${NEMOCLAW_MODEL:-nemotron-3-super-120b}"
    local _api_key_file="${NEMOCLAW_API_KEY_FILE:-/etc/nemoclaw/api_key}"
    local _gpu="${NEMOCLAW_GPU_DETECTED:-false}"

    # --- Validate API key file exists ---
    if [ ! -f "${_api_key_file}" ]; then
        msg error "API key file not found at ${_api_key_file}"
        msg error "service_configure should have created this file"
        return 1
    fi

    local _api_key
    _api_key=$(cat "${_api_key_file}")

    if [ -z "${_api_key}" ]; then
        msg error "API key file is empty at ${_api_key_file}"
        return 1
    fi

    # --- Ensure Docker is running ---
    if ! systemctl is-active --quiet docker; then
        msg info "Starting Docker daemon..."
        systemctl start docker
        sleep 5
    fi

    # --- Run NemoClaw onboard non-interactively (per D-03) ---
    msg info "Running NemoClaw onboard (non-interactive)..."
    msg info "  Sandbox name: ${_sandbox_name}"
    msg info "  Model:        ${_model}"
    msg info "  GPU:          ${_gpu}"

    # Set environment variables for NemoClaw onboard
    # NemoClaw reads NVIDIA_API_KEY from environment for non-interactive onboard
    export NVIDIA_API_KEY="${_api_key}"

    # Run onboard with API key and model selection
    # The onboard command sets up the inference provider and creates initial config
    if ! nemoclaw onboard \
        --api-key "${_api_key}" \
        --model "${_model}" \
        --non-interactive 2>&1 | while IFS= read -r line; do msg info "  onboard: ${line}"; done; then

        # If --non-interactive flag is not supported, try alternative approach
        msg warning "Non-interactive onboard may have failed; trying environment variable approach..."

        # Alternative: NemoClaw may read from env vars directly
        NVIDIA_API_KEY="${_api_key}" \
        NEMOCLAW_MODEL="${_model}" \
        nemoclaw onboard 2>&1 | while IFS= read -r line; do msg info "  onboard: ${line}"; done || {
            msg error "NemoClaw onboard failed. Check API key validity and network connectivity."
            msg error "You can retry manually: nemoclaw onboard"

            cat > /etc/motd <<'MOTD_FAIL'
============================================================
  NemoClaw Appliance - BOOTSTRAP FAILED

  NemoClaw onboard failed. Possible causes:
  - Invalid NVIDIA API key
  - Network connectivity issues
  - NemoClaw service unavailable

  To retry: nemoclaw onboard
  To check: nemoclaw status
============================================================
MOTD_FAIL
            # Clear sensitive data from environment
            unset NVIDIA_API_KEY
            return 1
        }
    fi

    # Clear API key from environment after use
    unset NVIDIA_API_KEY

    # --- Create sandbox (per D-07, D-08) ---
    msg info "Creating NemoClaw sandbox '${_sandbox_name}'..."

    if ! nemoclaw create "${_sandbox_name}" 2>&1 | while IFS= read -r line; do msg info "  create: ${line}"; done; then
        msg error "Failed to create NemoClaw sandbox '${_sandbox_name}'"
        msg error "Retrying sandbox creation..."

        # One retry with verbose output
        if ! nemoclaw create "${_sandbox_name}" --verbose 2>&1; then
            msg error "Sandbox creation failed after retry"
            cat > /etc/motd <<MOTD_FAIL2
============================================================
  NemoClaw Appliance - BOOTSTRAP FAILED

  Failed to create sandbox '${_sandbox_name}'.

  To retry: nemoclaw create ${_sandbox_name}
  To check: nemoclaw status
============================================================
MOTD_FAIL2
            return 1
        fi
    fi

    # --- Start sandbox ---
    msg info "Starting NemoClaw sandbox '${_sandbox_name}'..."
    nemoclaw start "${_sandbox_name}" 2>&1 | while IFS= read -r line; do msg info "  start: ${line}"; done || {
        msg warning "Sandbox start command returned non-zero; checking status..."
    }

    # --- Run health checks ---
    if check_nemoclaw_health "${_sandbox_name}"; then
        msg info "NemoClaw bootstrap completed successfully"

        # --- Update MOTD with success status ---
        # Refresh GPU info in case it changed
        detect_gpu

        # Write final MOTD with success message
        write_motd

        # Append the success marker that tests look for
        echo "" >> /etc/motd
        echo "  ${ONE_SERVICE_STARTMSG}" >> /etc/motd
        echo "" >> /etc/motd

        # Also write service report
        cat > "${ONE_SERVICE_SETUP_DIR}/config" <<REPORT_EOF
# NemoClaw Appliance Report - $(date -Iseconds)
READY=YES
SANDBOX_NAME=${_sandbox_name}
MODEL=${_model}
GPU_DETECTED=${_gpu}
GPU_MODEL=${NEMOCLAW_GPU_MODEL:-none}
REPORT_EOF

        msg info "============================================"
        msg info "  NemoClaw appliance is ready!"
        msg info "  Sandbox: ${_sandbox_name}"
        msg info "  Model:   ${_model}"
        msg info "  GPU:     $([ \"${_gpu}\" = \"true\" ] && echo \"${NEMOCLAW_GPU_MODEL}\" || echo \"Remote inference only\")"
        msg info "============================================"

        return 0
    else
        msg error "NemoClaw health check failed"
        msg error "The sandbox may still be starting. Check with: nemoclaw ${_sandbox_name} status"

        cat > /etc/motd <<MOTD_WARN
============================================================
  NemoClaw Appliance - HEALTH CHECK WARNING

  Sandbox '${_sandbox_name}' did not pass health checks.
  It may still be initializing.

  Check status: nemoclaw ${_sandbox_name} status
  View logs:    nemoclaw ${_sandbox_name} logs
============================================================
MOTD_WARN
        return 1
    fi
}

service_cleanup()
{
    msg info "Cleaning up NemoClaw configuration for recontext..."

    # Remove config file so service_configure rewrites it
    rm -f "${ONE_SERVICE_SETUP_DIR}/nemoclaw.conf"

    # Remove API key file (will be re-created from new CONTEXT)
    rm -f "${NEMOCLAW_API_KEY_FILE}"

    msg info "Cleanup complete. service_configure will run with new CONTEXT values."

    return 0
}

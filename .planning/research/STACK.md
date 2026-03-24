# Technology Stack

**Project:** NemoClaw OpenNebula Marketplace Appliance
**Researched:** 2026-03-24

## Recommended Stack

### Base OS Image

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Ubuntu Server | 22.04.5 LTS (Jammy) | Base VM operating system | NemoClaw officially supports Ubuntu 22.04 LTS. The PROJECT.md confirms this. Ubuntu 22.04 has LTS support until April 2027 (standard), extended to 2032 with ESM. The one-apps build system uses Ubuntu 22.04 for service appliances (Harbor, MinIO, OneKE). | HIGH |
| Linux Kernel | 5.15 HWE (default) | Kernel for NVIDIA driver support | The stock 5.15 HWE kernel in Ubuntu 22.04 supports NVIDIA driver 550-server and 575. No need for a custom kernel. | HIGH |

**Why NOT Ubuntu 24.04:** NemoClaw's official docs specify "Ubuntu 22.04 LTS or later" but the project was announced March 16, 2026 and all testing references use 22.04. Going with what NVIDIA tested on reduces risk with an alpha product. The NVIDIA driver 560+ had documented failures on 22.04 due to gcc-11/12 conflicts, but the 550-server and 575 branches work. On 24.04, newer drivers work but NemoClaw has less validation. Stick with 22.04 for v1.

### NVIDIA Driver Stack

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| nvidia-driver-550-server | 550.x (latest in Ubuntu repos) | GPU driver for data center / cloud workloads | The `-server` variant is designed for headless compute workloads (no X11). 550 is the most stable branch for Ubuntu 22.04 with proven compatibility. The 575 driver is now backported to 22.04 repos and could be an option, but 550-server has the longest track record. | HIGH |
| NVIDIA Container Toolkit | 1.19.0 | Docker integration for GPU passthrough to containers | Latest stable release (March 12, 2025). Provides `nvidia-ctk` for configuring Docker runtime. Required by OpenShell for GPU sandbox support. Installed from NVIDIA's apt repo, not Ubuntu's. | HIGH |

**Why NOT nvidia-driver-575:** The 575 branch was backported to Ubuntu 22.04 in July 2025 and is available, but 550-server has longer production exposure for server workloads. For a marketplace appliance where stability matters, 550-server is the safer choice. If users need 575 features (RTX 50 series support), they can upgrade.

**Why NOT nvidia-driver-560:** NVIDIA driver 560+ fails to install on Ubuntu 22.04 due to a gcc-11/gcc-12 compiler conflict when CUDA 12.6 is installed. The root cause is that CUDA 12.6 implicitly installs gcc-11 which lacks the `-ftrivial-auto-var-init=zero` flag needed by the 560+ module build. This is a known issue documented on NVIDIA Developer Forums. Avoid the entire 560 branch on 22.04.

**Why NOT CUDA Toolkit on host:** NemoClaw uses NVIDIA Endpoints API for inference (remote), not local CUDA compute. The NVIDIA Container Toolkit docs explicitly state "you do not need to install the CUDA Toolkit on the host system, but the NVIDIA driver needs to be installed." CUDA lives inside the container images if needed. Do not install the full CUDA toolkit on the base image -- it wastes 3-5GB of disk space.

### Container Runtime

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Docker Engine (docker-ce) | 28.x or 29.x (latest stable from Docker repos) | Container runtime for NemoClaw/OpenShell | Docker is NemoClaw's primary supported container runtime on Linux. Docker 29.x is the current latest (29.3.0, March 2026). Docker 28.x is still supported. Install from Docker's official apt repo, not Ubuntu's `docker.io` package. The NVIDIA Container Toolkit requires Docker >= 19.03, and CDI support (modern GPU integration path) requires Docker >= 25. | HIGH |
| Docker Compose Plugin | Latest (bundled with docker-ce) | Multi-container orchestration | Installed automatically with `docker-compose-plugin` package from Docker repos. NemoClaw may use Compose for multi-service setups. | HIGH |
| containerd.io | Latest (bundled with docker-ce) | Low-level container runtime | Required by Docker Engine. Installed from Docker repos. | HIGH |

**Why NOT Podman:** NemoClaw explicitly does not support Podman yet ("macOS + Podman: Not yet supported" in NemoClaw docs). Even on Linux, OpenShell runs a K3s Kubernetes cluster inside a single Docker container -- this pattern requires Docker's daemon architecture.

**Why NOT Ubuntu's docker.io package:** The Ubuntu-packaged Docker is significantly older and not maintained by Docker Inc. Using Docker's official repo ensures latest security patches and NVIDIA Container Toolkit compatibility.

### NemoClaw & OpenShell

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| NemoClaw | Latest (alpha, March 2026) | AI agent security stack | Core application being packaged. Installed via `curl -fsSL https://www.nvidia.com/nemoclaw.sh \| bash`. The installer downloads OpenShell, configures the sandbox, and sets up the CLI. | MEDIUM |
| OpenShell | Latest (installed by NemoClaw) | Secure sandbox runtime | Provides Landlock/seccomp/network namespace isolation. Runs K3s inside a Docker container. Sandbox image is ~2.4 GB compressed. Installed automatically by the NemoClaw installer. | MEDIUM |
| Node.js | 22.x LTS | NemoClaw CLI runtime | NemoClaw requires Node.js 20+. However, Node.js 20 reaches EOL April 30, 2026 -- just one month from now. Node.js 22 is the current Active LTS (codename 'Jod'). Install via NodeSource or the NemoClaw installer handles it. Use 22.x for longevity. | HIGH |
| npm | 10.x | Package manager | Bundled with Node.js 22.x. NemoClaw requires npm 10+. | HIGH |

**Installation strategy for Packer build:** The NemoClaw installer (`nemoclaw.sh`) has an interactive `nemoclaw onboard` step that requires an NVIDIA API key. For the Packer image build, we need a non-interactive install. The documented approach is:

```bash
curl -fsSL https://nvidia.com/nemoclaw.sh -o /tmp/nemoclaw-install.sh
sed -i 's/^ run_onboard$/ # run_onboard (skipped)/' /tmp/nemoclaw-install.sh
bash /tmp/nemoclaw-install.sh
```

This installs NemoClaw and OpenShell but skips the interactive onboarding wizard. The onboarding (API key, model selection, sandbox creation) runs at first boot via the appliance's `service_bootstrap` contextualization hook.

**Confidence note (MEDIUM):** NemoClaw is alpha software announced March 16, 2026. APIs, installer behavior, and CLI flags may change without notice. The non-interactive install hack (sed-ing out `run_onboard`) is fragile -- a future installer version could break this. Monitor the NVIDIA/NemoClaw GitHub repo for changes.

### Build Toolchain

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Packer | 1.15.0 | VM image builder | Latest stable (February 4, 2026). The one-apps build system uses Packer with the QEMU plugin. Packer 1.14+ added automatic plugin installation via `packer init`. Version 1.15.0 is the current supported release (N-2 policy covers 1.13+). | HIGH |
| packer-plugin-qemu | ~> 1 (latest 1.1.4) | QEMU/KVM builder plugin | The one-apps `plugins.pkr.hcl` specifies `version = "~> 1"`. Latest is 1.1.4. Builds qcow2 images using QEMU/KVM. | HIGH |
| QEMU/KVM | System package | Virtualization backend for Packer | Required on the build host (`qemu-system-x86_64`). The build host at 100.123.42.13 should have this installed. | HIGH |
| Make | System package | Build orchestration | The marketplace-community project uses Makefiles. The community-apps `Makefile.config` shows VERSION=6.10.0, RELEASE=3. | HIGH |

### OpenNebula Contextualization

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| one-context (Linux) | 6.10.0 | VM contextualization at boot | Sets up networking, SSH keys, passwords, custom scripts. The one-apps 7.0.0 release (May 2025) includes updated context packages, but the marketplace-community `Makefile.config` still references VERSION=6.10.0. Use whatever version the one-apps build system provides -- it is baked into the base image during Packer build. | MEDIUM |

**How contextualization works in this appliance:**

The appliance script (`appliance.sh`) implements three lifecycle hooks that OpenNebula's context system calls:

1. **`service_install`** -- Runs during Packer build. Installs Docker, NVIDIA driver, NVIDIA Container Toolkit, NemoClaw. Bakes everything into the qcow2 image.
2. **`service_configure`** -- Runs on every boot. Sets up networking, reads context variables (API key, model, security level).
3. **`service_bootstrap`** -- Runs on first boot only. Runs `nemoclaw onboard` non-interactively with the user's API key, creates the sandbox, starts services.

Context variables exposed to users (via `user_inputs` in the marketplace YAML):

| Variable | Purpose | Default |
|----------|---------|---------|
| `NVIDIA_API_KEY` | NVIDIA Endpoints API key | (required) |
| `NEMOCLAW_MODEL` | Inference model | `nvidia/nemotron-3-super-120b-a12b` |
| `NEMOCLAW_SECURITY_LEVEL` | Security policy strictness | `standard` |
| `NEMOCLAW_EGRESS_MODE` | Network egress policy | `restricted` |

### Marketplace Submission

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| marketplace-community repo | master branch | PR target for appliance submission | The appliance PR goes to github.com/OpenNebula/marketplace-community. Follow the Prowler PR #99 pattern exactly. | HIGH |
| marketplace-check | (CI action) | PR validation | Automated check that runs on marketplace PRs. Must pass for merge. | MEDIUM |

**File structure (following Prowler PR #99):**

```
appliances/nemoclaw/
  appliance.sh            # Lifecycle hooks (install/configure/bootstrap)
  metadata.yaml           # Build metadata
  README.md               # Documentation
  CHANGELOG.md            # Version history
  context.yaml            # OpenNebula context parameters
  tests.yaml              # Test suite config
  tests/
    00-nemoclaw_basic.rb   # RSpec tests

apps-code/community-apps/packer/nemoclaw/
  nemoclaw.pkr.hcl        # Packer HCL config
  variables.pkr.hcl       # Build variables
  common.pkr.hcl          # Symlink to shared config
  gen_context             # Context generation
  81-configure-ssh.sh     # SSH setup
  82-configure-context.sh # Contextualization setup
  postprocess.sh          # Post-build processing

logos/
  nemoclaw.png            # Appliance logo

docs/automatic-appliance-tutorial/
  nemoclaw.env            # Environment config wizard

<UUID>.yaml               # Marketplace metadata (UUID filename)
```

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ruby | System package | RSpec test runner | Running appliance tests (`tests/00-nemoclaw_basic.rb`) |
| qemu-utils | System package | Image manipulation | Post-processing qcow2 images (qemu-img convert) |
| guestfs-tools | System package | Image inspection | Mounting/inspecting built images for testing |
| jq | System package | JSON parsing | Appliance scripts parsing context/API responses |
| NetworkManager | System package (in image) | Network configuration | Required for proper OpenNebula contextualization (learned from Prowler PR) |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Base OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS | NemoClaw was tested on 22.04. Alpha product = minimize variables. 24.04 possible for v2. |
| Base OS | Ubuntu 22.04 LTS | Alma/Rocky 9 | NemoClaw officially supports Ubuntu. No RHEL-family testing documented. |
| GPU Driver | nvidia-driver-550-server | nvidia-driver-575-server | 575 is newer but less proven for server workloads. 550-server is battle-tested. |
| GPU Driver | nvidia-driver-550-server | nvidia-driver-560+ | Broken on Ubuntu 22.04 due to gcc compiler conflict. Do not use. |
| Container Runtime | Docker CE | Podman | NemoClaw does not support Podman. OpenShell requires Docker daemon. |
| Container Runtime | Docker CE (official repo) | docker.io (Ubuntu repo) | Ubuntu-packaged Docker is outdated. Official repo gets security patches faster. |
| Node.js | 22.x LTS | 20.x LTS | Node 20 EOL is April 2026 -- one month away. 22.x is the active LTS. |
| Build Tool | Packer 1.15.0 | Manual QEMU scripts | one-apps mandates Packer. No alternative. |
| Contextualization | one-context 6.10.0 | Custom cloud-init | OpenNebula ecosystem requires one-context. Not optional. |
| Inference | NVIDIA Endpoints (remote) | Local vLLM/Ollama | NemoClaw marks local inference as experimental. Remote is the supported path. |

## Installation Commands

```bash
# === On the Build Host (for Packer builds) ===

# Packer
curl -fsSL https://releases.hashicorp.com/packer/1.15.0/packer_1.15.0_linux_amd64.zip -o packer.zip
unzip packer.zip && sudo mv packer /usr/local/bin/

# QEMU and build tools
sudo apt-get install -y qemu-system-x86 qemu-utils guestfs-tools ruby make

# Clone marketplace-community
git clone https://github.com/OpenNebula/marketplace-community.git
cd marketplace-community
git submodule update --init --recursive


# === Inside the VM Image (via Packer provisioner / appliance.sh service_install) ===

# Docker Engine (official repo)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# NVIDIA Driver (server variant, no X11)
apt-get install -y nvidia-driver-550-server

# NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' > /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update && apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Node.js 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# NemoClaw (non-interactive install, skip onboarding)
curl -fsSL https://nvidia.com/nemoclaw.sh -o /tmp/nemoclaw-install.sh
sed -i 's/^ *run_onboard$/ # run_onboard (skipped)/' /tmp/nemoclaw-install.sh
bash /tmp/nemoclaw-install.sh

# NetworkManager (needed for contextualization)
apt-get install -y network-manager

# Utilities
apt-get install -y jq curl wget
```

## Disk Space Budget

| Component | Size (approx.) | Notes |
|-----------|-----------------|-------|
| Ubuntu 22.04 base | ~1.5 GB | Minimal server install |
| NVIDIA driver 550-server | ~300 MB | Kernel modules + userspace |
| Docker Engine | ~400 MB | Engine + CLI + containerd |
| NVIDIA Container Toolkit | ~50 MB | Lightweight shim |
| Node.js 22 + npm | ~100 MB | Runtime only |
| NemoClaw + OpenShell | ~3 GB | OpenShell sandbox image is 2.4 GB compressed |
| System packages (jq, etc.) | ~50 MB | Utilities |
| **Total estimated** | **~5.5 GB** | Before first boot; grows with sandbox creation |

Minimum disk requirement: 20 GB (to allow room for sandbox, logs, agent data). Recommended: 40 GB.

## Sources

- [NVIDIA NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw) -- System requirements, installation
- [NVIDIA NemoClaw Developer Guide - Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html) -- Prerequisites, installation steps
- [NVIDIA NemoClaw Developer Guide - Overview](https://docs.nvidia.com/nemoclaw/latest/about/overview.html) -- Architecture, security model
- [NVIDIA OpenShell GitHub](https://github.com/NVIDIA/OpenShell) -- Sandbox runtime requirements
- [NVIDIA Container Toolkit Releases](https://github.com/NVIDIA/nvidia-container-toolkit/releases) -- v1.19.0 (March 12, 2025)
- [NVIDIA Container Toolkit Install Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) -- Installation steps
- [NVIDIA Container Toolkit Supported Platforms](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/supported-platforms.html) -- Ubuntu 22.04 support confirmed
- [NVIDIA Driver 560 Failure on Ubuntu 22.04](https://forums.developer.nvidia.com/t/root-cause-analysis-for-nvidia-driver-560-install-failure-on-ubuntu-22-04/335528) -- gcc-11/12 compiler conflict
- [Ubuntu NVIDIA 575 Driver Backport](https://ubuntuhandbook.org/index.php/2025/07/ubuntu-adding-nvidia-575-driver-support-for-24-04-22-04-lts/) -- 575.57.08 available for 22.04
- [Docker Engine Release Notes v29](https://docs.docker.com/engine/release-notes/29/) -- Latest stable (29.3.0, March 2026)
- [Docker Engine Install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) -- Official installation guide
- [OpenNebula one-apps GitHub](https://github.com/OpenNebula/one-apps) -- Build toolchain
- [OpenNebula one-apps Releases](https://github.com/OpenNebula/one-apps/releases) -- Apps 7.0.0 (May 2025)
- [OpenNebula one-apps plugins.pkr.hcl](https://github.com/OpenNebula/one-apps/blob/master/packer/plugins.pkr.hcl) -- QEMU plugin `~> 1`
- [OpenNebula marketplace-community GitHub](https://github.com/OpenNebula/marketplace-community) -- Appliance structure
- [OpenNebula marketplace-community Wiki](https://github.com/OpenNebula/marketplace-community/wiki/marketplace_start) -- Submission guide
- [OpenNebula marketplace-community PR #99 (Prowler)](https://github.com/OpenNebula/marketplace-community/pull/99) -- Reference appliance structure
- [OpenNebula addon-context-linux Releases](https://github.com/OpenNebula/addon-context-linux/releases) -- v6.6.1 (June 2024), repo archived
- [HashiCorp Packer Releases](https://github.com/hashicorp/packer/releases) -- v1.15.0 (February 4, 2026)
- [Packer QEMU Plugin](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu) -- Latest 1.1.4
- [Packer End-of-Life](https://endoflife.date/hashicorp-packer) -- N-2 support policy, 1.13+ supported
- [Node.js End-of-Life](https://nodejs.org/en/about/eol) -- Node 20 EOL April 2026, Node 22 is current LTS
- [NemoClaw Non-Interactive Install](https://www.secondtalent.com/resources/how-to-install-nvidia-nemoclaw/) -- sed workaround for skipping onboard

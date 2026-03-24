<!-- GSD:project-start source:PROJECT.md -->
## Project

**NemoClaw OpenNebula Marketplace Appliance**

A community marketplace appliance that packages NVIDIA's NemoClaw (open-source AI agent security stack built on OpenClaw) as a ready-to-deploy single-VM image for OpenNebula. Users import the appliance from the Community Marketplace and get a fully configured NemoClaw instance with GPU passthrough support, Docker-based sandbox runtime, and NVIDIA inference routing out of the box.

**Core Value:** One-click deployment of NemoClaw on OpenNebula with GPU passthrough and secure defaults, so cloud operators can run AI agents without manual Docker/NVIDIA setup.

### Constraints

- **Tech stack**: Ubuntu 22.04 LTS base image, Docker Engine, NVIDIA Container Toolkit, NemoClaw installer
- **Image format**: qcow2 for KVM hypervisor
- **Build toolchain**: Must use the one-apps Packer build system from marketplace-community
- **GPU**: NVIDIA GPU with passthrough required for full functionality; appliance should gracefully handle no-GPU case (remote inference only)
- **NemoClaw status**: Alpha software - APIs may change, document this clearly
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Base OS Image
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Ubuntu Server | 22.04.5 LTS (Jammy) | Base VM operating system | NemoClaw officially supports Ubuntu 22.04 LTS. The PROJECT.md confirms this. Ubuntu 22.04 has LTS support until April 2027 (standard), extended to 2032 with ESM. The one-apps build system uses Ubuntu 22.04 for service appliances (Harbor, MinIO, OneKE). | HIGH |
| Linux Kernel | 5.15 HWE (default) | Kernel for NVIDIA driver support | The stock 5.15 HWE kernel in Ubuntu 22.04 supports NVIDIA driver 550-server and 575. No need for a custom kernel. | HIGH |
### NVIDIA Driver Stack
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| nvidia-driver-550-server | 550.x (latest in Ubuntu repos) | GPU driver for data center / cloud workloads | The `-server` variant is designed for headless compute workloads (no X11). 550 is the most stable branch for Ubuntu 22.04 with proven compatibility. The 575 driver is now backported to 22.04 repos and could be an option, but 550-server has the longest track record. | HIGH |
| NVIDIA Container Toolkit | 1.19.0 | Docker integration for GPU passthrough to containers | Latest stable release (March 12, 2025). Provides `nvidia-ctk` for configuring Docker runtime. Required by OpenShell for GPU sandbox support. Installed from NVIDIA's apt repo, not Ubuntu's. | HIGH |
### Container Runtime
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Docker Engine (docker-ce) | 28.x or 29.x (latest stable from Docker repos) | Container runtime for NemoClaw/OpenShell | Docker is NemoClaw's primary supported container runtime on Linux. Docker 29.x is the current latest (29.3.0, March 2026). Docker 28.x is still supported. Install from Docker's official apt repo, not Ubuntu's `docker.io` package. The NVIDIA Container Toolkit requires Docker >= 19.03, and CDI support (modern GPU integration path) requires Docker >= 25. | HIGH |
| Docker Compose Plugin | Latest (bundled with docker-ce) | Multi-container orchestration | Installed automatically with `docker-compose-plugin` package from Docker repos. NemoClaw may use Compose for multi-service setups. | HIGH |
| containerd.io | Latest (bundled with docker-ce) | Low-level container runtime | Required by Docker Engine. Installed from Docker repos. | HIGH |
### NemoClaw & OpenShell
| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| NemoClaw | Latest (alpha, March 2026) | AI agent security stack | Core application being packaged. Installed via `curl -fsSL https://www.nvidia.com/nemoclaw.sh \| bash`. The installer downloads OpenShell, configures the sandbox, and sets up the CLI. | MEDIUM |
| OpenShell | Latest (installed by NemoClaw) | Secure sandbox runtime | Provides Landlock/seccomp/network namespace isolation. Runs K3s inside a Docker container. Sandbox image is ~2.4 GB compressed. Installed automatically by the NemoClaw installer. | MEDIUM |
| Node.js | 22.x LTS | NemoClaw CLI runtime | NemoClaw requires Node.js 20+. However, Node.js 20 reaches EOL April 30, 2026 -- just one month from now. Node.js 22 is the current Active LTS (codename 'Jod'). Install via NodeSource or the NemoClaw installer handles it. Use 22.x for longevity. | HIGH |
| npm | 10.x | Package manager | Bundled with Node.js 22.x. NemoClaw requires npm 10+. | HIGH |
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
# === On the Build Host (for Packer builds) ===
# Packer
# QEMU and build tools
# Clone marketplace-community
# === Inside the VM Image (via Packer provisioner / appliance.sh service_install) ===
# Docker Engine (official repo)
# NVIDIA Driver (server variant, no X11)
# NVIDIA Container Toolkit
# Node.js 22 LTS
# NemoClaw (non-interactive install, skip onboarding)
# NetworkManager (needed for contextualization)
# Utilities
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

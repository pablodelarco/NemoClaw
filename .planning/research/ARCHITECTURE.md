# Architecture Patterns

**Domain:** OpenNebula Marketplace Appliance (Docker-based GPU service)
**Researched:** 2026-03-24
**Confidence:** HIGH (based on Prowler PR #99 direct reference, official OpenNebula docs, NVIDIA NemoClaw docs)

## Recommended Architecture

NemoClaw is packaged as a single-VM OpenNebula marketplace appliance. The appliance image (qcow2) is built offline with Packer, uploaded to the marketplace, and instantiated by users through Sunstone or the CLI. At boot, OpenNebula contextualization triggers the appliance lifecycle (configure, bootstrap), which sets up Docker containers, GPU access, and the NemoClaw sandbox.

### Architecture Layers (Outside-In)

```
+------------------------------------------------------------------+
|  OpenNebula Cloud                                                 |
|  +--------------------------------------------------------------+|
|  |  KVM/QEMU VM (Ubuntu 22.04, qcow2 image)                    ||
|  |  +----------------------------------------------------------+||
|  |  |  Host OS Layer                                            |||
|  |  |  - OpenNebula context packages                            |||
|  |  |  - /etc/one-appliance/service (lifecycle manager)         |||
|  |  |  - /etc/one-appliance/service.d/appliance.sh (NemoClaw)   |||
|  |  |  - NVIDIA drivers + Container Toolkit                     |||
|  |  |  - Docker Engine                                          |||
|  |  |  +------------------------------------------------------+|||
|  |  |  |  Docker Layer                                         ||||
|  |  |  |  +--------------------------------------------------+||||
|  |  |  |  |  OpenShell Gateway Container                      |||||
|  |  |  |  |  - K3s-based sandbox orchestrator                 |||||
|  |  |  |  |  - Inference routing proxy                        |||||
|  |  |  |  |  - Policy enforcement engine                      |||||
|  |  |  |  |  +----------------------------------------------+|||||
|  |  |  |  |  |  OpenClaw Sandbox Container                   ||||||
|  |  |  |  |  |  - OpenClaw agent + NemoClaw plugin           ||||||
|  |  |  |  |  |  - Landlock/seccomp filesystem isolation      ||||||
|  |  |  |  |  |  - Network namespace (egress restricted)      ||||||
|  |  |  |  |  +----------------------------------------------+|||||
|  |  |  |  +--------------------------------------------------+||||
|  |  |  +------------------------------------------------------+|||
|  |  +----------------------------------------------------------+||
|  +--------------------------------------------------------------+|
+------------------------------------------------------------------+
```

## Component Boundaries

### 1. Build-Time Components (Developer Machine / Build Host)

| Component | Responsibility | Location |
|-----------|---------------|----------|
| **Packer Build Config** | Defines VM image build: base ISO, provisioning, post-processing | `apps-code/community-apps/packer/nemoclaw/` |
| **gen_context** | Generates context ISO for Packer build SSH access | `packer/nemoclaw/gen_context` |
| **cloud-init.yml** | Bootstraps root access during Packer build | `packer/nemoclaw/cloud-init.yml` |
| **81-configure-ssh.sh** | Hardens SSH after Packer provisioning (disables password auth) | `packer/nemoclaw/81-configure-ssh.sh` |
| **82-configure-context.sh** | Installs context hooks into `/etc/one-context.d/` | `packer/nemoclaw/82-configure-context.sh` |
| **postprocess.sh** | virt-sysprep (clean machine-id, hostname) + virt-sparsify (compress) | Symlink to `one-apps/packer/postprocess.sh` |
| **Makefile / Makefile.config** | Build orchestration targets | `apps-code/community-apps/Makefile*` |

### 2. Marketplace Metadata Components (Repository)

| Component | Responsibility | Location |
|-----------|---------------|----------|
| **UUID.yaml** | Marketplace entry: name, description, template, user_inputs, image URL, checksums | `appliances/nemoclaw/<uuid>.yaml` |
| **metadata.yaml** | Build configuration: OS base, context params, template defaults, disk format | `appliances/nemoclaw/metadata.yaml` |
| **appliance.sh** | Service lifecycle: service_install, service_configure, service_bootstrap | `appliances/nemoclaw/appliance.sh` |
| **context.yaml** | Default context parameter values | `appliances/nemoclaw/context.yaml` |
| **tests.yaml** | Test file manifest | `appliances/nemoclaw/tests.yaml` |
| **Test scripts** | Ruby RSpec tests for appliance certification | `appliances/nemoclaw/tests/00-nemoclaw_basic.rb` |
| **README.md** | User documentation | `appliances/nemoclaw/README.md` |
| **CHANGELOG.md** | Version history | `appliances/nemoclaw/CHANGELOG.md` |
| **Logo** | Marketplace icon | `logos/nemoclaw.png` |

### 3. Runtime Components (Inside the VM)

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **OpenNebula Context Agent** | Injects SSH keys, network config, context params at boot | VM metadata -> OS config |
| **net-90-service-appliance** | Context hook that triggers service configure + bootstrap | Context agent -> service.sh |
| **net-99-report-ready** | Reports successful boot to OpenNebula | service.sh -> OpenNebula API |
| **service.sh** | Lifecycle manager: loads appliance.sh, runs stages, manages locks/logs | Context hooks -> appliance.sh |
| **appliance.sh** | NemoClaw-specific install/configure/bootstrap logic | service.sh -> Docker / NemoClaw |
| **Docker Engine** | Container runtime with NVIDIA Container Toolkit | appliance.sh -> containers |
| **NVIDIA Container Toolkit** | Exposes GPU to containers via `--gpus` flag | Docker -> NVIDIA drivers |
| **NVIDIA GPU Drivers** | Kernel-level GPU access (installed in VM) | Container Toolkit -> hardware |
| **OpenShell Gateway** | Sandbox orchestrator: manages inference routing, policies | NemoClaw CLI -> sandbox |
| **OpenClaw Sandbox** | Isolated agent container with security policies | Gateway -> NVIDIA Endpoints |
| **NemoClaw Plugin** | TypeScript CLI plugin for sandbox lifecycle management | User CLI -> Gateway |
| **NemoClaw Blueprint** | Python artifact: policy definitions, sandbox configuration | Plugin -> OpenShell CLI |

## Data Flow

### A. Build Pipeline (Offline, on Build Host)

```
Ubuntu 22.04 base qcow2 (from one-apps)
    |
    v
[Packer QEMU builder]
    |-- Boot VM with context ISO (gen_context)
    |-- SSH in as root
    |-- 81-configure-ssh.sh (harden SSH)
    |-- Create /etc/one-appliance/ directory structure
    |-- Copy service.sh, lib/common.sh, lib/functions.sh
    |-- Copy appliance.sh to /etc/one-appliance/service.d/
    |-- 82-configure-context.sh (install context hooks)
    |-- /etc/one-appliance/service install (runs service_install)
    |       |-- apt install: Docker, NVIDIA Container Toolkit, Node.js
    |       |-- Install NemoClaw (curl installer)
    |       |-- Pre-pull sandbox container image (~2.4GB)
    |       |-- Configure console autologin, welcome message
    |       |-- Cleanup (apt cache, tmp files)
    |
    v
[Post-processor: postprocess.sh]
    |-- virt-sysprep: clear machine-id, hostname, resolv.conf, disable root pw
    |-- virt-sparsify: compress qcow2 in-place
    |
    v
Final qcow2 image (~8-12GB estimated)
    |
    v
Upload to CDN, update UUID.yaml with URL + checksums
```

### B. VM Boot Sequence (Runtime, on OpenNebula Cloud)

```
1. OpenNebula instantiates VM from qcow2 image
   |-- PCI passthrough: GPU assigned via PCI=[SHORT_ADDRESS="xx:xx.x"]
   |-- Network: DHCP on eth0
   |-- Context: SSH keys, ONEAPP_* parameters injected

2. VM boots Ubuntu 22.04
   |-- cloud-init / one-context configures networking, hostname, SSH keys

3. Context scripts execute in order:
   |-- /etc/one-context.d/net-90-service-appliance
   |       |-- /etc/one-appliance/service configure
   |       |       |-- service_configure() in appliance.sh
   |       |       |-- Read ONEAPP_NEMOCLAW_* context params
   |       |       |-- Configure NVIDIA API key
   |       |       |-- Set security policy level
   |       |       |-- Configure network egress mode
   |       |       |-- Write config files, generate secrets
   |       |       |-- Write service report to /etc/one-appliance/config
   |       |
   |       |-- /etc/one-appliance/service bootstrap
   |               |-- service_bootstrap() in appliance.sh
   |               |-- Start Docker if not running
   |               |-- Run nemoclaw onboard (creates sandbox)
   |               |-- Verify sandbox health
   |               |-- Display access information
   |
   |-- /etc/one-context.d/net-99-report-ready
           |-- Reports VM ready to OpenNebula

4. VM is accessible:
   |-- SSH: root@<VM_IP> (key-based auth)
   |-- VNC: via Sunstone
   |-- NemoClaw CLI: nemoclaw <name> connect
```

### C. GPU Passthrough Chain

```
Physical NVIDIA GPU (on OpenNebula host)
    |
    | [IOMMU + vfio-pci driver on host]
    |
    v
OpenNebula PCI Device Assignment
    |
    | [PCI=[SHORT_ADDRESS="xx:xx.x"] in VM template]
    |
    v
KVM/QEMU VM (PCI device visible as /dev/nvidia*)
    |
    | [NVIDIA kernel drivers loaded inside VM]
    |
    v
NVIDIA Container Toolkit (nvidia-ctk)
    |
    | [Configures Docker runtime: /etc/docker/daemon.json]
    | [docker run --gpus all ...]
    |
    v
OpenShell Gateway Container (access to GPU)
    |
    v
OpenClaw Sandbox Container (GPU available for local inference)
```

**Important:** For v1, GPU is optional. NemoClaw defaults to remote NVIDIA Endpoints (build.nvidia.com) for inference. GPU passthrough enables future local inference with Ollama/vLLM (currently experimental in NemoClaw).

### D. Network Flow (User Interaction)

```
User
  |
  |-- SSH --> VM:22 --> bash shell
  |               |-- nemoclaw my-agent connect --> sandbox shell
  |               |-- openclaw tui --> interactive agent chat
  |               |-- openclaw agent -m "..." --> single command
  |
  |-- VNC --> VM:5900 (via Sunstone) --> console
  |
  v
[Inside Sandbox]
  Agent needs inference:
    OpenClaw agent --> NemoClaw plugin intercepts
        --> OpenShell gateway (inside VM)
            --> NVIDIA Endpoints API (build.nvidia.com)
                --> Nemotron 3 Super 120B model
                <-- Response
            <-- Routed back through gateway
        <-- Plugin delivers to agent
    Agent produces output

  Agent needs network (e.g., web browsing):
    OpenClaw agent --> sandbox network namespace
        --> Policy check (openclaw-sandbox.yaml allowlist)
            --> ALLOWED: request proceeds through VM network
            --> DENIED: blocked, surfaces in TUI for operator approval
```

### E. Inference Routing Detail

```
                     +-----------+
                     |  Agent    |
                     | (sandbox) |
                     +-----+-----+
                           |
                    inference request
                           |
                     +-----v-----+
                     | NemoClaw  |
                     |  Plugin   |
                     +-----+-----+
                           |
                  intercept & route
                           |
                     +-----v-----+
                     | OpenShell |
                     |  Gateway  |
                     +-----+-----+
                           |
              +------------+------------+
              |                         |
        [Remote Mode]            [Local Mode]
              |                    (experimental)
              v                         v
    +------------------+      +------------------+
    | NVIDIA Endpoints |      | Ollama / vLLM    |
    | build.nvidia.com |      | (localhost GPU)   |
    | Nemotron 120B    |      | (requires GPU)    |
    +------------------+      +------------------+
```

## PR Structure for marketplace-community

Based directly on Prowler PR #99 (Pablo's own submission), the NemoClaw PR should contain exactly these files:

```
marketplace-community/
|
+-- appliances/nemoclaw/
|   +-- <uuid>.yaml               # Marketplace metadata (uuidgen for filename)
|   +-- appliance.sh              # Lifecycle script (service_install/configure/bootstrap)
|   +-- metadata.yaml             # Build config (OS base, context params, template)
|   +-- context.yaml              # Default context parameter values
|   +-- tests.yaml                # Test manifest
|   +-- tests/
|   |   +-- 00-nemoclaw_basic.rb  # RSpec appliance certification tests
|   +-- README.md                 # Documentation
|   +-- CHANGELOG.md              # Version history
|
+-- apps-code/community-apps/
|   +-- Makefile.config            # ADD 'nemoclaw' to SERVICES list
|   +-- packer/nemoclaw/
|       +-- nemoclaw.pkr.hcl      # Main Packer config (QEMU source, provisioners, post-processor)
|       +-- variables.pkr.hcl     # Packer variables (appliance_name, version, dirs, headless)
|       +-- common.pkr.hcl        # Symlink -> ../../../one-apps/packer/common.pkr.hcl
|       +-- gen_context            # Script generating context ISO for build-time SSH
|       +-- cloud-init.yml        # Cloud-init config for build VM (root access)
|       +-- 81-configure-ssh.sh   # SSH hardening (runs during Packer provisioning)
|       +-- 82-configure-context.sh  # Install context hooks into /etc/one-context.d/
|
+-- logos/
    +-- nemoclaw.png              # Application logo for marketplace listing
```

**Modified files (not new):**
- `apps-code/community-apps/Makefile.config` - Add `nemoclaw` to the `SERVICES` list

## How the one-apps Build System Works

### Makefile Targets

```
make nemoclaw              # Build the NemoClaw appliance
make services              # Build all community appliances
make -j 4 services         # Parallel build (4 jobs)
make clean                 # Remove all built images
```

Internally, `make nemoclaw` resolves to `packer-nemoclaw` which builds `export/nemoclaw.qcow2`.

### Packer Build Flow

The `.pkr.hcl` file defines two builds:

1. **Context ISO build** (source: `null`):
   - Runs `gen_context` script to produce a context.sh
   - Creates an ISO with `mkisofs` containing context variables for build-time VM access

2. **QEMU VM build** (source: `qemu`):
   - Uses pre-built Ubuntu 22.04 base qcow2 from `one-apps/export/ubuntu2204.qcow2`
   - Boots with KVM acceleration, attaches context ISO as CDROM
   - SSH in with root/opennebula credentials
   - Provisioners run in sequence:
     a. `81-configure-ssh.sh` - Harden SSH config
     b. Create `/etc/one-appliance/` directory structure
     c. Copy framework files: `net-90-service-appliance`, `net-99-report-ready`, `common.sh`, `functions.sh`, `service.sh`
     d. Copy `appliance.sh` to `/etc/one-appliance/service.d/`
     e. `82-configure-context.sh` - Install context hooks
     f. `/etc/one-appliance/service install` - Execute `service_install()`
   - Post-processor: `postprocess.sh` (virt-sysprep + virt-sparsify)

### Key Differences from Prowler

NemoClaw's Packer config needs these adjustments vs. the Prowler template:

| Aspect | Prowler | NemoClaw |
|--------|---------|----------|
| Base image | `ubuntu2404.qcow2` | `ubuntu2204.qcow2` (NemoClaw requires 22.04) |
| Memory | 8192 MB | 8192 MB (same, minimum for NemoClaw) |
| Disk size | 20480 MB (20 GB) | 40960 MB (40 GB, sandbox image is 2.4 GB + Docker overhead) |
| GPU in template | Not needed | PCI passthrough section in UUID.yaml template |
| Pre-pulled images | Prowler containers (~5 GB) | OpenShell sandbox (~2.4 GB compressed) |
| Runtime | Docker Compose (multi-container) | NemoClaw installer (manages OpenShell internally) |
| NVIDIA toolkit | Not needed | Required (nvidia-container-toolkit package) |

## Patterns to Follow

### Pattern 1: Appliance Lifecycle Script (appliance.sh)

The appliance.sh follows a strict contract defined by the `service.sh` framework:

```bash
#!/usr/bin/env bash
set -o errexit -o pipefail

# Configuration constants
NEMOCLAW_DATA_DIR="/opt/nemoclaw"
ONE_SERVICE_SETUP_DIR="/opt/one-appliance"

# Context parameters - define what users can set in Sunstone
ONE_SERVICE_PARAMS=(
    'ONEAPP_NEMOCLAW_API_KEY'       'configure' 'NVIDIA API key'                'M|password'
    'ONEAPP_NEMOCLAW_MODEL'         'configure' 'Inference model name'          'O|text'
    'ONEAPP_NEMOCLAW_POLICY'        'configure' 'Security policy level'         'O|text'
    'ONEAPP_NEMOCLAW_EGRESS_MODE'   'configure' 'Network egress mode'           'O|text'
)

# Metadata
ONE_SERVICE_NAME='NemoClaw'
ONE_SERVICE_VERSION='0.1.0'
ONE_SERVICE_RECONFIGURABLE=true

# REQUIRED FUNCTIONS:
service_install()   { ... }  # Called during Packer build
service_configure() { ... }  # Called at first boot (via context)
service_bootstrap() { ... }  # Called after configure (via context)
service_cleanup()   { : }    # Called on reconfigure
```

**Parameter format:** `'NAME' 'stage' 'description' 'M|O|type'`
- M = mandatory, O = optional
- Types: text, password, boolean

### Pattern 2: Packer Provisioner Chain

Follow the exact sequence from Prowler PR #99. The order matters because later steps depend on earlier ones (e.g., `service install` requires the directory structure created by earlier provisioners).

```hcl
build {
  sources = ["source.qemu.nemoclaw"]

  provisioner "shell" { scripts = ["81-configure-ssh.sh"] }           # 1. SSH hardening
  provisioner "shell" { inline = ["install -d /etc/one-appliance/..."] } # 2. Dirs
  provisioner "file"  { sources = ["net-90-*", "net-99-*"] }          # 3. Context hooks
  provisioner "file"  { sources = ["common.sh", "functions.sh"] }     # 4. Libraries
  provisioner "file"  { source = "service.sh" }                       # 5. Service manager
  provisioner "file"  { sources = ["appliance.sh"] }                  # 6. App script
  provisioner "shell" { scripts = ["82-configure-context.sh"] }       # 7. Context config
  provisioner "shell" { inline = ["/etc/one-appliance/service install"] } # 8. Install

  post-processor "shell-local" { scripts = ["postprocess.sh"] }       # 9. Cleanup
}
```

### Pattern 3: UUID YAML Template with GPU Support

The UUID.yaml must include PCI passthrough configuration in the template section and NemoClaw-specific user_inputs:

```yaml
opennebula_template:
  context:
    network: 'YES'
    ssh_public_key: $USER[SSH_PUBLIC_KEY]
  cpu: '4'
  vcpu: '4'
  graphics:
    listen: 0.0.0.0
    type: vnc
  memory: '8192'
  os:
    arch: x86_64
    firmware: UEFI
    machine: q35
  cpu_model:
    model: host-passthrough
  # PCI passthrough placeholder - user must configure their GPU address
  # PCI: SHORT_ADDRESS will be set by the cloud administrator
  user_inputs:
    ONEAPP_NEMOCLAW_API_KEY: 'M|password|NVIDIA API key (from build.nvidia.com)||'
    ONEAPP_NEMOCLAW_MODEL: 'O|text|Inference model|nvidia/nemotron-3-super-120b-a12b|nvidia/nemotron-3-super-120b-a12b'
    ONEAPP_NEMOCLAW_POLICY: 'O|text|Security policy (default/strict/permissive)|default|default'
    ONEAPP_NEMOCLAW_EGRESS_MODE: 'O|text|Network egress (restricted/open)|restricted|restricted'
  inputs_order: ONEAPP_NEMOCLAW_API_KEY,ONEAPP_NEMOCLAW_MODEL,ONEAPP_NEMOCLAW_POLICY,ONEAPP_NEMOCLAW_EGRESS_MODE
```

### Pattern 4: Test Structure

Tests use RSpec with SSH-based verification. Each test SSHs into the running VM and checks a condition:

```ruby
describe 'Appliance Certification' do
  include_context('vm_handler')

  it 'docker is installed' do
    result = @info[:vm].ssh('which docker')
    # retry loop with timeout
  end

  it 'nemoclaw sandbox is running' do
    result = @info[:vm].ssh('nemoclaw my-agent status')
    # verify healthy
  end

  it 'check oneapps motd' do
    # Verify "All set and ready to serve" in /etc/motd
  end
end
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Installing NemoClaw at Boot Time
**What:** Downloading and installing NemoClaw during service_configure or service_bootstrap instead of during build.
**Why bad:** The NemoClaw installer downloads ~2.4 GB of container images. Doing this at every VM boot is slow (5-10 minutes), fragile (network dependency), and wastes bandwidth.
**Instead:** Run the NemoClaw installer and pre-pull the sandbox container image during `service_install()` in the Packer build. At boot, only run `nemoclaw onboard` to create the sandbox from pre-pulled images.

### Anti-Pattern 2: Hardcoding GPU PCI Addresses
**What:** Setting a specific PCI address like `PCI=[SHORT_ADDRESS="e1:00.0"]` in the template.
**Why bad:** GPU PCI addresses vary across hosts. Hardcoding makes the appliance undeployable on most hardware.
**Instead:** Document GPU assignment as a post-deploy step. The cloud administrator assigns GPUs via Sunstone or `onevm update`. The appliance should detect GPU presence at boot and adjust behavior (GPU available = offer local inference, no GPU = remote-only).

### Anti-Pattern 3: Running as Non-Root Without Preparation
**What:** Assuming NemoClaw/OpenShell can run as a non-root user without explicit setup.
**Why bad:** Docker, NVIDIA drivers, and OpenShell gateway require elevated privileges or specific group membership. The Prowler pattern runs everything as root for simplicity.
**Instead:** Run as root (marketplace appliance convention) but ensure sandbox isolation provides the security boundary. NemoClaw's Landlock/seccomp policies handle agent containment.

### Anti-Pattern 4: Blocking on GPU During Bootstrap
**What:** Making service_bootstrap() fail if no GPU is detected.
**Why bad:** Many users will test without GPU first, or use remote inference only. Failing bootstrap breaks the appliance for the majority use case.
**Instead:** Detect GPU, log a warning if absent, and configure for remote-only inference. GPU becomes an enhancement, not a requirement.

## Scalability Considerations

| Concern | Single VM (v1) | Future: OneFlow Service |
|---------|----------------|------------------------|
| Agent count | 1 sandbox per VM | Multiple VMs, each with 1 sandbox |
| GPU sharing | Exclusive GPU passthrough | vGPU or MIG for sharing |
| High availability | None (single VM) | Service template with HA |
| Load balancing | N/A | OneFlow service with LB |
| Storage | Local qcow2 disk | Shared filesystem (Ceph) |

Scalability is explicitly out of scope for v1. The single-VM architecture is correct for an alpha-status tool like NemoClaw.

## Suggested Build Order (Dependencies)

Components should be built in this order because each depends on the previous:

```
Phase 1: Foundation
  +-- appliance.sh (lifecycle script - core of everything)
  +-- metadata.yaml (build config)
  +-- context.yaml (default params)

Phase 2: Build Pipeline
  +-- gen_context (depends on: knowing context params from Phase 1)
  +-- cloud-init.yml (standard, low dependency)
  +-- 81-configure-ssh.sh (standard, copy from Prowler)
  +-- 82-configure-context.sh (standard, copy from Prowler)
  +-- variables.pkr.hcl (standard, copy from Prowler)
  +-- nemoclaw.pkr.hcl (depends on: all provisioning scripts exist)
  +-- Makefile.config (add 'nemoclaw' to SERVICES)

Phase 3: Build & Test
  +-- Run Packer build on build host (depends on: all Phase 2 files)
  +-- Boot VM, verify manually (depends on: successful build)
  +-- tests.yaml + test scripts (depends on: knowing what to test)

Phase 4: Marketplace Packaging
  +-- Upload qcow2 to CDN (depends on: tested image)
  +-- UUID.yaml with checksums (depends on: uploaded image)
  +-- README.md, CHANGELOG.md (depends on: tested functionality)
  +-- logos/nemoclaw.png
  +-- PR submission
```

## Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| NemoClaw installer (not manual Docker setup) | NemoClaw has its own installer script that handles OpenShell, blueprint, and sandbox creation. Wrapping it preserves upgrade path. |
| Pre-pull sandbox image during build | 2.4 GB download at boot is unacceptable. Pre-pulling during Packer build means instant sandbox creation at boot. |
| Remote inference as default | Local inference is experimental in NemoClaw. NVIDIA Endpoints (build.nvidia.com) is the supported path. |
| GPU optional at boot | Appliance must work without GPU for testing and remote-inference-only use cases. |
| Single sandbox named "my-agent" | Matches NemoClaw quickstart convention. Users can create additional sandboxes manually. |
| Root execution | Marketplace appliance convention. Docker/NVIDIA access requires it. NemoClaw sandbox provides agent isolation. |

## Sources

- [OpenNebula marketplace-community repository](https://github.com/OpenNebula/marketplace-community)
- [Prowler PR #99](https://github.com/OpenNebula/marketplace-community/pull/99) - Pablo's own submission, direct template
- [OpenNebula one-apps build toolchain](https://github.com/OpenNebula/one-apps)
- [NVIDIA NemoClaw Architecture](https://docs.nvidia.com/nemoclaw/latest/reference/architecture.html)
- [NVIDIA NemoClaw How It Works](https://docs.nvidia.com/nemoclaw/latest/about/how-it-works.html)
- [NVIDIA NemoClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html)
- [NVIDIA NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw)
- [OpenNebula NVIDIA GPU Passthrough](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/nvidia_gpu_passthrough/)
- [OpenNebula PCI Passthrough](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/pci_passthrough/)
- [OpenNebula Appliance Lifecycle](https://docs.opennebula.io/6.6/marketplace/appliances/overview.html)
- [NVIDIA Container Toolkit Install Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

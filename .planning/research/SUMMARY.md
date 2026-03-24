# Project Research Summary

**Project:** NemoClaw OpenNebula Marketplace Appliance
**Domain:** GPU-enabled AI agent security appliance packaging (OpenNebula Community Marketplace)
**Researched:** 2026-03-24
**Confidence:** MEDIUM-HIGH

## Executive Summary

NemoClaw is NVIDIA's alpha-stage AI agent security stack that wraps OpenClaw with sandboxed execution via OpenShell (Landlock, seccomp, network namespaces). The goal is to package it as a single-VM OpenNebula marketplace appliance -- a qcow2 image built with Packer that auto-configures at first boot via OpenNebula contextualization. The build pattern is well-established: the marketplace-community repository (with Prowler PR #99 as the direct template) defines the file structure, lifecycle hooks, Packer provisioner chain, and marketplace YAML format. The technology stack is high-confidence: Ubuntu 22.04 LTS, Docker CE, NVIDIA driver 550-server, NVIDIA Container Toolkit 1.19, Node.js 22 LTS, and Packer 1.15. No exotic choices are needed.

The recommended approach is to follow the Prowler/vLLM appliance pattern exactly for build infrastructure and marketplace packaging, then layer NemoClaw-specific logic into the appliance lifecycle script (`appliance.sh`). The core value proposition over the existing vLLM appliance is security: deny-by-default network egress, sandboxed agent execution, and policy-governed inference routing. The appliance should expose security controls (policy level, egress mode, policy presets) as contextualization parameters alongside the mandatory NVIDIA API key. GPU passthrough should be supported but not required -- remote NVIDIA Endpoints inference is the default and stable path.

The primary risks are threefold. First, NemoClaw is alpha software with unstable APIs, so the installer hack (sed-ing out the interactive onboarding wizard) and CLI commands could break without notice. Version pinning during Packer build is essential. Second, GPU passthrough depends on host-side IOMMU configuration that the appliance cannot control, so graceful fallback when no GPU is detected is mandatory. Third, the NemoClaw sandbox image is 2.4 GB compressed, pushing the final qcow2 to 8-12 GB, which demands careful build host sizing (16+ GB RAM, 60+ GB disk, swap space) and qcow2 compression.

## Key Findings

### Recommended Stack

The stack is conventional and high-confidence for the OpenNebula marketplace ecosystem. Ubuntu 22.04 LTS is the validated base (NemoClaw was tested on it; 24.04 is possible for v2 but adds risk to an alpha product). Docker CE from official repos is required (NemoClaw does not support Podman, and OpenShell runs K3s inside Docker). NVIDIA driver 550-server is the safest branch (560+ is broken on 22.04 due to a gcc compiler conflict; 575 is available but less proven for server workloads).

**Core technologies:**
- **Ubuntu 22.04 LTS**: Base OS -- NemoClaw validated, LTS support through 2027/2032 ESM
- **Docker CE 28.x/29.x**: Container runtime -- required by NemoClaw/OpenShell, CDI support needs Docker >= 25
- **NVIDIA driver 550-server**: GPU driver -- stable server branch, avoids the 560 gcc conflict on 22.04
- **NVIDIA Container Toolkit 1.19**: Docker GPU integration -- provides nvidia-ctk for runtime configuration
- **Node.js 22 LTS**: NemoClaw CLI runtime -- Node 20 EOL is April 2026 (one month away)
- **Packer 1.15**: Image builder -- mandated by one-apps build system with QEMU plugin
- **one-context 6.10**: OpenNebula contextualization -- lifecycle hooks for install/configure/bootstrap

**Critical version constraints:**
- Do NOT use NVIDIA driver 560+ on Ubuntu 22.04 (gcc-11/12 conflict)
- Do NOT install CUDA Toolkit on the host (NemoClaw uses remote inference; CUDA lives in containers)
- Do NOT use Ubuntu's `docker.io` package (outdated, use Docker's official apt repo)

### Expected Features

**Must have (table stakes):**
- Contextualization-driven first boot (service_install/configure/bootstrap lifecycle)
- NVIDIA API key injection via CONTEXT (ONEAPP_NEMOCLAW_API_KEY)
- Docker + NVIDIA Container Toolkit pre-installed and configured
- SSH key-based access (password auth disabled)
- GPU passthrough template with PCI config (UEFI, q35, host-passthrough CPU)
- NemoClaw sandbox auto-start on first boot (zero SSH required)
- Marketplace YAML metadata with checksums and user_inputs
- README with prerequisites and quick start

**Should have (differentiators):**
- Security policy level selector (strict/moderate/permissive via CONTEXT)
- Network egress mode control (nvidia-only/development/custom via CONTEXT)
- Model selection via CONTEXT (4 Nemotron models)
- GPU-present detection with graceful fallback to remote-only inference
- First-boot health validation chain (Docker, nvidia-smi, sandbox, inference)
- Status MOTD on SSH login (version, sandbox state, GPU status, model)
- REPORT_READY OneGate integration (enables future OneFlow service templates)
- Policy preset management via CONTEXT (discord, npm, pypi, etc.)

**Defer (v2+):**
- Local inference with Ollama/vLLM (experimental in NemoClaw, doubles image size)
- OneFlow multi-VM service template (NemoClaw lacks distributed coordination)
- Web UI (NemoClaw has no web interface; TUI via openshell term suffices)
- Automatic driver version selection (pinned version is safer)
- Custom model upload (requires local inference stack)

### Architecture Approach

The architecture is a single-VM appliance with nested container layers: Ubuntu 22.04 host OS runs Docker Engine, which runs the OpenShell Gateway container (K3s-based sandbox orchestrator with policy enforcement), which in turn runs the OpenClaw Sandbox container (agent with Landlock/seccomp isolation). Build-time components live in the `packer/nemoclaw/` directory and produce the qcow2 image. Runtime components are triggered by OpenNebula's contextualization system via `net-90-service-appliance` and `net-99-report-ready` hooks. The critical architectural decision is that NemoClaw's own installer manages the OpenShell/OpenClaw stack internally -- the appliance wraps the installer rather than managing Docker containers directly, preserving the upgrade path.

**Major components:**
1. **Packer build pipeline** -- produces the qcow2 image with all dependencies pre-installed
2. **appliance.sh lifecycle script** -- implements service_install (build), service_configure (every boot), service_bootstrap (first boot)
3. **OpenNebula contextualization** -- injects SSH keys, API key, model, security settings via CONTEXT variables
4. **NemoClaw/OpenShell stack** -- manages sandbox creation, inference routing, and policy enforcement inside Docker
5. **Marketplace YAML metadata** -- defines the appliance listing with template, user_inputs, checksums

### Critical Pitfalls

1. **NemoClaw alpha API instability** -- Pin version at build time. The installer is curl-pipe-bash with no version flag. Capture the npm package version (nemoclaw@x.y.z) and Docker image SHA digest during build. Wrap CLI calls with version checks. Expect breakage and plan for appliance rebuilds when NemoClaw ships breaking changes.

2. **NVIDIA driver version mismatch** -- The host VM's baked-in driver must match what the containers expect. Pin to 550-server. Regenerate the CDI spec (`nvidia-ctk cdi generate`) during service_configure, not at build time. Add nvidia-smi container health check in service_bootstrap.

3. **GPU passthrough is a host-side problem** -- The appliance cannot configure IOMMU, vfio-pci, or udev rules on the OpenNebula host. Document host prerequisites prominently. Implement graceful no-GPU fallback (detect via lspci, skip GPU init, use remote inference only).

4. **Image size bloat** -- NemoClaw sandbox (2.4 GB) + Docker + NVIDIA drivers = 8-12 GB qcow2. Build host needs 16+ GB RAM and 60+ GB disk. Add swap during Packer build to prevent OOM. Enable qcow2 compression. Run `docker system prune` after install.

5. **Contextualization timing race** -- Docker/NemoClaw may start before network is ready. Pre-pull all images during Packer build (service_install) so no network is needed at boot for the core stack. Disable `systemd-networkd-wait-online.service`. Add network readiness check before API calls in service_bootstrap.

6. **NVIDIA API key exposure** -- Context variables are visible in Sunstone and stored as plain text. Read the key in service_configure, write to a restricted file (0600), unset the environment variable, and clear it from one_env. Document the security implication.

## Implications for Roadmap

Based on the combined research, the project has a natural four-phase structure dictated by build dependencies, the marketplace submission process, and the separation between MVP and enhancement features.

### Phase 1: Build Foundation and Appliance Lifecycle

**Rationale:** Everything depends on the appliance lifecycle script (appliance.sh) and the Packer build pipeline. These are the foundation -- no testing, no marketplace submission, and no features are possible without a bootable image that follows the one-apps conventions.

**Delivers:** A minimal bootable qcow2 image with Docker, NVIDIA drivers, and NemoClaw pre-installed. The appliance lifecycle script handles service_install (bake dependencies), service_configure (read CONTEXT, configure services), and service_bootstrap (create sandbox, run health checks).

**Addresses features:** Contextualization-driven first boot, Docker + NVIDIA toolkit pre-installed, API key injection, model selection, SSH key access, NemoClaw sandbox auto-start, GPU detection with fallback, basic health checks, basic MOTD.

**Avoids pitfalls:** NemoClaw fresh install requirement (clean base), image size bloat (pre-pull + compression), contextualization timing (pre-pull images, disable wait-online), driver version pinning (550-server).

**Key files:**
- `appliances/nemoclaw/appliance.sh`
- `appliances/nemoclaw/metadata.yaml`
- `appliances/nemoclaw/context.yaml`
- `apps-code/community-apps/packer/nemoclaw/*.pkr.hcl`
- `apps-code/community-apps/packer/nemoclaw/gen_context`
- `apps-code/community-apps/packer/nemoclaw/81-configure-ssh.sh`
- `apps-code/community-apps/packer/nemoclaw/82-configure-context.sh`

### Phase 2: Build Execution and Manual Validation

**Rationale:** Phase 1 produces the code; Phase 2 produces the artifact. The Packer build must run on the dedicated build host (100.123.42.13) with KVM acceleration. Manual validation catches issues that automated tests miss -- GPU passthrough, first-boot timing, MOTD rendering, VNC console experience.

**Delivers:** A tested qcow2 image that boots, auto-configures, creates a NemoClaw sandbox, and validates health. Manual verification covers both GPU and no-GPU paths.

**Addresses features:** GPU passthrough template (PCI config), first-boot health validation, VNC console access.

**Avoids pitfalls:** Build system dependency issues (verify build host), driver mismatch (test nvidia-smi in container), timing races (verify first boot < 3 minutes), API key exposure (verify key file permissions post-boot).

### Phase 3: Testing and Marketplace Packaging

**Rationale:** The marketplace PR requires specific artifacts (UUID.yaml, README, CHANGELOG, tests, logo) and must pass the `/marketplace-check` validation bot. Testing should be split into Tier 1 (CI-compatible, no GPU) and Tier 2 (GPU-required, manual on build host).

**Delivers:** Complete PR-ready package for marketplace-community repo. RSpec test suite, marketplace YAML with correct checksums and virtual size, documentation.

**Addresses features:** Marketplace YAML metadata, README with quick start, CHANGELOG.

**Avoids pitfalls:** YAML validation errors (use qemu-img info for virtual size, generate both md5 and sha256, lowercase UUID), GPU testing gap (Tier 1/Tier 2 split), build host SSH keys in image (verify virt-sysprep ran).

**Key files:**
- `appliances/nemoclaw/<uuid>.yaml`
- `appliances/nemoclaw/README.md`
- `appliances/nemoclaw/CHANGELOG.md`
- `appliances/nemoclaw/tests.yaml`
- `appliances/nemoclaw/tests/00-nemoclaw_basic.rb`
- `logos/nemoclaw.png`

### Phase 4: Security Enhancements (v1.x)

**Rationale:** Security policy management is NemoClaw's differentiator over the vLLM appliance, but it is not required for a functional marketplace PR. Adding it after the core appliance is accepted reduces risk and lets the team validate the base appliance first.

**Delivers:** ONEAPP_NEMOCLAW_SECURITY_LEVEL, ONEAPP_NEMOCLAW_EGRESS_MODE, and ONEAPP_NEMOCLAW_POLICY_PRESETS contextualization parameters. Enhanced MOTD. In-VM help command. REPORT_READY integration.

**Addresses features:** Security level selector, egress mode control, policy presets, REPORT_READY, rich MOTD, in-VM help.

**Avoids pitfalls:** NemoClaw alpha instability (security policy API may change; deferring lets the API stabilize).

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** You cannot build what you have not written. The appliance.sh and Packer configs must exist before the build runs.
- **Phase 2 before Phase 3:** You cannot write correct marketplace YAML (checksums, virtual size) without a built image. Tests need a running VM to verify against.
- **Phase 3 before Phase 4:** The marketplace PR should go in with a solid MVP. Security enhancements can be submitted as a follow-up PR or version bump.
- **GPU passthrough in Phase 2, not Phase 1:** GPU testing requires the build host with physical hardware. Phase 1 focuses on code that can be written and reviewed without hardware. Phase 2 introduces the hardware dependency.
- **Security features in Phase 4:** NemoClaw's policy API is the most likely to break during the alpha period. Deferring reduces the surface area of breaking changes and lets the core appliance prove itself.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** The NemoClaw non-interactive installation hack (sed-ing out `run_onboard`) is fragile and needs validation against the current installer version. Check if a `--headless` or `--non-interactive` flag has been added since research.
- **Phase 1:** The exact Packer provisioner sequence (file copy paths, service.sh framework files) should be validated by diff-ing against the Prowler PR #99 implementation.
- **Phase 2:** Build host at 100.123.42.13 needs validation for KVM acceleration, available RAM/disk, and GPU availability for Tier 2 testing.

Phases with standard patterns (skip research-phase):
- **Phase 3:** Marketplace YAML format, RSpec test structure, and PR submission process are well-documented via existing appliances (Prowler, vLLM, RabbitMQ). Follow the pattern directly.
- **Phase 4:** NemoClaw CLI commands for policy management are documented in the developer guide. Standard CONTEXT parameter addition.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified against official release pages and compatibility matrices. Ubuntu 22.04 + Docker CE + NVIDIA 550-server is a well-validated combination. |
| Features | MEDIUM-HIGH | Table stakes are clear from existing marketplace appliances. Differentiators are based on NemoClaw's documented capabilities, but alpha status means features could change. |
| Architecture | HIGH | Architecture pattern is directly copied from Prowler PR #99 (Pablo's own submission). One-apps build system, Packer provisioner chain, and contextualization lifecycle are well-documented. |
| Pitfalls | HIGH | Pitfalls are sourced from official NVIDIA docs, OpenNebula issues, NemoClaw troubleshooting guide, and community experience. The NVIDIA driver 560 gcc conflict is a confirmed, documented issue. |

**Overall confidence:** MEDIUM-HIGH

The build infrastructure and marketplace packaging patterns are HIGH confidence. The NemoClaw-specific integration is MEDIUM confidence due to the alpha status of the software. The non-interactive install hack and CLI command stability are the weakest links.

### Gaps to Address

- **NemoClaw version pinning mechanism:** Research did not find a `--version` flag for the installer. During Phase 1, investigate whether the npm package can be pinned (`npm install -g nemoclaw@x.y.z`) or whether the installer script must be cached and checksummed.
- **Build host readiness:** The build host at 100.123.42.13 has not been validated for KVM acceleration, RAM, disk, or GPU availability. This must be confirmed before Phase 2 begins.
- **NemoClaw non-interactive mode:** The `sed` hack to skip onboarding is fragile. Check the NemoClaw GitHub for a `--headless` or `--skip-onboard` flag before implementing. If none exists, consider filing an issue or feature request.
- **OpenNebula version compatibility range:** The marketplace YAML needs an `opennebula_version` range. Research did not determine the minimum OpenNebula version required for PCI passthrough with UEFI/q35. Likely 6.8+, but needs validation.
- **Image hosting/CDN:** The built qcow2 image (8-12 GB) needs to be hosted somewhere for the marketplace YAML to reference. The hosting solution was not researched.

## Sources

### Primary (HIGH confidence)
- [OpenNebula marketplace-community repo](https://github.com/OpenNebula/marketplace-community) -- file structure, PR patterns
- [Prowler PR #99](https://github.com/OpenNebula/marketplace-community/pull/99) -- direct template for appliance structure
- [OpenNebula one-apps](https://github.com/OpenNebula/one-apps) -- build toolchain, Packer patterns
- [NVIDIA NemoClaw Developer Guide](https://docs.nvidia.com/nemoclaw/latest/) -- architecture, commands, quickstart
- [NVIDIA Container Toolkit Install Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) -- installation steps
- [OpenNebula NVIDIA GPU Passthrough (v7.0)](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/nvidia_gpu_passthrough/) -- host-side requirements
- [Docker Engine Install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) -- official installation
- [HashiCorp Packer 1.15 Release](https://github.com/hashicorp/packer/releases) -- version confirmation
- [NVIDIA Driver 560 Failure on Ubuntu 22.04](https://forums.developer.nvidia.com/t/root-cause-analysis-for-nvidia-driver-560-install-failure-on-ubuntu-22-04/335528) -- gcc conflict

### Secondary (MEDIUM confidence)
- [OpenNebula vLLM Appliance docs (v7.0)](https://docs.opennebula.io/7.0/product/integration_references/marketplace_appliances/vllm/) -- competitor feature reference
- [NemoClaw GitHub repo](https://github.com/NVIDIA/NemoClaw) -- system requirements, alpha status
- [NVIDIA OpenShell Blog Post](https://blogs.nvidia.com/blog/secure-autonomous-ai-agents-openshell/) -- architecture context
- [one-apps issue #134](https://github.com/OpenNebula/one-apps/issues/134) -- systemd-networkd-wait-online delay
- [NemoClaw Troubleshooting Guide](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html) -- pitfall validation
- [DigitalOcean NemoClaw 1-Click](https://www.digitalocean.com/community/tutorials/how-to-set-up-nemoclaw) -- competitor comparison

### Tertiary (LOW confidence)
- [NemoClaw Non-Interactive Install (secondtalent.com)](https://www.secondtalent.com/resources/how-to-install-nvidia-nemoclaw/) -- sed workaround for onboarding skip (community source, not official)
- [NemoClaw common mistakes (stormap.ai)](https://stormap.ai/post/getting-started-with-nemoclaw-install-onboard-and-avoid-the-obvious-mistakes) -- community pitfalls

---
*Research completed: 2026-03-24*
*Ready for roadmap: yes*

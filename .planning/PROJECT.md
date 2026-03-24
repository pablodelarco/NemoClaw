# NemoClaw OpenNebula Marketplace Appliance

## What This Is

A community marketplace appliance that packages NVIDIA's NemoClaw (open-source AI agent security stack built on OpenClaw) as a ready-to-deploy single-VM image for OpenNebula. Users import the appliance from the Community Marketplace and get a fully configured NemoClaw instance with GPU passthrough support, Docker-based sandbox runtime, and NVIDIA inference routing out of the box.

## Core Value

One-click deployment of NemoClaw on OpenNebula with GPU passthrough and secure defaults, so cloud operators can run AI agents without manual Docker/NVIDIA setup.

## Requirements

### Validated

- Appliance script implements service_install, service_configure, service_bootstrap lifecycle - Phase 1
- Contextualization parameters expose: NVIDIA API key, model selection, sandbox name - Phase 1
- GPU detection with graceful fallback to remote-only inference - Phase 1

### Active

- [ ] Packer build produces a bootable qcow2 image with NemoClaw pre-installed on Ubuntu 22.04
- [ ] GPU passthrough configuration works with NVIDIA GPUs via OpenNebula PCI device assignment
- [ ] Docker and NVIDIA Container Toolkit pre-installed and configured
- [ ] NemoClaw sandbox runtime (OpenShell) starts on boot via contextualization
- [ ] Contextualization parameters expose: NVIDIA API key, model selection, security policy level, network egress mode
- [ ] User can SSH into the VM and interact with NemoClaw CLI
- [ ] VNC console access works via OpenNebula Sunstone
- [ ] Marketplace YAML metadata follows community conventions (UUID filename, checksums, user_inputs)
- [ ] Tests verify Docker, NVIDIA drivers, NemoClaw container health, CLI availability
- [ ] README documents quick start, architecture, configuration parameters, GPU requirements
- [ ] PR to OpenNebula/marketplace-community passes /marketplace-check validation
- [ ] Image builds successfully on the build host (ssh root@100.123.42.13)

### Out of Scope

- Multi-VM OneFlow service template - single VM only for v1
- Local inference with Ollama/vLLM - experimental in NemoClaw, use remote NVIDIA Endpoints
- macOS/Windows support - NemoClaw is Linux-only
- Non-NVIDIA GPU support - NemoClaw requires NVIDIA ecosystem

## Context

- **NemoClaw** is NVIDIA's open-source (Apache 2.0) security stack wrapping OpenClaw AI agents. Announced at GTC 2026 (March 16). Alpha status. Docker-based with Landlock/seccomp/network namespace isolation. Requires Ubuntu 22.04+, 4 vCPU, 8GB RAM minimum. Uses NVIDIA Nemotron models via NVIDIA Endpoints API.
- **OpenNebula Community Marketplace** hosts community-contributed VM appliances. PRs go to github.com/OpenNebula/marketplace-community. Appliances use the one-apps build toolchain (Packer + QEMU). Each appliance has: UUID.yaml (metadata), appliance.sh (lifecycle), metadata.yaml (build config), tests, README, Packer build files.
- **NVIDIA is an OpenNebula partner** with official GPU passthrough support, making this appliance a natural fit for the marketplace.
- **Reference appliances**: Prowler (PR #99, Pablo's own submission) and Nextcloud AIO provide direct templates for the file structure, appliance script patterns, Packer config, and test conventions.
- **Build/test host**: ssh root@100.123.42.13 for Packer builds and image validation.

## Constraints

- **Tech stack**: Ubuntu 22.04 LTS base image, Docker Engine, NVIDIA Container Toolkit, NemoClaw installer
- **Image format**: qcow2 for KVM hypervisor
- **Build toolchain**: Must use the one-apps Packer build system from marketplace-community
- **GPU**: NVIDIA GPU with passthrough required for full functionality; appliance should gracefully handle no-GPU case (remote inference only)
- **NemoClaw status**: Alpha software - APIs may change, document this clearly

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single VM, not Service Template | Simpler for v1, NemoClaw runs self-contained in Docker | - Pending |
| Ubuntu 22.04 base (not 24.04) | NemoClaw officially supports 22.04 LTS | - Pending |
| GPU passthrough enabled | OpenNebula is NVIDIA partner, core value proposition | - Pending |
| Remote NVIDIA Endpoints as default inference | Local inference is experimental in NemoClaw | - Pending |
| Follow Prowler PR pattern exactly | Pablo's own recent submission, proven structure | - Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-24 after Phase 1 completion*

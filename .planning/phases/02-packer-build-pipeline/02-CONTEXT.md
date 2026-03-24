# Phase 2: Packer Build Pipeline - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Create the complete Packer build pipeline that takes the one-apps Ubuntu 24.04 base image, provisions it with all NemoClaw dependencies via the existing appliance.sh, and produces a clean qcow2 image. Includes all supporting files: HCL configs, provisioner scripts, gen_context, metadata.yaml, and Makefile.config entry. Does NOT include actually running the build (Phase 3) or marketplace submission (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Base Image
- **D-01:** Use the one-apps `ubuntu2404` base image (Ubuntu 24.04 LTS), matching Prowler's choice. NemoClaw supports "Ubuntu 22.04 or later" so 24.04 is fully compatible and more current.
- **D-02:** This overrides the initial PROJECT.md constraint of Ubuntu 22.04. Ubuntu 24.04 is the better choice: Prowler uses it, it has newer kernel with better NVIDIA driver support, and longer LTS support window.

### Packer Configuration (Claude's Discretion)
- **D-03:** Follow Prowler's exact Packer HCL structure: `nemoclaw.pkr.hcl` (main build), `variables.pkr.hcl` (variables), `common.pkr.hcl` (symlink to shared config), `gen_context` (context ISO generation), `81-configure-ssh.sh`, `82-configure-context.sh`.
- **D-04:** QEMU builder with 20GB virtual disk (NemoClaw sandbox ~2.4GB + Docker images + OS + packages = ~10-12GB used, 20GB gives headroom). 8GB RAM and 2 CPUs for build, matching Prowler.
- **D-05:** Provisioner chain calls `/etc/one-appliance/service install` which invokes appliance.sh's service_install(). This is the standard one-apps pattern - the Packer provisioner does NOT install packages directly, it delegates to the appliance script.

### Post-Processing (Claude's Discretion)
- **D-06:** Use Prowler's `postprocess.sh` pattern which runs virt-sysprep (clean machine IDs, SSH host keys, logs) and virt-sparsify (compress unused space) on the output qcow2. This is the community convention.

### VM Template Defaults (Claude's Discretion)
- **D-07:** metadata.yaml VM template: 2 CPU, 8192 MB RAM (NemoClaw minimum is 8GB), KVM hypervisor, virtio NIC, host-passthrough CPU model (required for GPU passthrough). Matches the resource profile NemoClaw needs.

### gen_context Script (Claude's Discretion)
- **D-08:** Follow Prowler's gen_context pattern: output ETH0 DHCP config, hostname, default password, MAC address, and a START_SCRIPT that configures SSH (PasswordAuthentication yes for initial setup, PermitRootLogin without-password) and DNS.

### Makefile Integration (Claude's Discretion)
- **D-09:** Add `nemoclaw` to the SERVICES variable in `apps-code/community-apps/Makefile.config`. This registers the appliance as a build target (`make service_nemoclaw`).

### Carrying Forward from Phase 1
- D-01 (Phase 1): Official NemoClaw installer - already in appliance.sh, Packer just calls it
- D-04 (Phase 1): Version pinning - reflected in Packer variables.pkr.hcl version field
- D-11 (Phase 1): Follow Prowler patterns exactly - applies to all Packer files

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Code (from Phase 1)
- `appliances/nemoclaw/appliance.sh` - The appliance lifecycle script Packer will invoke

### Research
- `.planning/research/ARCHITECTURE.md` - Build pipeline architecture and PR file structure
- `.planning/research/STACK.md` - Packer versions, QEMU plugin, build host requirements
- `.planning/research/PITFALLS.md` - Build system gotchas (disk space, timing, driver versions)

### Project Context
- `.planning/PROJECT.md` - Project scope and constraints
- `.planning/REQUIREMENTS.md` - Phase 2 requirements (BUILD-01..08, MKT-04, MKT-08, MKT-10)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `appliances/nemoclaw/appliance.sh` (605 lines) - Complete lifecycle script, Packer provisioner delegates to this via `/etc/one-appliance/service install`

### Established Patterns
- Prowler PR #99 provides exact file-for-file template for all Packer build files
- one-apps build system uses Packer QEMU builder with post-processing chain

### Integration Points
- Packer HCL provisioner copies appliance.sh to `/etc/one-appliance/service.d/` inside the VM
- Packer provisioner runs `/etc/one-appliance/service install` to trigger service_install()
- gen_context creates the context ISO for first-boot configuration
- Makefile.config SERVICES variable enables `make service_nemoclaw` build target

</code_context>

<specifics>
## Specific Ideas

- User explicitly chose Ubuntu 24.04 (not 22.04) to match Prowler's base image choice
- All Packer files should be structurally identical to Prowler's, with NemoClaw-specific values substituted

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 02-packer-build-pipeline*
*Context gathered: 2026-03-24*

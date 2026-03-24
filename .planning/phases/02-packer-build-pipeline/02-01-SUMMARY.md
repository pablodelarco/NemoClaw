---
phase: 02-packer-build-pipeline
plan: 01
subsystem: infra
tags: [packer, hcl, qemu, qcow2, cloud-init, ssh-hardening, opennebula-context]

# Dependency graph
requires:
  - phase: 01-appliance-lifecycle
    provides: appliance.sh lifecycle script that Packer provisioner invokes via /etc/one-appliance/service install
provides:
  - Packer HCL config defining QEMU build from Ubuntu 24.04 with full provisioner chain
  - Variables file declaring appliance_name=nemoclaw, version=0.1.0
  - Common.pkr.hcl symlink to shared one-apps config
  - Cloud-init config for build VM root SSH access
  - SSH hardening script (81-configure-ssh.sh) for deployed image security
  - Context hook installation script (82-configure-context.sh) for one-apps lifecycle
affects: [02-02-PLAN, 03-build-validation]

# Tech tracking
tech-stack:
  added: [packer-hcl, qemu-builder, cloud-init, mkisofs]
  patterns: [prowler-packer-pattern, two-build-blocks, provisioner-chain-ordering]

key-files:
  created:
    - apps-code/community-apps/packer/nemoclaw/nemoclaw.pkr.hcl
    - apps-code/community-apps/packer/nemoclaw/variables.pkr.hcl
    - apps-code/community-apps/packer/nemoclaw/common.pkr.hcl
    - apps-code/community-apps/packer/nemoclaw/cloud-init.yml
    - apps-code/community-apps/packer/nemoclaw/81-configure-ssh.sh
    - apps-code/community-apps/packer/nemoclaw/82-configure-context.sh
  modified: []

key-decisions:
  - "Used Ubuntu 24.04 base image (ubuntu2404.qcow2) per D-01, overriding initial 22.04 constraint for better kernel/driver support"
  - "Followed Prowler two-build-block pattern: context ISO generation (null source) + QEMU VM build"
  - "20GB disk, 8GB RAM, 2 CPUs matching Prowler spec and NemoClaw minimum requirements"

patterns-established:
  - "Two-build-block Packer pattern: null source for context ISO, qemu source for VM build"
  - "Provisioner chain ordering: SSH harden -> dirs -> context hooks -> libs -> service manager -> appliance.sh -> context config -> service install"
  - "Post-processor delegates to shared postprocess.sh for virt-sysprep + virt-sparsify"

requirements-completed: [BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07, BUILD-08, MKT-08]

# Metrics
duration: 3min
completed: 2026-03-24
---

# Phase 02 Plan 01: Packer Build Pipeline Summary

**Packer HCL build config with QEMU source targeting Ubuntu 24.04, 10-step provisioner chain following Prowler pattern, and virt-sysprep/virt-sparsify post-processing**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-24T16:08:00Z
- **Completed:** 2026-03-24T16:11:04Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Complete Packer build pipeline as 6 files defining how to build a NemoClaw qcow2 image from Ubuntu 24.04 base
- Provisioner chain follows exact Prowler sequence: SSH harden, create dirs, copy context hooks, copy libraries, copy service manager, copy appliance.sh, configure context, run service install
- Post-processor invokes shared postprocess.sh for virt-sysprep (clean machine IDs, SSH host keys, logs) and virt-sparsify (compress unused space)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Packer HCL config, variables, and common symlink** - `948b7de` (feat)
2. **Task 2: Create cloud-init.yml, 81-configure-ssh.sh, and 82-configure-context.sh** - `84fc40b` (feat)

## Files Created/Modified
- `apps-code/community-apps/packer/nemoclaw/nemoclaw.pkr.hcl` - Main Packer build config with QEMU source, 10 provisioners, and post-processor (139 lines)
- `apps-code/community-apps/packer/nemoclaw/variables.pkr.hcl` - Variable declarations for appliance_name, version, input/output dirs, headless mode (31 lines)
- `apps-code/community-apps/packer/nemoclaw/common.pkr.hcl` - Symlink to shared one-apps Packer config
- `apps-code/community-apps/packer/nemoclaw/cloud-init.yml` - Cloud-init config enabling root SSH with opennebula password during build
- `apps-code/community-apps/packer/nemoclaw/81-configure-ssh.sh` - SSH hardening: key-only root login, no empty passwords, no X11 forwarding
- `apps-code/community-apps/packer/nemoclaw/82-configure-context.sh` - Context hook installation: permissions on hooks/libs, enables one-context systemd services

## Decisions Made
- Used Ubuntu 24.04 base image (ubuntu2404.qcow2) per D-01 from 02-CONTEXT.md, overriding the initial PROJECT.md constraint of Ubuntu 22.04. Ubuntu 24.04 matches Prowler, has newer kernel with better NVIDIA driver support, and longer LTS window.
- Followed Prowler's exact two-build-block pattern: first build generates context ISO via null source and gen_context/mkisofs, second build runs QEMU with full provisioner chain.
- Set PasswordAuthentication to yes during build (for gen_context START_SCRIPT initial access), with PermitRootLogin without-password ensuring only key-based root access after deployment.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Packer build pipeline core files are complete (6 of the expected files in the packer/nemoclaw/ directory)
- Plan 02-02 should create the remaining build infrastructure: gen_context script, metadata.yaml, and Makefile.config entry
- Build host (100.123.42.13) validation still deferred to Phase 3

## Self-Check: PASSED

All 6 created files verified present with correct types (regular files, symlink, executables).
Both task commits (948b7de, 84fc40b) verified in git history.

---
*Phase: 02-packer-build-pipeline*
*Completed: 2026-03-24*

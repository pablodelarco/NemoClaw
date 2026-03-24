# Plan 03-01 Summary: Build Host Validation + Packer Build

**Status:** Complete
**Duration:** ~30 min (including 4 fix iterations)

## What Was Done

1. Validated build host (100.123.42.13): KVM, Packer 1.15.0, QEMU 8.2.2, guestfs-tools, 125GB RAM, 447GB free disk
2. Cloned marketplace-community repo with one-apps submodule
3. Copied all NemoClaw build files (appliance.sh, Packer HCL, gen_context, metadata.yaml, Makefile.config)
4. Fixed and rebuilt through 4 iterations:
   - Fix 1: Corrected Packer HCL paths to match Prowler pattern (../one-apps/, ../../appliances/)
   - Fix 2: Fixed gen_context to output to stdout (not file) + match MAC address 00:11:22:33:44:55
   - Fix 3: Used DEB822 .sources format for NVIDIA Container Toolkit repo (Ubuntu 24.04)
   - Fix 4: Used --non-interactive flag instead of fragile sed patch for NemoClaw installer
   - Fix 5: Replaced missing postinstall_cleanup with inline cleanup commands
5. Packer build completed successfully in 6 minutes 15 seconds

## Key Files

- **Image:** `/root/marketplace-community/apps-code/community-apps/output/nemoclaw` (qcow2, 6.5 GiB compressed, 20 GiB virtual)

## Build Fixes Applied to Local Repo

| Commit | Fix |
|--------|-----|
| 5215da4 | Correct Packer HCL paths to match Prowler pattern |
| fd1ac32 | Fix gen_context stdout output + MAC address match |
| 1b3b746 | DEB822 sources format for NVIDIA Container Toolkit |
| 796594d | --non-interactive flag for NemoClaw installer |
| e350924 | Inline cleanup replacing missing postinstall_cleanup |

## Deviations

- NemoClaw sandbox image could not be pre-pulled during build (registry requires auth). Will download at first boot.
- Output file named `nemoclaw` not `nemoclaw.qcow2` (matches Prowler's vm_name pattern)

## Self-Check: PASSED
- qcow2 image exists on build host
- qemu-img info confirms format
- virt-sysprep + virt-sparsify completed
- Image size reasonable (6.5 GiB compressed)

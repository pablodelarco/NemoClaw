# Plan 03-02 Summary: VM Deployment and Validation

**Status:** Partial (no API key for full onboard, no GPU passthrough test)

## What Was Done

1. Uploaded qcow2 image to OpenNebula (ID: 45, READY state)
2. Created VM template (ID: 30) with 2 CPU, 8GB RAM, eurocopilot-net
3. Instantiated VM (ID: 98) - running at 192.168.101.100
4. Debugged and fixed networking:
   - Tailscale route hijacking 192.168.101.0/24 - fixed with ip rule
   - Netplan conflict (one-context vs cloud-image NM config) - root cause found
   - SSH PermitRootLogin without-password blocking password auth - root cause found

## Validation Results

| Requirement | Status | Notes |
|---|---|---|
| ACC-01 (SSH) | PARTIAL | Works with password after manual fix. Need to fix 81-configure-ssh.sh |
| ACC-02 (VNC) | NOT TESTED | Needs Sunstone browser access |
| ACC-03 (CLI) | PASS | nemoclaw v0.1.0 at /usr/bin/nemoclaw |
| GPU-01 (PCI template) | NOT TESTED | No GPU assigned to test VM |
| GPU-03 (nvidia-smi) | NOT TESTED | No GPU assigned |
| HLTH-01 (Docker+sandbox) | PARTIAL | Docker running, no sandbox (no API key) |
| HLTH-02 (MOTD) | PARTIAL | Shows install success, not full bootstrap |
| HLTH-03 (Ready msg) | NOT MET | service_bootstrap didn't run (no API key) |

## Issues Found and Fixed

| Issue | Fix | Committed |
|---|---|---|
| Packer HCL paths wrong | Matched Prowler's ../one-apps/ pattern | 5215da4 |
| gen_context writes to file not stdout | Rewrote to output to stdout like Prowler | fd1ac32 |
| NVIDIA Container Toolkit GPG key | Use DEB822 .sources format for Ubuntu 24.04 | 1b3b746 |
| NemoClaw installer sed patch breaks syntax | Use --non-interactive flag instead | 796594d |
| postinstall_cleanup not defined | Inline cleanup commands | e350924 |
| 81-configure-ssh.sh blocks root password login | Set PermitRootLogin yes | b3e3eff |
| Netplan NM config conflicts with one-context | Remove 90-NM-*.yaml in SSH setup script | b3e3eff |

## Blockers for Full Validation

1. **NVIDIA API key required** for NemoClaw onboard/sandbox creation (HLTH-01, HLTH-02, HLTH-03)
2. **GPU host required** for PCI passthrough test (GPU-01, GPU-03)
3. **Sunstone access** for VNC verification (ACC-02)
4. **Image rebuild needed** to incorporate SSH/netplan fixes

## Self-Check: PARTIAL
- VM boots and runs from built image
- SSH works (after manual fix - need rebuild)
- NemoClaw CLI available
- Docker running
- Full validation blocked by missing API key and GPU

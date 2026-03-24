# Phase 2: Packer Build Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 02-packer-build-pipeline
**Areas discussed:** Base image source

---

## Base Image Source

| Option | Description | Selected |
|--------|-------------|----------|
| one-apps ubuntu2204 | Pre-built with contextualization. Used by vLLM. | |
| Ubuntu cloud image | Official Canonical cloud image, needs manual one-context. | |
| You decide | Claude picks based on Prowler pattern. | |
| Other (user) | "one-apps ubuntu2404" | ✓ |

**User's choice:** one-apps ubuntu2404 (Ubuntu 24.04 LTS)
**Notes:** User explicitly chose 24.04 over 22.04 to match Prowler's base. Overrides initial PROJECT.md constraint. NemoClaw supports 22.04+ so this is valid.

---

## Claude's Discretion

- Packer HCL structure (D-03): Follow Prowler exactly
- Disk sizing (D-04): 20GB virtual disk, 8GB RAM, 2 CPUs
- Provisioner chain (D-05): Delegate to appliance.sh via one-apps service framework
- Post-processing (D-06): Prowler's postprocess.sh pattern
- VM template (D-07): 2 CPU, 8192 MB RAM, host-passthrough CPU
- gen_context (D-08): Prowler pattern with NemoClaw values
- Makefile (D-09): Add nemoclaw to SERVICES

## Deferred Ideas

None

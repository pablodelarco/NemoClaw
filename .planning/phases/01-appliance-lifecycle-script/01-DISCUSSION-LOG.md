# Phase 1: Appliance Lifecycle Script - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 01-appliance-lifecycle-script
**Areas discussed:** Install method

---

## Install Method

### Question 1: How should NemoClaw be installed during Packer build?

| Option | Description | Selected |
|--------|-------------|----------|
| Deferred onboard (Recommended) | Install binaries + pre-pull during build, defer onboard to first boot | |
| Patched installer | Patch installer with sed/env for non-interactive. Fragile with alpha. | |
| You decide | Claude picks best approach | |
| Other (user) | "I want to offer users the official NemoClaw experience they would find in other clouds" | ✓ |

**User's choice:** Official NemoClaw experience matching other clouds
**Notes:** User wants the standard installer flow, not a custom path. The deferred onboard approach aligns with this - use official installer at build, official onboard at first boot.

### Question 2: Version pinning?

| Option | Description | Selected |
|--------|-------------|----------|
| Pin to current stable | Lock specific version. Predictable. | |
| Always latest | Pull current at build time. Could break. | |
| You decide | Claude picks based on alpha concerns | ✓ |

**User's choice:** Claude's discretion
**Notes:** Claude chose pinning due to alpha instability risk.

---

## Claude's Discretion

- API key handling (D-05, D-06): Secure file storage with 0600 permissions
- Sandbox boot flow (D-07, D-08): Configure then bootstrap, GPU detection early
- GPU fallback UX (D-09, D-10): Warn but don't block, MOTD notice
- Script conventions (D-11, D-12): Follow Prowler/RabbitMQ patterns

## Deferred Ideas

None

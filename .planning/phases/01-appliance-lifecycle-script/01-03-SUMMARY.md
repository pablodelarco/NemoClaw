---
phase: 01-appliance-lifecycle-script
plan: 03
subsystem: infra
tags: [bash, nemoclaw, sandbox, bootstrap, health-check, onboard, motd, cleanup]

# Dependency graph
requires:
  - phase: 01-appliance-lifecycle-script
    plan: 02
    provides: service_configure() with nemoclaw.conf generation, detect_gpu(), store_api_key(), write_motd()
provides:
  - service_bootstrap() with NemoClaw onboard, sandbox creation, start, and health validation
  - check_nemoclaw_health() with 30-retry health check loop
  - service_cleanup() for recontext support
  - Complete appliance.sh with all four lifecycle functions fully implemented
affects: [packer-build, testing, marketplace-packaging]

# Tech tracking
tech-stack:
  added: []
  patterns: [non-interactive NemoClaw onboard with API key injection, retry-based health check with Docker and sandbox status, cross-phase config sourcing via nemoclaw.conf, MOTD-based failure reporting with actionable retry commands]

key-files:
  created: []
  modified:
    - appliances/nemoclaw/appliance.sh

key-decisions:
  - "service_bootstrap sources nemoclaw.conf from service_configure rather than reading CONTEXT vars directly, maintaining clean phase separation"
  - "NemoClaw onboard uses --non-interactive flag with --api-key and --model, with env var fallback for compatibility"
  - "Health check uses 30 retries at 10s intervals (5min timeout) checking both Docker and sandbox status"
  - "NVIDIA_API_KEY is unset from environment in both success and failure paths to prevent credential leakage"

patterns-established:
  - "Bootstrap fallback: try CLI flags first, then env var injection, then fail with actionable MOTD"
  - "Health check pattern: retry loop with Docker readiness gate before sandbox status check"
  - "Service report: READY=YES written to ONE_SERVICE_SETUP_DIR/config on successful bootstrap"
  - "Cleanup pattern: remove config and credentials files so service_configure rewrites from fresh CONTEXT"

requirements-completed: [LIFE-03]

# Metrics
duration: 5min
completed: 2026-03-24
---

# Phase 1 Plan 03: Service Bootstrap Summary

**service_bootstrap() with non-interactive NemoClaw onboard, sandbox creation/start, 30-retry health validation, success/failure MOTD updates, and service_cleanup() for recontext -- completing all four lifecycle functions in appliance.sh (605 lines)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-24T15:28:56Z
- **Completed:** 2026-03-24T15:33:39Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Implemented check_nemoclaw_health() with retry loop (30 attempts, 10s intervals) checking Docker daemon and NemoClaw sandbox status via `nemoclaw <name> status`
- Implemented service_bootstrap() with full lifecycle: source nemoclaw.conf, validate API key file, ensure Docker running, run nemoclaw onboard non-interactively, create sandbox, start sandbox, health check, MOTD update, service report
- Implemented service_cleanup() removing nemoclaw.conf and API key file for clean recontext
- All four lifecycle functions (service_install, service_configure, service_bootstrap, service_cleanup) are now fully implemented with no stubs remaining

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement service_bootstrap() with NemoClaw onboard, sandbox creation, and health validation** - `85cb477` (feat)

## Files Created/Modified
- `appliances/nemoclaw/appliance.sh` - Added check_nemoclaw_health() helper, replaced service_bootstrap() stub with full implementation, replaced service_cleanup() stub with recontext support

## Decisions Made
- service_bootstrap() sources nemoclaw.conf from ONE_SERVICE_SETUP_DIR rather than re-reading CONTEXT variables directly, maintaining clean separation between configure and bootstrap phases
- NemoClaw onboard uses --non-interactive flag first with --api-key and --model flags, with an environment variable fallback approach for CLI compatibility across NemoClaw versions
- Health check retries 30 times at 10-second intervals (5-minute total timeout), checking Docker daemon availability before sandbox status
- NVIDIA_API_KEY environment variable is unset in both success and failure code paths to prevent credential leakage
- Failure MOTDs include specific retry commands (nemoclaw onboard, nemoclaw create, nemoclaw status) so users can self-remediate

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- appliance.sh is complete with all four lifecycle functions (605 lines), ready for Packer build integration
- Phase 1 (appliance-lifecycle-script) is complete: all three plans executed successfully
- Ready for Phase 2 (build infrastructure) to create Packer configs referencing this appliance.sh

## Self-Check: PASSED

- FOUND: appliances/nemoclaw/appliance.sh
- FOUND: commit 85cb477
- FOUND: 01-03-SUMMARY.md

---
*Phase: 01-appliance-lifecycle-script*
*Completed: 2026-03-24*

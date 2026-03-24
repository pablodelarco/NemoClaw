---
phase: 01-appliance-lifecycle-script
plan: 01
subsystem: infra
tags: [bash, docker, nvidia, nemoclaw, opennebula, appliance, lifecycle]

# Dependency graph
requires:
  - phase: none
    provides: greenfield project
provides:
  - appliance.sh skeleton with one-apps lifecycle convention
  - ONE_SERVICE_PARAMS defining 3 contextualization parameters
  - service_install() with full dependency installation chain
affects: [01-02, 01-03, packer-build]

# Tech tracking
tech-stack:
  added: [docker-ce, nvidia-driver-550-server, nvidia-container-toolkit, nodejs-22, nemoclaw-installer]
  patterns: [one-apps lifecycle convention, msg info logging, postinstall_cleanup, non-interactive installer via sed]

key-files:
  created:
    - appliances/nemoclaw/appliance.sh
  modified: []

key-decisions:
  - "Used variable expansion for nvidia-driver branch and nodejs major version for maintainability"
  - "Docker log rotation configured via heredoc writing daemon.json with variable interpolation"

patterns-established:
  - "one-apps lifecycle: service_install/configure/bootstrap/cleanup function contract"
  - "ONEAPP_ prefix for all custom context parameters"
  - "Constants section at top with pinned versions for alpha stability"

requirements-completed: [LIFE-01, LIFE-04, LIFE-05, CTX-01, CTX-02, CTX-03]

# Metrics
duration: 2min
completed: 2026-03-24
---

# Phase 1 Plan 01: Appliance Script Skeleton Summary

**appliance.sh with one-apps lifecycle skeleton, 3 contextualization parameters (API key, model, sandbox name), and service_install() baking Docker, NVIDIA 550-server, Container Toolkit, Node.js 22, and NemoClaw into the qcow2 image**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-24T15:19:08Z
- **Completed:** 2026-03-24T15:21:39Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created appliance.sh following the one-apps service lifecycle convention with all four required functions
- Defined ONE_SERVICE_PARAMS array with ONEAPP_NEMOCLAW_API_KEY (mandatory password), ONEAPP_NEMOCLAW_MODEL (optional text), and ONEAPP_NEMOCLAW_SANDBOX_NAME (optional text)
- Implemented complete service_install() with 12 ordered steps: prerequisites, Docker CE from official repo, Docker log rotation, Docker autostart, NVIDIA driver 550-server, NVIDIA Container Toolkit with runtime configuration, Node.js 22 LTS, NemoClaw non-interactive install (sed to skip run_onboard), sandbox image pre-pull, systemd-networkd-wait-online disable, swap configuration, and postinstall_cleanup

## Task Commits

Each task was committed atomically:

1. **Task 1: Create appliance.sh with skeleton, constants, ONE_SERVICE_PARAMS, and service_install()** - `dd2bcd4` (feat)

## Files Created/Modified
- `appliances/nemoclaw/appliance.sh` - Complete appliance lifecycle script with skeleton, constants, ONE_SERVICE_PARAMS, and fully implemented service_install()

## Decisions Made
- Used variable expansion (`${NVIDIA_DRIVER_BRANCH}`, `${NODEJS_MAJOR}`) for version constants rather than hardcoding in the install commands, improving maintainability
- Docker log rotation uses variable interpolation in the heredoc for consistency with the constants section

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- appliance.sh skeleton is ready for Plan 02 (service_configure with GPU detection and CONTEXT variable handling)
- service_configure() and service_bootstrap() are stub functions ready to be implemented
- All constants and parameters are in place for downstream plans to reference

## Self-Check: PASSED

- FOUND: appliances/nemoclaw/appliance.sh
- FOUND: commit dd2bcd4
- FOUND: 01-01-SUMMARY.md

---
*Phase: 01-appliance-lifecycle-script*
*Completed: 2026-03-24*

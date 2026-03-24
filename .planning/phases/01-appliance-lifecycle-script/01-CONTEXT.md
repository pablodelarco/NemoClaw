# Phase 1: Appliance Lifecycle Script - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Write the `appliance.sh` script that implements the one-apps service lifecycle (service_install, service_configure, service_bootstrap) for NemoClaw. This script handles all runtime logic: installing NemoClaw via the official installer, configuring it from OpenNebula CONTEXT variables, creating the sandbox, and validating health. It does NOT include the Packer build pipeline or marketplace packaging (those are later phases).

</domain>

<decisions>
## Implementation Decisions

### Install Method
- **D-01:** Use the official NemoClaw installer (`curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash`) during service_install to match the standard deployment experience users find on DigitalOcean and other clouds. Do NOT create a custom install path.
- **D-02:** Pre-pull the NemoClaw sandbox container image during service_install (Packer build time) to avoid a ~2.4GB download at every VM boot.
- **D-03:** Defer the interactive `nemoclaw onboard` wizard to service_configure/service_bootstrap where CONTEXT variables (API key, model) are available. The onboard step runs programmatically with injected vars, not interactively.

### Version Pinning (Claude's Discretion)
- **D-04:** Pin NemoClaw to the current stable version at build time. Alpha software with breaking changes makes "always latest" risky. The appliance version string in marketplace YAML encodes which NemoClaw version was tested. Users deploy a new appliance version to get NemoClaw updates.

### API Key Handling (Claude's Discretion)
- **D-05:** NVIDIA API key injected via ONEAPP_NEMOCLAW_API_KEY context variable. Written to NemoClaw's expected credentials location (`~/.nemoclaw/credentials.json` or equivalent) with 0600 permissions during service_configure. Never persisted in the distributed image.
- **D-06:** If no API key is provided, service_bootstrap should fail with a clear error message in MOTD and logs explaining that the API key is required and how to provide it via recontext.

### Sandbox Boot Flow (Claude's Discretion)
- **D-07:** Boot sequence order: (1) service_configure reads CONTEXT vars and writes config files, (2) service_bootstrap detects GPU, runs `nemoclaw onboard` with API key and model, creates sandbox, runs health checks. GPU detection happens early in bootstrap to decide the setup path.
- **D-08:** Sandbox name comes from ONEAPP_NEMOCLAW_SANDBOX_NAME context variable, defaulting to "nemoclaw".

### GPU Fallback (Claude's Discretion)
- **D-09:** When no GPU detected: log a prominent warning, set a flag in MOTD ("Running without GPU - remote inference only"), but do NOT block sandbox creation. NemoClaw can function with remote NVIDIA Endpoints inference even without a local GPU.
- **D-10:** When GPU detected: validate with nvidia-smi, regenerate CDI spec if needed, and note GPU model/memory in MOTD.

### Script Conventions
- **D-11:** Follow the exact patterns from Prowler and RabbitMQ appliance.sh scripts: use `msg info`/`msg error` logging, define ONE_SERVICE_PARAMS array, implement postinstall_cleanup, set ONE_SERVICE_RECONFIGURABLE=true.
- **D-12:** Use ONEAPP_ prefix for all custom context parameters (ONEAPP_NEMOCLAW_*) to follow marketplace conventions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Marketplace Patterns
- `.planning/research/ARCHITECTURE.md` - Appliance file structure and lifecycle patterns
- `.planning/research/STACK.md` - Technology stack with versions and install commands
- `.planning/research/FEATURES.md` - Contextualization parameters specification
- `.planning/research/PITFALLS.md` - Common mistakes and prevention strategies

### Project Context
- `.planning/PROJECT.md` - Project scope, constraints, key decisions
- `.planning/REQUIREMENTS.md` - Phase 1 requirements (LIFE-01..05, CTX-01..05, GPU-02, GPU-04)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None (greenfield project)

### Established Patterns
- Prowler PR #99 appliance.sh: Docker container management, OS detection, DNS configuration, console autologin, welcome message
- Nextcloud AIO appliance.sh: OS-family detection (debian/rhel/suse), Docker install, container lifecycle management
- RabbitMQ appliance.sh: ONE_SERVICE_PARAMS array pattern, credential generation, TLS configuration, service reconfigurability

### Integration Points
- appliance.sh is called by the one-apps service framework at `/etc/one-appliance/service`
- service_install() is invoked during Packer build via provisioner
- service_configure() and service_bootstrap() are invoked at VM first boot via contextualization scripts

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants the "official NemoClaw experience" matching what users find on other clouds (DigitalOcean, etc.)
- The installer, onboarding flow, and CLI should feel like standard NemoClaw, not a custom fork

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 01-appliance-lifecycle-script*
*Context gathered: 2026-03-24*

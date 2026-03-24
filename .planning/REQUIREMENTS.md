# Requirements: NemoClaw OpenNebula Marketplace Appliance

**Defined:** 2026-03-24
**Core Value:** One-click deployment of NemoClaw on OpenNebula with GPU passthrough and secure defaults

## v1 Requirements

Requirements for initial marketplace PR submission. Each maps to roadmap phases.

### Build Pipeline

- [ ] **BUILD-01**: Packer build produces a bootable qcow2 image from Ubuntu 22.04 base
- [ ] **BUILD-02**: Docker Engine CE pre-installed and enabled at boot
- [ ] **BUILD-03**: NVIDIA driver 550-server pre-installed in the image
- [ ] **BUILD-04**: NVIDIA Container Toolkit 1.19+ pre-installed and configured as default Docker runtime
- [ ] **BUILD-05**: Node.js 22 LTS and npm pre-installed (NemoClaw dependency)
- [ ] **BUILD-06**: NemoClaw installed and sandbox container image pre-pulled during build
- [ ] **BUILD-07**: OpenNebula contextualization packages (addon-context-linux) pre-installed
- [ ] **BUILD-08**: Image post-processed with virt-sysprep and virt-sparsify for clean distribution
- [ ] **BUILD-09**: Packer build runs successfully on build host (ssh root@100.123.42.13)

### Appliance Lifecycle

- [x] **LIFE-01**: appliance.sh implements service_install() for package installation during Packer build
- [x] **LIFE-02**: appliance.sh implements service_configure() for first-boot configuration from CONTEXT variables
- [ ] **LIFE-03**: appliance.sh implements service_bootstrap() for NemoClaw sandbox creation and startup
- [x] **LIFE-04**: ONE_SERVICE_PARAMS array defines all contextualization parameters with types and descriptions
- [x] **LIFE-05**: ONE_SERVICE_RECONFIGURABLE=true enables recontext without redeploy

### GPU Support

- [ ] **GPU-01**: OpenNebula VM template includes PCI configuration for NVIDIA GPU passthrough (vendor 10de)
- [x] **GPU-02**: Appliance detects GPU presence at boot and adjusts behavior accordingly
- [ ] **GPU-03**: When GPU is present, nvidia-smi validates driver/device availability
- [x] **GPU-04**: When GPU is absent, appliance logs warning and continues with remote-only inference mode

### Contextualization

- [x] **CTX-01**: ONEAPP_NEMOCLAW_API_KEY (mandatory password) injects NVIDIA API key for inference
- [x] **CTX-02**: ONEAPP_NEMOCLAW_MODEL (optional list) selects Nemotron model, default nemotron-3-super-120b
- [x] **CTX-03**: ONEAPP_NEMOCLAW_SANDBOX_NAME (optional text) sets sandbox instance name, default "nemoclaw"
- [x] **CTX-04**: SSH key-based access via $USER[SSH_PUBLIC_KEY] contextualization
- [x] **CTX-05**: Network auto-configuration via standard OpenNebula contextualization

### Health and Monitoring

- [ ] **HLTH-01**: Basic health checks verify Docker running, NemoClaw sandbox status after bootstrap
- [ ] **HLTH-02**: MOTD displays NemoClaw version, sandbox state, model, GPU status on SSH login
- [ ] **HLTH-03**: /etc/motd shows "All set and ready to serve" when bootstrap completes successfully

### Marketplace Submission

- [ ] **MKT-01**: UUID-named YAML metadata file with all required fields (name, version, publisher, description, tags, format, OS, checksums, user_inputs)
- [ ] **MKT-02**: README.md with quick start guide, architecture overview, configuration parameters table, GPU requirements
- [ ] **MKT-03**: CHANGELOG.md with initial version entry
- [ ] **MKT-04**: metadata.yaml with build/test infrastructure config (OS base, context params, VM template)
- [ ] **MKT-05**: context.yaml with test context parameter defaults
- [ ] **MKT-06**: tests.yaml listing test files
- [ ] **MKT-07**: RSpec tests verify Docker, NVIDIA drivers, NemoClaw container health, CLI availability, MOTD readiness
- [ ] **MKT-08**: Packer build files (HCL config, variables, gen_context, SSH config, context config scripts)
- [ ] **MKT-09**: NemoClaw logo file in logos/ directory
- [ ] **MKT-10**: Makefile.config updated with nemoclaw as build target
- [ ] **MKT-11**: PR passes /marketplace-check validation

### Access

- [ ] **ACC-01**: User can SSH into VM with key-based authentication
- [ ] **ACC-02**: VNC console access works via OpenNebula Sunstone
- [ ] **ACC-03**: User can interact with NemoClaw CLI inside the VM after SSH

## v2 Requirements

Deferred to future versions. Tracked but not in current roadmap.

### Security Configuration

- **SEC-01**: ONEAPP_NEMOCLAW_SECURITY_LEVEL parameter (strict/moderate/permissive)
- **SEC-02**: ONEAPP_NEMOCLAW_EGRESS_MODE parameter (nvidia-only/development/custom)
- **SEC-03**: ONEAPP_NEMOCLAW_POLICY_PRESETS parameter (comma-separated preset list)
- **SEC-04**: ONEAPP_NEMOCLAW_GPU_MEM_UTIL parameter (GPU memory utilization fraction)

### Polish

- **POL-01**: REPORT_READY OneGate integration for OneFlow compatibility
- **POL-02**: nemoclaw-help in-VM command with usage info and troubleshooting
- **POL-03**: Rich MOTD with full status (inference endpoint, security level, egress policy)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Local inference (Ollama/vLLM) | NemoClaw marks experimental, doubles image size, alpha-on-alpha risk |
| Multi-VM OneFlow service template | Single VM only for v1, NemoClaw has no distributed coordination |
| Web UI for management | NemoClaw has no web UI, OpenShell TUI serves monitoring needs |
| Automatic NVIDIA driver version selection | Driver pinning is safer than auto-detection |
| Custom model upload/download | NemoClaw uses remote NVIDIA Endpoints, not local model files |
| TLS/HTTPS for API endpoint | NemoClaw API is localhost-only, use SSH tunnels for external access |
| Automatic updates | Alpha software with breaking changes, versioned images only |
| Non-NVIDIA GPU support | NemoClaw requires NVIDIA OpenShell runtime |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 2 | Pending |
| BUILD-02 | Phase 2 | Pending |
| BUILD-03 | Phase 2 | Pending |
| BUILD-04 | Phase 2 | Pending |
| BUILD-05 | Phase 2 | Pending |
| BUILD-06 | Phase 2 | Pending |
| BUILD-07 | Phase 2 | Pending |
| BUILD-08 | Phase 2 | Pending |
| BUILD-09 | Phase 3 | Pending |
| LIFE-01 | Phase 1 | Complete |
| LIFE-02 | Phase 1 | Complete |
| LIFE-03 | Phase 1 | Pending |
| LIFE-04 | Phase 1 | Complete |
| LIFE-05 | Phase 1 | Complete |
| GPU-01 | Phase 3 | Pending |
| GPU-02 | Phase 1 | Complete |
| GPU-03 | Phase 3 | Pending |
| GPU-04 | Phase 1 | Complete |
| CTX-01 | Phase 1 | Complete |
| CTX-02 | Phase 1 | Complete |
| CTX-03 | Phase 1 | Complete |
| CTX-04 | Phase 1 | Complete |
| CTX-05 | Phase 1 | Complete |
| HLTH-01 | Phase 3 | Pending |
| HLTH-02 | Phase 3 | Pending |
| HLTH-03 | Phase 3 | Pending |
| MKT-01 | Phase 4 | Pending |
| MKT-02 | Phase 4 | Pending |
| MKT-03 | Phase 4 | Pending |
| MKT-04 | Phase 2 | Pending |
| MKT-05 | Phase 4 | Pending |
| MKT-06 | Phase 4 | Pending |
| MKT-07 | Phase 4 | Pending |
| MKT-08 | Phase 2 | Pending |
| MKT-09 | Phase 4 | Pending |
| MKT-10 | Phase 2 | Pending |
| MKT-11 | Phase 4 | Pending |
| ACC-01 | Phase 3 | Pending |
| ACC-02 | Phase 3 | Pending |
| ACC-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0

---
*Requirements defined: 2026-03-24*
*Last updated: 2026-03-24 after roadmap creation*

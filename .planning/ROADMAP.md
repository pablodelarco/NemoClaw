# Roadmap: NemoClaw OpenNebula Marketplace Appliance

## Overview

This roadmap delivers a community marketplace appliance that packages NVIDIA NemoClaw as a ready-to-deploy single-VM image for OpenNebula. The work progresses from writing the appliance lifecycle script (the runtime brain), through building the Packer pipeline (the image factory), to validating the built image on real hardware with GPU passthrough, and finally packaging everything for marketplace PR submission. Each phase produces a coherent, verifiable deliverable that unblocks the next.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Appliance Lifecycle Script** - Write appliance.sh with service lifecycle hooks, contextualization handling, GPU detection, and NemoClaw sandbox management
- [ ] **Phase 2: Packer Build Pipeline** - Create Packer HCL configs, provisioner scripts, and build infrastructure to produce the qcow2 image
- [ ] **Phase 3: Image Build and Validation** - Execute the Packer build on the build host and validate boot, GPU passthrough, access, and health
- [ ] **Phase 4: Marketplace Packaging and PR Submission** - Create marketplace YAML, documentation, RSpec tests, and submit PR to marketplace-community

## Phase Details

### Phase 1: Appliance Lifecycle Script
**Goal**: The appliance runtime logic is complete -- appliance.sh handles installation, configuration, and bootstrap of NemoClaw with full contextualization support and graceful GPU fallback
**Depends on**: Nothing (first phase)
**Requirements**: LIFE-01, LIFE-02, LIFE-03, LIFE-04, LIFE-05, CTX-01, CTX-02, CTX-03, CTX-04, CTX-05, GPU-02, GPU-04
**Success Criteria** (what must be TRUE):
  1. appliance.sh implements service_install(), service_configure(), and service_bootstrap() following the one-apps lifecycle convention
  2. ONE_SERVICE_PARAMS defines all contextualization parameters (API key, model, sandbox name) with correct types, defaults, and descriptions
  3. service_configure() reads CONTEXT variables and writes NemoClaw configuration (API key to restricted file, model selection, sandbox name)
  4. service_bootstrap() creates and starts the NemoClaw sandbox, then runs health validation
  5. GPU detection logic differentiates GPU-present (proceed with nvidia-smi validation) from GPU-absent (log warning, continue with remote-only inference)
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md -- Script skeleton, ONE_SERVICE_PARAMS, and service_install() with all dependency installation
- [ ] 01-02-PLAN.md -- GPU detection, helper functions, and service_configure() with CONTEXT variable handling
- [ ] 01-03-PLAN.md -- service_bootstrap() with NemoClaw onboard, sandbox creation, and health validation

### Phase 2: Packer Build Pipeline
**Goal**: The Packer build system is complete -- all HCL configs, provisioner scripts, and build metadata produce a qcow2 image with every dependency baked in
**Depends on**: Phase 1
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07, BUILD-08, MKT-04, MKT-08, MKT-10
**Success Criteria** (what must be TRUE):
  1. Packer HCL config defines a QEMU builder that starts from Ubuntu 22.04 base and produces a qcow2 image
  2. The provisioner chain installs Docker CE, NVIDIA driver 550-server, NVIDIA Container Toolkit, Node.js 22 LTS, NemoClaw, and OpenNebula contextualization packages in the correct order
  3. NemoClaw sandbox container image is pre-pulled during build so no network download is needed at first boot
  4. Image is post-processed with virt-sysprep (clean machine IDs, SSH keys) and virt-sparsify (reduce size)
  5. metadata.yaml, gen_context, SSH/context config scripts, and Makefile.config entry are complete and follow one-apps conventions
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

### Phase 3: Image Build and Validation
**Goal**: A tested, bootable qcow2 image exists that auto-configures NemoClaw at first boot, supports GPU passthrough, and provides SSH/VNC access
**Depends on**: Phase 2
**Requirements**: BUILD-09, GPU-01, GPU-03, ACC-01, ACC-02, ACC-03, HLTH-01, HLTH-02, HLTH-03
**Success Criteria** (what must be TRUE):
  1. Packer build completes successfully on the build host (ssh root@100.123.42.13) and produces a qcow2 artifact
  2. VM booted from the image auto-configures NemoClaw via contextualization and reaches "All set and ready to serve" MOTD within 5 minutes
  3. User can SSH into the VM with key-based authentication and interact with the NemoClaw CLI
  4. VNC console access works via OpenNebula Sunstone
  5. When a GPU is passed through, nvidia-smi validates driver/device availability inside the VM
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: Marketplace Packaging and PR Submission
**Goal**: A complete, PR-ready package for the OpenNebula marketplace-community repository that passes validation
**Depends on**: Phase 3
**Requirements**: MKT-01, MKT-02, MKT-03, MKT-05, MKT-06, MKT-07, MKT-09, MKT-11
**Success Criteria** (what must be TRUE):
  1. UUID-named YAML metadata file contains all required fields (name, version, publisher, checksums, user_inputs, VM template with PCI GPU config) and references the correct image
  2. README.md documents quick start, architecture overview, configuration parameters, and GPU host requirements
  3. RSpec tests verify Docker running, NVIDIA drivers loaded, NemoClaw container healthy, CLI available, and MOTD showing readiness
  4. PR to OpenNebula/marketplace-community passes /marketplace-check validation bot
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Appliance Lifecycle Script | 0/3 | Planning complete | - |
| 2. Packer Build Pipeline | 0/0 | Not started | - |
| 3. Image Build and Validation | 0/0 | Not started | - |
| 4. Marketplace Packaging and PR Submission | 0/0 | Not started | - |

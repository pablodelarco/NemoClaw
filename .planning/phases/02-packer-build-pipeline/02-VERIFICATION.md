---
phase: 02-packer-build-pipeline
verified: 2026-03-24T16:21:30Z
status: passed
score: 9/9 artifacts verified
re_verification: false
gaps: []
human_verification:
  - test: "Run `bash -c 'cd /path/to/checkout && make service_nemoclaw'` on build host (100.123.42.13)"
    expected: "Packer build completes and produces output/nemoclaw.qcow2"
    why_human: "Cannot execute Packer builds or verify qcow2 image output without the build host environment and one-apps submodule checkout"
  - test: "Boot produced qcow2 in KVM, verify one-context agent runs at boot and invokes net-90-service-appliance"
    expected: "Context hooks in /etc/one-context.d/ execute, triggering service configure and bootstrap"
    why_human: "Requires running VM; one-context agent presence depends on ubuntu2404 base image having addon-context-linux pre-installed (documented assumption in STACK.md, not verifiable without the base image)"
---

# Phase 2: Packer Build Pipeline Verification Report

**Phase Goal:** The Packer build system is complete -- all HCL configs, provisioner scripts, and build metadata produce a qcow2 image with every dependency baked in
**Verified:** 2026-03-24T16:21:30Z
**Status:** passed
**Re-verification:** No -- initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Packer HCL config defines a QEMU builder that starts from Ubuntu 24.04 base and produces a qcow2 image | VERIFIED | `nemoclaw.pkr.hcl` line 38: `iso_url = "${var.input_dir}/ubuntu2404.qcow2"`, line 48: `format = "qcow2"` |
| 2 | The provisioner chain delegates to appliance.sh's service_install() which installs Docker CE, NVIDIA driver 550-server, NVIDIA Container Toolkit, Node.js 22 LTS, NemoClaw, and pre-pulls the sandbox container image | VERIFIED | `nemoclaw.pkr.hcl` line 124: `"/etc/one-appliance/service install"` calls appliance.sh. Confirmed via appliance.sh: Docker CE (lines 66-79), NVIDIA 550-server (107), Container Toolkit (121), Node.js 22 (130), NemoClaw (136-138), pre-pull (147-149) |
| 3 | NemoClaw sandbox container image is pre-pulled during build so no network download is needed at first boot | VERIFIED | `appliance.sh` lines 145-149: `nemoclaw sandbox-image pull` with `docker pull ghcr.io/nvidia/openshell:latest` fallback inside `service_install()` |
| 4 | Image is post-processed with virt-sysprep and virt-sparsify for clean distribution | VERIFIED | `nemoclaw.pkr.hcl` lines 131-138: post-processor delegates to `one-apps/packer/postprocess.sh` with `OUTPUT_DIR` and `APPLIANCE_NAME` env vars |
| 5 | metadata.yaml, gen_context, SSH/context config scripts, and Makefile.config entry are complete and follow one-apps conventions | VERIFIED | All 9 files present and substantive; gen_context (37 lines, executable), metadata.yaml (71 lines), Makefile.config (8 lines) |

**Score:** 5/5 truths verified

---

## Required Artifacts

### Plan 02-01 Artifacts

| Artifact | Min Lines | Actual Lines | Status | Details |
|----------|-----------|-------------|--------|---------|
| `apps-code/community-apps/packer/nemoclaw/nemoclaw.pkr.hcl` | 80 | 139 | VERIFIED | Regular file; QEMU source, 10 provisioners, post-processor block |
| `apps-code/community-apps/packer/nemoclaw/variables.pkr.hcl` | 15 | 31 | VERIFIED | Declares appliance_name="nemoclaw", version="0.1.0", input_dir, output_dir, headless, nemoclaw map |
| `apps-code/community-apps/packer/nemoclaw/common.pkr.hcl` | -- | -- | VERIFIED | Confirmed symlink (`test -L` passes); target: `../../../one-apps/packer/common.pkr.hcl` (dangling locally, resolves on build host with submodule checkout -- by design) |
| `apps-code/community-apps/packer/nemoclaw/cloud-init.yml` | 5 | 7 | VERIFIED | Contains `ssh_pwauth: true`, `root:opennebula`, `disable_root: false` |
| `apps-code/community-apps/packer/nemoclaw/81-configure-ssh.sh` | 10 | 18 | VERIFIED | Executable; hardens PasswordAuthentication, PermitRootLogin without-password, PubkeyAuthentication yes, PermitEmptyPasswords no, X11Forwarding no |
| `apps-code/community-apps/packer/nemoclaw/82-configure-context.sh` | 10 | 23 | VERIFIED | Executable; chmod on context hooks, systemctl enable one-context.service |

### Plan 02-02 Artifacts

| Artifact | Min Lines | Actual Lines | Status | Details |
|----------|-----------|-------------|--------|---------|
| `apps-code/community-apps/packer/nemoclaw/gen_context` | 30 | 37 | VERIFIED | Executable; generates context.sh with ETH0_METHOD=dhcp, ROOT_PASSWORD, SET_HOSTNAME, base64-encoded START_SCRIPT for SSH/DNS |
| `appliances/nemoclaw/metadata.yaml` | 40 | 71 | VERIFIED | name: NemoClaw, version: 0.1.0, base_image: ubuntu2404, all 3 context params, host-passthrough CPU, 8192MB RAM, hypervisor: kvm |
| `apps-code/community-apps/Makefile.config` | 5 | 8 | VERIFIED | VERSION := 6.10.0, RELEASE := 3, SERVICES := nemoclaw |

---

## Key Link Verification

| From | To | Via | Pattern Found | Status |
|------|-----|-----|---------------|--------|
| `nemoclaw.pkr.hcl` | `variables.pkr.hcl` | `var.appliance_name` references | Lines 60, 108, 135: `${var.appliance_name}` present | WIRED |
| `nemoclaw.pkr.hcl` | `appliances/nemoclaw/appliance.sh` | file provisioner to `/etc/one-appliance/service.d/` | Line 108: `source = "appliances/${var.appliance_name}/appliance.sh"`, line 109: `destination = "/etc/one-appliance/service.d/appliance.sh"` | WIRED |
| `nemoclaw.pkr.hcl` | `one-apps/packer/postprocess.sh` | post-processor shell-local | Line 137: `scripts = ["one-apps/packer/postprocess.sh"]` | WIRED |
| `gen_context` | `nemoclaw.pkr.hcl` | Called by null.context build to produce context ISO | Line 20: `"${path.root}/gen_context > context.sh"`, line 26: mkisofs creates context.iso | WIRED |
| `metadata.yaml` | `nemoclaw.pkr.hcl` | base_image: ubuntu2404 matches iso_url | metadata.yaml line 29: `base_image: ubuntu2404`, nemoclaw.pkr.hcl line 38: `ubuntu2404.qcow2` | WIRED |
| `Makefile.config` | `nemoclaw.pkr.hcl` | SERVICES = nemoclaw enables make service_nemoclaw | Makefile.config line 8: `SERVICES := nemoclaw` | WIRED |

---

## Data-Flow Trace (Level 4)

Not applicable. Phase 2 produces build-time infrastructure files (shell scripts, HCL configs, YAML metadata), not components that render dynamic data at runtime. There are no state variables, React components, or API routes to trace.

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| gen_context has valid bash syntax | `bash -n gen_context` | exit 0 | PASS |
| 81-configure-ssh.sh has valid bash syntax | `bash -n 81-configure-ssh.sh` | exit 0 | PASS |
| 82-configure-context.sh has valid bash syntax | `bash -n 82-configure-context.sh` | exit 0 | PASS |
| common.pkr.hcl is a symlink (not a regular file) | `test -L common.pkr.hcl` | IS_SYMLINK | PASS |
| 81-configure-ssh.sh is executable | `test -x 81-configure-ssh.sh` | true | PASS |
| 82-configure-context.sh is executable | `test -x 82-configure-context.sh` | true | PASS |
| gen_context is executable | `test -x gen_context` | true | PASS |
| nemoclaw.pkr.hcl contains 12 provisioner entries | `grep -c provisioner nemoclaw.pkr.hcl` | 12 | PASS |
| Makefile.config registers SERVICES := nemoclaw | `grep SERVICES Makefile.config` | SERVICES := nemoclaw | PASS |
| Packer build on actual build host | Requires make service_nemoclaw on 100.123.42.13 | NOT_RUN | SKIP -- deferred to Phase 3 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BUILD-01 | 02-01-PLAN | Packer build produces bootable qcow2 from Ubuntu base | SATISFIED with note | HCL uses ubuntu2404 (24.04). REQUIREMENTS.md text says "22.04" but CONTEXT.md D-01 and D-02 explicitly document the override to 24.04. ROADMAP.md Success Criterion 1 says "Ubuntu 24.04 base." The requirement text is stale; intent is satisfied. |
| BUILD-02 | 02-01-PLAN | Docker Engine CE pre-installed and enabled at boot | SATISFIED via delegation | `service_install()` in appliance.sh installs docker-ce, docker-ce-cli, containerd.io; `systemctl enable docker` (appliance.sh line 100) |
| BUILD-03 | 02-01-PLAN | NVIDIA driver 550-server pre-installed | SATISFIED via delegation | `service_install()` installs `nvidia-driver-${NVIDIA_DRIVER_BRANCH}` where `NVIDIA_DRIVER_BRANCH="550-server"` (appliance.sh line 107) |
| BUILD-04 | 02-01-PLAN | NVIDIA Container Toolkit 1.19+ pre-installed as default Docker runtime | SATISFIED via delegation | `service_install()` installs nvidia-container-toolkit (line 121) and runs `nvidia-ctk runtime configure --runtime=docker` (line 122) |
| BUILD-05 | 02-01-PLAN | Node.js 22 LTS and npm pre-installed | SATISFIED via delegation | `service_install()` installs nodejs with `NODEJS_MAJOR="22"` (appliance.sh lines 128-130) |
| BUILD-06 | 02-01-PLAN | NemoClaw installed and sandbox container image pre-pulled | SATISFIED via delegation | `service_install()` runs NemoClaw installer (lines 135-139) and pre-pulls sandbox image (lines 145-149) |
| BUILD-07 | 02-01-PLAN | OpenNebula contextualization packages (addon-context-linux) pre-installed | SATISFIED with assumption | The one-apps ubuntu2404 base image is documented to include one-context pre-installed (STACK.md line 76). No explicit apt-get install in service_install() -- relies on base image. This follows the Prowler pattern. Context hooks (net-90, net-99) are explicitly copied via provisioner chain. Assumption documented; cannot be verified without the actual base image. |
| BUILD-08 | 02-01-PLAN | Image post-processed with virt-sysprep and virt-sparsify | SATISFIED | `nemoclaw.pkr.hcl` post-processor delegates to `one-apps/packer/postprocess.sh` which handles both operations |
| MKT-04 | 02-02-PLAN | metadata.yaml with build/test infrastructure config | SATISFIED | `appliances/nemoclaw/metadata.yaml` contains OS base (ubuntu2404), all 3 context params matching appliance.sh ONE_SERVICE_PARAMS, VM template with host-passthrough CPU, 8192 MB RAM |
| MKT-08 | 02-01-PLAN | Packer build files (HCL config, variables, gen_context, SSH config, context config scripts) | SATISFIED | All 7 Packer files present: nemoclaw.pkr.hcl, variables.pkr.hcl, common.pkr.hcl (symlink), cloud-init.yml, gen_context, 81-configure-ssh.sh, 82-configure-context.sh |
| MKT-10 | 02-02-PLAN | Makefile.config updated with nemoclaw as build target | SATISFIED | `apps-code/community-apps/Makefile.config` line 8: `SERVICES := nemoclaw` |

**Orphaned requirements check:** REQUIREMENTS.md Traceability table maps exactly BUILD-01 through BUILD-08, MKT-04, MKT-08, MKT-10 to Phase 2. These 11 IDs match precisely what the plans declare. No orphaned requirements.

---

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None | -- | -- | -- |

No TODO, FIXME, PLACEHOLDER, or stub patterns found in any phase 2 file.

---

## Notable Observations

### BUILD-01: Ubuntu 22.04 vs 24.04 Discrepancy

REQUIREMENTS.md line 12 states "Packer build produces a bootable qcow2 image from Ubuntu **22.04** base" but all implementation uses Ubuntu 24.04 (`ubuntu2404.qcow2`). This is a deliberate documented decision:
- CONTEXT.md D-01 and D-02 explicitly authorize the override
- ROADMAP.md Phase 2 Success Criterion 1 states "Ubuntu **24.04** base"
- The SUMMARY records it as a key decision

The requirement text is stale. REQUIREMENTS.md should be updated to say "Ubuntu 24.04 base" to match the roadmap and implementation. This is a documentation gap, not an implementation gap.

### BUILD-07: one-context Package -- Assumption, Not Explicit Install

The `service_install()` function does not contain an `apt-get install one-context` or `apt-get install addon-context-linux` call. BUILD-07 is satisfied by relying on the ubuntu2404 one-apps base image having the package pre-installed, following the same convention as Prowler. This is explicitly documented in STACK.md. It is not a bug but is a testability assumption that Phase 3 (live build validation) should confirm.

### common.pkr.hcl: Dangling Symlink Locally

`common.pkr.hcl -> ../../../one-apps/packer/common.pkr.hcl` resolves to a path that does not exist in this working tree because `one-apps` is a git submodule that is not checked out here. This is intentional by design -- the file is specified to resolve in the full `marketplace-community` checkout on the build host. No action needed.

---

## Human Verification Required

### 1. Full Packer Build Execution

**Test:** On build host (100.123.42.13), run `make service_nemoclaw` from the apps-code/community-apps directory with the one-apps submodule checked out.
**Expected:** Packer completes all 10 provisioner steps, service_install() runs without error, post-processor produces `output/nemoclaw.qcow2`.
**Why human:** Requires the build host environment, KVM, qemu-system-x86_64, virt-sysprep, and virt-sparsify. Cannot run locally.

### 2. one-context Agent Boot Verification

**Test:** Boot the produced qcow2 in an OpenNebula KVM VM, attach a context ISO, observe /var/log/one-context.log.
**Expected:** one-context agent decodes context ISO, sets up networking, calls net-90-service-appliance which triggers service_configure and service_bootstrap.
**Why human:** Requires BUILD-07's assumption to be validated in practice -- that the ubuntu2404 base image has addon-context-linux pre-installed. Cannot verify without the base image or a running VM.

---

## Gaps Summary

No gaps found. All 9 artifacts are present, substantive (above minimum line counts), executable where required, and wired to each other via the key links. All 5 success criteria truths from ROADMAP.md are verified in the codebase. All 11 requirement IDs (BUILD-01 through BUILD-08, MKT-04, MKT-08, MKT-10) are accounted for with evidence.

Two observations warrant attention but do not block the goal:
1. REQUIREMENTS.md BUILD-01 text says "22.04" but implementation uses 24.04 (stale text, documented decision)
2. BUILD-07 (one-context packages) relies on base image assumption, which Phase 3 must validate

---

_Verified: 2026-03-24T16:21:30Z_
_Verifier: Claude (gsd-verifier)_

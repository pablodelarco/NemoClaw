# Pitfalls Research

**Domain:** GPU-enabled OpenNebula Marketplace Appliance packaging NemoClaw (NVIDIA AI agent security stack)
**Researched:** 2026-03-24
**Confidence:** HIGH (verified against official NVIDIA docs, OpenNebula docs, one-apps wiki, marketplace-community repo, NemoClaw troubleshooting guide)

## Critical Pitfalls

### Pitfall 1: NVIDIA Driver Version Mismatch Between Host and Container

**What goes wrong:**
The host VM runs one NVIDIA driver version, but the NemoClaw Docker container (via NVIDIA Container Toolkit) expects a different version. This causes `nvidia-smi` to fail inside the container, CUDA errors at runtime, or the container silently falling back to CPU-only mode. CUDA forward-compatibility libraries on the host can also be injected into containers even when the GPU hardware does not support them, causing cryptic failures.

**Why it happens:**
The appliance bakes a specific NVIDIA driver version into the qcow2 image at build time. When a user deploys this image months later on a host with a different GPU generation or driver expectation, the versions diverge. The NVIDIA Container Toolkit relies on the host kernel module matching the userspace libraries -- unlike most Docker abstractions, the GPU driver cannot be fully containerized.

**How to avoid:**
- Pin the NVIDIA driver to a specific branch (e.g., 550.xx LTS) during Packer build and document which GPU architectures it supports.
- Use `nvidia-container-toolkit` CDI mode and regenerate the CDI spec (`nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`) during `service_configure`, not at build time.
- Add a health check in `service_bootstrap` that runs `nvidia-smi` inside the Docker container and logs a clear warning if it fails, rather than silently proceeding.
- Document the supported driver branch and GPU generations (Ampere/Hopper/Blackwell) in the appliance README and YAML description.

**Warning signs:**
- `nvidia-smi` works on the host but fails inside the Docker container.
- Container logs show "NVIDIA driver was not detected" or "CUDA version mismatch."
- NemoClaw sandbox starts but inference requests time out (falling back to remote API may mask the issue).

**Phase to address:**
Phase 1 (Packer Build) -- driver installation and pinning. Phase 2 (Appliance Script) -- runtime CDI regeneration in `service_configure`. Phase 3 (Testing) -- GPU health check validation.

---

### Pitfall 2: GPU Passthrough Requires Host-Side IOMMU Configuration That the Appliance Cannot Control

**What goes wrong:**
Users deploy the appliance and assign a PCI GPU device, but the VM cannot access the GPU. The appliance boots fine but `nvidia-smi` shows no devices. This is because GPU passthrough requires IOMMU kernel parameters (`intel_iommu=on iommu=pt` or `amd_iommu=on`), vfio-pci driver binding, udev rules, and driverctl overrides -- all on the KVM host, not inside the VM.

**Why it happens:**
Appliance developers focus on what is inside the VM image and forget that GPU passthrough is a two-sided configuration. The appliance can only control the guest side. The host-side configuration (IOMMU, vfio-pci binding, udev rules for `/dev/vfio/`, PCI filter in `pci.conf`) must be done by the OpenNebula administrator before the appliance is deployed.

**How to avoid:**
- Document host-side prerequisites clearly and prominently in the appliance README, including exact commands for Intel and AMD hosts.
- Include a `service_bootstrap` check that tests for GPU presence via `lspci | grep -i nvidia` and falls back gracefully with a clear log message: "No GPU detected. NemoClaw will use remote NVIDIA Endpoints only."
- Reference the official OpenNebula NVIDIA GPU Passthrough guide (docs.opennebula.io/7.0) in the appliance metadata.
- Set the YAML `short_description` to explicitly mention GPU passthrough requirement.

**Warning signs:**
- `lspci` inside the VM shows no NVIDIA devices.
- `/dev/nvidia*` device files do not exist in the VM.
- OpenNebula Sunstone shows the PCI device but the VM fails to start (IOMMU not enabled on host).

**Phase to address:**
Phase 1 (Documentation) -- host prerequisites. Phase 2 (Appliance Script) -- graceful GPU-absent fallback in `service_bootstrap`.

---

### Pitfall 3: NemoClaw Alpha API Instability Breaks the Appliance After Updates

**What goes wrong:**
NemoClaw is alpha software (released March 16, 2026). The installer script (`curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash`), CLI interface, configuration schemas, and Docker image tags can change without notice. An appliance built today may break next month when NemoClaw pushes a breaking change. The installer itself is a curl-pipe-to-bash pattern that downloads whatever is current, not a pinned version.

**Why it happens:**
Alpha software by definition has unstable APIs. NemoClaw explicitly warns: "APIs, configuration schemas, and runtime behavior are subject to breaking changes between releases." The appliance script likely calls NemoClaw CLI commands that may be renamed or have changed flags. The Docker images may change tag conventions.

**How to avoid:**
- Pin the NemoClaw version at build time. If the installer supports a `--version` flag, use it. If not, capture and pin the npm package version (`nemoclaw@x.y.z`).
- Pin the Docker image tags used by NemoClaw (capture the exact SHA digest during build and store it).
- Wrap NemoClaw CLI calls in the appliance script with version checks and clear error messages.
- Add a `NEMOCLAW_VERSION` context variable so users can override the pinned version if needed.
- Track the NemoClaw GitHub releases and plan appliance updates when breaking changes ship.
- Document the alpha status prominently in the marketplace YAML description field.

**Warning signs:**
- The appliance stops working without any changes on the user's side (NemoClaw pushed an update).
- `nemoclaw` CLI commands fail with "unknown command" or changed flag errors.
- Docker Compose file format changes cause `docker compose up` to fail.

**Phase to address:**
Phase 1 (Packer Build) -- version pinning strategy. Phase 2 (Appliance Script) -- version-aware CLI calls. Every phase -- version pinning discipline.

---

### Pitfall 4: Docker Image Size Bloat Causing Build Failures and Slow Deployments

**What goes wrong:**
The NemoClaw sandbox image is approximately 2.4 GB compressed. Combined with the Docker Engine, NVIDIA Container Toolkit packages, and Ubuntu base system, the final qcow2 image can easily exceed 8-10 GB. During the Packer build, Docker pulls and extracts these layers, which can OOM-kill the build process on machines with less than 8 GB RAM. Users downloading the appliance face multi-GB downloads before they can even start.

**Why it happens:**
NVIDIA CUDA runtime libraries are inherently large. The NemoClaw stack layers Docker, k3s, OpenShell gateway, and the agent sandbox on top. During image build, Docker buffers decompressed layers in memory. The Packer QEMU builder also needs disk space for the temporary VM, and `qemu-img convert` needs space for the final compressed output.

**How to avoid:**
- Allocate at least 16 GB RAM and 60+ GB disk on the build host (the project build host at 100.123.42.13 should be verified for these specs).
- Pre-pull NemoClaw Docker images during the Packer build phase (in `service_install`), not during first boot. This bakes them into the qcow2 image but makes the user experience instant.
- Use `docker system prune` after installation to remove build caches and intermediate layers.
- Enable qcow2 compression in Packer (`"disk_compression": true`) to minimize the final image size.
- Add swap space (8 GB) during the Packer build to prevent OOM during Docker image pulls.
- Document the expected image size in the marketplace YAML so users know what to expect.

**Warning signs:**
- Packer build process killed by OOM (check `dmesg | grep -i oom`).
- Build hangs during `docker pull` or `docker compose pull`.
- Final qcow2 image is unexpectedly large (over 12 GB compressed).
- User complaints about slow marketplace downloads.

**Phase to address:**
Phase 1 (Packer Build) -- build host sizing, swap, image pre-pull, compression. Phase 3 (Testing) -- verify final image size.

---

### Pitfall 5: Contextualization Timing -- Services Starting Before Network Is Ready

**What goes wrong:**
The appliance script's `service_configure` or `service_bootstrap` tries to pull Docker images, contact NVIDIA API endpoints, or configure NemoClaw before the VM's network is fully configured. This causes silent failures: Docker pull times out, API key validation fails, NemoClaw onboarding hangs. On Ubuntu 22.04, `systemd-networkd-wait-online.service` can add a 2-minute delay that causes race conditions with services that start on boot.

**Why it happens:**
OpenNebula contextualization runs in stages: network configuration happens first, then "post-networking" scripts execute. But Docker and systemd services may start before contextualization completes, or the network may not be fully routed even after the interface is up. The `service_bootstrap` stage may fire before DNS is resolving or before the default gateway is reachable.

**How to avoid:**
- In `service_configure`, add an explicit network readiness check before any network-dependent operations: `until curl -sf https://api.nvidia.com/health > /dev/null 2>&1; do sleep 2; done` with a timeout.
- Pre-pull all Docker images during Packer build (in `service_install`) so no network access is needed at boot for the core stack.
- Disable `systemd-networkd-wait-online.service` in the Packer build to avoid the 2-minute boot delay (OpenNebula one-apps issue #134 documents this exact problem).
- Use systemd `After=network-online.target` dependencies for any NemoClaw-related service units.
- Separate operations: `service_install` for offline setup, `service_configure` for config file writing, `service_bootstrap` for network-dependent operations (API key validation, model selection).

**Warning signs:**
- First boot takes over 5 minutes due to network timeout retries.
- NemoClaw service status shows "failed" after first boot but works after manual restart.
- Docker logs show "network unreachable" or "DNS resolution failed" errors during boot.
- `systemd-networkd-wait-online.service` shows in `systemd-analyze blame` as a 2-minute bottleneck.

**Phase to address:**
Phase 2 (Appliance Script) -- network readiness guards in lifecycle hooks. Phase 1 (Packer Build) -- disable wait-online service, pre-pull images.

---

### Pitfall 6: NVIDIA API Keys Exposed in OpenNebula Context Variables

**What goes wrong:**
The NVIDIA API key (required for NemoClaw inference via NVIDIA Endpoints) is passed as a contextualization parameter. OpenNebula context variables are stored in the VM template, visible in Sunstone to any user with VM access, and written to `/run/one-context/one_env` or the context CD-ROM as plain text. An API key leak can result in unauthorized inference charges against the user's NVIDIA account.

**Why it happens:**
OpenNebula contextualization was designed for configuration data (hostnames, IPs, SSH keys), not secrets. Context variables are not encrypted at rest in the VM template database, and they appear in plain text in the VM's context ISO and environment files. The Prowler reference appliance and others use this same pattern for API keys, so it feels like the standard approach -- but it is insecure.

**How to avoid:**
- Accept the API key via context variable (it is the only mechanism available) but immediately move it to a restricted file (`/etc/nemoclaw/api_key`, mode 0600, owned by root) in `service_configure` and unset the environment variable.
- Clear the API key from the context environment after reading it: `unset NVIDIA_API_KEY` in the bootstrap script.
- Document the security implication clearly: "API keys are visible in the VM template to any OpenNebula user with access to this VM."
- Recommend that cloud administrators use OpenNebula's access control (ACLs) to restrict who can view VM templates containing API keys.
- Consider supporting a "bring your own config file" pattern where users can SSH in and set the API key directly, bypassing contextualization for sensitive values.

**Warning signs:**
- API key visible in Sunstone VM template details.
- API key logged in contextualization output (`/var/log/one-context.log`).
- API key persists in `/run/one-context/one_env` after boot.

**Phase to address:**
Phase 2 (Appliance Script) -- secure API key handling in `service_configure`. Phase 1 (Documentation) -- security advisory for operators.

---

### Pitfall 7: one-apps Build System Symlinks and Packer Version Requirements

**What goes wrong:**
The marketplace-community build process depends on the one-apps toolchain, which has specific requirements: Packer 1.9.4+ (1.10.0 recommended), QEMU with KVM acceleration, `guestfs-tools` (virt-sysprep), and `cloud-utils`. The build system uses Makefiles and symlinks internally. Building on a system without KVM acceleration (e.g., a cloud VM without nested virtualization) causes Packer to fall back to TCG software emulation, making builds 10-50x slower. Missing `guestfs-tools` causes the post-processing (virt-sysprep) step to fail silently or produce images with stale SSH host keys.

**Why it happens:**
Developers set up the build host once and forget the requirements. The one-apps wiki lists dependencies but they are easy to overlook. Packer auto-installs the QEMU plugin but does not verify KVM acceleration or post-processing tools. The build may appear to succeed but produce a broken or insecure image.

**How to avoid:**
- Verify the build host (100.123.42.13) meets all one-apps requirements before starting: Packer 1.10.0+, `qemu-system-x86_64` with KVM, `guestfs-tools`, `cloud-utils`, 16+ GB RAM, 60+ GB disk.
- Run `kvm-ok` or check `/dev/kvm` exists on the build host.
- Always run `virt-sysprep` as a post-processor to remove SSH host keys, machine IDs, and other host-specific data from the image.
- Pin the Packer version in the build documentation. Do not rely on the system package manager's version.
- Test the build process end-to-end on a clean host before assuming it works.

**Warning signs:**
- Packer build takes hours instead of minutes (TCG fallback, no KVM).
- Build fails at "post-processing" step with guestfs errors.
- Built image contains SSH host keys from the build host (security issue).
- `packer validate` fails with plugin version errors.

**Phase to address:**
Phase 1 (Build Environment Setup) -- verify all dependencies upfront. Phase 3 (Testing) -- image hygiene checks.

---

### Pitfall 8: Marketplace YAML Validation Errors Blocking the PR

**What goes wrong:**
The PR to `OpenNebula/marketplace-community` fails the `/marketplace-check` validation bot. Common failures: UUID filename format wrong, `creation_time` not updated to current epoch, image `size` is the file size instead of the virtual disk size (must use `qemu-img info` to get the correct value), checksum mismatches (md5 and sha256 must both be correct), `user_inputs` format errors (OpenNebula's user_inputs have specific type syntax), `opennebula_version` range incorrect, or missing required fields.

**Why it happens:**
The marketplace YAML format has subtle requirements not fully documented in one place. Image `size` must be the virtual size in bytes (from `qemu-img info`), not the compressed file size. UUIDs must be lowercase and properly formatted. `user_inputs` follow a specific DSN-like syntax (`M|text|Description|...`) that is easy to get wrong. Version bumps require updating `creation_time` to force client cache invalidation.

**How to avoid:**
- Use `uuidgen | tr '[:upper:]' '[:lower:]'` for the filename.
- Use `qemu-img info --output=json <image>` and extract `virtual-size` for the size field.
- Generate checksums with both `md5sum` and `sha256sum` on the final qcow2 file.
- Set `creation_time` to `$(date +%s)`.
- Study the `user_inputs` format from existing appliances (Prowler PR #99 and Nextcloud AIO are references).
- Validate the YAML locally before submitting: check for required fields (name, version, publisher, description, short_description, tags, format, creation_time, os-id, os-release, os-arch, hypervisor, opennebula_version, images).
- Run the marketplace-check validation locally if possible.

**Warning signs:**
- PR bot immediately comments with validation errors.
- `size` field does not match `qemu-img info` output.
- `user_inputs` cause Sunstone to render broken input forms.
- Appliance does not appear in the marketplace after merging (opennebula_version mismatch filtering it out).

**Phase to address:**
Phase 3 (Marketplace Submission) -- YAML validation checklist. Phase 1 (Build) -- automate checksum and size extraction in the build script.

---

### Pitfall 9: Testing Requires GPU Hardware That CI/CD Cannot Provide

**What goes wrong:**
Full integration testing of the appliance requires a physical NVIDIA GPU with passthrough configured, which standard CI/CD runners (GitHub Actions, GitLab CI) do not offer. Developers skip GPU tests, ship the appliance, and discover GPU-related failures only when users deploy it. Without GPU testing, the NVIDIA driver installation, Container Toolkit configuration, and NemoClaw GPU inference path are all unvalidated.

**Why it happens:**
GPU hardware is expensive and not available in standard CI environments. Even GPU-enabled CI runners (e.g., GitHub Actions with GPU) typically do not support nested virtualization or PCI passthrough, which are needed to test the full appliance lifecycle inside a VM.

**How to avoid:**
- Use the dedicated build host (100.123.42.13) for integration tests that require GPU access.
- Split testing into two tiers:
  - **Tier 1 (CI-compatible, no GPU):** YAML validation, shell script linting (shellcheck), Packer template validation (`packer validate`), basic VM boot test (can run with TCG/no GPU), Docker service starts, NemoClaw CLI is available, remote inference endpoint reachable.
  - **Tier 2 (GPU-required, manual/build-host):** GPU passthrough works, `nvidia-smi` inside container, NemoClaw GPU inference benchmark, full end-to-end agent run.
- Document which tests are Tier 1 vs Tier 2 and make Tier 2 a manual gate before marketplace submission.
- Write Tier 1 tests to explicitly skip GPU checks with a clear "SKIP: no GPU detected" message, not silent passes.

**Warning signs:**
- All tests pass in CI but appliance fails on real GPU hardware.
- Tests contain `|| true` or silent GPU check bypasses.
- No test exercises `nvidia-smi` or Docker GPU access.

**Phase to address:**
Phase 3 (Testing) -- test tier strategy. Phase 1 (Build Environment) -- confirm GPU availability on build host.

---

### Pitfall 10: NemoClaw Requires Fresh Installation -- Cannot Overlay on Existing OpenClaw

**What goes wrong:**
The appliance script tries to install NemoClaw alongside or on top of a pre-existing OpenClaw setup, or the user later tries to add NemoClaw features to an existing OpenClaw installation. NemoClaw explicitly requires a fresh installation. Attempting to add it to an existing setup causes configuration conflicts, missing security policies, and broken sandbox isolation.

**Why it happens:**
NemoClaw wraps OpenClaw with security features (Landlock, seccomp, network namespaces). It is not a plugin or extension but a complete replacement of the runtime environment. The installer assumes it controls the entire Docker Compose stack and the filesystem layout.

**How to avoid:**
- Ensure the Packer build installs NemoClaw on a clean Ubuntu 22.04 base with no pre-existing OpenClaw.
- Do not install OpenClaw separately and then add NemoClaw on top.
- If the installer (`nemoclaw.sh`) includes an interactive onboarding wizard, either pre-answer its questions via environment variables or run it in headless/non-interactive mode during `service_install`.
- Document that this appliance provides NemoClaw (which includes OpenClaw), not a separate OpenClaw + NemoClaw setup.

**Warning signs:**
- Packer build log shows "existing OpenClaw installation detected" errors.
- Security policy enforcement does not activate after deployment.
- Sandbox isolation tests fail (processes escape the namespace).

**Phase to address:**
Phase 1 (Packer Build) -- clean installation sequence. Phase 2 (Appliance Script) -- verify no stale OpenClaw state.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `curl \| bash` installer at boot | Simple, always gets latest | Unpinned version, network dependency at boot, security risk | Never in production appliance; pre-install during Packer build |
| Hardcoding NVIDIA driver version | Predictable builds | Incompatible with newer GPU generations | MVP only; plan to add driver detection or multiple driver packages |
| Skipping virt-sysprep | Faster builds | Leaked SSH keys, machine IDs from build host in production images | Never |
| Single large qcow2 with everything baked in | Simple deployment, fast first boot | Huge download, slow marketplace sync | Acceptable for v1; consider split image later |
| Passing API keys via context variables | Only available mechanism | Keys visible in Sunstone, not encrypted | Always for MVP, but mitigate with file-based storage on first boot |
| Testing only with remote inference (no GPU) | Can test without hardware | GPU passthrough path untested | Tier 1 only; always run Tier 2 before submission |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| NVIDIA Container Toolkit + Docker | Installing toolkit before Docker, causing broken runtime config | Install Docker first, then nvidia-container-toolkit, then run `nvidia-ctk runtime configure --runtime=docker` and restart Docker daemon |
| OpenNebula Contextualization + Docker | Docker service starts before context scripts finish configuring it | Use `service_install` to install Docker, `service_configure` to write config, `service_bootstrap` to start services. Do not enable Docker autostart during install phase |
| NemoClaw + NVIDIA Endpoints API | Hardcoding the API endpoint URL | Use `NVIDIA_BASE_URL` env var or NemoClaw config, as endpoint URLs may change |
| Packer + qcow2 compression | Using default disk_size (40 GB) and no compression | Set disk_size to actual needs (20-25 GB), enable `disk_compression: true`, and use `format: "qcow2"` explicitly |
| marketplace YAML + OpenNebula versions | Setting `opennebula_version` to exact version | Use version range (e.g., `"6.8..7.0"`) so appliance appears for multiple OpenNebula releases |
| NemoClaw + Podman | Assuming Docker alternatives work | NemoClaw requires Docker (standard Docker socket behavior). Do not attempt Podman substitution. Document this requirement |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Docker image pull on first boot | 5-10 min first boot, timeout on slow networks | Pre-pull images during Packer build | Always, on any network slower than 100 Mbps |
| No swap configured on 8 GB VM | OOM killer terminates Docker or NemoClaw processes | Configure 4-8 GB swap in Packer build | When NemoClaw + Docker daemon + k3s + OpenShell use more than physical RAM |
| systemd-networkd-wait-online | 2-minute boot delay on every boot | Disable the service in Packer build (one-apps issue #134) | Always on Ubuntu 22.04 with OpenNebula contextualization |
| Unbounded NemoClaw log files | Disk fills up, Docker daemon crashes | Configure Docker log rotation (`max-size: 10m`, `max-file: 3`) in daemon.json | After days/weeks of continuous operation |
| k3s + Docker daemon competing for resources | High memory usage, slow container starts | Ensure minimum 8 GB RAM documented; monitor with cgroup limits | On VMs with exactly 8 GB RAM under load |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| API key in context environment persists after boot | Key extractable by any process in the VM | Read key in `service_configure`, write to restricted file (0600), unset env var, clear from one_env |
| SSH host keys from build host baked into image | All deployed VMs share the same SSH host key (MITM possible) | Always run virt-sysprep as Packer post-processor; regenerate keys on first boot |
| NemoClaw installer runs as root with unrestricted network | Supply chain attack vector if NVIDIA CDN is compromised | Pin installer version/checksum; install during Packer build (controlled environment), not at user boot time |
| Docker socket accessible to non-root users | Container escape to host root | Keep Docker socket restricted to root; NemoClaw manages its own access |
| Egress allowed by default (misconfiguration) | Sandbox agents can exfiltrate data to arbitrary endpoints | NemoClaw defaults to deny-all egress; verify this is not overridden in appliance config |
| Build host credentials in Packer template | SSH keys or passwords leak into version control | Use environment variables for build host credentials; never commit them. Use `.gitignore` for sensitive Packer variables files |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during 5-minute first boot | User thinks VM is broken, power-cycles it | Add progress messages to VNC console output during `service_bootstrap`. Log each stage clearly |
| GPU not detected but no error message | User deploys, tries inference, gets cryptic timeouts | Print clear message at boot: "GPU detected: YES/NO. Using: [local/remote] inference" |
| user_inputs in Sunstone render as raw text | User does not understand what to fill in | Use descriptive labels and defaults in user_inputs: `M\|text\|NVIDIA API Key (from build.nvidia.com)\|\|` |
| VNC console shows login prompt before services ready | User logs in, NemoClaw not yet running | Add MOTD or login banner: "NemoClaw is initializing. Run 'nemoclaw status' to check." |
| Alpha software warning not visible | User expects production quality, files bug reports for intended alpha behavior | Add alpha warning to MOTD, README, and YAML description. Make it impossible to miss |

## "Looks Done But Isn't" Checklist

- [ ] **Image builds:** Often missing virt-sysprep post-processing -- verify no build-host SSH keys in `/etc/ssh/ssh_host_*`
- [ ] **Docker GPU access:** Often missing `nvidia-ctk runtime configure` step -- verify `docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi` works
- [ ] **Contextualization:** Often missing `service_bootstrap` stage -- verify all user_inputs are actually consumed and applied
- [ ] **Marketplace YAML:** Often missing `size` field using file size instead of virtual size -- verify with `qemu-img info --output=json`
- [ ] **Network egress:** Often missing firewall/policy verification -- verify NemoClaw sandbox blocks unauthorized outbound connections
- [ ] **Swap space:** Often missing swap configuration -- verify `free -h` shows swap after boot
- [ ] **Log rotation:** Often missing Docker log limits -- verify `/etc/docker/daemon.json` has log driver config
- [ ] **First-boot experience:** Often missing VNC console output -- verify user sees progress during `service_bootstrap`
- [ ] **API key security:** Often missing key file permissions -- verify `/etc/nemoclaw/api_key` is mode 0600 after boot
- [ ] **Graceful GPU fallback:** Often missing no-GPU path -- verify appliance works with remote inference when no GPU is attached

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Driver version mismatch | MEDIUM | SSH into VM, uninstall current driver, install matching version, regenerate CDI spec, restart Docker |
| Missing IOMMU on host | HIGH | Requires host reboot with new kernel parameters; cannot be fixed from inside the VM |
| NemoClaw breaking change | HIGH | Identify changed APIs, update appliance script, rebuild image, resubmit to marketplace |
| Image too large | LOW | Re-run Packer build with compression and prune; or resize disk_size parameter |
| Network timing race | LOW | SSH into VM, re-run `service_bootstrap` manually; or reboot the VM |
| API key exposure | MEDIUM | Rotate the NVIDIA API key immediately; update the appliance script to secure the key |
| YAML validation failure | LOW | Fix the YAML fields, re-run checksums, update PR |
| Build host missing deps | LOW | Install missing packages on 100.123.42.13; re-run build |
| GPU tests skipped | MEDIUM | Run Tier 2 tests manually on GPU-equipped host before submission |
| Stale OpenClaw conflict | HIGH | Wipe the VM, rebuild from clean base image with fresh NemoClaw install |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Driver version mismatch | Phase 1 (Packer Build) | `nvidia-smi` works in container during build; CDI spec regenerates on boot |
| GPU passthrough host config | Phase 1 (Documentation) | README includes host-side setup commands; appliance logs GPU status at boot |
| NemoClaw API instability | Phase 1 (Build) + ongoing | Version pinned in Packer build; CLI calls wrapped with version checks |
| Image size bloat | Phase 1 (Packer Build) | Final qcow2 under 10 GB compressed; build host has 60+ GB disk |
| Contextualization timing | Phase 2 (Appliance Script) | First boot completes in under 3 minutes; no network errors in logs |
| API key exposure | Phase 2 (Appliance Script) | Key not in env after boot; file permissions verified |
| Build system dependencies | Phase 1 (Setup) | Build host validated with checklist before first build |
| YAML validation errors | Phase 3 (Submission) | `/marketplace-check` passes on first or second attempt |
| GPU testing gap | Phase 3 (Testing) | Tier 2 tests documented and run on build host with GPU |
| Fresh install requirement | Phase 1 (Packer Build) | No OpenClaw pre-existing state; NemoClaw installer runs on clean system |

## Sources

- [OpenNebula NVIDIA GPU Passthrough Guide (v7.0)](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/nvidia_gpu_passthrough/)
- [OpenNebula PCI Passthrough Guide (v7.0)](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/pci_passthrough/)
- [OpenNebula marketplace-community repository](https://github.com/OpenNebula/marketplace-community)
- [OpenNebula one-apps build system](https://github.com/OpenNebula/one-apps)
- [one-apps build requirements wiki](https://github.com/OpenNebula/one-apps/wiki/tool_reqs)
- [one-apps issue #134: systemd-networkd-wait-online delay](https://github.com/OpenNebula/one-apps/issues/134)
- [NVIDIA Container Toolkit installation guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [NVIDIA Container Toolkit issue #946: GPU not detected in Docker](https://github.com/NVIDIA/nvidia-container-toolkit/issues/946)
- [CUDA Compatibility and Forward Compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/)
- [NemoClaw Developer Guide](https://docs.nvidia.com/nemoclaw/latest/index.html)
- [NemoClaw Troubleshooting Guide](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html)
- [NemoClaw Release Notes (alpha warning)](https://docs.nvidia.com/nemoclaw/latest/about/release-notes.html)
- [NemoClaw GitHub repository](https://github.com/NVIDIA/NemoClaw)
- [NemoClaw common mistakes guide (Stormap)](https://stormap.ai/post/getting-started-with-nemoclaw-install-onboard-and-avoid-the-obvious-mistakes)
- [Packer QEMU builder documentation](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu)
- [OpenNebula contextualization security discussion](https://forum.opennebula.io/t/security-doubt-about-windows-contextualization/6903)

---
*Pitfalls research for: NemoClaw OpenNebula Marketplace Appliance*
*Researched: 2026-03-24*

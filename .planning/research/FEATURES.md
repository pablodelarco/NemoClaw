# Feature Research

**Domain:** GPU-enabled AI agent security appliance for OpenNebula Community Marketplace
**Researched:** 2026-03-24
**Confidence:** MEDIUM-HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Contextualization-driven first boot** | Every marketplace appliance auto-configures via CONTEXT parameters. Users never SSH in to set up manually. | MEDIUM | Must implement `service_install`, `service_configure`, `service_bootstrap` lifecycle in `/etc/one-appliance/service`. Follow RabbitMQ/vLLM pattern exactly. |
| **NVIDIA API key injection via CONTEXT** | NemoClaw requires `NVIDIA_API_KEY` for inference. Users expect to paste it into Sunstone UI, not hunt for config files. | LOW | Map to `ONEAPP_NEMOCLAW_API_KEY`. Never persist in image. Inject as env var at runtime (NemoClaw already does this via `~/.nemoclaw/credentials.json`). |
| **Docker + NVIDIA Container Toolkit pre-installed** | Users expect GPU workloads to "just work" without driver/runtime setup. vLLM appliance sets this precedent. | MEDIUM | Install Docker Engine, nvidia-container-toolkit, and configure Docker runtime during Packer build (`service_install`). Set `INSTALL_DRIVERS=true` pattern from vLLM. |
| **SSH key-based access** | All marketplace appliances support `$USER[SSH_PUBLIC_KEY]` contextualization. Password auth disabled by default. | LOW | Standard contextualization handles this. Just ensure `PasswordAuthentication no` in sshd_config. |
| **VNC console access** | Users expect Sunstone VNC access for troubleshooting. Standard in all appliances. | LOW | Template includes `GRAPHICS = [ LISTEN = "0.0.0.0", TYPE = "VNC" ]`. No custom work needed. |
| **Dynamic credential generation** | "No security credentials are persisted in the distributed appliances." Marketplace security standard. | LOW | Generate any needed passwords at first boot in `service_configure`. Store in `/etc/one-appliance/config`. |
| **QCOW2 image format for KVM** | Only image format supported by OpenNebula marketplace for KVM hypervisors. | LOW | Packer build produces qcow2. Standard. |
| **Network contextualization** | VMs must auto-configure networking from OpenNebula-provided CONTEXT. | LOW | Handled by `addon-context-linux` package. Pre-installed in base image. |
| **Marketplace YAML metadata** | Appliance must have UUID-named YAML with checksums, version, tags, user_inputs. Without it, marketplace-check fails. | LOW | Follow RabbitMQ pattern: `{uuid}.yaml` with all required fields. |
| **README with quick start** | Users need deployment instructions. Every appliance has one. | LOW | Document: prerequisites (GPU host, IOMMU enabled, API key), deployment steps, parameter reference. |

### Differentiators (Competitive Advantage)

Features that set NemoClaw appliance apart from the vLLM appliance and other AI marketplace offerings.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Security policy level selector** | NemoClaw's core value is security. Exposing policy level as a simple CONTEXT parameter (`strict`/`moderate`/`permissive`) lets users choose security posture without editing YAML files. No other appliance does this. | MEDIUM | Map to `ONEAPP_NEMOCLAW_SECURITY_LEVEL`. In `service_configure`, translate to appropriate `openclaw-sandbox.yaml` policy. `strict` = deny-all egress except NVIDIA endpoints. `moderate` = add common presets (PyPI, npm, Docker Hub). `permissive` = broader egress. |
| **Network egress mode control** | NemoClaw's deny-by-default network policy is a key differentiator over vLLM (which has no network isolation). Exposing egress mode lets operators control what the AI agent can reach. | MEDIUM | Map to `ONEAPP_NEMOCLAW_EGRESS_MODE` with options: `nvidia-only` (default, safest), `development` (adds PyPI/npm/Docker Hub/GitHub), `custom` (user provides policy YAML). |
| **Model selection via CONTEXT** | NemoClaw supports 4 Nemotron models. Letting users pick model at deploy time without SSH is valuable. vLLM has `ONEAPP_VLLM_MODEL_ID` - we should match this pattern. | LOW | Map to `ONEAPP_NEMOCLAW_MODEL`. Default: `nvidia/nemotron-3-super-120b-a12b`. Options: `nemotron-3-super-120b`, `nemotron-ultra-253b`, `nemotron-super-49b`, `nemotron-3-nano-30b`. |
| **First-boot health validation** | After `service_configure` completes, automatically verify: Docker running, NVIDIA drivers loaded, NemoClaw sandbox healthy, inference reachable. Report status to `/etc/one-appliance/config` and MOTD. No other community appliance does this level of validation. | MEDIUM | Chain health checks: `docker info`, `nvidia-smi`, `nemoclaw <name> status`, test inference call. Write results to config file. Set READY=YES via OneGate only after all pass. |
| **GPU-present detection with graceful fallback** | Appliance should detect whether a GPU is actually passed through and adjust behavior. If no GPU: skip driver init, warn user, still allow remote-only inference. Prevents confusing errors. | MEDIUM | Check `/dev/nvidia*` or `lspci | grep -i nvidia` in `service_configure`. If absent, log warning, skip GPU setup, note in MOTD "Running without GPU - remote inference only". |
| **In-VM help system** | `nemoclaw-help` command that prints available commands, parameter reference, connection info, and troubleshooting steps. Makes the appliance self-documenting. | LOW | Install a shell script at `/usr/local/bin/nemoclaw-help` that prints usage info. Add to MOTD on login. |
| **Status MOTD on SSH login** | Dynamic login banner showing: NemoClaw version, sandbox state, model in use, GPU status, API endpoint, security policy level. Immediate situational awareness. | LOW | Write `/etc/update-motd.d/99-nemoclaw` that calls `nemoclaw <name> status` and formats output. |
| **OpenShell TUI availability** | NemoClaw's `openshell term` provides a real-time monitoring TUI showing network requests, policy decisions, and agent activity. Unique to NemoClaw. | LOW | Pre-installed with NemoClaw. Document in README and help command. No extra work needed beyond ensuring terminal works via SSH. |
| **Policy preset management** | NemoClaw ships presets for Discord, Docker Hub, Hugging Face, Jira, npm, PyPI, Slack, Telegram. Expose preset selection via CONTEXT parameter. | LOW | Map to `ONEAPP_NEMOCLAW_POLICY_PRESETS` (comma-separated list). Apply each with `nemoclaw <name> policy-add` during bootstrap. |
| **Resource limit configuration** | Let operators set GPU memory utilization and sandbox resource constraints via CONTEXT. Prevents runaway resource consumption in shared environments. | LOW | Map `ONEAPP_NEMOCLAW_GPU_MEM_UTIL` (0.0-1.0, default 0.9). Similar to vLLM's `ONEAPP_VLLM_GPU_MEMORY_UTILIZATION`. |
| **REPORT_READY integration** | Use OneGate to report VM readiness only after NemoClaw is fully operational. Enables OneFlow service orchestration if users build multi-VM setups later. | LOW | Set `REPORT_READY=YES` in CONTEXT. Call OneGate ready endpoint after health checks pass in `service_bootstrap`. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for this appliance.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Local inference with Ollama/vLLM** | Users want fully offline AI agents without API costs. | NemoClaw marks local inference as experimental. Adding Ollama/vLLM doubles image size (models are 10-70GB), complicates GPU memory management, and couples us to alpha-on-alpha features. Project scope explicitly excludes this. | Document how to configure local inference post-deployment for advanced users. Keep appliance focused on remote NVIDIA Endpoints (stable path). |
| **Multi-VM OneFlow service template** | Operators want scalable multi-agent deployments. | v1 scope is single VM. OneFlow adds complexity (role dependencies, scaling rules, health gates). NemoClaw itself doesn't support distributed agent coordination yet. | Ship single VM image first. REPORT_READY support enables future OneFlow integration. Document OneFlow path in README for v2. |
| **Web UI for NemoClaw management** | Users want a browser-based dashboard instead of CLI. | NemoClaw has no web UI. Building one is out of scope and would diverge from upstream. OpenShell TUI (`openshell term`) serves monitoring needs. | Document `openshell term` for monitoring. VNC console provides browser-like access to TUI via Sunstone. |
| **Automatic NVIDIA driver version selection** | Users want the appliance to auto-detect GPU model and install optimal driver. | Driver compatibility is a minefield. Pinning a tested driver version in the image is safer. Auto-detection could install incompatible drivers, breaking GPU passthrough. | Pin NVIDIA driver version tested with the image (match what vLLM appliance uses). Document supported GPU models. |
| **Custom model upload/download** | Users want to upload custom fine-tuned models. | NemoClaw's inference routing uses NVIDIA Endpoints API, not local model files. Custom model support would require vLLM/Ollama (see above). Adds massive complexity. | Users who need custom models should use the vLLM appliance instead. Different use cases. |
| **TLS/HTTPS for API endpoint** | Users want encrypted API access. | NemoClaw's API runs inside the sandbox and is accessed via localhost. Adding TLS adds certificate management complexity. OpenNebula's network security groups handle external access control. | Document that NemoClaw API is localhost-only by design. For external access, use SSH tunnels or OpenNebula security groups. |
| **Automatic updates** | Users want NemoClaw to self-update. | NemoClaw is alpha software with breaking changes between releases. Auto-updates could break running sandboxes. Marketplace appliances are versioned images, not rolling releases. | Pin NemoClaw version in image. Users deploy new appliance version to update. Document version in MOTD. |
| **Non-NVIDIA GPU support** | AMD/Intel GPU users want to use the appliance. | NemoClaw requires NVIDIA OpenShell which uses NVIDIA-specific container runtime. OpenClaw itself is GPU-agnostic but NemoClaw is not. | Document this limitation clearly. AMD/Intel users should use plain OpenClaw. |

## Contextualization Parameters (Full Specification)

These are the `user_inputs` that appear in the Sunstone deployment form.

### Required Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ONEAPP_NEMOCLAW_API_KEY` | password | (none) | NVIDIA API key from build.nvidia.com. Required for inference. Never stored in image. |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ONEAPP_NEMOCLAW_MODEL` | list | `nemotron-3-super-120b` | Nemotron model to use. Options: `nemotron-3-super-120b`, `nemotron-ultra-253b`, `nemotron-super-49b`, `nemotron-3-nano-30b` |
| `ONEAPP_NEMOCLAW_SANDBOX_NAME` | text | `nemoclaw` | Name for the OpenShell sandbox instance (RFC 1123: lowercase alphanumeric and hyphens) |
| `ONEAPP_NEMOCLAW_SECURITY_LEVEL` | list | `strict` | Security posture: `strict` (NVIDIA endpoints only), `moderate` (adds common dev presets), `permissive` (broader egress) |
| `ONEAPP_NEMOCLAW_EGRESS_MODE` | list | `nvidia-only` | Network egress policy: `nvidia-only`, `development`, `custom` |
| `ONEAPP_NEMOCLAW_POLICY_PRESETS` | text | (none) | Comma-separated policy presets to apply: discord, docker, huggingface, jira, npm, pypi, slack, telegram |
| `ONEAPP_NEMOCLAW_GPU_MEM_UTIL` | text | `0.9` | GPU memory utilization fraction (0.0-1.0) |

### Template PCI Configuration (for GPU passthrough)

```
PCI = [
  CLASS = "0300",
  DEVICE = "",
  VENDOR = "10de"
]
```

This matches any NVIDIA GPU (vendor 10de). Specific GPU selection happens at instantiation in Sunstone. The appliance template should include this PCI attribute with NVIDIA vendor filter, UEFI firmware, q35 machine type, and host-passthrough CPU model for optimal GPU performance.

## Feature Dependencies

```
Docker + NVIDIA Container Toolkit (pre-installed)
    |
    +---> NemoClaw Installation
              |
              +---> Sandbox Creation (requires API key)
              |         |
              |         +---> Security Policy Application (requires security level)
              |         |         |
              |         |         +---> Policy Preset Loading (optional, requires presets list)
              |         |
              |         +---> Model Configuration (requires model selection)
              |         |
              |         +---> Egress Mode Configuration (requires egress mode)
              |
              +---> Health Validation
                        |
                        +---> MOTD Generation (requires health status)
                        |
                        +---> REPORT_READY (requires health validation pass)

GPU Detection (independent)
    |
    +---> GPU Present: Full setup with nvidia-smi validation
    +---> GPU Absent: Skip GPU init, warn user, remote-only mode
```

### Dependency Notes

- **Sandbox Creation requires API Key:** NemoClaw's `onboard` wizard needs NVIDIA_API_KEY to register the inference provider. Without it, no sandbox can be created.
- **Security Level requires Sandbox:** Policy is applied to an existing sandbox. Must create first, then configure.
- **Policy Presets enhance Security Level:** Presets add to the base policy. They layer on top of the security level baseline.
- **Health Validation requires all above:** Can only validate after Docker, NVIDIA toolkit, NemoClaw sandbox, and inference are all configured.
- **GPU Detection is independent:** Must run early in `service_configure` to decide the setup path before NemoClaw installation proceeds.
- **MOTD depends on Health Validation:** Login banner content requires knowing the final system state.
- **Egress Mode and Security Level overlap:** If both are set, egress mode should take precedence over security level's default egress rules. Document this clearly.

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed for a successful marketplace PR.

- [ ] **Packer build producing qcow2** - Without a bootable image, nothing else matters
- [ ] **Appliance lifecycle script** (`service_install`/`service_configure`/`service_bootstrap`) - Required by marketplace conventions
- [ ] **Docker + NVIDIA Container Toolkit pre-installed** - Runtime dependency for NemoClaw
- [ ] **ONEAPP_NEMOCLAW_API_KEY contextualization** - Users must be able to provide their API key via Sunstone
- [ ] **ONEAPP_NEMOCLAW_MODEL selection** - Match vLLM's pattern of model selection at deploy time
- [ ] **GPU passthrough template with PCI config** - Core value proposition of the appliance
- [ ] **GPU-present detection with fallback** - Prevents confusing failures when GPU not assigned
- [ ] **NemoClaw sandbox auto-start on boot** - Appliance must be functional after first boot without SSH
- [ ] **Basic health checks** - Docker, nvidia-smi, sandbox status verification
- [ ] **Marketplace YAML metadata** - Required for PR acceptance
- [ ] **README with quick start** - Required for PR acceptance
- [ ] **SSH key-based access** - Standard security expectation
- [ ] **Basic MOTD with status** - Minimal situational awareness on login

### Add After Validation (v1.x)

Features to add once core appliance is accepted and working.

- [ ] **ONEAPP_NEMOCLAW_SECURITY_LEVEL parameter** - Add once base policy application is proven stable
- [ ] **ONEAPP_NEMOCLAW_EGRESS_MODE parameter** - Add once security level works
- [ ] **ONEAPP_NEMOCLAW_POLICY_PRESETS parameter** - Add once egress mode works
- [ ] **REPORT_READY OneGate integration** - Enable OneFlow compatibility
- [ ] **In-VM help command** (`nemoclaw-help`) - Polish feature after core works
- [ ] **Rich MOTD with full status** - Enhance after basic MOTD is stable
- [ ] **ONEAPP_NEMOCLAW_GPU_MEM_UTIL parameter** - Optimization feature, not needed for launch

### Future Consideration (v2+)

Features to defer until appliance is proven and NemoClaw matures past alpha.

- [ ] **OneFlow service template** - Multi-VM orchestration after v1 validates single VM
- [ ] **Local inference option** - When NemoClaw's local inference exits experimental
- [ ] **Multiple sandbox support** - Running multiple agent instances in one VM
- [ ] **Telegram bridge auto-config** - `nemoclaw start` with TELEGRAM_BOT_TOKEN contextualization
- [ ] **Cloudflared tunnel auto-config** - Remote access without VPN

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Appliance lifecycle script | HIGH | MEDIUM | P1 |
| API key contextualization | HIGH | LOW | P1 |
| Docker + NVIDIA toolkit pre-installed | HIGH | MEDIUM | P1 |
| GPU passthrough template | HIGH | LOW | P1 |
| NemoClaw auto-start on boot | HIGH | MEDIUM | P1 |
| Model selection parameter | MEDIUM | LOW | P1 |
| GPU detection with fallback | MEDIUM | LOW | P1 |
| Basic health checks | MEDIUM | MEDIUM | P1 |
| Marketplace YAML metadata | HIGH | LOW | P1 |
| README quick start | HIGH | LOW | P1 |
| Basic MOTD | MEDIUM | LOW | P1 |
| Security level parameter | MEDIUM | MEDIUM | P2 |
| Egress mode parameter | MEDIUM | MEDIUM | P2 |
| Policy presets parameter | LOW | LOW | P2 |
| REPORT_READY integration | LOW | LOW | P2 |
| In-VM help command | LOW | LOW | P2 |
| Rich MOTD | LOW | LOW | P2 |
| GPU memory utilization | LOW | LOW | P2 |
| OneFlow service template | MEDIUM | HIGH | P3 |
| Local inference | MEDIUM | HIGH | P3 |
| Telegram bridge | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for marketplace PR submission
- P2: Should have, add in subsequent versions
- P3: Nice to have, future consideration after NemoClaw matures

## Competitor Feature Analysis

| Feature | vLLM Appliance (Official) | DigitalOcean 1-Click NemoClaw | NemoClaw Appliance (Ours) |
|---------|---------------------------|-------------------------------|---------------------------|
| GPU passthrough | PCI device assignment in template | Droplet GPU selection | PCI device assignment with auto-detection and fallback |
| Model selection | `ONEAPP_VLLM_MODEL_ID` (any HF model) | Manual post-deploy via `nemoclaw onboard` | `ONEAPP_NEMOCLAW_MODEL` (4 Nemotron models via CONTEXT) |
| API key handling | `ONEAPP_VLLM_MODEL_TOKEN` (HF token) | Manual SSH setup | `ONEAPP_NEMOCLAW_API_KEY` via CONTEXT (never stored in image) |
| Security policies | None (vLLM has no sandbox isolation) | Manual policy configuration | Security level and egress mode via CONTEXT parameters |
| Network isolation | None | Manual OpenShell setup | Deny-by-default with configurable policy presets |
| Health checks | Basic service status | Unknown | Docker + GPU + sandbox + inference chain validation |
| Web interface | `ONEAPP_VLLM_API_WEB` (chat UI) | None | None (TUI via `openshell term` instead) |
| First-boot experience | Auto-configure, model download, serve | Manual install + wizard | Auto-configure sandbox, apply policies, validate health |
| Monitoring | Service logs | OpenShell TUI | OpenShell TUI + MOTD status |
| GPU memory control | `ONEAPP_VLLM_GPU_MEMORY_UTILIZATION` | None | `ONEAPP_NEMOCLAW_GPU_MEM_UTIL` (v1.x) |
| Quantization | `ONEAPP_VLLM_MODEL_QUANTIZATION` | N/A | N/A (remote inference, no local model) |
| Sleep mode | `ONEAPP_VLLM_SLEEP_MODE` | N/A | N/A |
| Target audience | ML engineers serving LLMs | Developers exploring AI agents | Cloud operators deploying secure AI agents |

### Key Competitive Insights

1. **vLLM is about serving models; NemoClaw is about securing agents.** Different value propositions, complementary not competing. Our appliance fills a gap the vLLM appliance does not address: sandboxed, policy-governed AI agent execution.

2. **DigitalOcean's 1-Click requires manual setup after deployment.** Our contextualization-driven approach is strictly superior for the OpenNebula ecosystem - zero SSH required for basic operation.

3. **No existing marketplace appliance combines GPU passthrough with security policy management.** This is our differentiator. Security-conscious operators have no current option.

4. **The vLLM appliance pattern is the gold standard to follow.** Its `ONEAPP_VLLM_*` parameter naming, `config.rb` structure, and Packer build pattern should be our template. Consistency with existing AI appliance conventions reduces user friction.

## Sources

- [OpenNebula Marketplace Appliances Overview (v6.10)](https://docs.opennebula.io/6.10/marketplace/appliances/overview.html)
- [OpenNebula vLLM AI Appliance (v7.0)](https://docs.opennebula.io/7.0/product/integration_references/marketplace_appliances/vllm/)
- [OpenNebula NVIDIA GPU Passthrough (v7.0)](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/nvidia_gpu_passthrough/)
- [OpenNebula one-apps vLLM config.rb](https://github.com/OpenNebula/one-apps/tree/master/appliances/Vllm)
- [OpenNebula marketplace-community repo](https://github.com/OpenNebula/marketplace-community)
- [OpenNebula marketplace README (YAML format spec)](https://github.com/OpenNebula/marketplace/blob/master/README.md)
- [RabbitMQ community appliance (contextualization pattern)](https://github.com/OpenNebula/marketplace-community/tree/master/appliances/rabbitmq)
- [NVIDIA NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw)
- [NVIDIA NemoClaw Developer Guide - Overview](https://docs.nvidia.com/nemoclaw/latest/about/overview.html)
- [NVIDIA NemoClaw Developer Guide - Commands](https://docs.nvidia.com/nemoclaw/latest/reference/commands.html)
- [NVIDIA NemoClaw Developer Guide - Inference Profiles](https://docs.nvidia.com/nemoclaw/latest/reference/inference-profiles.html)
- [NVIDIA NemoClaw Developer Guide - Network Policy](https://docs.nvidia.com/nemoclaw/latest/network-policy/customize-network-policy.html)
- [NVIDIA NemoClaw Developer Guide - Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html)
- [NVIDIA NemoClaw Developer Guide - Remote GPU Deploy](https://docs.nvidia.com/nemoclaw/latest/deployment/deploy-to-remote-gpu.html)
- [NVIDIA OpenShell Blog Post](https://blogs.nvidia.com/blog/secure-autonomous-ai-agents-openshell/)
- [NVIDIA NemoClaw Announcement](https://nvidianews.nvidia.com/news/nvidia-announces-nemoclaw)
- [OpenNebula AI Factories Blog](https://opennebula.io/blog/product/ai-factories-llm/)
- [OpenNebula GPU/vGPU Blog](https://opennebula.io/blog/product/gpu-and-vgpu-in-opennebula/)
- [NemoClaw Deployment Guide (openclawapi.org)](https://openclawapi.org/en/blog/2026-03-19-nemoclaw-deployment-guide)
- [OpenNebula 2025 Year in Review](https://opennebula.io/blog/newsletter/2025-year-in-review/)
- [DigitalOcean NemoClaw 1-Click](https://www.digitalocean.com/community/tutorials/how-to-set-up-nemoclaw)

---
*Feature research for: NemoClaw OpenNebula Marketplace Appliance*
*Researched: 2026-03-24*

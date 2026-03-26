# NemoClaw OpenNebula Marketplace Appliance

OpenNebula Community Marketplace appliance for [NVIDIA NemoClaw](https://www.nvidia.com/en-us/ai/nemoclaw/), the open-source AI agent security stack built on OpenClaw.

Deploys a ready-to-use VM image with NemoClaw CLI, Docker, NVIDIA GPU drivers, and Container Toolkit pre-installed. Users SSH in, run `nemoclaw onboard`, and get sandboxed AI agent execution with deny-by-default network policies.

## Marketplace PR

**PR**: [OpenNebula/marketplace-community#118](https://github.com/OpenNebula/marketplace-community/pull/118)

## What's Included

| Component | Version |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| Docker Engine CE | Latest stable |
| NVIDIA Driver | 550-server |
| NVIDIA Container Toolkit | Latest stable |
| Node.js | 22.x LTS |
| NemoClaw CLI | 0.1.0 (alpha) |

## Quick Start

1. Deploy the appliance from the [OpenNebula Community Marketplace](https://community-marketplace.opennebula.io/)
2. SSH in: `ssh root@<VM_IP>` (password: `opennebula`)
3. Get an API key at [build.nvidia.com](https://build.nvidia.com)
4. Run: `nemoclaw onboard`
5. Connect: `nemoclaw <sandbox-name> connect`

## Building the Image

Requires a KVM-capable host with Packer 1.10+, QEMU, and guestfs-tools.

```bash
# Clone marketplace-community with one-apps submodule
git clone --recurse-submodules https://github.com/OpenNebula/marketplace-community.git
cd marketplace-community/apps-code/community-apps

# Copy appliance and Packer files from this repo
cp -r /path/to/NemoClaw/appliances/nemoclaw ../../appliances/
cp -r /path/to/NemoClaw/apps-code/community-apps/packer/nemoclaw packer/

# Build
packer build packer/nemoclaw/
```

Output: `output/nemoclaw` (qcow2, ~7 GiB compressed, 40 GiB virtual)

## Repository Structure

```
appliances/nemoclaw/
  appliance.sh              # Service lifecycle script
  *.yaml                    # Marketplace metadata, build config, test config
  tests/                    # RSpec certification tests
  README.md                 # Appliance documentation

apps-code/community-apps/
  packer/nemoclaw/          # Packer build pipeline
  Makefile.config           # Build system registration

logos/
  nemoclaw.png              # Appliance logo
```

## License

Appliance packaging: [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0)

NemoClaw itself is licensed under [Apache 2.0](https://github.com/NVIDIA/NemoClaw/blob/main/LICENSE) by NVIDIA.

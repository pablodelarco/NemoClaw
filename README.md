# NemoClaw OpenNebula Marketplace Appliance

OpenNebula Community Marketplace appliance for [NVIDIA NemoClaw](https://www.nvidia.com/en-us/ai/nemoclaw/), the open-source AI agent security stack built on OpenClaw.

Deploys a ready-to-use VM with NemoClaw, Docker, NVIDIA GPU drivers, and Container Toolkit pre-installed. SSH in, run `nemoclaw onboard`, and get sandboxed AI agent execution with deny-by-default network policies.

## Download

Available at the [OpenNebula Community Marketplace](https://community-marketplace.opennebula.io/).

## Quick Start

1. Import the appliance from the Community Marketplace in OpenNebula Sunstone
2. Create a VM template from the imported image
3. Instantiate the VM (minimum 8 GiB RAM, 2 vCPU, 40 GiB disk)
4. SSH in: `ssh root@<VM_IP>` (password: `opennebula`)
5. Get an API key at [build.nvidia.com](https://build.nvidia.com)
6. Run: `nemoclaw onboard`
7. Follow the interactive setup wizard
8. Connect to your sandbox: `nemoclaw <sandbox-name> connect`

## What's Included

| Component | Version |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| Docker Engine CE | Latest stable |
| NVIDIA Driver | 550-server |
| NVIDIA Container Toolkit | Latest stable |
| Node.js | 22.x LTS |
| NemoClaw CLI | 0.1.0 (alpha) |

## GPU Passthrough (Optional)

NemoClaw works without a GPU using cloud inference via NVIDIA Endpoints. For local GPU inference, configure PCI device assignment on the OpenNebula host:

1. Enable IOMMU in BIOS and kernel (`intel_iommu=on` or `amd_iommu=on`)
2. Assign an NVIDIA GPU to the VM via Sunstone (PCI vendor `10de`)
3. The appliance auto-detects the GPU and configures the container runtime

See the [OpenNebula GPU Passthrough docs](https://docs.opennebula.io/7.0/product/cluster_configuration/hosts_and_clusters/nvidia_gpu_passthrough/) for details.

## System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 vCPU | 4+ vCPU |
| RAM | 8 GiB | 16 GiB |
| Disk | 40 GiB | 40 GiB |
| GPU | Optional | NVIDIA GPU with passthrough |

## Documentation

- [NVIDIA NemoClaw Developer Guide](https://docs.nvidia.com/nemoclaw/latest/)
- [NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw)
- [OpenNebula Community Marketplace](https://community-marketplace.opennebula.io/)

## License

Appliance packaging: [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0)

NemoClaw is licensed under [Apache 2.0](https://github.com/NVIDIA/NemoClaw/blob/main/LICENSE) by NVIDIA.

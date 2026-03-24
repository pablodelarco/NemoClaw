# --------------------------------------------------------------------------- #
# NemoClaw OpenNebula Marketplace Appliance - Packer Build Configuration
# --------------------------------------------------------------------------- #
# Builds a qcow2 image from Ubuntu 24.04 base with NemoClaw pre-installed.
# Follows the one-apps/Prowler build pattern exactly.
# --------------------------------------------------------------------------- #

# =========================================================================== #
# Build 1: Context ISO Generation
# =========================================================================== #
# Generates a context ISO that provides SSH credentials and network config
# for the Packer build VM to boot and accept SSH connections.

build {
  sources = ["source.null.context"]

  provisioner "shell-local" {
    inline = [
      "mkdir -p ${var.input_dir}",
      "${path.root}/gen_context > context.sh"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "mkisofs -o '${var.input_dir}/context.iso' -V CONTEXT -J -R context.sh"
    ]
  }
}

# =========================================================================== #
# Build 2: QEMU VM Build
# =========================================================================== #
# Boots the Ubuntu 24.04 base image, provisions NemoClaw via the appliance
# lifecycle script, and produces a clean qcow2 image.

source "qemu" "nemoclaw" {
  iso_url          = "${var.input_dir}/ubuntu2404.qcow2"
  iso_checksum     = "none"
  disk_image       = true
  disk_size        = "20480"
  memory           = 8192
  cpus             = 2
  accelerator      = "kvm"
  headless         = var.headless
  format           = "qcow2"
  disk_compression = true
  net_device       = "virtio-net"
  disk_interface   = "virtio"

  qemuargs = [
    ["-cdrom", "${var.input_dir}/context.iso"]
  ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "20m"
  shutdown_command  = "shutdown -P now"
  output_directory = "${var.output_dir}"
  vm_name          = "${var.appliance_name}.qcow2"
}

source "null" "context" {
  communicator = "none"
}

build {
  sources = ["source.qemu.nemoclaw"]

  # 1. SSH hardening
  provisioner "shell" {
    scripts = ["${path.root}/81-configure-ssh.sh"]
  }

  # 2. Create one-appliance directory structure
  provisioner "shell" {
    inline = [
      "mkdir -p /etc/one-appliance/service.d",
      "chmod 0750 /etc/one-appliance"
    ]
  }

  # 3. Copy context hooks from one-apps framework
  provisioner "file" {
    sources     = ["one-apps/appliances/scripts/net-90-service-appliance", "one-apps/appliances/scripts/net-99-report-ready"]
    destination = "/etc/one-context.d/"
  }

  # 4. Copy framework libraries
  provisioner "file" {
    sources     = ["one-apps/appliances/lib/common.sh", "one-apps/appliances/lib/functions.sh"]
    destination = "/etc/one-appliance/"
  }

  # 5. Copy service manager
  provisioner "file" {
    source      = "one-apps/appliances/scripts/service.sh"
    destination = "/etc/one-appliance/service"
  }

  # 6. Make service executable
  provisioner "shell" {
    inline = ["chmod 0755 /etc/one-appliance/service"]
  }

  # 7. Copy appliance.sh
  provisioner "file" {
    source      = "appliances/${var.appliance_name}/appliance.sh"
    destination = "/etc/one-appliance/service.d/appliance.sh"
  }

  # 8. Make appliance.sh executable
  provisioner "shell" {
    inline = ["chmod 0755 /etc/one-appliance/service.d/appliance.sh"]
  }

  # 9. Configure context
  provisioner "shell" {
    scripts = ["${path.root}/82-configure-context.sh"]
  }

  # 10. Run service install (triggers service_install from appliance.sh)
  provisioner "shell" {
    inline = ["/etc/one-appliance/service install"]
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
  }

  # Post-processor: virt-sysprep + virt-sparsify for clean distribution
  post-processor "shell-local" {
    execute_command = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "OUTPUT_DIR=${var.output_dir}",
      "APPLIANCE_NAME=${var.appliance_name}"
    ]
    scripts = ["one-apps/packer/postprocess.sh"]
  }
}

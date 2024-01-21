resource "xenorchestra_cloud_config" "ares1" {
  name = "ares1-cloudconfig"
  # Template the cloudinit if needed
  template = templatefile("arch-cloud.tftpl", {
    hostname = "ares1"
  })
}

resource "xenorchestra_vm" "ares1" {
  memory_max       = 17179869184
  cpus             = 4
  cloud_config     = xenorchestra_cloud_config.ares1.template
  name_label       = "ares1"
  name_description = "VM for Docker host machine"
  template         = data.xenorchestra_template.arch-dopti1.id
  exp_nested_hvm   = false
  auto_poweron     = true
  wait_for_ip      = true


  # Prefer to run the VM on the primary pool instance
  affinity_host = data.xenorchestra_pool.dopti1.master
  network {
    network_id  = xenorchestra_network.dopti1vlan15.id
    mac_address = "7a:fe:62:0a:44:08"
  }

  network {
    network_id  = data.xenorchestra_network.dopti1.id
    mac_address = "9a:a6:a0:90:79:90"
  }

  disk {
    sr_id      = data.xenorchestra_sr.dopti1.id
    name_label = "ares1"
    size       = 64424509440
  }

  tags = [
    "ares",
    "arch",
    "prod",
  ]
}

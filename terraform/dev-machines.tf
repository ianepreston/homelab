resource "xenorchestra_cloud_config" "d-mars" {
  name = "d-mars-cloudconfig"
  # Template the cloudinit if needed
  template = templatefile("arch-cloud.tftpl", {
    hostname = "d-mars"
  })
}

resource "xenorchestra_vm" "d-mars" {
  memory_max       = 4294967296
  cpus             = 2
  cloud_config     = xenorchestra_cloud_config.d-mars.template
  name_label       = "d-mars"
  name_description = "Dev VM for Docker host machine"
  template         = data.xenorchestra_template.arch-dhpp3.id
  exp_nested_hvm   = false
  auto_poweron     = true
  wait_for_ip      = true


  # Prefer to run the VM on the primary pool instance
  affinity_host = data.xenorchestra_pool.dhpp3.master
  network {
    network_id = xenorchestra_network.dhpp3vlan40.id
  }

  disk {
    sr_id      = data.xenorchestra_sr.dhpp3.id
    name_label = "d-mars"
    size       = 21474836480
  }

  tags = [
    "dev",
    "arch",
    "d-mars",
  ]
}

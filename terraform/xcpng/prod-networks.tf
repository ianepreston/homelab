########################################################################################
# DOPTI-1
########################################################################################
resource "xenorchestra_network" "dopti1vlan15" {
  pool_id           = data.xenorchestra_pool.dopti1.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "dopti1vlan40" {
  pool_id           = data.xenorchestra_pool.dopti1.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# HPE-1
########################################################################################
resource "xenorchestra_network" "hpe1vlan15" {
  pool_id           = data.xenorchestra_pool.hpe1.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "hpe1vlan40" {
  pool_id           = data.xenorchestra_pool.hpe1.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# HPP-1
########################################################################################
resource "xenorchestra_network" "hpp1vlan15" {
  pool_id           = data.xenorchestra_pool.hpp1.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "hpp1vlan40" {
  pool_id           = data.xenorchestra_pool.hpp1.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# HPP-2
########################################################################################
resource "xenorchestra_network" "hpp2vlan15" {
  pool_id           = data.xenorchestra_pool.hpp2.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "hpp2vlan40" {
  pool_id           = data.xenorchestra_pool.hpp2.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

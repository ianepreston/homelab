########################################################################################
# D-HPP-1
########################################################################################
resource "xenorchestra_network" "dhpp1vlan15" {
  pool_id           = data.xenorchestra_pool.dhpp1.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "dhpp1vlan40" {
  pool_id           = data.xenorchestra_pool.dhpp1.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# D-HPP-2
########################################################################################
resource "xenorchestra_network" "dhpp2vlan15" {
  pool_id           = data.xenorchestra_pool.dhpp2.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "dhpp2vlan40" {
  pool_id           = data.xenorchestra_pool.dhpp2.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# D-HPP-3
########################################################################################
resource "xenorchestra_network" "dhpp3vlan15" {
  pool_id           = data.xenorchestra_pool.dhpp3.id
  source_pif_device = "eth0"
  name_label        = "vlan15"
  name_description  = "VLAN 15 - Trust"
  vlan              = 15
}

resource "xenorchestra_network" "dhpp3vlan40" {
  pool_id           = data.xenorchestra_pool.dhpp3.id
  source_pif_device = "eth0"
  name_label        = "vlan40"
  name_description  = "VLAN 40 - Trust"
  vlan              = 40
}

########################################################################################
# D-HPP-1
########################################################################################

data "xenorchestra_pool" "dhpp1" {
  name_label = "d-hpp-1"
}

data "xenorchestra_sr" "dhpp1" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.dhpp1.id
}

data "xenorchestra_network" "dhpp1" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.dhpp1.id
}

data "xenorchestra_template" "arch-dhpp1" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.dhpp1.id
}

########################################################################################
# D-HPP-2
########################################################################################

data "xenorchestra_pool" "dhpp2" {
  name_label = "d-hpp-2"
}

data "xenorchestra_sr" "dhpp2" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.dhpp2.id
}
data "xenorchestra_network" "dhpp2" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.dhpp2.id
}

data "xenorchestra_template" "arch-dhpp2" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.dhpp2.id
}

########################################################################################
# D-HPP-3
########################################################################################

data "xenorchestra_pool" "dhpp3" {
  name_label = "d-hpp-3"
}

data "xenorchestra_sr" "dhpp3" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.dhpp3.id
}

data "xenorchestra_network" "dhpp3" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.dhpp3.id
}

data "xenorchestra_template" "arch-dhpp3" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.dhpp3.id
}

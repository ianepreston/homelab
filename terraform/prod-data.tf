########################################################################################
# DOPTI-1
########################################################################################

data "xenorchestra_pool" "dopti1" {
  name_label = "dopti-1"
}

data "xenorchestra_sr" "dopti1" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.dopti1.id
}

data "xenorchestra_network" "dopti1" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.dopti1.id
}

data "xenorchestra_template" "arch-dopti1" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.dopti1.id
}

data "xenorchestra_template" "debian-dopti1" {
  name_label = "debian12base_template"
  pool_id    = data.xenorchestra_pool.dopti1.id
}

########################################################################################
# HPE-1
########################################################################################

data "xenorchestra_pool" "hpe1" {
  name_label = "hpe-1"
}

data "xenorchestra_sr" "hpe1" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.hpe1.id
}
data "xenorchestra_network" "hpe1" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.hpe1.id
}

data "xenorchestra_template" "arch-hpe1" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.hpe1.id
}

data "xenorchestra_template" "debian-hpe1" {
  name_label = "debian12base_template"
  pool_id    = data.xenorchestra_pool.hpe1.id
}

########################################################################################
# HPP-1
########################################################################################

data "xenorchestra_pool" "hpp1" {
  name_label = "hpp-1"
}

data "xenorchestra_sr" "hpp1" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.hpp1.id
}

data "xenorchestra_network" "hpp1" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.hpp1.id
}

data "xenorchestra_template" "arch-hpp1" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.hpp1.id
}

data "xenorchestra_template" "debian-hpp1" {
  name_label = "debian12base_template"
  pool_id    = data.xenorchestra_pool.hpp1.id
}


########################################################################################
# HPP-2
########################################################################################

data "xenorchestra_pool" "hpp2" {
  name_label = "hpp-2"
}

data "xenorchestra_sr" "hpp2" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.hpp2.id
}

data "xenorchestra_network" "hpp2" {
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.hpp2.id
}

data "xenorchestra_template" "arch-hpp2" {
  name_label = "archbase_template"
  pool_id    = data.xenorchestra_pool.hpp2.id
}

data "xenorchestra_template" "debian-hpp2" {
  name_label = "debian12base_template"
  pool_id    = data.xenorchestra_pool.hpp2.id
}


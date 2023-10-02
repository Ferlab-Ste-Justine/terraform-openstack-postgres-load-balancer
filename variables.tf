variable "name" {
  description = "Name to give to the vm."
  type        = string
}

variable "network_port" {
  description = "Network port to assign to the node. Should be of type openstack_networking_port_v2"
  type        = any
}

variable "server_group" {
  description = "Server group to assign to the node. Should be of type openstack_compute_servergroup_v2"
  type        = any
}

variable "image_source" {
  description = "Source of the vm's image"
  type = object({
    image_id = string
    volume_id = string
  })
}

variable "flavor_id" {
  description = "ID of the VM flavor"
  type = string
}

variable "keypair_name" {
  description = "Name of the keypair that will be used by admins to ssh to the node"
  type = string
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0,
      limit = 0
    }
  }
}

variable "haproxy" {
  description = "Haproxy configuration parameters"
  sensitive   = true
  type        = object({
    postgres_nodes_max_count   = number
    postgres_nameserver_ips    = list(string)
    postgres_domain            = string
    patroni_client             = object({
      ca_certificate     = string
      client_key         = string
      client_certificate = string
    })
    timeouts                   = object({
      connect = string
      check   = string
      idle    = string
    })
  })
}

variable "fluentd" {
  description = "Fluentd configurations"
  sensitive   = true
  type = object({
    enabled = bool,
    load_balancer_tag = string,
    node_exporter_tag = string,
    forward = object({
      domain = string,
      port = number,
      hostname = string,
      shared_key = string,
      ca_cert = string,
    }),
    buffer = object({
      customized = bool,
      custom_value = string,
    })
  })
  default = {
    enabled = false
    load_balancer_tag = ""
    node_exporter_tag = ""
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
    buffer = {
      customized = false
      custom_value = ""
    }
  }
}

variable "container_registry" {
  description = "Parameters for the container registry"
  sensitive   = true
  type        = object({
    url      = string,
    username = string,
    password = string
  })
  default = {
    url      = ""
    username = ""
    password = ""
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type = bool
  default = true
}
locals {
  block_devices = var.image_source.volume_id != "" ? [{
    uuid                  = var.image_source.volume_id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }] : []
}

module "postgres_load_balancer_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//postgres-load-balancer?ref=v0.37.2"
  install_dependencies = var.install_dependencies
  haproxy = {
    postgres_nodes_max_count   = var.haproxy.postgres_nodes_max_count
    postgres_nameserver_ips    = var.haproxy.postgres_nameserver_ips
    postgres_domain            = var.haproxy.postgres_domain
    patroni_api                = {
      ca_certificate     = var.haproxy.patroni_client.ca_certificate
      client_certificate = var.haproxy.patroni_client.client_certificate
      client_key         = var.haproxy.patroni_client.client_key
    }
    timeouts                   = var.haproxy.timeouts
  }
  container_registry = var.container_registry
  fluentd = {
    port = 28080
    tag = var.fluentd.enabled ? var.fluentd.load_balancer_tag : ""
  }
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.14.2"
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.14.2"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

module "fluentd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluentd?ref=v0.14.2"
  install_dependencies = var.install_dependencies
  fluentd = {
    docker_services = [
      {
        tag                = var.fluentd.load_balancer_tag
        service            = "load-balancer"
        local_forward_port = 28080
      }
    ]
    systemd_services = [
      {
        tag     = var.fluentd.node_exporter_tag
        service = "node-exporter"
      }
    ]
    forward = var.fluentd.forward,
    buffer = var.fluentd.buffer
  }
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = var.name
            install_dependencies = var.install_dependencies
          }
        )
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      },
      {
        filename     = "postgres_load_balancer.cfg"
        content_type = "text/cloud-config"
        content      = module.postgres_load_balancer_configs.configuration
      },
    ],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    var.fluentd.enabled ? [{
      filename     = "fluentd.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentd_configs.configuration
    }] : []
  )
}

data "cloudinit_config" "user_data" {
  gzip = true
  base64_encode = true
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "openstack_compute_instance_v2" "postgres_load_balancer" {
  name            = var.name
  image_id        = var.image_source.image_id != "" ? var.image_source.image_id : null
  flavor_id       = var.flavor_id
  key_pair        = var.keypair_name
  user_data = data.cloudinit_config.user_data.rendered

  network {
    port = var.network_port.id
  }

  dynamic "block_device" {
    for_each = local.block_devices
    content {
      uuid                  = block_device.value["uuid"]
      source_type           = block_device.value["source_type"]
      boot_index            = block_device.value["boot_index"]
      destination_type      = block_device.value["destination_type"]
      delete_on_termination = block_device.value["delete_on_termination"]
    }
  }

  scheduler_hints {
    group = var.server_group.id
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}
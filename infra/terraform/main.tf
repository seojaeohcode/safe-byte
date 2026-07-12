locals {
  name           = var.project_name
  login_key_name = var.create_login_key ? ncloud_login_key.generated[0].key_name : var.login_key_name
}

resource "ncloud_login_key" "generated" {
  count    = var.create_login_key ? 1 : 0
  key_name = var.login_key_name
}

data "ncloud_server_image_numbers" "ubuntu" {
  server_image_name = var.server_image_name

  filter {
    name   = "hypervisor_type"
    values = ["KVM"]
  }
}

data "ncloud_server_specs" "app" {
  filter {
    name   = "server_spec_code"
    values = [var.server_spec_code]
  }
}

resource "ncloud_vpc" "main" {
  name            = "${local.name}-vpc"
  ipv4_cidr_block = var.vpc_cidr
}

resource "ncloud_subnet" "public" {
  name           = "${local.name}-public-kr2"
  vpc_no         = ncloud_vpc.main.id
  subnet         = var.public_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_vpc.main.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "GEN"
}

resource "ncloud_access_control_group" "app" {
  name        = "${local.name}-app-acg"
  description = "Safe-Byte web/API ingress"
  vpc_no      = ncloud_vpc.main.id
}

resource "ncloud_access_control_group_rule" "app" {
  access_control_group_no = ncloud_access_control_group.app.id

  inbound {
    protocol    = "TCP"
    ip_block    = var.ssh_allowed_cidr
    port_range  = "22"
    description = "SSH for deploy user"
  }

  inbound {
    protocol    = "TCP"
    ip_block    = var.web_allowed_cidr
    port_range  = "80"
    description = "HTTP via nginx from trusted client CIDR"
  }

  outbound {
    protocol    = "TCP"
    ip_block    = "0.0.0.0/0"
    port_range  = "80"
    description = "Outbound HTTP package access"
  }

  outbound {
    protocol    = "TCP"
    ip_block    = "0.0.0.0/0"
    port_range  = "443"
    description = "Outbound HTTPS API/package access"
  }

  outbound {
    protocol    = "UDP"
    ip_block    = "0.0.0.0/0"
    port_range  = "53"
    description = "Outbound DNS"
  }

  outbound {
    protocol    = "TCP"
    ip_block    = "0.0.0.0/0"
    port_range  = "53"
    description = "Outbound DNS over TCP fallback"
  }
}

resource "ncloud_network_interface" "app" {
  name                  = "${local.name}-app-nic"
  subnet_no             = ncloud_subnet.public.id
  access_control_groups = [ncloud_access_control_group.app.id]
}

resource "ncloud_init_script" "docker" {
  name = "${local.name}-docker-bootstrap"
  content = templatefile("${path.module}/scripts/bootstrap.sh.tpl", {
    deploy_user          = var.deploy_user
    admin_ssh_public_key = var.admin_ssh_public_key
    app_dir              = var.app_dir
    ssh_allowed_cidr     = var.ssh_allowed_cidr
    web_allowed_cidr     = var.web_allowed_cidr
  })

  lifecycle {
    ignore_changes = [content]
  }
}

resource "ncloud_server" "app" {
  name                 = "${local.name}-app"
  subnet_no            = ncloud_subnet.public.id
  zone                 = var.zone
  login_key_name       = local.login_key_name
  init_script_no       = ncloud_init_script.docker.id
  fee_system_type_code = var.fee_system_type_code
  server_image_number = (
    data.ncloud_server_image_numbers.ubuntu.image_number_list[0].server_image_number
  )
  server_spec_code = data.ncloud_server_specs.app.server_spec_list[0].server_spec_code

  network_interface {
    network_interface_no = ncloud_network_interface.app.id
    order                = 0
  }
}

resource "ncloud_public_ip" "app" {
  server_instance_no = ncloud_server.app.id
  description        = "Safe-Byte app public IP"
}

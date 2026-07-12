variable "ncloud_access_key" {
  description = "NAVER Cloud Platform access key. Prefer NCLOUD_ACCESS_KEY env var."
  type        = string
  default     = null
  sensitive   = true
}

variable "ncloud_secret_key" {
  description = "NAVER Cloud Platform secret key. Prefer NCLOUD_SECRET_KEY env var."
  type        = string
  default     = null
  sensitive   = true
}

variable "region" {
  description = "Ncloud region."
  type        = string
  default     = "KR"
}

variable "site" {
  description = "Ncloud site."
  type        = string
  default     = "public"
}

variable "zone" {
  description = "Ncloud zone."
  type        = string
  default     = "KR-2"
}

variable "project_name" {
  description = "Prefix used for Ncloud resource names."
  type        = string
  default     = "safebyte"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH. Use your public IP with /32 for real deployments."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "web_allowed_cidr" {
  description = "CIDR allowed to access the HTTP frontend/API. Use your public IP with /32 for locked demos."
  type        = string

  validation {
    condition     = can(cidrhost(var.web_allowed_cidr, 0))
    error_message = "web_allowed_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "admin_ssh_public_key" {
  description = "Public SSH key inserted into the deploy user's authorized_keys."
  type        = string
}

variable "login_key_name" {
  description = "Ncloud login key name. Created by Terraform when create_login_key is true."
  type        = string
  default     = "safebyte-tf-key"
}

variable "create_login_key" {
  description = "Create an Ncloud login key with Terraform. State will contain generated private key material."
  type        = bool
  default     = true
}

variable "server_image_name" {
  description = "Ncloud server image name."
  type        = string
  default     = "ubuntu-22.04-base"
}

variable "server_spec_code" {
  description = "Ncloud server spec code. mi1-g3 is the Micro-g3 low-cost 1 vCPU Gen3 KVM spec."
  type        = string
  default     = "mi1-g3"
}

variable "fee_system_type_code" {
  description = "Ncloud rate system code. Micro servers require flat rate (FXSUM); time plan is MTRAT."
  type        = string
  default     = "FXSUM"

  validation {
    condition     = contains(["FXSUM", "MTRAT"], var.fee_system_type_code)
    error_message = "fee_system_type_code must be FXSUM (flat rate) or MTRAT (time plan)."
  }
}

variable "deploy_user" {
  description = "Linux user created by the init script for SSH deployments."
  type        = string
  default     = "deploy"
}

variable "app_dir" {
  description = "Remote directory where the Docker Compose project will live."
  type        = string
  default     = "/opt/safebyte"
}

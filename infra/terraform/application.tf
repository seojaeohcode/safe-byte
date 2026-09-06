variable "deploy_application" {
  description = "Deploy the application after infrastructure is ready (Windows PowerShell deployment host)."
  type        = bool
  default     = false
}

variable "public_domain" {
  description = "DNS hostname pointed at this server; empty uses localhost through SSH for development."
  type        = string
  default     = ""
  validation {
    condition     = var.public_domain == "" || can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.public_domain))
    error_message = "Supply a DNS hostname without scheme, port or path."
  }
}

variable "ocr_daily_limit" {
  type    = number
  default = 50
  validation {
    condition     = var.ocr_daily_limit >= 0 && var.ocr_daily_limit <= 1000
    error_message = "OCR daily limit must be between 0 and 1000."
  }
}

variable "allow_paid_ocr" {
  description = "Allow CLOVA calls within the daily quota. Credentials remain outside Terraform state."
  type        = bool
  default     = false
}

variable "enable_docs" {
  description = "Serve Swagger UI at /docs on the deployed server. Publishes the full API surface."
  type        = bool
  default     = false
}

variable "deployment_ssh_key_path" {
  type    = string
  default = "~/.ssh/safebyte_ed25519"
}

locals {
  source_root = abspath("${path.module}/../..")
  application_files = concat(
    sort(tolist(fileset(local.source_root, "app/**/*.py"))),
    sort(tolist(fileset(local.source_root, "web/*.js"))),
    sort(tolist(fileset(local.source_root, "mobile/lib/**"))),
    sort(tolist(fileset(local.source_root, "mobile/web/**"))),
    sort(tolist(fileset(local.source_root, "mobile/assets/**"))),
    ["mobile/pubspec.yaml", "mobile/pubspec.lock", "scripts/mobile_check.py"],
    ["web/index.html", "web/styles.css"],
    ["requirements.txt", "Dockerfile", "docker-compose.yml", "docker-compose.tls.yml", "deploy/Caddyfile", "deploy/nginx.conf", "data/risk_rules.json", "infra/terraform/scripts/deploy_app.ps1", "scripts/deploy_application.py"]
  )
  application_revision = sha256(join("", [for name in local.application_files : filesha256("${local.source_root}/${name}")]))
}

resource "terraform_data" "application" {
  count            = var.deploy_application ? 1 : 0
  triggers_replace = [ncloud_server.app.id, local.application_revision, var.ocr_daily_limit, var.allow_paid_ocr, var.public_domain, var.enable_docs]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "& $env:SAFEBYTE_DEPLOY_SCRIPT -HostIp $env:SAFEBYTE_DEPLOY_HOST -SshKeyPath $env:SAFEBYTE_DEPLOY_KEY -OcrDailyLimit $env:SAFEBYTE_OCR_LIMIT -PublicDomain $env:SAFEBYTE_PUBLIC_DOMAIN -EnablePaidOcr:([bool]::Parse($env:SAFEBYTE_PAID_OCR)) -EnableDocs:([bool]::Parse($env:SAFEBYTE_ENABLE_DOCS))"
    environment = {
      SAFEBYTE_DEPLOY_SCRIPT = "${local.source_root}/infra/terraform/scripts/deploy_app.ps1"
      SAFEBYTE_DEPLOY_HOST   = ncloud_public_ip.app.public_ip
      SAFEBYTE_DEPLOY_KEY    = pathexpand(var.deployment_ssh_key_path)
      SAFEBYTE_OCR_LIMIT     = tostring(var.ocr_daily_limit)
      SAFEBYTE_PAID_OCR      = tostring(var.allow_paid_ocr)
      SAFEBYTE_PUBLIC_DOMAIN = var.public_domain
      SAFEBYTE_ENABLE_DOCS   = tostring(var.enable_docs)
    }
  }
}

output "ocr_connection" {
  description = "OCR credentials are read from the local runtime env file, never persisted in Terraform state."
  value = {
    provider          = "clova"
    daily_limit       = var.ocr_daily_limit
    allow_paid_ocr    = var.allow_paid_ocr
    credential_source = ".env (CLOVA_OCR_INVOKE_URL, CLOVA_OCR_SECRET_KEY)"
    domain_management = "Existing CLOVA OCR domain + API Gateway; not managed by the Ncloud Terraform provider"
  }
}

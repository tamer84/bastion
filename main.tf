# ========================================
# Initialization
# ========================================
terraform {
  // Declares where terraform stores the application state
  backend "s3" {
    encrypt        = "true"
    bucket         = "tango-terraform"
    key            = "resources/bastion/tfstate.tf"
    dynamodb_table = "terraform"
    region         = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "github" {
  token        = data.terraform_remote_state.account_resources.outputs.github_access_token
  base_url     = "https://github.com/tamer84"
}

provider "null" {}

provider "tls" {}

provider "template" {}

provider "local" {}

data "terraform_remote_state" "account_resources" {
  backend = "s3"
  config = {
    encrypt = "true"
    bucket  = "tango-terraform"
    key     = "account_resources/tfstate.tf"
    region  = "eu-central-1"
  }
  workspace = "default"
}

data "terraform_remote_state" "environment_resources" {
  backend = "s3"
  config = {
    encrypt = "true"
    bucket  = "tango-terraform"
    key     = "environment_resources/tfstate.tf"
    region  = "eu-central-1"
  }
  workspace = terraform.workspace
}

data "terraform_remote_state" "aggregator" {
  backend = "s3"
  config = {
    encrypt = "true"
    bucket  = "tango-terraform"
    key     = "resources/aggregator/tfstate.tf"
    region  = "eu-central-1"
  }
  workspace = terraform.workspace
}

data "terraform_remote_state" "terraform_build_image_resources" {
  backend = "s3"
  config = {
    encrypt = "true"
    bucket  = "tango-terraform"
    key     = "resources/terraform-build-image/tfstate.tf"
    region  = "eu-central-1"
  }
  workspace = terraform.workspace
}

# ========================================
# Locals
# ========================================
locals {
  server_name                 = "bastion-public"
  server_url                  = "bastion.${terraform.workspace}.tamer84.eu"
  aws_region                  = "eu-central-1"
  bastion_security_group_name = "bastion_access-${terraform.workspace}"
  with_public_ip              = true
  generate_certificate         = true
  create_dns                  = true
  template_file                = "${path.module}/scripts/bastion.tpl"
  // Services needed t
  service_list = jsonencode([
    {
      "name" : "aggregator"
      "url" : "https://product-aggregator.dev.tamer84.com"
    }
  ])
  // Change the CICD branch here depending on the terraform workspace, if needed
  cicd_branch = contains(["dev", "test", "int"], terraform.workspace) ? "develop" : "main"
}

# ========================================
# Bastion definition
# ========================================

module "bastion-public" {
  source = "git::ssh://git@github.com/tamer84/infra.git//modules/ec2?ref=develop"

  ami               = var.default_ami
  amount            = 1
  availability_zone = local.aws_region
  instance_profile  = aws_iam_instance_profile.bastion_instance_profile.name
  instance_type     = var.instance_type
  security_groups = [
    aws_security_group.bastion_access.id
  ]
  server_name   = local.server_name
  server_url    = local.server_url
  subnet_id     = data.terraform_remote_state.environment_resources.outputs.public-subnet[0].id
  zone_id       = data.terraform_remote_state.account_resources.outputs.dns.zone_id
  template_file = local.template_file
  template_vars = {
    "secret_arn" : var.secret_arn,
    "nginx_port" : var.nginx_port,
    "region" : local.aws_region,
    "log_group" : "/ec2/bastion-${terraform.workspace}"
  }
  generate_certificate = local.generate_certificate
  create_alarms        = false
  local_output         = var.local_output
  create_dns           = true
  create_local_dns     = false
  create_ebs           = false
  with_public_ip       = true
}

resource "null_resource" "update_service_list" {
  depends_on = [module.bastion-public]

  triggers = {
    instance_id  = module.bastion-public.servers_id[0]
    service_list = local.service_list
  }
  provisioner "local-exec" {
    command = "${path.module}/scripts/update_service_list.sh ${module.bastion-public.servers_id[0]} '${local.service_list}'"
  }
}

output "service_list" {
  value = local.service_list
}
output "bastion_server_id" {
  value = module.bastion-public.servers_id[0]
}


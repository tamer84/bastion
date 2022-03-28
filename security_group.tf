// Strict network access
// Traffic allowed :
// ssh can be used only through Session Manager
// ngnix in
// dns/http(s) out
resource "aws_security_group" "bastion_access" {
  name = local.bastion_security_group_name

  //nginx
  ingress {
    from_port   = var.nginx_port
    to_port     = var.nginx_port
    protocol    = "tcp"
    cidr_blocks = flatten([var.nginx_white_list_ips, var.nginx_white_list_ips_private])
  }

  //SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = flatten([var.nginx_white_list_ips, var.nginx_white_list_ips_private])
  }

  //DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // http / https
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //SSH to our VPCs
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.31.0.0/16"]
  }


  vpc_id = data.terraform_remote_state.environment_resources.outputs.vpc.id

  tags = {
    Name        = local.bastion_security_group_name
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

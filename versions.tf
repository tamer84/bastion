terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.31"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.5.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
  }
  required_version = "1.0.5"
}

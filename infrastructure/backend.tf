terraform {
  backend "s3" {
    key          = "lab/foundation.tfstate"
    encrypt      = true
    use_lockfile = true

  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.28.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

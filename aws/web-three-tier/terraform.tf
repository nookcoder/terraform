provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      "Author" : "Hyeonuk Kim"
      "ManagedBy" : "Terraform"
    }
  }
}
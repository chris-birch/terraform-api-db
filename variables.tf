# These are inputs we need to define, these two are fairly common (on basically every stack ever)
variable "region" { }  # The aws region we want to be working with
variable "project" { }   # The name of this project, often used in naming of resources created also
# These are things we'll use in various places
locals {
  tags = {
    Terraform = "true"
    Project = "${var.project}"
  }
}
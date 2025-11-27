variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-west-2"
}

variable "project_name" {
  type        = string
  description = "Name prefix for all resources and Tailscale hostnames."
  default     = "rob-briggs"
}

variable "subnet_router_authkey" {
  type        = string
  description = "Tailscale auth key for the subnet router node (tskey-auth-...)."
  sensitive   = true
}

variable "ssh_node_authkey" {
  type        = string
  description = "Tailscale auth key for the SSH node."
  sensitive   = true
}
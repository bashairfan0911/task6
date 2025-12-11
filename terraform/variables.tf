variable "aws_region" {
  type        = string
  default     = "ap-south-1"
}
 
variable "instance_type" {
  type        = string
  default     = "t2.micro"
}
 
variable "key_name" {
  description = "EC2 key pair name for SSH"
  type        = string
}
 
variable "docker_image" {
  description = "ECR image URI for Strapi"
  type        = string
}
 
variable "strapi_port" {
  type        = number
  default     = 1337
}
 
variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for ECR authentication"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for ECR authentication"
  type        = string
  sensitive   = true
}

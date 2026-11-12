variable "project" {
  type    = string
  default = "cloudops"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "alert_email" {
  type        = string
  description = "Email that receives CloudWatch + budget alerts"
}
variable "monthly_budget_usd" {
  type    = number
  default = 20
}
variable "enable_nat" {
  type        = bool
  default     = false
  description = "NAT Gateway costs ~$32/month. Needed only for EKS private nodes."
}
variable "enable_eks" {
  type        = bool
  default     = false
  description = "Create an EKS cluster (paid). Use minikube for free local Kubernetes."
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "github_repo" {
  type        = string
  default     = ""
  description = "owner/repo for GitHub Actions OIDC role (leave empty to skip)"
}

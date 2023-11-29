variable "app_name" {
  description = "Application Name"
  type        = string
}
variable "ecs_role_arn" {
  description = "IAM Role for ECS"
  type        = string
}
variable "ecs_services" {
  type = map(object({
    image          = string
    cpu            = number
    memory         = number
    container_port = number
    host_port      = number
    desired_count  = number
    is_public      = bool
    protocol       = string
    auto_scaling = object({
      max_capacity     = number
      min_capacity     = number
      cpu_threshold    = number
      memory_threshold = number
    })
  }))
}
variable "internal_alb_dns" {
  description = "Internal ALB DNS name"
  type        = string
}
variable "private_subnet_ids" {
  description = "List of Private VPC Subnet IDs"
  type        = list(string)
}
variable "public_subnet_ids" {
  description = "List of Public VPC Subnet IDs"
  type        = list(string)
}
variable "security_group_ids" {
  description = "List of EC2 Security Group IDs"
  type        = list(string)
}
variable "target_group_arns" {
  description = "Map of ALB Target Group ARNs"
  type = map(object({
    arn       = string
  }))
}
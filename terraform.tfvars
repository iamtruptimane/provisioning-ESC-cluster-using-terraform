app_name = "lab"
ecs_role_arn = "arn:aws:iam::854014963917:role/lab-ecs-task-execution-role"
ecs_services = {
  frontend = {
    image          = "854014963917.dkr.ecr.us-west-2.amazonaws.com/frontend:1.0.0"
    cpu            = 256
    memory         = 512
    container_port = 8080
    host_port      = 8080
    desired_count  = 2
    is_public      = true
    protocol       = "HTTP"
    auto_scaling = {
      max_capacity    = 3
      min_capacity    = 2
      cpu_threshold    = 50
      memory_threshold = 50
    }
  }
  backend = {
    image          = "854014963917.dkr.ecr.us-west-2.amazonaws.com/backend:1.0.0"
    cpu            = 256
    memory         = 512
    container_port = 8080
    host_port      = 8080
    desired_count  = 2
    is_public      = false
    protocol       = "HTTP"
    auto_scaling = {
      max_capacity    = 3
      min_capacity    = 2
      cpu_threshold    = 75
      memory_threshold = 75
    }
  }
}
internal_alb_dns = "internal-lab-internal-1730317406.us-west-2.elb.amazonaws.com"
private_subnet_ids = [
  "subnet-0b77b31375dca62fc",
  "subnet-088624d93c16bfda4"
]
public_subnet_ids = [
  "subnet-02b9cd6d5616768ea",
  "subnet-0f0e7d58b636d60c5"
]
security_group_ids = [
  "sg-058cc63df792bab4b",
  "sg-084377daaf8d469e7"
]
target_group_arns = {
  backend = {
    arn = "arn:aws:elasticloadbalancing:us-west-2:854014963917:targetgroup/backend-tg/762c31c99de39e21"
  }
  frontend = {
    arn = "arn:aws:elasticloadbalancing:us-west-2:854014963917:targetgroup/frontend-tg/05ca77eb47b7932a"
  }
}
provider "aws" {
  region = "us-west-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.58.0"
    }
  }
  required_version = ">= 1.0"
}

# Data
data "aws_region" "current" {}

# Resources
resource "aws_ecs_cluster" "ecs_cluster" {
  name = lower("${var.app_name}-cluster")
}

# ECS Services
resource "aws_ecs_service" "service" {
  for_each = var.ecs_services
  name            = "${each.key}-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type     = "FARGATE"
  desired_count   = each.value.desired_count
  network_configuration {
    subnets          = each.value.is_public == true ? var.public_subnet_ids : var.private_subnet_ids
    assign_public_ip = each.value.is_public
    security_groups  = var.security_group_ids
  }
  load_balancer {
    target_group_arn = var.target_group_arns[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }
}
# ECS Task Definitions
resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each = var.ecs_services
  family                   = "${lower(var.app_name)}-${each.key}"
  execution_role_arn       = var.ecs_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = each.value.memory
  cpu                      = each.value.cpu
  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      cpu       = each.value.cpu
      memory    = each.value.memory
      essential = true
      environment = [
        { name = "INTERNAL_ALB", value = var.internal_alb_dns },
        { name = "SERVICE_HOST", value = var.internal_alb_dns },
        { name = "SERVER_SERVLET_CONTEXT_PATH", value = each.value.is_public == true ? "/" : "/${each.key}" },
        { name = "SERVICES", value = "backend" },
        { name = "SERVICE", value = each.key },
        { name = "SERVICE_NAME", value = each.key }
      ]
      portMappings = [
        {
          containerPort = each.value.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${lower(each.key)}-logs"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = var.app_name
        }
      }
    }
  ])
}
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs_cw_log_group" {
  for_each = toset(keys(var.ecs_services))
  name     = lower("${each.key}-logs")
}

# ECS Auto Scaling Configuration
resource "aws_appautoscaling_target" "service_autoscaling" {
  for_each = var.ecs_services
  max_capacity       = each.value.auto_scaling.max_capacity
  min_capacity       = each.value.auto_scaling.min_capacity
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policies
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  for_each = var.ecs_services
  name               = "${var.app_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = each.value.auto_scaling.memory_threshold
  }
}
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each = var.ecs_services
  name               = "${var.app_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = each.value.auto_scaling.cpu_threshold
  }
}
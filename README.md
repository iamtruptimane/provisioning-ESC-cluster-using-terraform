# Provosioning ESC-cluster using terraform

In this project, you will provision an Amazon ECS Cluster into an existing Amazon VPC.

## Project objectives:
* Define a Terraform module that deploys Amazon ECS resources
* Apply an Auto Scaling Group Policy to respond to ECS metrics
* Deploy an Amazon ECS Cluster into an existing Amazon VPC using Terraform

## Prerequisites
* Amazon Elastic Container Service
* Terraform


![environment before](https://github.com/iamtruptimane/provisioning-ESC-cluster-using-terraform/blob/main/img/env_before.png)

![environment after](https://github.com/iamtruptimane/provisioning-ESC-cluster-using-terraform/blob/main/img/env_after.png)

## Existing Infrastructure
The following resources you should deployed before starting this project and it will be referenced in your ECS Cluster:
* 1 Virtual Private Cloud
* 2 Public Subnets
* 2 Private Subnets
* Public-facing Application Load Balancer
* Internal-facing Application Load Balancer

## Terraform configuration file
### variables.tf and main.tf:
The variables.tf file defines the name, description, and expected data type for each variable referenced in the main.tf file.

### terraform.tfvars file:
This file will include the actual values for each variable. These values have been retrieved from the existing infrastructure.

### outputs.tf file:
The outputs.tf file defines the expected output values for the deployment. In this project, the CloudWatch Log Group names and the ECS Cluster ARN will be output after a successful deployment.

let's start the project!

## Step 1: Configure Terraform AWS Credentials
In this step, you will access your IDE and configure Terraform with the AWS provider and credentials.

1. open your IDE(example VScode) in your local machine.

2. At the top of the IDE, click Terminal, then click New Terminal:

3. Run the following commands to configure your AWS credentials:
```
aws configure set aws_access_key_id <Your_aws_access_key> &&
aws configure set aws_secret_access_key <Your_aws_secret_access_key> &&
aws configure set default.region us-west-2
```
4. In the terminal, enter aws configure list to confirm your credentials have been set properly:
```
aws configure list
```
## Step 2: create main.tf file
In this file add terraform block and provider block
```
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
```
## Step 3: create variables.tf file
add the following piece of code in the file
```
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
```

## Step 4: Defining an Amazon ECS Cluster Using Terraform
In this step first we will  explore the terraform.tfvars file that provides configuration values to the ECS Cluster.
then we will configure an Amazon ECS cluster, service, and task definition in the main Terraform configuration file.

The ECS Cluster will contain two ECS Services.

A frontend service will deploy tasks (containers) behind the public-facing Application Load Balancer (ALB) and in each of the public subnets. These tasks are based on an existing ECR image that serves a simple webpage and data retrieved from the backend.

The backend service tasks will be behind the internal-facing application load balancer, inside each private subnet. The ECR image used for the backend service generates sample data that is passed to the frontend service.

Once the ECS Cluster is deployed, you will be able to access the entire application by navigating to the public ALB's URL.

### create terraform.tfvars file
1.create a terraform.tfvars file and, then paste in the following configuration values:
```
app_name = "lab"
ecs_role_arn = "arn:aws:iam::871033831194:role/lab-ecs-task-execution-role"
ecs_services = {
  frontend = {
    image          = "871033831194.dkr.ecr.us-west-2.amazonaws.com/frontend:1.0.0"
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
    image          = "871033831194.dkr.ecr.us-west-2.amazonaws.com/backend:1.0.0"
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
internal_alb_dns = "internal-lab-internal-927755423.us-west-2.elb.amazonaws.com"
private_subnet_ids = [
  "subnet-01a99171df98898a4",
  "subnet-0838c1b1161bbff6c"
]
public_subnet_ids = [
  "subnet-0200298e7b3faefb8",
  "subnet-0f03f4baadf06d969"
]
security_group_ids = [
  "sg-03bcb13ab4795cc74",
  "sg-08c92b564e2f92cac"
]
target_group_arns = {
  backend = {
    arn = "arn:aws:elasticloadbalancing:us-west-2:871033831194:targetgroup/backend-tg/0867f13b466fec5f"
  }
  frontend = {
    arn = "arn:aws:elasticloadbalancing:us-west-2:871033831194:targetgroup/frontend-tg/523f2a0270811488"
  }
}
```
The most important value defined in this file is the ecs_services map. This map of objects includes the frontend and backend service configurations. The use of maps, objects, and lists allows you to template an application effectively. Terraform provides meta-arguments such as for_each, that can be used to traverse a map or list to reduce the number of resources defined in your main.tf file.

### Add ECS services in main.tf file
2.click on the main.tf file to open it in the editor, then right-click the main.tf tab and select Split Right in the dropdown menu:
```
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
```
The first resource is an ECS Cluster. The cluster is named lab-cluster after retrieving the app_name variable from the terraform.tfvars file.

The ECS Service definition uses the for_each meta-argument to create one service for each object defined in the ecs_services variable. The each.key will resolve to frontend and backend. Instances of each.value are followed by the corresponding attribute name of the object. The desired_count of tasks for each service uses each.value.desired_count and resolves to 2. Surrounding these dynamic calls with ${ } allows you to resolve and concatenate the value into a string, i.e. name = frontend-service.

The network_configuration references the is_public attribute of each ECS service to determine which subnet to deploy the services into. For each service, if this attribute is set to true, the service is deployed into the public subnets, and each task is assigned a public IP address. If set to false, no public IP is assigned, and the service is deployed into the private subnets.

The target_group_arns map determines which ALB each service is associated with. The backend target group is associated with the internal ALB, which is not publicly accessible. The frontend target group is associated with the public ALB since it will serve the application's webpage.

### Add ECS-task definations in main.tf file

3.Paste the following code to the end of the main.tf file:
```
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
```
The ecs_task_definition resource defines the tasks, or containers, within each ECS service. All ECS tasks are set to the Fargate launch type and assume the same task execution IAM Role. This role provides the task agent with permission to perform AWS API calls on your behalf.

container_definitions include which ECR image to use, CPU and memory configurations, as well as environment variables to be passed into the container. The environment variables in this task definition will be referenced by both frontend and backend services and are specific to the ECR image used in this lab.

The task portMappings allow the containers to access the container port to send or receive traffic. Data will travel between frontend and backend tasks using this port.

Finally, the logConfiguration defines the awslogs log driver which is used to send logs from the containers to Amazon CloudWatch Logs. The options define which CloudWatch Logs Group and AWS Region to send logs to.

In this step, you began to define the Amazon ECS Cluster, Service, and Task Definition resources.

## Step 5:Applying CloudWatch Monitoring and Auto Scaling to an ECS Cluster With Terraform
In this step, you will define CloudWatch Logs that store container logs for each of the ECS Services. You will also configure your ECS Services with Auto Scaling Group policies that scale the service task count in or out depending on certain ECS metrics.

1. Paste the following code to the end of the main.tf file:
```
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
```
The ecs_cw_log_group will serve as the destination for container logs sent from the ECS tasks. The resulting CloudWatch Log Groups, frontend-logs and backend-logs, will store your container logs.

The final three resource definitions are used to configure ECS task auto-scaling. The aws_appautoscaling_target targets the task count and defines a minimum and a maximum number of tasks that you need running in each service. For both ECS services, the desired number of tasks is 2. In addition to this desired count, a maximum task count of 3 and a minimum task count of 2 is defined for each service.

Two aws_appautoscaling_policy resources are applied to each service. One policy will track the ECSServiceAverageCPUUtilization metric, while the other will track the ECSServiceAverageMemoryUtilization metric. If either metric exceeds the defined threshold, this ECS auto-scaling configuration will deploy another ECS task up to the maximum count of 3. At the minimum, this auto-scaling group will ensure at least 2 ECS tasks are running in each service at all times.

In this step, you defined the CloudWatch Logs and Auto Scaling Groups for your ECS Cluster.

## Step 6: Deploying and Testing an Amazon ECS Application
In this step, you will deploy and test your ECS application using the Terraform CLI.

1.In the browser IDE terminal, enter the following command to validate and summarize your deployment:
```
terraform plan -no-color > plan.txt 
```
The command will send the output to the plan.txt file rather than displaying it in the terminal. There will be a total of 13 resources outlined in this plan and sorted in alphabetical order.

This command also runs terraform validate before outputting the plan. Any misaligned variable types or misconfigured resources will be output if found.

2.Enter the following command to deploy your ECS Cluster:
```
terraform apply --auto-approve
```
3.Open the following URL in a new browser tab to confirm the application is running:
```
lab-public-438827517.us-west-2.elb.amazonaws.com
```
The application is a simple API Results webpage. Each time you refresh the page, the frontend ECS tasks retrieve a new set of data from the backend tasks, then display them in a table organized by Record ID

## Summary
By completing this project, you have accomplished the following tasks:
* Defined a Terraform module that deploys Amazon ECS resources
* Applied an Auto Scaling Group Policy to respond to ECS metrics
* Deployed an Amazon ECS Cluster into an existing Amazon VPC using Terraform

































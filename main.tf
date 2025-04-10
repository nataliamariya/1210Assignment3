provider "aws" {
  region = "ca-central-1"
}

resource "aws_ecr_repository" "flask_app_repo" {
  name = "bohulevych-flask-app-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "flask_app_cluster" {
  name = "bohulevych-flask-app-cluster"
}

# IAM Roles for ECS Task
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerServiceforEC2Role"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "bohelevych_flask_app_task" {
  family                   = "bohulevych-flask-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "flask-app-container"
    image     = "${aws_ecr_repository.flask_app_repo.repository_url}:latest"
    portMappings = [
      {
        containerPort = 5000
        hostPort      = 5000
      }
    ]
  }])
}

# VPC Setup - Declaring VPC Properly
resource "aws_vpc" "bohulevych_flask_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subnets in Multiple Availability Zones (for High Availability)
resource "aws_subnet" "flask_subnet_a" {
  vpc_id                  = aws_vpc.bohulevych_flask_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ca-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "flask_subnet_b" {
  vpc_id                  = aws_vpc.bohulevych_flask_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ca-central-1b"
  map_public_ip_on_launch = true
}

# Security Group for Flask App
resource "aws_security_group" "flask_sg" {
  vpc_id = aws_vpc.bohulevych_flask_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer Setup
resource "aws_lb" "flask_alb" {
  name               = "flask-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.flask_sg.id]
  subnets            = [aws_subnet.flask_subnet_a.id, aws_subnet.flask_subnet_b.id]
}

# ALB Target Group
resource "aws_lb_target_group" "flask_target_group" {
  name     = "flask-app-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.bohulevych_flask_vpc.id
}

# ALB Listener Configuration
resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.flask_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_target_group.arn
  }
}

# ECS Service Configuration
resource "aws_ecs_service" "flask_app_service" {
  name            = "flask-app-service"
  cluster         = aws_ecs_cluster.flask_app_cluster.id
  task_definition = aws_ecs_task_definition.bohelevych_flask_app_task.arn
  desired_count   = 2  # For High Availability (HA)
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.flask_subnet_a.id, aws_subnet.flask_subnet_b.id]
    security_groups = [aws_security_group.flask_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_target_group.arn
    container_name   = "flask-app-container"
    container_port   = 5000
  }
}

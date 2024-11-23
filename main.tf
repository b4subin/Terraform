resource "aws_vpc" "main" {
  cidr_block = var.cidr
}
resource "aws_subnet" "sub1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_subnet" "sub2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}
#Route table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.example.id
}
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.example.id
}
#Security group
resource "aws_security_group" "test" {
  name = "web"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "HTTP from server"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH to server"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "test"
  }
}
# S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "subincbabufirststerraform2024nov23project"
}
# EC2 instances
resource "aws_instance" "server1" {
  ami           = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.test.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userdata.sh"))
}
resource "aws_instance" "server2" {
  ami           = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.test.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userdata1.sh"))
}

# application load balacer
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Environment = "production"
  }
}
resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "lb1" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id = aws_instance.server1.id
  port = 80
}
resource "aws_lb_target_group_attachment" "lb2" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id = aws_instance.server2.id
  port = 80
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.test.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.test.arn
    type = "forward"
  }
}
output "loadbalance" {
  value = aws_lb.test.dns_name
}
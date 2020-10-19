# VARIABLES #

variable "key_name" {}
variable "region" {
  default = "eu-west-1"
}
variable "network_address_space" {
  default = "10.10.0.0/16"
}
variable "subnet01_address_space" {
  default = "10.10.0.0/24"
}
variable "subnet02_address_space" {
  default = "10.10.1.0/24"
}
variable "environment_tag" {}

#######################################################################################

# PROVIDERS # 

provider "aws" {
    region  = var.region
    profile = "ronnie"
    
}

#######################################################################################

# LOCALS #

locals {
  common_tags = {
    Environment = var.environment_tag
    }
}

#######################################################################################

# DATA #

data "aws_availability_zones" "available" {}


#######################################################################################

# RESOURCES # 

resource "aws_vpc" "vpc" {
  cidr_block = var.network_address_space

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-igw" })
}

resource "aws_subnet" "subnet01" {
  cidr_block              = var.subnet01_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-subnet01" })

}

resource "aws_subnet" "subnet02" {
  cidr_block              = var.subnet02_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-subnet02" })

}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-rtb" })

}

resource "aws_route_table_association" "rta-subnet01" {
  subnet_id      = aws_subnet.subnet01.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-subnet02" {
  subnet_id      = aws_subnet.subnet02.id
  route_table_id = aws_route_table.rtb.id
}

#######################################################################################

# SECURITY GROUP for EC2 #

resource "aws_security_group" "nginx" {
  name = "Nginx"
  vpc_id = aws_vpc.vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-nginx" })


}

# SECURITY GROUP for ELB #

resource "aws_security_group" "elb-sg" {
  name   = "NginX_elb_SG"
  vpc_id = aws_vpc.vpc.id

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-elb-sg" })
}

#######################################################################################

# INSTANCES #

resource "aws_instance" "nginx01" {
  ami = "ami-0c89b70758a267d60"
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.subnet01.id
  vpc_security_group_ids = [aws_security_group.nginx.id]
  key_name               = var.key_name
  user_data = file("./installnginx.sh")
    ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = "10"
    volume_type = "standard"
    encrypted = true

  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-NginX01" })
}


resource "aws_instance" "nginx02" {
  ami = "ami-0c89b70758a267d60"
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.subnet02.id
  vpc_security_group_ids = [aws_security_group.nginx.id]
  key_name               = var.key_name
  user_data = file("./installnginx.sh")
    ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = "10"
    volume_type = "standard"
    encrypted = true

  }

  tags = merge(local.common_tags, { Name = "${var.environment_tag}-NginX02" })
}

#######################################################################################

# LOAD BALANCER #

resource "aws_elb" "web" {
  name = "nginx-elb"

  subnets         = [aws_subnet.subnet01.id, aws_subnet.subnet02.id]
  security_groups = [aws_security_group.elb-sg.id]
  instances       = [aws_instance.nginx01.id, aws_instance.nginx02.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

    
  
}

#######################################################################################

# OUTPUT 

  output "aws_elb_public_dns" {
    value = aws_elb.web.dns_name
  }

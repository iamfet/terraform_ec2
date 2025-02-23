
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

module "myapp-subnet" {
  source            = "./modules/subnet"
  subnet_cidr_block = var.subnet_cidr_block
  avail_zone        = var.avail_zone
  env_prefix        = var.env_prefix
  vpc_id            = aws_vpc.myapp-vpc.id
}

resource "aws_security_group" "myapp-sg" {
  name        = "myapp-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "myapp-ssh-access" {
  security_group_id = aws_security_group.myapp-sg.id
  cidr_ipv4         = var.my_ip_cidr # Your IP for SSH access
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_ingress_rule" "myapp-port8080-access" {
  security_group_id = aws_security_group.myapp-sg.id
  cidr_ipv4         = "0.0.0.0/0" # Allow HTTP from anywhere
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "myapp-allow-all-outbound" {
  security_group_id = aws_security_group.myapp-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# Create an EC2 Key Pair using the public key from your local machine
resource "aws_key_pair" "ssh-key" {
  key_name   = "myapp-keypair"
  public_key = file(var.public_key_location)

  tags = {
    Name = "${var.env_prefix}-myapp-ssh-keypair"
  }
}

resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = module.myapp-subnet.subnet.id
  security_groups             = [aws_security_group.myapp-sg.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.id

  user_data                   = file("entry-script.sh")
  user_data_replace_on_change = true
  tags = {
    Name = "${var.env_prefix}-myapp-server"
  }
}
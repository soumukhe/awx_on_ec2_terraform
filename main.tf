provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create the vpc
resource "aws_vpc" "vpc-tf" {
  cidr_block = "100.127.0.0/16"

  tags = {
    Name = "phy-dummy-vpc"
  }

}

# Create the subnet for the vpc
resource "aws_subnet" "phy-dummy-subnet1" {
  vpc_id            = aws_vpc.vpc-tf.id
  availability_zone = var.availability_zone1
  cidr_block        = "100.127.1.0/24"

  tags = {
    Name = "phy-dummy-subnet1"
  }
}

# Create the subnet for the csr vpc
resource "aws_subnet" "csr-subnet1" {
  vpc_id            = aws_vpc.vpc-tf.id
  availability_zone = var.availability_zone1
  cidr_block        = "100.127.2.0/24"

  tags = {
    Name = "csr-subnet1"
  }
}

/*
# Test only to get output.  You can get the same info from terraform.tfstate
output "routetable" {
  value = aws_vpc.vpc-tf.default_route_table_id
}

*/

# Create the IGW
resource "aws_internet_gateway" "igw-phy-dummy" {
  vpc_id = aws_vpc.vpc-tf.id

  tags = {
    Name = "phy-dummy-IGW"
  }
}

# Associate the route table created earlier with IGW
resource "aws_route" "default_to_igw" {
  route_table_id         = aws_vpc.vpc-tf.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw-phy-dummy.id

}
##  Notice that this will upload my public key to AWS and use it for the EC2s.  This way, I can ssh-in with my private keys.
##  so, first do:   cp ~/.ssh/id_rsa.pub   ./.certs

resource "aws_key_pair" "loginkey1" {
  key_name = try("phy-login-key") #  using function try here.  If key is already present don't mess with it
  #public_key = file("${path.module}/.certs/id_rsa.pub")  # #  path.module is in relation to the current directory, in case you want to put your id_rsa.pub in ./.certs folder
  public_key = file("~/.ssh/id_rsa.pub")
}


# spin up the aws instance

data "aws_ami" "std_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# create the security group
resource "aws_security_group" "allow_all" {
  name        = "allow_all-sgroup"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.vpc-tf.id

  ingress {
    description = "All Traffic Inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All Traffic Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "phy-dummy_all-in_out"
  }

}

## Associate the security group with the instance
#resource "aws_network_interface_sg_attachment" "sg_attachment" {
#  count                = var.num_inst
#  security_group_id    = aws_security_group.allow_all.id
#  network_interface_id = aws_instance.dummy-phy-ec2[count.index].primary_network_interface_id
#}

resource "aws_instance" "dummy-phy-ec2" {
  ami                         = data.aws_ami.std_ami.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.phy-dummy-subnet1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  key_name                    = aws_key_pair.loginkey1.key_name
  count                       = var.num_inst
  tags = {
    Name = "ec2-${count.index}-AWX" # first instance will be ec2-0, then ec2-1 etc, etc
  }
}

/**
  Install Apache
  Note we are using triggers here to force the provisioners to run everytime "terraform apply" is used.   
  Normal behavior for provisioner is to run only during first run
  You may or maynot want to use triggers
**/

resource "null_resource" "update" {
  depends_on = [aws_instance.dummy-phy-ec2]
  triggers = {
    build_number = timestamp()
  }

  provisioner "local-exec" {
    command = "sleep 30" # buy a little time to make sure ec2 is reachable
  }
}

# install httpd on all the EC2 instances.  We are using count.index to make sure all EC2s are configured
resource "null_resource" "awx" {
  depends_on = [null_resource.update]
  count      = var.num_inst
  triggers = {
    build_number = timestamp()
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum upgrade  -y",
      "cp /etc/sysctl.conf .",
      "echo net.ipv4.ip_forward=1 >> sysctl.conf",
      "sudo cp sysctl.conf /etc/",
      "sudo sysctl -p",
      "sudo amazon-linux-extras install docker  -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker $USER",
      "sudo pip3 install docker-compose",

      #"sudo curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-docker-compose/master/run.sh -o /usr/local/bin/docker-compose",
      #"sudo chmod +x /usr/local/bin/docker-compose",

      "sudo yum install git -y",
      "git clone -b 17.1.0 https://github.com/ansible/awx.git",
      "sed -i 's/# admin_password=password/admin_password=${var.awx_pass}/g' /home/ec2-user/awx/installer/inventory",
      "sudo pip3 install ansible",
      "sed -i 's/# admin_password=password/admin_password=C1sc0123!/g' /home/ec2-user/awx/installer/inventory",
      "sed -i 's/#project_data_dir=\\/var\\/lib\\/awx\\/projects/project_data_dir=\\/var\\/lib\\/awx\\/projects/g' /home/ec2-user/awx/installer/inventory",


      "echo ansible-playbook -i /home/ec2-user/awx/installer/inventory /home/ec2-user/awx/installer/install.yml >> 1.runansible_play.sh",
      "chmod 775 1.runansible_play.sh",
      "echo docker exec -it awx_task ansible-galaxy collection install cisco.aci >> 2.instll_galaxy-awx_task.sh",
      "chmod 775 2.instll_galaxy-awx_task.sh",
      "echo docker exec -it awx_web ansible-galaxy collection install cisco.aci >> 3.instll_galaxy-awx_web.sh",
      "chmod 775 3.instll_galaxy-awx_web.sh",
      "sudo mkdir /var/lib/awx/projects/aci/",

      "echo sudo mkdir /var/lib/awx/projects/aci/ >> 4.create_aci_dir.sh",
      "chmod 775 4.create_aci_dir.sh",

    ]

    connection {
      type        = "ssh"
      user        = "ec2-user" # this is the inbuilt ec2 user name for the used ami
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.dummy-phy-ec2[count.index].public_ip
    }
  }
}


# Show Public IPs
output "publicIP" {

  value = {
    for instance in aws_instance.dummy-phy-ec2 :
    instance.id => instance.public_ip
  }
}

variable "info" {
  default = "ssh username is ec2-user, ssh to ec2 and run the 3 scripts 1.runansible_play.sh, 2.install_galay_awx_tasksh, 3.install_galaxy-awx_web.sh, 4.create_aci_dir.sh, for awx ui browse whit http to the publicIP"
}

output "showinfo" {
  value = {
    "username" = var.info
  }
}

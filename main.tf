#--------------------------------------------------------------------------------------------
# Creating the VPC
#--------------------------------------------------------------------------------------------

resource "aws_vpc" "terra-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Nmae = "Terra-VPC"
  }
}

#--------------------------------------------------------------------------------------------
# Creating public subnet
#--------------------------------------------------------------------------------------------

resource "aws_subnet" "terra-public-subnet" {
  vpc_id     = aws_vpc.terra-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Terra-Public-Subnet"
  }
}

#--------------------------------------------------------------------------------------------
# Creating private subnet
#--------------------------------------------------------------------------------------------

resource "aws_subnet" "terra-private-subnet" {
  vpc_id     = aws_vpc.terra-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Terra-Private-Subnet"
  }
}

#--------------------------------------------------------------------------------------------
# Creating security group
#--------------------------------------------------------------------------------------------

resource "aws_security_group" "terra-sg" {
  name        = "Terra-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.terra-vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Terra-SG"
  }
}

#--------------------------------------------------------------------------------------------
# Creating internet gateway
#--------------------------------------------------------------------------------------------

resource "aws_internet_gateway" "terra-igw" {
  vpc_id = aws_vpc.terra-vpc.id

  tags = {
    Name = "Terra-IGW"
  }
}

#--------------------------------------------------------------------------------------------
# Creating public route table
#--------------------------------------------------------------------------------------------

resource "aws_route_table" "terra-public-rt" {
  vpc_id = aws_vpc.terra-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra-igw.id
  }

  tags = {
    Name = "Terra-Public-RT"
  }
}

#--------------------------------------------------------------------------------------------
# Associating public route table to public subnet
#--------------------------------------------------------------------------------------------

resource "aws_route_table_association" "terra-public-rt-assoc" {
  subnet_id      = aws_subnet.terra-public-subnet.id
  route_table_id = aws_route_table.terra-public-rt.id
}

#--------------------------------------------------------------------------------------------
# Creating instance in public subnet to host the website
#--------------------------------------------------------------------------------------------

resource "aws_instance" "web-server" {
  ami           = "ami-08e5424edfe926b43" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "gitlab"
  subnet_id     = aws_subnet.terra-public-subnet.id
  vpc_security_group_ids = [aws_security_group.terra-sg.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = ubuntu
    private_key = file("~/gitlab.pem")
  }
 
  tags = {
    Name = "Web-Server"
  }
}

#--------------------------------------------------------------------------------------------
# Assigning elastic IP to the instance in public subnet
#--------------------------------------------------------------------------------------------

resource "aws_eip" "terra-eip" {
  instance = aws_instance.web-server.id
  vpc = true
  tags = {
    Name = "Terra-EIP"
  }
}

#--------------------------------------------------------------------------------------------
# Creating instance in private subnet to host the database
#--------------------------------------------------------------------------------------------

resource "aws_instance" "db-server" {
  ami           = "ami-08e5424edfe926b43" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "gitlab"
  subnet_id     = aws_subnet.terra-private-subnet.id
  vpc_security_group_ids = [aws_security_group.terra-sg.id]

  connection {
      type        = "ssh"
      # host        = self.public_ip
      user        = ubuntu
      private_key = file("~/gitlab.pem")
    }
 
  tags = {
    Name = "DB-Server"
  }
}

#--------------------------------------------------------------------------------------------
# Creating elestic IP to be used for NAT Gateway
#--------------------------------------------------------------------------------------------

resource "aws_eip" "terra-natgw" {
  vpc = true
}

#--------------------------------------------------------------------------------------------
# Creating NAT Gateway and aasigning elastic IP to it
#--------------------------------------------------------------------------------------------

resource "aws_nat_gateway" "terra-natgw" {
  allocation_id = aws_eip.terra-natgw.id
  subnet_id = aws_subnet.terra-public-subnet.id

  tags = {
    Name = "Terra-NATGW"
  }
  
}

#--------------------------------------------------------------------------------------------
# Creating private route table 
#--------------------------------------------------------------------------------------------

resource "aws_route_table" "terra-private-rt" {
  vpc_id = aws_vpc.terra-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.terra-natgw.id
  }

  tags = {
    Name = "Terra-Private-RT"
  }
}

#--------------------------------------------------------------------------------------------
# Associating private route table with private subnet 
#--------------------------------------------------------------------------------------------

resource "aws_route_table_association" "terra-private-rt-assoc" {
  subnet_id      = aws_subnet.terra-private-subnet.id
  route_table_id = aws_route_table.terra-private-rt.id
}


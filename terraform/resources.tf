# resource "random_password" "password" {
#   length  = 16
#   special = false
# }

resource "aws_vpc" "floci_test" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

locals {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

resource "aws_subnet" "floci_test" {
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.floci_test.id
  cidr_block        = cidrsubnet(aws_vpc.floci_test.cidr_block, 3, index(local.availability_zones, each.value) + 1)
  availability_zone = each.value

  tags = {
    Name = "floci_test-${each.value}"
  }
}

# resource "aws_subnet" "floci_test" {
#   cidr_block        = cidrsubnet(aws_vpc.floci_test.cidr_block, 3, 1)
#   vpc_id            = aws_vpc.floci_test.id
#   availability_zone = "us-east-1a"
# }

resource "aws_internet_gateway" "floci_test" {
  vpc_id = aws_vpc.floci_test.id
}

resource "aws_route_table" "floci_test" {
  vpc_id = aws_vpc.floci_test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.floci_test.id
  }
}

resource "aws_route_table_association" "floci_test" {
  for_each       = toset(["us-east-1a", "us-east-1b", "us-east-1c"])
  subnet_id      = aws_subnet.floci_test[each.key].id
  route_table_id = aws_route_table.floci_test.id
}

resource "aws_security_group" "floci_test_ssh" {
  # ... other configuration ...
  name = "allow_ssh"

  vpc_id = aws_vpc.floci_test.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "floci_test_http" {
  # ... other configuration ...
  name = "allow_http"

  vpc_id = aws_vpc.floci_test.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM role creations and ploicy attachment
resource "aws_iam_role" "eks_cluster_role" {
  name = "floci-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_role" {
  name = "floci-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#EKS cluster creation
resource "aws_eks_cluster" "floci_eks" {
  name     = "floci-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.31"

  vpc_config {
    subnet_ids = [
      for subnet in aws_subnet.floci_test : subnet.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

#EKS node creation
resource "aws_eks_node_group" "floci_nodes" {
  cluster_name    = aws_eks_cluster.floci_eks.name
  node_group_name = "floci-worker-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    for subnet in aws_subnet.floci_test : subnet.id
  ]

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_policy
  ]
}



# resource "aws_key_pair" "open_web_ui" {
#   key_name = "open_web_ui"
#   public_key = file("C:/Users/Pratiti_User/AppData/Local/Temp/public_key")
# }

# resource "aws_instance" "terraform_test" {
#   ami           = data.aws_ami.debain.id
#   instance_type = "t3.micro"

#   associate_public_ip_address = true
#   vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.http.id]
#   subnet_id                   = aws_subnet.open_web_ui.id
#   key_name                    = "terraform_test"

#   user_data = <<-EOF
#               #!/bin/bash
#               export DEBIAN_FRONTEND=noninteractive

#               # 1. Standard package installation
#               apt-get update -y
#               apt-get install nginx -y

#               # 2. Force start the service to generate the web roots
#               systemctl start nginx
#               systemctl enable nginx

#               # 3. CRITICAL DEBIAN FIX: Delete the system-default index file completely 
#               # to prevent Nginx from caching or prioritizing it over your new index.
#               rm -f /var/www/html/index.nginx-debian.html
#               rm -f /var/www/html/index.html

#               # Overwrite the default Nginx welcome page with a custom static HTML template
#               cat << 'HTML' > /var/www/html/index.nginx-debian.html
#               <!DOCTYPE html>
#               <html lang="en">
#               <head>
#                   <meta charset="UTF-8">
#                   <title>My Terraform Static Page</title>
#                   <style>
#                       body {
#                           font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
#                           background: linear-gradient(135deg, #74b9ff, #a29bfe);
#                           color: #2d3436;
#                           display: flex;
#                           justify-content: center;
#                           align-items: center;
#                           height: 100vh;
#                           margin: 0;
#                       }
#                       .card {
#                           background: white;
#                           padding: 40px;
#                           border-radius: 12px;
#                           box-shadow: 0 10px 20px rgba(0,0,0,0.15);
#                           text-align: center;
#                       }
#                       h1 { color: #6c5ce7; margin-bottom: 10px; }
#                       p { font-size: 1.1em; color: #636e72; }
#                   </style>
#               </head>
#               <body>
#                   <div class="card">
#                       <h1>Hello from EC2! 👋</h1>
#                       <p>This static HTML page was deployed completely unauthenticated using Terraform on Debian 11.</p>
#                   </div>
#               </body>
#               </html>
#               HTML

#               systemctl start nginx
#               systemctl enable nginx
#               EOF


#   tags = {
#     Name = "terracurl-debian11-endpoint"
#   }


# # Allocate the Elastic IP
# resource "aws_eip" "terraform_test" {
#   domain = "vpc" # Allocates the EIP inside your VPC

#   tags = {
#     Name = "open_web_ui"
#   }
# }

# # Associate the Elastic IP with the EC2 Instance
# resource "aws_eip_association" "open_web_ui" {
#   instance_id   = aws_instance.terraform_test.id
#   allocation_id = aws_eip.terraform_test.id
# }

# # Debian apt configurations can sometimes take a moment; 45s sleep ensures Nginx is fully online
# resource "time_sleep" "wait_for_nginx" {
#   depends_on      = [aws_instance.terraform_test]
#   create_duration = "45s"
# }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "mongo-cluster"
  cluster_version = "1.25"

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id = module.myapp-vpc.vpc_id
  subnet_ids = module.myapp-vpc.private_subnets


  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t2.medium", "t2.small", "t2.micro"]
  }

  eks_managed_node_groups = {
    T2_MICRO_GROUP = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"
    }
    T2_MEDIUM_GROUP = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t2.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    Application   = "mongo"
  }
}

# an inbound rule to allow the communication between kubeseal tool and sealed secret controller
resource "aws_security_group_rule" "cluster_api_webhook" {
  security_group_id = module.eks.node_security_group_id 

  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  description       = "Cluster API to node 8080/tcp webhook"
  source_security_group_id = module.eks.cluster_security_group_id 
}
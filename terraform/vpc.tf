variable vpc_cidr_block {}
variable private_subnet_cidr_blocks {}
variable public_subnet_cidr_blocks {}

data "aws_availability_zones" "azs" {}

module "myapp-vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.0.0"

    name = "myapp-vpc"
    cidr = var.vpc_cidr_block
    private_subnets = var.private_subnet_cidr_blocks
    public_subnets = var.public_subnet_cidr_blocks

    #distibute in all availability zones "one subnet in each availabiltiy zone"
    azs = data.aws_availability_zones.azs.names 
    
    enable_nat_gateway = true
     # create a shared common gateway for all private subnets
    single_nat_gateway = true

    #ec2 have dns names
    enable_dns_hostnames = true

    #help tell cloud controller manager which vpc it should connect to
    tags = {
        "kubernetes.io/cluster/mongo-cluster" = "shared"
    }

    public_subnet_tags = {
        #help tell cloud controller manager which subnets it should connect to
        "kubernetes.io/cluster/mongo-cluster" = "shared"

        # put load balancer in the public subnets
        "kubernetes.io/role/elb" = 1 
    }

    private_subnet_tags = {
        #help tell cloud controller manager which subnets it should connect to
        "kubernetes.io/cluster/mongo-cluster" = "shared"

        # put internal load balancer in the private subnets
        "kubernetes.io/role/internal-elb" = 1 
    }

}
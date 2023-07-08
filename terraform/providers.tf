terraform { # "terraform" block is used to configure information and metadata about terraform itself
  required_version = ">=1.4.5" 
  backend "s3" { 
    # S3 is a storage in AWS used to store files
    bucket = <bucket-name> # must exist in the AWS account
    key = "mymongoapp/state.tfstate"  #path inside the bucket
    region = "eu-west-1" # no need to be in same region of created server and its resources
   }
}

provider "aws" {
    region = "eu-west-1"
}

# used to connect and configure authentication with k8s cluster
provider "kubernetes" {
  # end point of the cluster - (API server) address
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

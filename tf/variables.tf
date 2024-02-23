variable vpc_cidr_range  {
  type = string
  default = "10.0.0.0/16"
  description = "The CIDR block to use as the base for the vpc in this example"
}

variable public_subnets {
  type        = map(object)
  description = "Public Subnet CIDR values in AZ order"
  default = {
    public-1 = {
      az = "euw1-az1"
      cidr = "10.0.0.0/24"
    }
    public-2 = {
      az = "euw1-az2"
      cidr = "10.0.1.0/24"
    }
    public-3 = {
      az = "euw1-az3"
      cidr = "10.0.2.0/24"
    }
  }
}

variable private_subnets {
  type        = map(object)
  description = "Private Subnet CIDR values in AZ order"
  default = {
    public-1 = {
      az = "euw1-az1"
      cidr = "10.0.3.0/24"
    }
    public-2 = {
      az = "euw1-az2"
      cidr = "10.0.4.0/24"
    }
    public-3 = {
      az = "euw1-az3"
      cidr = "10.0.5.0/24"
    }
  }
}
variable "ami_id" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

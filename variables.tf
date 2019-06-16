variable "do_token" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
  default = "fra1"
}

variable "cluster_version" {
  type = string
  default = "1.14.1-do.4"
}

variable "cluster_worker_size" {
  type = string
  default = "s-2vcpu-2gb"
}

variable "cluster_worker_count" {
  type = number
  default = 1
}

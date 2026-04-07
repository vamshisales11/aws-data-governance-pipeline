variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "raw_bucket" {
  type = string
}

variable "processed_bucket" {
  type = string
}

variable "curated_bucket" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
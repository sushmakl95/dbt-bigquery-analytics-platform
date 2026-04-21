variable "dataset_id" { type = string }
variable "friendly_name" { type = string }
variable "description" {
  type    = string
  default = ""
}
variable "location" {
  type    = string
  default = "US"
}
variable "default_table_expiration_ms" {
  type    = number
  default = null
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "access" {
  type = list(object({
    role           = string
    user_by_email  = optional(string)
    group_by_email = optional(string)
    domain         = optional(string)
  }))
  default = []
}

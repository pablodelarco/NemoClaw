variable "appliance_name" {
  type    = string
  default = "nemoclaw"
}

variable "version" {
  type    = string
  default = "0.1.0"
}

variable "input_dir" {
  type    = string
  default = "export"
}

variable "output_dir" {
  type    = string
  default = "output"
}

variable "headless" {
  type    = bool
  default = true
}

variable "nemoclaw" {
  type = map(string)
  default = {
    one_service_version = "0.1.0"
  }
}

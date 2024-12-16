locals {
  vm_memory = 10240
  vm_cpus = 6
  vm_disk = 50
}
variable "vm_memory" {
  description = "Memory(MB) for virtual machine of podman"
  default     = 10240
}

variable "vm_cpus" {
  description = "CPUs for virtual machine of podman"
  default     = 6
}

variable "vm_disk" {
  description = "DISK(GB) for virtual machine of podman"
  default     = 50
}

variable "ingressClass" {
  description = "Ingress Class Type: 'nginx' or 'traefik'. Use traefik for Gateway API support"
  default     = "traefik"
}

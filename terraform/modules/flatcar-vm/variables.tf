variable "cluster_name" {
  description = "Name des Clusters (Präfix für Ressourcen)"
  type        = string
}

variable "vm_name" {
  description = "Name der virtuellen Maschine"
  type        = string
}

variable "pool_name" {
  description = "Name des libvirt Storage Pools"
  type        = string
}

variable "base_volume_id" {
  description = "ID des Basis-Image Volumes"
  type        = string
}

variable "butane_config_path" {
  description = "Pfad zur Butane Config Template-Datei"
  type        = string
}

variable "ssh_keys" {
  description = "Liste von SSH Public Keys"
  type        = list(string)
}

variable "vcpu" {
  description = "Anzahl virtueller CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "network_name" {
  description = "Name des libvirt Netzwerks"
  type        = string
  default     = "default"
}

variable "graphics_type" {
  description = "Grafik-Typ (spice oder vnc)"
  type        = string
  default     = "spice"
}

# k3s-spezifische Variablen
variable "k3s_role" {
  description = "k3s Rolle (server oder agent)"
  type        = string
  validation {
    condition     = contains(["server", "agent"], var.k3s_role)
    error_message = "k3s_role muss 'server' oder 'agent' sein."
  }
}

variable "k3s_token" {
  description = "k3s Cluster Token"
  type        = string
  sensitive   = true
}

variable "k3s_server_url" {
  description = "k3s Server URL (nur für Agents)"
  type        = string
  default     = ""
}

variable "extra_butane_config" {
  description = "Zusätzliche Butane Config (YAML)"
  type        = string
  default     = ""
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
  folder_id = "b1gns4nf6143135t5p7d"
}

resource "yandex_compute_instance" "vm" {

  count = 2
  name  = "vm${count.index}"
  platform_id ="standard-v1"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8037i5hvleukdnk2s4" #ubuntu-26-04-lts-v20260907 
      size     = 10
    }
  }

 
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet2.id
    nat       = true
    ipv6      = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

}




resource "yandex_vpc_network" "network2" {
  name = "network2" 
}

resource "yandex_vpc_subnet" "subnet2" {
  name           = "subnet2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network2.id
  v4_cidr_blocks = ["192.168.88.0/24"]
}




resource "yandex_lb_target_group" "nlb-2" {
  name      = "nlb-target-group-2"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.subnet2.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "nlb-2" {
  name = "nlb-2-load-balancer"
  deletion_protection = "false"
  listener {
    name = "nginx-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-2.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

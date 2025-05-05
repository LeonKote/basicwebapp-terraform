terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

variable "yc_token" {
  type = string
}

variable "yc_cloud_id" {
  type = string
}

variable "yc_folder_id" {
  type = string
}

variable "yc_zone" {
  type = string
}

variable "image_id" {
  type = string
}

variable "db_database" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "bucket_name" {
  type = string
}

resource "yandex_compute_instance_group" "instance-group-1" {
  name               = "instance-group-1"
  service_account_id = yandex_iam_service_account.compute_account.id

  instance_template {
    platform_id = "standard-v1"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.subnet-1.id]
      nat        = true
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
      user-data = templatefile("${path.module}/templates/cloud-init.tmpl", {
        env_file = templatefile("${path.module}/templates/.env.tmpl", {
          bucket_name = var.bucket_name
        })
        appsettings = templatefile("${path.module}/templates/appsettings.json.tmpl", {
          db_host     = yandex_mdb_postgresql_cluster.postgres-1.host[0].fqdn
          db_database = var.db_database
          db_username = var.db_username
          db_password = var.db_password
          access_key  = yandex_iam_service_account_static_access_key.storage_key.access_key
          secret_key  = yandex_iam_service_account_static_access_key.storage_key.secret_key
          bucket_name = var.bucket_name
        })
        basicwebappservice = file("${path.module}/basicwebapp.service")
      })
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "from-terraform-network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "from-terraform-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_mdb_postgresql_cluster" "postgres-1" {
  name        = "postgres-1"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.network-1.id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 16
    }
    postgresql_config = {
      max_connections                   = 395
      enable_parallel_hash              = true
      vacuum_cleanup_index_scale_factor = 0.2
      autovacuum_vacuum_scale_factor    = 0.34
      default_transaction_isolation     = "TRANSACTION_ISOLATION_READ_COMMITTED"
      shared_preload_libraries          = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
    }
  }

  database {
    name  = var.db_database
    owner = var.db_username
  }

  user {
    name       = var.db_username
    password   = var.db_password
    conn_limit = 50
    permission {
      database_name = var.db_database
    }
    settings = {
      default_transaction_isolation = "read committed"
      log_min_duration_statement    = 5000
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-1.id
  }
}

resource "yandex_iam_service_account" "storage_account" {
  name = "storage-account"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage_account.id}"
}

resource "yandex_iam_service_account" "compute_account" {
  name = "compute-account"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.compute_account.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage_key" {
  service_account_id = yandex_iam_service_account.storage_account.id
}

resource "yandex_storage_bucket" "web_bucket" {
  access_key = yandex_iam_service_account_static_access_key.storage_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage_key.secret_key
  bucket     = var.bucket_name
  max_size   = 1073741824

  anonymous_access_flags {
    read = true
  }

  website {
    index_document = "index.html"
  }
}

resource "yandex_lb_target_group" "target-group-1" {
  name = "target-group-1"

  dynamic "target" {
    for_each = yandex_compute_instance_group.instance-group-1.instances
    content {
      subnet_id = yandex_vpc_subnet.subnet-1.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "network-load-balancer-1" {
  name = "network-load-balancer-1"

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.target-group-1.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
      }
    }
  }
}

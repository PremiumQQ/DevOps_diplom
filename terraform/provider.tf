terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "/opt/terraform/key.json"
  cloud_id                 = "xxx"
  folder_id                = "xxx"
  zone                     = "ru-central1-a"
}

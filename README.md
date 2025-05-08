# 🛠 Basic Web App with Terraform

Этот проект поднимает инфраструктуру Basic Web App в Yandex Cloud с помощью Terraform, включая сервисный аккаунт, IAM-права, Instance Group и настройку базового веб-приложения.

---

## ✏️ Что нужно заполнить в `terraform.tfvars`

Перед запуском необходимо указать значения переменных в файле `terraform.tfvars`:

```hcl
yc_token     = ""  # OAuth-токен Yandex Cloud
yc_cloud_id  = ""  # ID облака
yc_folder_id = ""  # ID папки
yc_zone      = "ru-central1-a"

# Образ Ubuntu 22.04 LTS (пример от 21.04.2025)
image_id     = "fd8e1sajg9qbr5mp1hco"

# Данные для БД
db_database  = "basicwebapp"
db_username  = "basicwebapp"
db_password  = "Test1234"

# Название бакета
bucket_name  = ""
````

---

## 🚀 Развёртывание инфраструктуры

1. Инициализируй Terraform:

```bash
terraform init
```

2. Примените конфигурацию (с подтверждением):

```bash
terraform apply
```

---

## 🔥 Удаление инфраструктуры

> Чтобы избежать ошибок при удалении, сначала нужно удалить ресурсы, которые зависят от IAM-ролей.

1. Удалить группу виртуальных машин:

```bash
terraform destroy -target=yandex_compute_instance_group.instance-group-1
```

2. Удалить остальные ресурсы:

```bash
terraform destroy
```

---

## 📁 Структура проекта

```
.
├── basicwebapp.service            # Systemd unit-файл для запуска приложения
├── my-config.tf                   # Основная конфигурация Terraform
├── terraform.tfvars               # Переменные окружения (заполняется вручную)
├── templates/                     # Шаблоны для cloud-init и настроек приложения
│   ├── .env.tmpl                  # Шаблон переменных окружения
│   ├── appsettings.json.tmpl      # Конфигурация ASP.NET приложения
│   └── cloud-init.tmpl            # cloud-init скрипт для установки и запуска
└── README.md                      # Этот файл
```

---

## 📌 Примечание

Terraform может неправильно удалить IAM-права раньше зависимых ресурсов. Чтобы избежать этого — удаляйте в два этапа (сначала ресурсы, потом IAM).


variable "location" {
  default = "West Europe"
}

variable "resource_group_name" {
  default = "myWEBServiceResourceGroup"
}

variable "service_plan_name" {
  default = "myWEBServicePlan"
}

variable "app_service_plan_sku" {
  default = {
    tier = "Free"
    size = "F1"
  }
}

variable "frontend_app_name" {
  default = "aminafront"
}

variable "backend_app_name" {
  default = "aminaback"
}

variable "function_app_name" {
  default = "hello-service"
}

variable "storage_account_name" {
  default = "webappstorage"
}

variable "application_gateway_name" {
  default = "myWEBServiceAppGateway"
}

variable "public_ip_name" {
  default = "appgw-public-ip"
}

variable "vnet_name" {
  default = "webapp-vnet"
}

variable "subnet_name" {
  default = "appgw-subnet"
}

variable "address_space" {
  default = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  default = ["10.0.1.0/24"]
}

variable "mysql_server_name" {
  default = "aminamysql"
}

variable "mysql_admin_login" {
  default = "adminuser"
}

variable "mysql_admin_password" {
  default = "P@ssw0rd1234"
}

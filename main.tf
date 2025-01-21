terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 1.0.2"
    }
  }
}

resource "snowflake_account" "minimal" {
  name                 = "vrakoup-fr81188"
  admin_name           = "tf-snow"
  email                = "snowflaketest03@outlook.com"
  admin_rsa_public_key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuY7MrmFv9chrZ+Y5QVtEwDL8XWqGys3YglkWXXjGWCCFoT+b3iWtSyDHHxYSrZHlWh7KokACqFKVca5SLRjVJDNnRUL1W4vyqUH5R9P3LjzwxYnrZf5WTLAc+uKI7L+QivKLK5diBAXqRDP46muP9T+PBmNHaiGW444Oy4wQT0EW61wmle99v1Bi04lP8Pok2EmG8/mc5gfwI5cy7T4dwJ+77xbG5SJpcwWPrUx5rjv3lOAto2CRm8OYJUbK1Mm1nOP0FRC3NspUF+p1s5UfssLCnEefY8ifsvlT/Wh/EzaLR0LKBjG1HEwN2qddFylKjw4rGXfTgEcTB4x1GoX0mQIDAQAB"
  edition              = "STANDARD"
  grace_period_in_days = 3
}

provider "snowflake" {
  organization_name = "VRAKOUP"
  account_name = "FR81188"
  user = "TF-SNOW"
  password = "Dipak@1979"
  role = "SYSADMIN"
  #alias = "security_admin"
  #role = "SECURITYADMIN"
}


resource "snowflake_database" "db" {
  name = "TF_DEMO"
}

resource "snowflake_warehouse" "warehouse" {
  name           = "TF_DEMO"
  warehouse_size = "xsmall"
  auto_suspend   = 60
}

provider "snowflake" {
  organization_name = "VRAKOUP"
  account_name = "FR81188"
  user = "TF-SNOW"
  password = "Dipak@1979"
  alias = "security_admin"
  role  = "SECURITYADMIN"
}
resource "snowflake_account_role" "role" {
  provider = snowflake.security_admin
  name     = "TF_DEMO_SVC_ROLE"
}

resource "snowflake_grant_privileges_to_account_role" "database_grant" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.db.name
  }
}

resource "snowflake_schema" "schema" {
  database   = snowflake_database.db.name
  name       = "TF_DEMO"
  #is_managed = false
}

resource "snowflake_grant_privileges_to_account_role" "schema_grant" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.role.name
  on_schema {
    schema_name = "\"${snowflake_database.db.name}\".\"${snowflake_schema.schema.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_grant" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.warehouse.name
  }
}

resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "snowflake_user" "user" {
    provider          = snowflake.security_admin
    name              = "tf_demo_user"
    default_warehouse = snowflake_warehouse.warehouse.name
    default_role      = snowflake_account_role.role.name
    default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
    rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

resource "snowflake_grant_privileges_to_account_role" "user_grant" {
  provider          = snowflake.security_admin
  privileges        = ["MONITOR"]
  account_role_name = snowflake_account_role.role.name  
  on_account_object {
    object_type = "USER"
    object_name = snowflake_user.user.name
  }
}

resource "snowflake_grant_account_role" "grants" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.role.name
  user_name = snowflake_user.user.name
}

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
	  version = "~> 0.87"
    }
  }
}

locals {
  organization_name = "vqwihfg"
  account_name      = "ua76311"
  private_key_path  = "~/.ssh/snowflake_tf_snow_key.p8"
}

provider "snowflake" {
    organization_name = local.organization_name
    account_name      = local.account_name
    user              = "TERRAFORM_SVC"
    role              = "SYSADMIN"
    authenticator     = "SNOWFLAKE_JWT"
    private_key       = file(local.private_key_path)
}



resource "snowflake_database" "tf_db" {
  name         = "TF_DEMO_DB"
  is_transient = false
}

resource "snowflake_warehouse" "tf_warehouse" {
  name                      = "TF_DEMO_WH"
  warehouse_type            = "STANDARD"
  warehouse_size            = "LARGE"
  max_cluster_count         = 1
  min_cluster_count         = 1
  auto_suspend              = 60
  auto_resume               = true
  enable_query_acceleration = false
  initially_suspended       = true
}

# Create a new schema in the DB
resource "snowflake_schema" "tf_db_tf_schema" {
  name                = "TF_DEMO_SC"
  database            = snowflake_database.tf_db.name
  with_managed_access = false
}


# New provider that will use USERADMIN to create users, roles, and grants
provider "snowflake" {
    organization_name = local.organization_name
    account_name      = local.account_name
    user              = "TERRAFORM_SVC"
    role              = "USERADMIN"
    alias             = "useradmin"
    authenticator     = "SNOWFLAKE_JWT"
    private_key       = file(local.private_key_path)
}

# Create a new role using USERADMIN
resource "snowflake_account_role" "tf_role" {
    provider          = snowflake.useradmin
    name              = "TF_DEMO_ROLE"
    comment           = "My Terraform role"
}

# Grant the new role to SYSADMIN (best practice)
resource "snowflake_grant_account_role" "grant_tf_role_to_sysadmin" {
    provider         = snowflake.useradmin
    role_name        = snowflake_account_role.tf_role.name
    parent_role_name = "SYSADMIN"
}

# Create a key for the new user
resource "tls_private_key" "svc_key" {
    algorithm = "RSA"
    rsa_bits  = 2048
}

# Create a new user
resource "snowflake_user" "tf_user" {
    provider          = snowflake.useradmin
    name              = "TF_DEMO_USER"
    default_warehouse = snowflake_warehouse.tf_warehouse.name
    default_role      = snowflake_account_role.tf_role.name
    default_namespace = "${snowflake_database.tf_db.name}.${snowflake_schema.tf_db_tf_schema.fully_qualified_name}"
    rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

# Grant the new role to the new user
resource "snowflake_grant_account_role" "grants" {
    provider          = snowflake.useradmin
    role_name         = snowflake_account_role.tf_role.name
    user_name         = snowflake_user.tf_user.name
}
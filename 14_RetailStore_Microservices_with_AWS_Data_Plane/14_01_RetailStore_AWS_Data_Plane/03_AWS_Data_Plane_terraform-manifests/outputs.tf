output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.catalog_rds.endpoint
}


output "debug_secret_json" {
  value     = local.retailstore_secret_json
  sensitive = true
}


output "debug_retailstore_secret_password" {
  value     = try(local.retailstore_secret_json.DB_PASS, "NOT_AVAILABLE")
  sensitive = true
}

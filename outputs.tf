output "app_table_name" {
  description = "The dynamic name created for the app's DynamoDB table"
  value       = aws_dynamodb_table.books_table.name
}

output "user_api_url" {
  description = "URL to invoke the API pointing to the stage"
  value       = aws_api_gateway_stage.user_api_prod.invoke_url
}
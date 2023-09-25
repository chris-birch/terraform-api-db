resource "aws_cloudwatch_log_group" "app_logs" {
  name = "${var.project}_app_logs_${random_id.generator.id}"
}
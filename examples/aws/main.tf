data "aws_caller_identity" "current" {}

output "identity" {
  value = data.aws_caller_identity.current
}

output "aws_lbc_role_arn" {
  value = aws_iam_role.aws_lbc.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}
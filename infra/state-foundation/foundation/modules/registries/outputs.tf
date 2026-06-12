# foundation/modules/registries/outputs.tf
output "ecr_url" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com)."
  value       = local.registry_host
}

output "ecr_repository_urls" {
  description = "Map of repo name => full ECR repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "codeartifact_endpoint" {
  description = "CodeArtifact internal repo coordinates (domain/repo)."
  value       = "${aws_codeartifact_domain.this.domain}/${aws_codeartifact_repository.internal.repository}"
}

output "codeartifact_domain" {
  description = "CodeArtifact domain name."
  value       = aws_codeartifact_domain.this.domain
}

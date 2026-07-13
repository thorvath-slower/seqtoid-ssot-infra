# foundation/modules/registries/outputs.tf
output "ecr_url" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com)."
  value       = local.registry_host
}

output "ecr_repository_urls" {
  description = "Map of repo name => full ECR repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

# Base URL per pull-through rule (GA-#511): "<ecr_host>/<prefix>". Consumers
# repoint FROM lines at "<base>/<upstream-path>:<tag>", e.g. for Docker Hub the
# default rule yields "<ecr_host>/docker-hub/library/ruby:3.3.6". This is the
# published handle the Dockerfile-repoint follow-up (post-apply) consumes.
output "pull_through_cache_base_urls" {
  description = "Map of pull-through rule id => local ECR base URL to prefix onto upstream image paths."
  value       = { for k, r in aws_ecr_pull_through_cache_rule.this : k => "${local.registry_host}/${r.ecr_repository_prefix}" }
}

output "codeartifact_endpoint" {
  description = "CodeArtifact internal repo coordinates (domain/repo)."
  value       = "${aws_codeartifact_domain.this.domain}/${aws_codeartifact_repository.internal.repository}"
}

output "codeartifact_domain" {
  description = "CodeArtifact domain name."
  value       = aws_codeartifact_domain.this.domain
}

# czid-infra developer tasks. `make check` runs the same gates as CI so you can validate
# locally before pushing (local == CI, CZID-311).
.DEFAULT_GOAL := help

.PHONY: check
check: ## Run all CI checks locally (terraform fmt + validate + security scanners)
	@./bin/check

.PHONY: fmt
fmt: ## Auto-format the IaC (terraform fmt -recursive infra/)
	@terraform fmt -recursive infra/

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

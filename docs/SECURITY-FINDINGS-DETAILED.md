# Security Findings — Detailed Register (2026-06-11)

Every individual finding (729) from the `improvement-#010` scanners (Trivy + Checkov), grouped by repo then by check type. Each entry lists the repo-relative path, the line, the resource, and a remediation. Remediation is per check *type* (the fix is identical for every instance of a check); the long-tail checks cite the tool's official guideline URL.

- Reproduce / triage: [`SECURITY-SCANNING.md`](./SECURITY-SCANNING.md)
- Overview + priorities: [`SECURITY-FINDINGS-2026-06-11.md`](./SECURITY-FINDINGS-2026-06-11.md)
- Spreadsheet (sortable/filterable): `CZ-ID-Security-Findings-Register-2026-06-11.xlsx` (workspace root)

> **Caveat:** the cypherid-web-infra **Trivy** scan did not complete (very large repo); its 591 **Checkov** findings cover the IaC-misconfig surface. gitleaks (7 hits, all triaged false positives) is documented in the overview, not repeated here.

| Repo | findings | trivy | checkov |
|------|---------:|------:|--------:|
| czid-infra | 20 | 3 | 17 |
| cypherid-workflow-infra | 118 | 53 | 65 |
| cypherid-web-infra | 591 | 0 | 591 |
| **total** | **729** | **56** | **673** |

## ⚑ Priority / OPEN findings

| Repo | Check | Sev | Path | Line | Remediation |
|------|-------|-----|------|-----:|-------------|
| czid-infra | `AWS-0040` | CRITICAL | `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 55 | EKS: set endpoint_public_access=false (private endpoint), or restrict public_access_cidrs to admin/VPN CIDRs. |
| czid-infra | `AWS-0041` | CRITICAL | `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 56 | EKS: set public_access_cidrs to specific admin/VPN CIDRs, not 0.0.0.0/0. |
| czid-infra | `CKV_AWS_38` | — | `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 47 | EKS: restrict public_access_cidrs (no 0.0.0.0/0). Same root cause as AWS-0041. |
| czid-infra | `CKV_AWS_39` | — | `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 47 | EKS: endpoint_public_access = false (or restrict CIDRs). Same root cause as AWS-0040. |

## czid-infra — 20 findings

### `AWS-0040` · CRITICAL · 1× — **OPEN (priority)**
*EKS Clusters should have the public access disabled*

**Remediation:** EKS: set endpoint_public_access=false (private endpoint), or restrict public_access_cidrs to admin/VPN CIDRs.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 55 | module.eks |

### `AWS-0041` · CRITICAL · 1× — **OPEN (priority)**
*EKS cluster should not have open CIDR range for public access*

**Remediation:** EKS: set public_access_cidrs to specific admin/VPN CIDRs, not 0.0.0.0/0.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 56 | module.eks |

### `AWS-0164` · HIGH · 1× — **ACCEPTED (by design)**
*Instances in a subnet should not receive a public IP address by default.*

**Remediation:** Subnet: set map_public_ip_on_launch=false (ACCEPTED for the intentional public subnet).

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/network/main.tf` | 55 | module.network |

### `CKV2_AWS_64` · — · 4×
*Ensure KMS key Policy is defined*

**Remediation:** aws_kms_key: add an explicit 'policy' (key administrators/users) instead of the default policy.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/dr.tf` | 30 | aws_kms_key.tfstate_dr |
| `czid-infra/infra/state-foundation/bootstrap/main.tf` | 35 | aws_kms_key.tfstate |
| `czid-infra/infra/state-foundation/foundation/main.tf` | 42 | aws_kms_key.app |
| `czid-infra/infra/state-foundation/foundation/modules/openbao/main.tf` | 32 | module.openbao.aws_kms_key.unseal |

### `CKV2_AWS_62` · — · 2×
*Ensure S3 buckets should have event notifications enabled*

**Remediation:** S3: add aws_s3_bucket_notification, or skip with justification if events aren't needed.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/dr.tf` | 46 | aws_s3_bucket.tfstate_dr |
| `czid-infra/infra/state-foundation/bootstrap/main.tf` | 47 | aws_s3_bucket.tfstate |

### `CKV_AWS_18` · — · 2×
*Ensure the S3 bucket has access logging enabled*

**Remediation:** S3: add aws_s3_bucket_logging targeting a dedicated log bucket.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/dr.tf` | 46 | aws_s3_bucket.tfstate_dr |
| `czid-infra/infra/state-foundation/bootstrap/main.tf` | 47 | aws_s3_bucket.tfstate |

### `CKV2_AWS_11` · — · 1×
*Ensure VPC flow logging is enabled in all VPCs*

**Remediation:** VPC: add aws_flow_log for the VPC -> CloudWatch/S3.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/network/main.tf` | 31 | module.network.aws_vpc.this |

### `CKV2_AWS_12` · — · 1×
*Ensure the default security group of every VPC restricts all traffic*

**Remediation:** Add aws_default_security_group for the VPC that denies all ingress/egress.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/network/main.tf` | 31 | module.network.aws_vpc.this |

### `CKV2_AWS_61` · — · 1×
*Ensure that an S3 bucket has a lifecycle configuration*

**Remediation:** S3: add aws_s3_bucket_lifecycle_configuration.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/dr.tf` | 46 | aws_s3_bucket.tfstate_dr |

### `CKV_AWS_119` · — · 1×
*Ensure DynamoDB Tables are encrypted using a KMS Customer Managed CMK*

**Remediation:** DynamoDB: server_side_encryption { enabled = true, kms_key_arn = <cmk> }.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/main.tf` | 119 | aws_dynamodb_table.tflock |

### `CKV_AWS_130` · — · 1× — **ACCEPTED (by design)**
*Ensure VPC subnets do not assign public IP by default*

**Remediation:** Subnet: map_public_ip_on_launch = false (ACCEPTED for the intentional public subnet).

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/network/main.tf` | 50 | module.network.aws_subnet.public |

### `CKV_AWS_28` · — · 1×
*Ensure DynamoDB point in time recovery (backup) is enabled*

**Remediation:** DynamoDB: point_in_time_recovery { enabled = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/bootstrap/main.tf` | 119 | aws_dynamodb_table.tflock |

### `CKV_AWS_37` · — · 1×
*Ensure Amazon EKS control plane logging is enabled for all log types*

**Remediation:** EKS: enabled_cluster_log_types = ["api","audit","authenticator","controllerManager","scheduler"].

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 47 | module.eks.aws_eks_cluster.this |

### `CKV_AWS_38` · — · 1× — **OPEN (priority)**
*Ensure Amazon EKS public endpoint not accessible to 0.0.0.0/0*

**Remediation:** EKS: restrict public_access_cidrs (no 0.0.0.0/0). Same root cause as AWS-0041.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 47 | module.eks.aws_eks_cluster.this |

### `CKV_AWS_39` · — · 1× — **OPEN (priority)**
*Ensure Amazon EKS public endpoint disabled*

**Remediation:** EKS: endpoint_public_access = false (or restrict CIDRs). Same root cause as AWS-0040.

| Path | Line | Resource |
|------|-----:|----------|
| `czid-infra/infra/state-foundation/foundation/modules/eks/main.tf` | 47 | module.eks.aws_eks_cluster.this |

## cypherid-workflow-infra — 118 findings

### `AWS-0104` · CRITICAL · 8×
*A security group rule should not allow unrestricted egress to any IP address.*

**Remediation:** Security group: restrict egress cidr_blocks to required destinations; remove 0.0.0.0/0.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn-batch-queue/main.tf` | 111 | module.idseq |
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn-batch-queue/main.tf` | 111 | module.idseq |
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 44 | module.idseq |
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 44 | module.idseq |
| `cypherid-workflow-infra/terraform/index-generation.tf` | 47 | module.idseq |
| `cypherid-workflow-infra/terraform/index-generation.tf` | 47 | module.idseq |
| `cypherid-workflow-infra/terraform/swipe.tf` | 170 | module.idseq |
| `cypherid-workflow-infra/terraform/swipe.tf` | 170 | module.idseq |

### `AWS-0031` · HIGH · 22×
*ECR images tags shouldn't be mutable.*

**Remediation:** ECR: set image_tag_mutability = "IMMUTABLE".

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |
| `cypherid-workflow-infra/terraform/ecr.tf` | 9 | module.idseq |

### `DS-0002` · HIGH · 4×
*Image user should not be 'root'*

**Remediation:** Dockerfile: add a USER directive with a non-root user before CMD/ENTRYPOINT.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/lambdas/Dockerfile` |  |  |
| `cypherid-workflow-infra/lambdas/taxon-indexing-concurrency-manager/Dockerfile` |  |  |
| `cypherid-workflow-infra/local-base-images/Dockerfile.node-base` |  |  |
| `cypherid-workflow-infra/local-base-images/Dockerfile.python-base` |  |  |

### `AWS-0086` · HIGH · 2×
*S3 Access block should block public ACL*

**Remediation:** Add aws_s3_bucket_public_access_block { block_public_acls = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |

### `AWS-0087` · HIGH · 2×
*S3 Access block should block public policy*

**Remediation:** Add aws_s3_bucket_public_access_block { block_public_policy = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |

### `AWS-0091` · HIGH · 2×
*S3 Access Block should Ignore Public ACL*

**Remediation:** Add aws_s3_bucket_public_access_block { ignore_public_acls = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |

### `AWS-0093` · HIGH · 2×
*S3 Access block should restrict public bucket to limit access*

**Remediation:** Add aws_s3_bucket_public_access_block { restrict_public_buckets = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |

### `AWS-0095` · HIGH · 2×
*Unencrypted SNS topic.*

**Remediation:** SNS topic: set kms_master_key_id to a KMS key.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn/notifications.tf` | 34 | module.idseq |
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn/notifications.tf` | 34 | module.idseq |

### `AWS-0096` · HIGH · 2×
*Unencrypted SQS queue.*

**Remediation:** SQS queue: set kms_master_key_id (or sqs_managed_sse_enabled = true).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn/notifications.tf` | 73 | module.idseq |
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn/notifications.tf` | 73 | module.idseq |

### `AWS-0130` · HIGH · 2×
*aws_instance should activate session tokens for Instance Metadata Service.*

**Remediation:** Launch template/instance: metadata_options { http_tokens = "required" } (IMDSv2).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn-batch-queue/main.tf` | 98 | module.idseq |
| `cypherid-workflow-infra/github.com/chanzuckerberg/swipe?ref=v1.4.9/terraform/modules/swipe-sfn-batch-queue/main.tf` | 98 | module.idseq |

### `AWS-0132` · HIGH · 2×
*S3 encryption should use Customer Managed Keys*

**Remediation:** S3: aws_s3_bucket_server_side_encryption_configuration with a KMS CMK (aws:kms).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq |

### `DS-0015` · HIGH · 2×
*'yum clean all' missing*

**Remediation:** Dockerfile: add 'yum clean all' (or 'rm -rf /var/cache/yum') after yum install.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/local-base-images/Dockerfile.node-base` | 4 |  |
| `cypherid-workflow-infra/local-base-images/Dockerfile.python-base` | 4 |  |

### `DS-0029` · HIGH · 1×
*'apt-get' missing '--no-install-recommends'*

**Remediation:** Dockerfile: add '--no-install-recommends' to apt-get install.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/lambdas/taxon-indexing-concurrency-manager/Dockerfile` | 3 |  |

### `CKV_AWS_136` · — · 11×
*Ensure that ECR repositories are encrypted using KMS*

**Remediation:** ECR: encryption_configuration { encryption_type = "KMS" }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["consensus-genome"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["diamond"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["phylotree-ng"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["index-generation"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["amr"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["long-read-mngs"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["bulk-download"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["host-genome-generation"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["benchmark"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["minimap2"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["short-read-mngs"] |

### `CKV_AWS_51` · — · 11×
*Ensure ECR Image Tags are immutable*

**Remediation:** ECR: image_tag_mutability = "IMMUTABLE".

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["consensus-genome"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["diamond"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["phylotree-ng"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["index-generation"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["amr"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["long-read-mngs"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["bulk-download"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["host-genome-generation"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["benchmark"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["minimap2"] |
| `cypherid-workflow-infra/terraform/ecr.tf` | 6 | module.idseq.aws_ecr_repository.workflow-repositories["short-read-mngs"] |

### `CKV_AWS_341` · — · 5×
*Ensure Launch template should not have a metadata response hop limit greater than 1*

**Remediation:** Launch template: metadata_options { http_put_response_hop_limit = 1 }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 51 | module.idseq.aws_launch_template.index_generation_launch_template |
| `cypherid-workflow-infra/terraform/modules/scalable-alignment-batch/main.tf` | 33 | module.idseq.module.diamond.aws_launch_template.alignment_launch_template_ec2 |
| `cypherid-workflow-infra/terraform/modules/scalable-alignment-batch/main.tf` | 33 | module.idseq.module.minimap2.aws_launch_template.alignment_launch_template_ec2 |
| `cypherid-workflow-infra/terraform/modules/scalable-alignment-batch/main.tf` | 69 | module.idseq.module.diamond.aws_launch_template.alignment_launch_template_spot |
| `cypherid-workflow-infra/terraform/modules/scalable-alignment-batch/main.tf` | 69 | module.idseq.module.minimap2.aws_launch_template.alignment_launch_template_spot |

### `CKV_AWS_23` · — · 3×
*Ensure every security group and rule has a description*

**Remediation:** Add a 'description' to every security group and every ingress/egress rule.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 37 | module.idseq.aws_security_group.idseq |
| `cypherid-workflow-infra/terraform/index-generation.tf` | 40 | module.idseq.aws_security_group.index_generation |
| `cypherid-workflow-infra/terraform/swipe.tf` | 168 | module.idseq.aws_vpc_security_group_egress_rule.aegea-ecs-allow_all_traffic_ipv4 |

### `CKV_AWS_115` · — · 2×
*Ensure that AWS Lambda function is configured for function-level concurrent execution limit*

**Remediation:** Lambda: set reserved_concurrent_executions.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_116` · — · 2×
*Ensure that AWS Lambda function is configured for a Dead Letter Queue(DLQ)*

**Remediation:** Lambda: add dead_letter_config (SQS/SNS DLQ).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_117` · — · 2×
*Ensure that AWS Lambda function is configured inside a VPC*

**Remediation:** Lambda: add vpc_config (subnet_ids + security_group_ids).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_173` · — · 2×
*Check encryption settings for Lambda environmental variable*

**Remediation:** Lambda: encrypt environment variables with a KMS CMK (kms_key_arn).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_272` · — · 2×
*Ensure AWS Lambda function is configured to validate code-signing*

**Remediation:** Lambda: set code_signing_config_arn (Signer).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_382` · — · 2×
*Ensure no security groups allow egress from 0.0.0.0:0 to port -1*

**Remediation:** Security group: restrict egress; avoid all-ports (-1) to 0.0.0.0/0.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 37 | module.idseq.aws_security_group.idseq |
| `cypherid-workflow-infra/terraform/index-generation.tf` | 40 | module.idseq.aws_security_group.index_generation |

### `CKV_AWS_50` · — · 2×
*X-Ray tracing is enabled for Lambda*

**Remediation:** Lambda: tracing_config { mode = "Active" } (X-Ray).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/index-generation.tf` | 205 | module.idseq.aws_lambda_function.start_index_generation |
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV2_AWS_11` · — · 1×
*Ensure VPC flow logging is enabled in all VPCs*

**Remediation:** VPC: add aws_flow_log for the VPC -> CloudWatch/S3.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 5 | module.idseq.aws_vpc.idseq |

### `CKV2_AWS_12` · — · 1×
*Ensure the default security group of every VPC restricts all traffic*

**Remediation:** Add aws_default_security_group for the VPC that denies all ingress/egress.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 5 | module.idseq.aws_vpc.idseq |

### `CKV2_AWS_34` · — · 1×
*AWS SSM Parameter should be Encrypted*

**Remediation:** Address per check: AWS SSM Parameter should be Encrypted. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-aws-ssm-parameter-is-encrypted

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/swipe.tf` | 126 | module.idseq.aws_ssm_parameter.sfn_notifications_queue_arn |

### `CKV2_AWS_5` · — · 1×
*Ensure that Security Groups are attached to another resource*

**Remediation:** Attach the security group to a resource (ENI/instance/LB), or delete it if unused.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/swipe.tf` | 159 | module.idseq.aws_security_group.aegea-ecs-sg |

### `CKV2_AWS_57` · — · 1×
*Ensure Secrets Manager secrets should have automatic rotation enabled*

**Remediation:** Address per check: Ensure Secrets Manager secrets should have automatic rotation enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-2-57

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 21 | module.idseq.module.cloudwatch-alerting.aws_secretsmanager_secret.slack_oauth_token[0] |

### `CKV2_AWS_6` · — · 1×
*Ensure that S3 bucket has a Public Access block*

**Remediation:** S3: add aws_s3_bucket_public_access_block (all four flags true).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq.aws_s3_bucket.workflows |

### `CKV2_AWS_62` · — · 1×
*Ensure S3 buckets should have event notifications enabled*

**Remediation:** S3: add aws_s3_bucket_notification, or skip with justification if events aren't needed.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq.aws_s3_bucket.workflows |

### `CKV_AWS_130` · — · 1× — **ACCEPTED (by design)**
*Ensure VPC subnets do not assign public IP by default*

**Remediation:** Subnet: map_public_ip_on_launch = false (ACCEPTED for the intentional public subnet).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/batch_vpc.tf` | 26 | module.idseq.aws_subnet.idseq |

### `CKV_AWS_144` · — · 1×
*Ensure that S3 bucket has cross-region replication enabled*

**Remediation:** S3: add cross-region replication (replication_configuration) — or skip if not required.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq.aws_s3_bucket.workflows |

### `CKV_AWS_145` · — · 1×
*Ensure that S3 buckets are encrypted with KMS by default*

**Remediation:** S3: default encryption with a KMS CMK (aws:kms), not SSE-S3.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq.aws_s3_bucket.workflows |

### `CKV_AWS_149` · — · 1×
*Ensure that Secrets Manager secret is encrypted using KMS CMK*

**Remediation:** Secrets Manager: set kms_key_id to a KMS CMK.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 21 | module.idseq.module.cloudwatch-alerting.aws_secretsmanager_secret.slack_oauth_token[0] |

### `CKV_AWS_158` · — · 1×
*Ensure that CloudWatch Log Group is encrypted by KMS*

**Remediation:** CloudWatch Log Group: set kms_key_id (KMS encryption).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 11 | module.idseq.module.cloudwatch-alerting.aws_cloudwatch_log_group.new_groups |

### `CKV_AWS_18` · — · 1×
*Ensure the S3 bucket has access logging enabled*

**Remediation:** S3: add aws_s3_bucket_logging targeting a dedicated log bucket.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 14 | module.idseq.aws_s3_bucket.workflows |

### `CKV_AWS_290` · — · 1×
*Ensure IAM policies does not allow write access without constraints*

**Remediation:** IAM policy: constrain write actions with specific resources/conditions.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 16 | module.idseq.module.taxon-indexing-concurrency-manager.aws_iam_role_policy.taxon_indexing_concurrency_manager_role |

### `CKV_AWS_300` · — · 1×
*Ensure S3 lifecycle configuration sets period for aborting failed uploads*

**Remediation:** S3 lifecycle: add abort_incomplete_multipart_upload { days_after_initiation = N }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/buckets.tf` | 26 | module.idseq.aws_s3_bucket_lifecycle_configuration.workflows |

### `CKV_AWS_338` · — · 1×
*Ensure CloudWatch log groups retains logs for at least 1 year*

**Remediation:** CloudWatch Log Group: retention_in_days >= 365.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 11 | module.idseq.module.cloudwatch-alerting.aws_cloudwatch_log_group.new_groups |

### `CKV_AWS_355` · — · 1×
*Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions*

**Remediation:** IAM policy: scope Resource to specific ARNs instead of "*".

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 16 | module.idseq.module.taxon-indexing-concurrency-manager.aws_iam_role_policy.taxon_indexing_concurrency_manager_role |

### `CKV_AWS_363` · — · 1×
*Ensure Lambda Runtime is not deprecated*

**Remediation:** Address per check: Ensure Lambda Runtime is not deprecated. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-363

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/taxon-indexing-concurrency-manager/main.tf` | 60 | module.idseq.module.taxon-indexing-concurrency-manager.aws_lambda_function.taxon_indexing_concurrency_manager |

### `CKV_AWS_364` · — · 1×
*Ensure that AWS Lambda function permissions delegated to AWS services are limited by SourceArn or SourceAccount*

**Remediation:** Lambda permission: scope delegated permissions to specific source ARNs.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 39 | module.idseq.module.cloudwatch-alerting.aws_lambda_permission.idseq_alerting_cloudwatch |

### `CKV_AWS_66` · — · 1×
*Ensure that CloudWatch Log Group specifies retention days*

**Remediation:** CloudWatch Log Group: set retention_in_days.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/modules/cloudwatch-alerting/main.tf` | 11 | module.idseq.module.cloudwatch-alerting.aws_cloudwatch_log_group.new_groups |

### `CKV_TF_1` · — · 1×
*Ensure Terraform module sources use a commit hash*

**Remediation:** Pin module 'source' to an immutable commit SHA (?ref=<sha>), not a tag/branch.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-workflow-infra/terraform/swipe.tf` | 1 | module.idseq.swipe |

## cypherid-web-infra — 591 findings

### `CKV_TF_1` · — · 121×
*Ensure Terraform module sources use a commit hash*

**Remediation:** Pin module 'source' to an immutable commit SHA (?ref=<sha>), not a tag/branch.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/accounts/idseq-dev/main.tf` | 1 | terraform-aws-tfstate-backend |
| `cypherid-web-infra/terraform/accounts/idseq-prod/main.tf` | 5 | terraform-aws-tfstate-backend |
| `cypherid-web-infra/terraform/accounts/idseq-staging/main.tf` | 1 | terraform-aws-tfstate-backend |
| `cypherid-web-infra/terraform/envs/dev/access-management/github-actions-runner-permissions.tf` | 6 | czid_web_private_gh_actions_executor |
| `cypherid-web-infra/terraform/envs/dev/auth0/main.tf` | 299 | auth0-ssm-params |
| `cypherid-web-infra/terraform/envs/dev/db/main.tf` | 41 | db-params |
| `cypherid-web-infra/terraform/envs/dev/db/secrets.tf` | 31 | db_password |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 203 | web-params |
| `cypherid-web-infra/terraform/envs/dev/eks/main.tf` | 1 | eks-cluster |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 124 | aws-s3-batch-taxon-indexing-private-bucket |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 165 | gh_actions_executor |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 49 | idseq-heatmap-es-param |
| `cypherid-web-infra/terraform/envs/dev/iam-password-policy/main.tf` | 1 | aws-iam-password-policy |
| `cypherid-web-infra/terraform/envs/dev/params-secrets/main.tf` | 1 | aws-params-secrets-setup |
| `cypherid-web-infra/terraform/envs/dev/redis/main.tf` | 1 | elasticache_secure |
| `cypherid-web-infra/terraform/envs/dev/resque/main.tf` | 1 | resque |
| `cypherid-web-infra/terraform/envs/dev/resque/main.tf` | 14 | resque-pipeline-monitor |
| `cypherid-web-infra/terraform/envs/dev/resque/main.tf` | 27 | resque-result-monitor |
| `cypherid-web-infra/terraform/envs/dev/resque/main.tf` | 40 | resque-scheduler |
| `cypherid-web-infra/terraform/envs/dev/resque/main.tf` | 53 | shoryuken |
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 10 | assets-cert |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 248 | parameters-policy |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 267 | web-service-params |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 290 | staging |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 302 | staging_east |
| `cypherid-web-infra/terraform/envs/prod/access-management/github-actions-runner-permissions.tf` | 6 | czid_web_private_gh_actions_executor |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 107 | idseq-batch |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 13 | images |
| `cypherid-web-infra/terraform/envs/prod/db/secrets.tf` | 1 | db_password |
| `cypherid-web-infra/terraform/envs/prod/downloads/main.tf` | 18 | downloads_iam_policy |
| `cypherid-web-infra/terraform/envs/prod/downloads/main.tf` | 37 | downloads_v1_iam_policy |
| `cypherid-web-infra/terraform/envs/prod/downloads/main.tf` | 51 | downloads_v1_iam_policy_for_old_samples_bucket |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 1 | ecs-cluster |
| `cypherid-web-infra/terraform/envs/prod/eks/main.tf` | 1 | eks-cluster |
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/iam.tf` | 1 | policy-params-service |
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/iam.tf` | 11 | ecs-role |
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 88 | parameters |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 123 | aws-s3-batch-taxon-indexing-private-bucket |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 16 | idseq-heatmap-es-param |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 163 | gh_actions_executor |
| `cypherid-web-infra/terraform/envs/prod/iam-password-policy/main.tf` | 1 | aws-iam-password-policy |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 40 | czid-assets-cert |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 39 | assets-cert |
| `cypherid-web-infra/terraform/envs/prod/params-secrets/main.tf` | 1 | aws-params-secrets-setup |
| `cypherid-web-infra/terraform/envs/prod/redis/main.tf` | 1 | elasticache_secure |
| `cypherid-web-infra/terraform/envs/prod/resque/main.tf` | 1 | resque |
| `cypherid-web-infra/terraform/envs/prod/resque/main.tf` | 14 | resque-pipeline-monitor |
| `cypherid-web-infra/terraform/envs/prod/resque/main.tf` | 27 | resque-result-monitor |
| `cypherid-web-infra/terraform/envs/prod/resque/main.tf` | 40 | resque-scheduler |
| `cypherid-web-infra/terraform/envs/prod/s3-tf-state/main.tf` | 1 | terraform-aws-tfstate-backend |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 12 | assets-cert |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 12 | czid-assets-cert |
| `cypherid-web-infra/terraform/envs/prod/web/czid-main.tf` | 19 | czid-web-service |
| `cypherid-web-infra/terraform/envs/prod/web/czid-main.tf` | 5 | czid-prod-cert |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 234 | parameters-policy |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 244 | web-service-params |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 267 | prod |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 282 | prod_east |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 302 | web-service |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 15 | czid_help_cert |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 15 | help_cert |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 13 | assets-cert |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 13 | czid-assets-cert |
| `cypherid-web-infra/terraform/envs/sandbox/eks/main.tf` | 1 | eks-cluster |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 123 | aws-s3-batch-taxon-indexing-private-bucket |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 49 | idseq-heatmap-es-param |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 40 | assets-cert |
| `cypherid-web-infra/terraform/envs/sandbox/redis/main.tf` | 1 | elasticache_secure |
| `cypherid-web-infra/terraform/envs/sandbox/resque/main.tf` | 1 | resque |
| `cypherid-web-infra/terraform/envs/sandbox/resque/main.tf` | 14 | resque-scheduler |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 14 | czid-assets-cert |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 254 | parameters-policy |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 264 | web-service-params |
| `cypherid-web-infra/terraform/envs/staging/access-management/github-actions-runner-permissions.tf` | 6 | czid_web_private_gh_actions_executor |
| `cypherid-web-infra/terraform/envs/staging/auth0/main.tf` | 136 | auth0-ssm-params |
| `cypherid-web-infra/terraform/envs/staging/batch/main.tf` | 17 | idseq-batch |
| `cypherid-web-infra/terraform/envs/staging/db/main.tf` | 41 | db-params |
| `cypherid-web-infra/terraform/envs/staging/db/secrets.tf` | 31 | db_password |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 129 | web-params |
| `cypherid-web-infra/terraform/envs/staging/eks/main.tf` | 1 | eks-cluster |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 138 | parameters |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 124 | aws-s3-batch-taxon-indexing-private-bucket |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 165 | gh_actions_executor |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 49 | idseq-heatmap-es-param |
| `cypherid-web-infra/terraform/envs/staging/iam-password-policy/main.tf` | 1 | aws-iam-password-policy |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 39 | assets-cert |
| `cypherid-web-infra/terraform/envs/staging/params-secrets/main.tf` | 1 | aws-params-secrets-setup |
| `cypherid-web-infra/terraform/envs/staging/redis/main.tf` | 1 | elasticache_secure |
| `cypherid-web-infra/terraform/envs/staging/resque/main.tf` | 1 | resque |
| `cypherid-web-infra/terraform/envs/staging/resque/main.tf` | 14 | resque-pipeline-monitor |
| `cypherid-web-infra/terraform/envs/staging/resque/main.tf` | 27 | resque-result-monitor |
| `cypherid-web-infra/terraform/envs/staging/resque/main.tf` | 40 | resque-scheduler |
| `cypherid-web-infra/terraform/envs/staging/resque/main.tf` | 53 | shoryuken |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 10 | assets-cert |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 248 | parameters-policy |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 267 | web-service-params |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 290 | staging |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 302 | staging_east |
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 95 | module.web-service.module.alb.sg |
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 87 | module.elasticsearch.es-sg |
| `cypherid-web-infra/terraform/modules/aws-elb-access-logs-bucket-v0.420.0/main.tf` | 26 | module.aws-elb-access-logs-bucket.aws-bucket |
| `cypherid-web-infra/terraform/modules/aws-env-v4.0.0/vpc.tf` | 61 | module.aws-env.vpc |
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 148 | module.ecs-cluster.attach-logs |
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 279 | module.ecs-cluster.sg |
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 47 | module.ecs-cluster.logs |
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 73 | module.ecs-cluster.profile |
| `cypherid-web-infra/terraform/modules/ecs-service-with-alb-v0.421.0/service.tf` | 24 | module.web-service.alb-sg |
| `cypherid-web-infra/terraform/modules/ecs-service-with-alb-v0.421.0/service.tf` | 49 | module.web-service.container-sg |
| `cypherid-web-infra/terraform/modules/happy-env-eks/acm.tf` | 7 | module.happy.cert |
| `cypherid-web-infra/terraform/modules/happy-env-eks/db.tf` | 7 | module.happy.dbs |
| `cypherid-web-infra/terraform/modules/happy-env-eks/ecr.tf` | 2 | module.happy.ecrs |
| `cypherid-web-infra/terraform/modules/happy-env-eks/s3.tf` | 1 | module.happy.s3_buckets |
| `cypherid-web-infra/terraform/modules/happy-github-ci-role/dynamo.tf` | 1 | module.happy.module.happy_github_ci_role.dynamodb_writer |
| `cypherid-web-infra/terraform/modules/happy-github-ci-role/ecr.tf` | 13 | module.happy.module.happy_github_ci_role.ecr_writer_policy[0] |
| `cypherid-web-infra/terraform/modules/happy-github-ci-role/ecr.tf` | 24 | module.happy.module.happy_github_ci_role.autocreated_ecr_writer_policy |
| `cypherid-web-infra/terraform/modules/idseq-s3-tar-writer/main.tf` | 1 | module.idseq-s3-tar-writer.aws-ecr-repo |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/kiam/kiam.tf` | 48 | module.k8s-core.module.kiam.kiam-role |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/linkerd/main.tf` | 25 | module.k8s-core.module.linkerd.linkerd-service-account |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/nginx-ingress-controller/role.tf` | 1 | module.k8s-core.module.nginx_ingress.eks_service_account_nginx_role |
| `cypherid-web-infra/terraform/modules/kubernetes-aws-ssm-k8s-core-v5/main.tf` | 8 | service-account-role |
| `cypherid-web-infra/terraform/modules/web-acl-regional-v3.3.1/logging.tf` | 87 | module.web-service-waf.logs_bucket |

### `CKV2_AWS_6` · — · 21×
*Ensure that S3 bucket has a Public Access block*

**Remediation:** S3: add aws_s3_bucket_public_access_block (all four flags true).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 83 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 155 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 79 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 149 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV2_AWS_62` · — · 21×
*Ensure S3 buckets should have event notifications enabled*

**Remediation:** S3: add aws_s3_bucket_notification, or skip with justification if events aren't needed.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 83 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 155 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 79 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 149 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_144` · — · 21×
*Ensure that S3 bucket has cross-region replication enabled*

**Remediation:** S3: add cross-region replication (replication_configuration) — or skip if not required.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 83 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 155 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 79 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 149 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_145` · — · 21×
*Ensure that S3 buckets are encrypted with KMS by default*

**Remediation:** S3: default encryption with a KMS CMK (aws:kms), not SSE-S3.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 83 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 155 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 79 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 149 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_18` · — · 21×
*Ensure the S3 bucket has access logging enabled*

**Remediation:** S3: add aws_s3_bucket_logging targeting a dedicated log bucket.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 83 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/prod/db/bucket.tf` | 155 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 79 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 149 | aws_s3_bucket.samples_v1 |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_23` · — · 18×
*Ensure every security group and rule has a description*

**Remediation:** Add a 'description' to every security group and every ingress/egress rule.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 22 | aws_security_group_rule.sec_group_allow_tcp |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 31 | aws_security_group_rule.sec_group_outbound_tcp |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 40 | aws_security_group_rule.sec_group_outbound_czid |
| `cypherid-web-infra/terraform/envs/prod/db/main.tf` | 1 | aws_security_group.rds |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 29 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 34 | aws_security_group_rule.sec_group_allow_tcp |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 43 | aws_security_group_rule.sec_group_outbound_tcp |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 52 | aws_security_group_rule.sec_group_outbound_czid |
| `cypherid-web-infra/terraform/envs/sandbox/db/main.tf` | 1 | aws_security_group.rds |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 22 | aws_security_group_rule.sec_group_allow_tcp |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 31 | aws_security_group_rule.sec_group_outbound_tcp |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 40 | aws_security_group_rule.sec_group_outbound_czid |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 22 | aws_security_group_rule.sec_group_allow_tcp |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 31 | aws_security_group_rule.sec_group_outbound_tcp |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 40 | aws_security_group_rule.sec_group_outbound_czid |

### `CKV_AWS_21` · — · 15×
*Ensure all data stored in the S3 bucket have versioning enabled*

**Remediation:** S3: aws_s3_bucket_versioning { status = "Enabled" }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 160 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 85 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/db/bucket.tf` | 1 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 161 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/db/bucket.tf` | 5 | aws_s3_bucket.samples |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 91 | aws_s3_bucket.aegea-ecs-execute |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_356` · — · 15×
*Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions*

**Remediation:** IAM policy: scope Resource to specific ARNs instead of "*".

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/prod/access-management/github-actions-runner-permissions.tf` | 59 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 112 | aws_iam_policy_document.idseq-batch |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 34 | aws_iam_policy_document.lambda_ncbi_copy_role_policy |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 31 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 41 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/staging/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/staging/batch/main.tf` | 22 | aws_iam_policy_document.idseq-batch |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/modules/aws-env-v4.0.0/flow_logs.tf` | 52 | module.aws-env.aws_iam_policy_document.vpc_flow_logs |
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 79 | module.ecs-cluster.aws_iam_policy_document.ecs-policy |
| `cypherid-web-infra/terraform/modules/happy-github-ci-role/ecr.tf` | 34 | module.happy.module.happy_github_ci_role.aws_iam_policy_document.ecr_scanner |
| `cypherid-web-infra/terraform/modules/individual-attr/main.tf` | 120 | module.individual-attr.aws_iam_policy_document.packer_instance_policy |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/kiam/kiam.tf` | 59 | module.k8s-core.module.kiam.aws_iam_policy_document.kiam |

### `CKV2_AWS_32` · — · 14×
*Ensure CloudFront distribution has a response headers policy attached*

**Remediation:** CloudFront: attach a response_headers_policy_id.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV2_AWS_47` · — · 14×
*Ensure AWS CloudFront attached WAFv2 WebACL is configured with AMR for Log4j Vulnerability*

**Remediation:** CloudFront: attach a WAFv2 WebACL with AWS Managed Rules.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_111` · — · 14×
*Ensure IAM policies does not allow write access without constraints*

**Remediation:** IAM policy: constrain write actions with specific resources/conditions.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/prod/access-management/github-actions-runner-permissions.tf` | 59 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 112 | aws_iam_policy_document.idseq-batch |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 34 | aws_iam_policy_document.lambda_ncbi_copy_role_policy |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 31 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 41 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/staging/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/staging/batch/main.tf` | 22 | aws_iam_policy_document.idseq-batch |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/modules/aws-env-v4.0.0/flow_logs.tf` | 52 | module.aws-env.aws_iam_policy_document.vpc_flow_logs |
| `cypherid-web-infra/terraform/modules/happy-github-ci-role/ecr.tf` | 34 | module.happy.module.happy_github_ci_role.aws_iam_policy_document.ecr_scanner |
| `cypherid-web-infra/terraform/modules/individual-attr/main.tf` | 120 | module.individual-attr.aws_iam_policy_document.packer_instance_policy |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/kiam/kiam.tf` | 59 | module.k8s-core.module.kiam.aws_iam_policy_document.kiam |

### `CKV_AWS_174` · — · 14×
*Verify CloudFront Distribution Viewer Certificate is using TLS v1.2 or higher*

**Remediation:** CloudFront: viewer_certificate.minimum_protocol_version >= TLSv1.2_2021.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_310` · — · 14×
*Ensure CloudFront distributions should have origin failover configured*

**Remediation:** CloudFront: configure an origin_group for origin failover.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_374` · — · 14×
*Ensure AWS CloudFront web distribution has geo restriction enabled*

**Remediation:** CloudFront: restrictions { geo_restriction { restriction_type = ... } }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_68` · — · 14×
*CloudFront Distribution should have WAF enabled*

**Remediation:** CloudFront: set web_acl_id (attach a WAF).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_86` · — · 14×
*Ensure CloudFront distribution has Access Logging enabled*

**Remediation:** CloudFront: add logging_config (access logs to S3).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 59 | aws_cloudfront_distribution.czid_distribution |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 57 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/public/web/czid-assets.tf` | 27 | aws_cloudfront_distribution.czid-distribution |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 59 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 58 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV2_AWS_61` · — · 9×
*Ensure that an S3 bucket has a lifecycle configuration*

**Remediation:** S3: add aws_s3_bucket_lifecycle_configuration.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/maintenance/czid-main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/prod/maintenance/main.tf` | 12 | aws_s3_bucket.bucket |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/sandbox/maintenance/main.tf` | 12 | aws_s3_bucket.maintenance_bucket |
| `cypherid-web-infra/terraform/envs/staging/maintenance/main.tf` | 10 | aws_s3_bucket.maintenance_bucket |

### `CKV_AWS_158` · — · 9×
*Ensure that CloudWatch Log Group is encrypted by KMS*

**Remediation:** CloudWatch Log Group: set kms_key_id (KMS encryption).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 32 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 21 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 31 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 27 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/modules/aws-env-v4.0.0/flow_logs.tf` | 27 | module.aws-env.aws_cloudwatch_log_group.vpc |

### `CKV_AWS_305` · — · 9×
*Ensure CloudFront distribution has a default root object configured*

**Remediation:** CloudFront: set default_root_object.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/assets.tf` | 26 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/prod/web/czid-assets.tf` | 26 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |
| `cypherid-web-infra/terraform/envs/sandbox/web/czid-assets.tf` | 28 | aws_cloudfront_distribution.czid-assets-distribution |
| `cypherid-web-infra/terraform/envs/staging/web/assets.tf` | 24 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_109` · — · 8×
*Ensure IAM policies does not allow permissions management / resource exposure without constraints*

**Remediation:** IAM: constrain permissions-management actions (e.g. iam:*) with conditions / specific resources.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/prod/access-management/github-actions-runner-permissions.tf` | 59 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 34 | aws_iam_policy_document.lambda_ncbi_copy_role_policy |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 31 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 41 | aws_iam_policy_document.idseq-web |
| `cypherid-web-infra/terraform/envs/staging/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 37 | aws_iam_policy_document.idseq-web |

### `CKV_AWS_338` · — · 8×
*Ensure CloudWatch log groups retains logs for at least 1 year*

**Remediation:** CloudWatch Log Group: retention_in_days >= 365.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 32 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 21 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 31 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 27 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |

### `CKV_AWS_66` · — · 8×
*Ensure that CloudWatch Log Group specifies retention days*

**Remediation:** CloudWatch Log Group: set retention_in_days.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 32 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 21 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 31 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 27 | aws_cloudwatch_log_group.ecs |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/esdomain.tf` | 1 | aws_cloudwatch_log_group.elasticsearch-log-publishing-policy |

### `CKV2_AWS_38` · — · 6×
*Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones*

**Remediation:** Route53: enable DNSSEC signing on the hosted zone.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/route53/main.tf` | 27 | aws_route53_zone.happy-env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/dev/route53/main.tf` | 6 | aws_route53_zone.env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/prod/route53/main.tf` | 19 | aws_route53_zone.seqtoid-org |
| `cypherid-web-infra/terraform/envs/prod/route53/main.tf` | 25 | aws_route53_zone.happy-seqtoid-org |
| `cypherid-web-infra/terraform/envs/staging/route53/main.tf` | 27 | aws_route53_zone.happy-env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/staging/route53/main.tf` | 6 | aws_route53_zone.env-seqtoid-org |

### `CKV2_AWS_39` · — · 6×
*Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones*

**Remediation:** Route53: enable DNS query logging on the hosted zone.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/route53/main.tf` | 27 | aws_route53_zone.happy-env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/dev/route53/main.tf` | 6 | aws_route53_zone.env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/prod/route53/main.tf` | 19 | aws_route53_zone.seqtoid-org |
| `cypherid-web-infra/terraform/envs/prod/route53/main.tf` | 25 | aws_route53_zone.happy-seqtoid-org |
| `cypherid-web-infra/terraform/envs/staging/route53/main.tf` | 27 | aws_route53_zone.happy-env-seqtoid-org |
| `cypherid-web-infra/terraform/envs/staging/route53/main.tf` | 6 | aws_route53_zone.env-seqtoid-org |

### `CKV2_AWS_5` · — · 6×
*Ensure that Security Groups are attached to another resource*

**Remediation:** Attach the security group to a resource (ENI/instance/LB), or delete it if unused.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 183 | aws_security_group.aegea-ecs |
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 29 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 110 | aws_security_group.aegea-ecs |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 17 | aws_security_group.glue_sec_group |

### `CKV_AWS_26` · — · 6×
*Ensure all data stored in the SNS topic is encrypted*

**Remediation:** SNS topic: set kms_master_key_id (KMS encryption).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/cloudwatch_dashboard.tf` | 582 | aws_sns_topic.aws_heatmap_topic |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/cloudwatch_dashboard.tf` | 582 | aws_sns_topic.aws_heatmap_topic |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/cloudwatch_dashboard.tf` | 582 | aws_sns_topic.aws_heatmap_topic |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/cloudwatch_dashboard.tf` | 582 | aws_sns_topic.aws_heatmap_topic |
| `cypherid-web-infra/terraform/modules/panther-s3-ingest-v2.0.1/sns.tf` | 25 | module.web-service-waf.module.panther-s3.aws_sns_topic.log_processing |
| `cypherid-web-infra/terraform/modules/panther-s3-ingest-v2.0.1/sns.tf` | 25 | module.web-service-waf.module.panther-s3[0].aws_sns_topic.log_processing |

### `CKV_AWS_20` · — · 5×
*S3 Bucket has an ACL defined which allows public READ access.*

**Remediation:** S3: remove public-read ACL; keep ACL private and use a scoped bucket policy.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/bucket.tf` | 1 | aws_s3_bucket.pipeline_public_assets |
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 353 | aws_s3_bucket.redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 6 | aws_s3_bucket.czid_help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 6 | aws_s3_bucket.help_redirect_bucket |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 27 | aws_s3_bucket.redirect_bucket |

### `CKV2_AWS_46` · — · 4×
*Ensure AWS CloudFront Distribution with S3 have Origin Access set to enabled*

**Remediation:** Address per check: Ensure AWS CloudFront Distribution with S3 have Origin Access set to enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/ensure-aws-cloudfromt-distribution-with-s3-have-origin-access-set-to-enabled

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |

### `CKV2_AWS_8` · — · 4×
*Ensure that RDS clusters has backup plan of AWS Backup*

**Remediation:** Address per check: Ensure that RDS clusters has backup plan of AWS Backup. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-rds-clusters-has-backup-plan-of-aws-backup

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_107` · — · 4×
*Ensure IAM policies does not allow credentials exposure*

**Remediation:** Address per check: Ensure IAM policies does not allow credentials exposure. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/ensure-iam-policies-do-not-allow-credentials-exposure

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/prod/access-management/github-actions-runner-permissions.tf` | 59 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/envs/staging/access-management/github-actions-runner-permissions.tf` | 88 | aws_iam_policy_document.ci_cd_policy_document |
| `cypherid-web-infra/terraform/modules/k8s-core-v5.5.1/kiam/kiam.tf` | 59 | module.k8s-core.module.kiam.aws_iam_policy_document.kiam |

### `CKV_AWS_118` · — · 4×
*Ensure that enhanced monitoring is enabled for Amazon RDS instances*

**Remediation:** Address per check: Ensure that enhanced monitoring is enabled for Amazon RDS instances. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/ensure-that-enhanced-monitoring-is-enabled-for-amazon-rds-instances

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 21 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 24 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |

### `CKV_AWS_139` · — · 4×
*Ensure that RDS clusters have deletion protection enabled*

**Remediation:** Address per check: Ensure that RDS clusters have deletion protection enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-that-rds-clusters-and-instances-have-deletion-protection-enabled

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_195` · — · 4×
*Ensure Glue component has a security configuration associated*

**Remediation:** Address per check: Ensure Glue component has a security configuration associated. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-aws-glue-component-is-associated-with-a-security-configuration

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/heatmap-optimization/main.tf` | 134 | aws_glue_job.batch-taxon-indexing |
| `cypherid-web-infra/terraform/envs/prod/heatmap-optimization/main.tf` | 132 | aws_glue_job.batch-taxon-indexing |
| `cypherid-web-infra/terraform/envs/sandbox/heatmap-optimization/main.tf` | 132 | aws_glue_job.batch-taxon-indexing |
| `cypherid-web-infra/terraform/envs/staging/heatmap-optimization/main.tf` | 134 | aws_glue_job.batch-taxon-indexing |

### `CKV_AWS_226` · — · 4×
*Ensure DB instance gets all minor upgrades automatically*

**Remediation:** Address per check: Ensure DB instance gets all minor upgrades automatically. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-aws-db-instance-gets-all-minor-upgrades-automatically

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 21 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 24 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |

### `CKV_AWS_313` · — · 4×
*Ensure RDS cluster configured to copy tags to snapshots*

**Remediation:** Address per check: Ensure RDS cluster configured to copy tags to snapshots. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-313

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_324` · — · 4×
*Ensure that RDS Cluster log capture is enabled*

**Remediation:** Address per check: Ensure that RDS Cluster log capture is enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-324

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_325` · — · 4×
*Ensure that RDS Cluster audit logging is enabled for MySQL engine*

**Remediation:** Address per check: Ensure that RDS Cluster audit logging is enabled for MySQL engine. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-325

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_326` · — · 4×
*Ensure that RDS Aurora Clusters have backtracking enabled*

**Remediation:** Address per check: Ensure that RDS Aurora Clusters have backtracking enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-326

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_327` · — · 4×
*Ensure RDS Clusters are encrypted using KMS CMKs*

**Remediation:** Address per check: Ensure RDS Clusters are encrypted using KMS CMKs. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-327

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 1 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 8 | aws_rds_cluster.db |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 1 | aws_rds_cluster.db |

### `CKV_AWS_34` · — · 4×
*Ensure CloudFront distribution ViewerProtocolPolicy is set to HTTPS*

**Remediation:** Address per check: Ensure CloudFront distribution ViewerProtocolPolicy is set to HTTPS. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/networking-32

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/web/main.tf` | 362 | aws_cloudfront_distribution.redirect_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/czid-main.tf` | 33 | aws_cloudfront_distribution.czid_help_s3_distribution |
| `cypherid-web-infra/terraform/envs/prod/zendesk/main.tf` | 33 | aws_cloudfront_distribution.help_s3_distribution |
| `cypherid-web-infra/terraform/envs/public/web/assets.tf` | 36 | aws_cloudfront_distribution.distribution |

### `CKV_AWS_353` · — · 4×
*Ensure that RDS instances have performance insights enabled*

**Remediation:** Address per check: Ensure that RDS instances have performance insights enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-353

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/prod/db/aurora.tf` | 21 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/sandbox/db/aurora.tf` | 24 | aws_rds_cluster_instance.db[0] |
| `cypherid-web-infra/terraform/envs/staging/db/aurora.tf` | 19 | aws_rds_cluster_instance.db[0] |

### `CKV_AWS_65` · — · 4×
*Ensure container insights are enabled on ECS cluster*

**Remediation:** Address per check: Ensure container insights are enabled on ECS cluster. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-logging-11

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/ecs/main.tf` | 156 | aws_ecs_cluster.idseq-fargate-tasks |
| `cypherid-web-infra/terraform/envs/prod/ecs/main.tf` | 81 | aws_ecs_cluster.idseq-fargate-tasks |
| `cypherid-web-infra/terraform/envs/sandbox/ecs/main.tf` | 157 | aws_ecs_cluster.idseq-fargate-tasks |
| `cypherid-web-infra/terraform/envs/staging/ecs/main.tf` | 87 | aws_ecs_cluster.idseq-fargate-tasks |

### `CKV_AWS_136` · — · 3×
*Ensure that ECR repositories are encrypted using KMS*

**Remediation:** ECR: encryption_configuration { encryption_type = "KMS" }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 360 | aws_ecr_repository.web-repository |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 22 | aws_ecr_repository.web-repository |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 359 | aws_ecr_repository.web-repository |

### `CKV_AWS_51` · — · 3×
*Ensure ECR Image Tags are immutable*

**Remediation:** ECR: image_tag_mutability = "IMMUTABLE".

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/dev/web/main.tf` | 360 | aws_ecr_repository.web-repository |
| `cypherid-web-infra/terraform/envs/sandbox/web/main.tf` | 22 | aws_ecr_repository.web-repository |
| `cypherid-web-infra/terraform/envs/staging/web/main.tf` | 359 | aws_ecr_repository.web-repository |

### `CKV_K8S_28` · — · 3×
*Minimize the admission of containers with the NET_RAW capability*

**Remediation:** Address per check: Minimize the admission of containers with the NET_RAW capability. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-27

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/modules/kubernetes-aws-ssm-k8s-core-v5/main.tf` | 39 | kubernetes_deployment.kubernetes-aws-ssm |

### `CKV_K8S_29` · — · 3×
*Apply security context to your pods, deployments and daemon_sets*

**Remediation:** Address per check: Apply security context to your pods, deployments and daemon_sets. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/ensure-securitycontext-is-applied-to-pods-and-containers

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/modules/kubernetes-aws-ssm-k8s-core-v5/main.tf` | 39 | kubernetes_deployment.kubernetes-aws-ssm |

### `CKV_K8S_30` · — · 3×
*Apply security context to your pods and containers*

**Remediation:** Address per check: Apply security context to your pods and containers. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-28

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/modules/kubernetes-aws-ssm-k8s-core-v5/main.tf` | 39 | kubernetes_deployment.kubernetes-aws-ssm |

### `CKV_K8S_43` · — · 3×
*Image should use digest*

**Remediation:** Address per check: Image should use digest. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-39

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/modules/kubernetes-aws-ssm-k8s-core-v5/main.tf` | 39 | kubernetes_deployment.kubernetes-aws-ssm |

### `CKV2_AWS_20` · — · 2×
*Ensure that ALB redirects HTTP requests into HTTPS ones*

**Remediation:** Address per check: Ensure that ALB redirects HTTP requests into HTTPS ones. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-that-alb-redirects-http-requests-into-https-ones

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 20 | module.web-service.module.alb.aws_alb.service |
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 32 | module.web-service.module.alb.aws_alb.service-access-logs |

### `CKV2_AWS_28` · — · 2×
*Ensure public facing ALB are protected by WAF*

**Remediation:** Address per check: Ensure public facing ALB are protected by WAF. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-public-facing-alb-are-protected-by-waf

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 20 | module.web-service.module.alb.aws_alb.service |
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 32 | module.web-service.module.alb.aws_alb.service-access-logs |

### `CKV_AWS_131` · — · 2×
*Ensure that ALB drops HTTP headers*

**Remediation:** Address per check: Ensure that ALB drops HTTP headers. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/ensure-that-alb-drops-http-headers

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 20 | module.web-service.module.alb.aws_alb.service |
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 32 | module.web-service.module.alb.aws_alb.service-access-logs |

### `CKV_AWS_150` · — · 2×
*Ensure that Load Balancer has deletion protection enabled*

**Remediation:** Address per check: Ensure that Load Balancer has deletion protection enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-150

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 20 | module.web-service.module.alb.aws_alb.service |
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 32 | module.web-service.module.alb.aws_alb.service-access-logs |

### `CKV_AWS_61` · — · 2×
*Ensure AWS IAM policy does not allow assume role permission across all services*

**Remediation:** Address per check: Ensure AWS IAM policy does not allow assume role permission across all services. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/bc-aws-iam-45

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/panther-s3-ingest-v2.0.1/main.tf` | 10 | module.web-service-waf.module.panther-s3.aws_iam_role.log_processing_role |
| `cypherid-web-infra/terraform/modules/panther-s3-ingest-v2.0.1/main.tf` | 10 | module.web-service-waf.module.panther-s3[0].aws_iam_role.log_processing_role |

### `CKV_K8S_10` · — · 2×
*CPU requests should be set*

**Remediation:** Address per check: CPU requests should be set. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-9

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_11` · — · 2×
*CPU Limits should be set*

**Remediation:** Address per check: CPU Limits should be set. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-10

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_12` · — · 2×
*Memory Limits should be set*

**Remediation:** Address per check: Memory Limits should be set. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-11

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_13` · — · 2×
*Memory requests should be set*

**Remediation:** Address per check: Memory requests should be set. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-12

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_14` · — · 2×
*Image Tag should be fixed - not latest or blank*

**Remediation:** Address per check: Image Tag should be fixed - not latest or blank. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-13

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_8` · — · 2×
*Liveness Probe Should be Configured*

**Remediation:** Address per check: Liveness Probe Should be Configured. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-7

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV_K8S_9` · — · 2×
*Readiness Probe Should be Configured*

**Remediation:** Address per check: Readiness Probe Should be Configured. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/kubernetes-policies/kubernetes-policy-index/bc-k8s-8

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/fivetran-ssh/next-gen.tf` | 10 | kubernetes_deployment_v1.fivetran_ssh |
| `cypherid-web-infra/terraform/envs/staging/fivetran-ssh-nextgen/main.tf` | 5 | kubernetes_deployment_v1.fivetran_ssh |

### `CKV2_AWS_52` · — · 1×
*Ensure AWS ElasticSearch/OpenSearch Fine-grained access control is enabled*

**Remediation:** Address per check: Ensure AWS ElasticSearch/OpenSearch Fine-grained access control is enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/bc-aws-2-52

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV2_AWS_57` · — · 1×
*Ensure Secrets Manager secrets should have automatic rotation enabled*

**Remediation:** Address per check: Ensure Secrets Manager secrets should have automatic rotation enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-2-57

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/czid-services-private-key/main.tf` | 21 | module.czid-services-private-key.aws_secretsmanager_secret.services_private_key_pem |

### `CKV2_AWS_59` · — · 1×
*Ensure ElasticSearch/OpenSearch has dedicated master node enabled*

**Remediation:** Address per check: Ensure ElasticSearch/OpenSearch has dedicated master node enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-2-59

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV_AWS_103` · — · 1×
*Ensure that load balancer is using at least TLS 1.2*

**Remediation:** Address per check: Ensure that load balancer is using at least TLS 1.2. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-general-43

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 50 | module.web-service.module.alb.aws_alb_listener.http[0] |

### `CKV_AWS_108` · — · 1×
*Ensure IAM policies does not allow data exfiltration*

**Remediation:** Address per check: Ensure IAM policies does not allow data exfiltration. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-iam-policies/ensure-iam-policies-do-not-allow-data-exfiltration

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 79 | module.ecs-cluster.aws_iam_policy_document.ecs-policy |

### `CKV_AWS_115` · — · 1×
*Ensure that AWS Lambda function is configured for function-level concurrent execution limit*

**Remediation:** Lambda: set reserved_concurrent_executions.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_116` · — · 1×
*Ensure that AWS Lambda function is configured for a Dead Letter Queue(DLQ)*

**Remediation:** Lambda: add dead_letter_config (SQS/SNS DLQ).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_117` · — · 1×
*Ensure that AWS Lambda function is configured inside a VPC*

**Remediation:** Lambda: add vpc_config (subnet_ids + security_group_ids).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_119` · — · 1×
*Ensure DynamoDB Tables are encrypted using a KMS Customer Managed CMK*

**Remediation:** DynamoDB: server_side_encryption { enabled = true, kms_key_arn = <cmk> }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/happy-env-eks/dynamo.tf` | 1 | module.happy.aws_dynamodb_table.locks |

### `CKV_AWS_149` · — · 1×
*Ensure that Secrets Manager secret is encrypted using KMS CMK*

**Remediation:** Secrets Manager: set kms_key_id to a KMS CMK.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/czid-services-private-key/main.tf` | 21 | module.czid-services-private-key.aws_secretsmanager_secret.services_private_key_pem |

### `CKV_AWS_2` · — · 1×
*Ensure ALB protocol is HTTPS*

**Remediation:** Address per check: Ensure ALB protocol is HTTPS. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/networking-29

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 50 | module.web-service.module.alb.aws_alb_listener.http[0] |

### `CKV_AWS_228` · — · 1×
*Verify Elasticsearch domain is using an up to date TLS policy*

**Remediation:** Address per check: Verify Elasticsearch domain is using an up to date TLS policy. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-aws-elasticsearch-domain-uses-an-updated-tls-policy

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV_AWS_247` · — · 1×
*Ensure all data stored in the Elasticsearch is encrypted with a CMK*

**Remediation:** Address per check: Ensure all data stored in the Elasticsearch is encrypted with a CMK. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/ensure-aws-all-data-stored-in-the-elasticsearch-domain-is-encrypted-using-a-customer-managed-key-cmk

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV_AWS_272` · — · 1×
*Ensure AWS Lambda function is configured to validate code-signing*

**Remediation:** Lambda: set code_signing_config_arn (Signer).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_28` · — · 1×
*Ensure DynamoDB point in time recovery (backup) is enabled*

**Remediation:** DynamoDB: point_in_time_recovery { enabled = true }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/happy-env-eks/dynamo.tf` | 1 | module.happy.aws_dynamodb_table.locks |

### `CKV_AWS_317` · — · 1×
*Ensure Elasticsearch Domain Audit Logging is enabled*

**Remediation:** Address per check: Ensure Elasticsearch Domain Audit Logging is enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-317

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV_AWS_318` · — · 1×
*Ensure Elasticsearch domains are configured with at least three dedicated master nodes for HA*

**Remediation:** Address per check: Ensure Elasticsearch domains are configured with at least three dedicated master nodes for HA. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-318

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/aws-elasticsearch-v0.199.1/main.tf` | 20 | module.elasticsearch.aws_elasticsearch_domain.es |

### `CKV_AWS_337` · — · 1×
*Ensure SSM parameters are using KMS CMK*

**Remediation:** Address per check: Ensure SSM parameters are using KMS CMK. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-337

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/sandbox/db/secrets.tf` | 25 | aws_ssm_parameter.db_master_password |

### `CKV_AWS_341` · — · 1×
*Ensure Launch template should not have a metadata response hop limit greater than 1*

**Remediation:** Launch template: metadata_options { http_put_response_hop_limit = 1 }.

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/ecs-cluster-v2.4.0/main.tf` | 158 | module.ecs-cluster.aws_launch_template.ecs |

### `CKV_AWS_363` · — · 1×
*Ensure Lambda Runtime is not deprecated*

**Remediation:** Address per check: Ensure Lambda Runtime is not deprecated. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/bc-aws-363

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_378` · — · 1×
*Ensure AWS Load Balancer doesn't use HTTP protocol*

**Remediation:** Address per check: Ensure AWS Load Balancer doesn't use HTTP protocol. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-networking-policies/bc-aws-378

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/ecs-service-with-alb-v0.421.0/alb.tf` | 24 | module.web-service.aws_alb_target_group.service |

### `CKV_AWS_50` · — · 1×
*X-Ray tracing is enabled for Lambda*

**Remediation:** Lambda: tracing_config { mode = "Active" } (X-Ray).

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/envs/prod/batch/main.tf` | 81 | aws_lambda_function.ncbi_copy_lambda |

### `CKV_AWS_91` · — · 1×
*Ensure the ELBv2 (Application/Network) has access logging enabled*

**Remediation:** Address per check: Ensure the ELBv2 (Application/Network) has access logging enabled. Guideline: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-logging-policies/bc-aws-logging-22

| Path | Line | Resource |
|------|-----:|----------|
| `cypherid-web-infra/terraform/modules/alb-http-v0.484.6/main.tf` | 20 | module.web-service.module.alb.aws_alb.service |

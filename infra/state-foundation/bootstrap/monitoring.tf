# =============================================================================
# state-foundation/bootstrap/monitoring.tf
# -----------------------------------------------------------------------------
# CZID-506 (follow-up to CZID-157/364) -- baseline CloudWatch alarms for the
# Terraform state backend created in this stack: the S3 state bucket and the
# DynamoDB lock table. A throttled or erroring lock table stalls every plan +
# apply across the whole fleet, and S3 errors on the state bucket break state
# reads/writes -- both are silent, fleet-wide failure modes worth alarming on.
#
# Bootstrap is the chicken-and-egg stack (it CREATES the bucket + lock table it
# later stores state in and runs BEFORE the foundation stack), so it cannot reuse
# the foundation's "${name}-alerts" SNS topic. The alerts topic here is therefore
# bootstrap-local. Ops wires the human-facing subscription (email/Slack/chatbot)
# to this topic out-of-band, exactly as for the foundation topic.
#
# Authored, NOT applied (Bucket B / merge-hold). Mirror across accounts per the
# isolated-env rule. The alarms are cheap, static, and safe to apply with the
# bucket on the first bootstrap run (they do not depend on remote state).
# =============================================================================

locals {
  alarm_tags = {
    ManagedBy = "terraform"
    Stack     = "state-foundation/bootstrap"
    Purpose   = "tfstate-backend-alarms"
  }
}

# --- Alerts SNS topic (bootstrap-local) --------------------------------------
#trivy:ignore:AVD-AWS-0136 SNS holds only CloudWatch-alarm metadata (no sensitive data); the AWS-managed SNS key satisfies encryption-at-rest, so a CMK is unwarranted.
resource "aws_sns_topic" "state_alerts" {
  name              = "czid-tfstate-alerts"
  kms_master_key_id = "alias/aws/sns" # encrypt at rest (CKV_AWS_26); AWS-managed SNS key (no CMK needed for alarm metadata)
  tags              = local.alarm_tags
}

# =============================================================================
# DynamoDB lock table alarms (namespace AWS/DynamoDB, dimension TableName).
# The table is PAY_PER_REQUEST (on-demand), so there is no provisioned capacity
# to alarm ConsumedRead/WriteCapacity against -- throttling and errors are the
# meaningful signals. On-demand tables can still throttle on sudden bursts
# (fleet-wide concurrent plans) until the partition auto-scales.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "lock_throttled_requests" {
  alarm_name        = "czid-tfstate-lock-throttled-requests"
  alarm_description = "DynamoDB lock table (${aws_dynamodb_table.tflock.name}) is throttling requests -- Terraform plan/apply will stall fleet-wide."

  namespace   = "AWS/DynamoDB"
  metric_name = "ThrottledRequests"
  dimensions  = { TableName = aws_dynamodb_table.tflock.name }

  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # no traffic == no data == healthy

  alarm_actions = [aws_sns_topic.state_alerts.arn]
  ok_actions    = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "lock_read_throttle_events" {
  alarm_name        = "czid-tfstate-lock-read-throttle-events"
  alarm_description = "DynamoDB lock table (${aws_dynamodb_table.tflock.name}) read throttle events -- lock reads (GetItem) are being throttled."

  namespace   = "AWS/DynamoDB"
  metric_name = "ReadThrottleEvents"
  dimensions  = { TableName = aws_dynamodb_table.tflock.name }

  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "lock_write_throttle_events" {
  alarm_name        = "czid-tfstate-lock-write-throttle-events"
  alarm_description = "DynamoDB lock table (${aws_dynamodb_table.tflock.name}) write throttle events -- lock acquire/release (PutItem/DeleteItem) is being throttled."

  namespace   = "AWS/DynamoDB"
  metric_name = "WriteThrottleEvents"
  dimensions  = { TableName = aws_dynamodb_table.tflock.name }

  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

# DynamoDB SystemErrors are only emitted per-operation (they require the
# Operation dimension -- a TableName-only alarm never matches a metric), so one
# alarm per lock operation Terraform's S3 backend actually uses: GetItem reads
# the lock, PutItem acquires it, DeleteItem releases it. SystemErrors are
# server-side (HTTP 5xx) DynamoDB faults that should be zero.
#
# NOTE on UserErrors: deliberately omitted. DynamoDB UserErrors is aggregated at
# the account/region level with no TableName dimension, so it cannot be scoped to
# this lock table and would alarm on unrelated client errors elsewhere in the
# account. Lock contention (a held lock) surfaces as ConditionalCheckFailedRequests,
# which is normal Terraform behavior and is NOT counted as UserErrors.
locals {
  lock_operations = ["GetItem", "PutItem", "DeleteItem"]
}

resource "aws_cloudwatch_metric_alarm" "lock_system_errors" {
  for_each = toset(local.lock_operations)

  alarm_name        = "czid-tfstate-lock-system-errors-${lower(each.value)}"
  alarm_description = "DynamoDB lock table (${aws_dynamodb_table.tflock.name}) server-side errors on ${each.value} -- state locking is failing at the service level."

  namespace   = "AWS/DynamoDB"
  metric_name = "SystemErrors"
  dimensions = {
    TableName = aws_dynamodb_table.tflock.name
    Operation = each.value
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

# =============================================================================
# S3 state bucket alarms (namespace AWS/S3, dimensions BucketName + FilterId).
# 4xx/5xx are REQUEST metrics, which S3 only emits when a request-metrics filter
# is configured on the bucket -- so enable one for the whole bucket first.
# =============================================================================

resource "aws_s3_bucket_metric" "tfstate_requests" {
  bucket = aws_s3_bucket.tfstate.id
  name   = "EntireBucket" # whole-bucket request metrics (no prefix/tag filter)
}

resource "aws_cloudwatch_metric_alarm" "state_bucket_5xx_errors" {
  alarm_name        = "czid-tfstate-bucket-5xx-errors"
  alarm_description = "S3 state bucket (${aws_s3_bucket.tfstate.bucket}) is returning 5xx server errors -- Terraform state reads/writes may be failing."

  namespace   = "AWS/S3"
  metric_name = "5xxErrors"
  dimensions = {
    BucketName = aws_s3_bucket.tfstate.bucket
    FilterId   = aws_s3_bucket_metric.tfstate_requests.name
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.state_alerts.arn]
  ok_actions    = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

# 4xx tolerates a small baseline: the Terraform S3 backend routinely issues HEAD
# requests for state/lock objects that legitimately do not exist yet (404), so a
# zero threshold would be noisy. Alarm only on a sustained elevated rate, which
# indicates real access-denied / precondition problems rather than normal 404s.
resource "aws_cloudwatch_metric_alarm" "state_bucket_4xx_errors" {
  alarm_name        = "czid-tfstate-bucket-4xx-errors"
  alarm_description = "S3 state bucket (${aws_s3_bucket.tfstate.bucket}) elevated 4xx client errors -- likely access-denied or precondition failures on state (normal 404 HEADs are tolerated below the threshold)."

  namespace   = "AWS/S3"
  metric_name = "4xxErrors"
  dimensions = {
    BucketName = aws_s3_bucket.tfstate.bucket
    FilterId   = aws_s3_bucket_metric.tfstate_requests.name
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.state_alerts.arn]

  tags = local.alarm_tags
}

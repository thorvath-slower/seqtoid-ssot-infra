# CZID-157 — foundation baseline alarms (first slice).
#
# An alerts SNS topic + NAT Gateway alarms. The NAT metrics (AWS/NATGateway) are always emitted by
# AWS (no Container Insights needed), and SNAT port exhaustion / sustained packet drops are real
# egress-outage failure modes for everything behind the NAT (nodes pulling images, reaching AWS
# APIs, etc.).
#
# NOT in this slice (documented so the gap is explicit):
#   - EKS pod/node alarms need the amazon-cloudwatch-observability addon (Container Insights), which
#     the foundation does not yet enable (only core addons) — a separate, larger change.
#   - RDS alarms live in cypherid-web-infra (the db stack), not the foundation.
#   - State-backend (S3 state bucket / DynamoDB lock table) alarms belong in state-foundation/bootstrap.
#
# count is derived from known config (var.single_nat_gateway / var.az_count), not the computed
# nat_gateway_ids list, so plan never hits "count depends on a value known only after apply".

locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : var.az_count
}

#trivy:ignore:AVD-AWS-0136 SNS holds only CloudWatch-alarm metadata (no sensitive data); the AWS-managed SNS key satisfies encryption-at-rest, so a CMK is unwarranted.
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns" # encrypt at rest (CKV_AWS_26); AWS-managed SNS key (no CMK needed for alarm metadata)
  tags              = local.tags
}

resource "aws_cloudwatch_metric_alarm" "nat_port_allocation_errors" {
  count = local.nat_gateway_count

  alarm_name        = "${local.name}-nat-${count.index}-port-allocation-errors"
  alarm_description = "NAT gateway SNAT port-allocation errors (egress capacity exhaustion) — foundation ${var.environment}."

  namespace   = "AWS/NATGateway"
  metric_name = "ErrorPortAllocation"
  dimensions = {
    NatGatewayId = module.network.nat_gateway_ids[count.index]
  }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "nat_packet_drops" {
  count = local.nat_gateway_count

  alarm_name        = "${local.name}-nat-${count.index}-packet-drops"
  alarm_description = "NAT gateway sustained dropped packets (network degradation) — foundation ${var.environment}."

  namespace   = "AWS/NATGateway"
  metric_name = "PacketsDropCount"
  dimensions = {
    NatGatewayId = module.network.nat_gateway_ids[count.index]
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

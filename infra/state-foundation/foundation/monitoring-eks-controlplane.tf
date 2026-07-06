# =============================================================================
# CZID-157 / CZID-364 — foundation EKS control-plane 5xx alarm.
# -----------------------------------------------------------------------------
# monitoring-eks.tf covers the ContainerInsights node/pod health metrics and
# explicitly deferred the control-plane 5xx alarm ("can be layered on later").
# This file closes that gap.
#
# Full control-plane logging (api/audit/authenticator/controllerManager/
# scheduler) is already enabled on the cluster (enabled_cluster_log_types in
# modules/eks/main.tf) and lands in the AWS-managed log group
#   /aws/eks/<cluster>/cluster
# Unlike the ContainerInsights metrics, this log group exists whenever cluster
# logging is on — it does NOT require the amazon-cloudwatch-observability addon.
# A metric filter turns apiserver responseStatus.code >= 500 audit entries into a
# custom count metric, and an alarm on that metric notifies the shared alerts SNS
# topic (monitoring.tf).
#
# Gated behind the same var.enable_eks_alarms toggle as the other EKS alarms so
# the whole EKS-alarm surface flips together, applied deliberately (Bucket B)
# once the cluster is live. The metric filter reads the audit log stream, so the
# cluster's "audit" log type (already enabled) must be on — it is.
# =============================================================================

locals {
  eks_controlplane_log_group = "/aws/eks/${module.eks.cluster_name}/cluster"
  eks_controlplane_metric_ns = "CZID/EKSControlPlane"
  eks_5xx_metric_name        = "${local.name}-apiserver-5xx"
}

# Count apiserver audit entries whose responseStatus.code is a 5xx.
resource "aws_cloudwatch_log_metric_filter" "eks_apiserver_5xx" {
  count = var.enable_eks_alarms ? 1 : 0

  name           = "${local.name}-eks-apiserver-5xx"
  log_group_name = local.eks_controlplane_log_group

  # EKS audit events are JSON. responseStatus.code is the HTTP status the
  # apiserver returned; >= 500 is a server-side failure.
  pattern = "{ $.responseStatus.code >= 500 }"

  metric_transformation {
    name          = local.eks_5xx_metric_name
    namespace     = local.eks_controlplane_metric_ns
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_apiserver_5xx" {
  count = var.enable_eks_alarms ? 1 : 0

  alarm_name        = "${local.name}-eks-apiserver-5xx"
  alarm_description = "EKS control-plane apiserver returning sustained 5xx responses (audit log) — foundation ${var.environment}."

  namespace   = local.eks_controlplane_metric_ns
  metric_name = local.eks_5xx_metric_name

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.eks_apiserver_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags

  # The metric only exists once the filter has matched at least once; the alarm
  # is fine to create ahead of that (treat_missing_data=notBreaching).
  depends_on = [aws_cloudwatch_log_metric_filter.eks_apiserver_5xx]
}

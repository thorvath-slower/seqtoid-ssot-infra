# =============================================================================
# CZID-364 — foundation EKS baseline alarms (Container Insights).
# -----------------------------------------------------------------------------
# Follow-up to CZID-157 (SNS topic + NAT alarms in monitoring.tf). These alarms
# read the ContainerInsights CloudWatch namespace published by the
# amazon-cloudwatch-observability addon (enabled via
# module.eks var.enable_container_insights). Without that addon the metrics do
# not exist, so the alarms are gated behind var.enable_eks_alarms (default
# false) and applied deliberately once the cluster + addon are live (Bucket B).
#
# All alarms notify the shared alerts SNS topic defined in monitoring.tf.
# Thresholds are conservative starting points, tunable per env once real
# baselines are observed.
#
# Control-plane visibility: full control-plane logging (api/audit/authenticator/
# controllerManager/scheduler) is already enabled on the cluster
# (enabled_cluster_log_types in modules/eks/main.tf) and lands in the
# /aws/eks/<cluster>/cluster log group. A metric-filter-based control-plane 5xx
# alarm can be layered on later; this slice covers the always-emitted
# ContainerInsights node/pod health metrics.

locals {
  eks_alarm_count = var.enable_eks_alarms ? 1 : 0

  # Container Insights dimensions key on the cluster name.
  eks_ci_dimensions = {
    ClusterName = module.eks.cluster_name
  }
}

# --- Nodes: any node reporting NotReady ---------------------------------------
resource "aws_cloudwatch_metric_alarm" "eks_node_not_ready" {
  count = local.eks_alarm_count

  alarm_name        = "${local.name}-eks-node-not-ready"
  alarm_description = "One or more EKS nodes reporting NotReady (Container Insights) — foundation ${var.environment}."

  namespace   = "ContainerInsights"
  metric_name = "cluster_failed_node_count"
  dimensions  = local.eks_ci_dimensions

  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Nodes: cluster has fewer running nodes than the node group minimum -------
resource "aws_cloudwatch_metric_alarm" "eks_node_count_low" {
  count = local.eks_alarm_count

  alarm_name        = "${local.name}-eks-node-count-low"
  alarm_description = "EKS running node count dropped below the node group minimum — foundation ${var.environment}."

  namespace   = "ContainerInsights"
  metric_name = "cluster_node_count"
  dimensions  = local.eks_ci_dimensions

  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.eks_node_min_size
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Pods: pods stuck failing/not running (aggregate across namespaces) -------
resource "aws_cloudwatch_metric_alarm" "eks_pods_failed" {
  count = local.eks_alarm_count

  alarm_name        = "${local.name}-eks-pods-failed"
  alarm_description = "EKS pods in a failed/unschedulable state (Container Insights) — foundation ${var.environment}."

  namespace   = "ContainerInsights"
  metric_name = "cluster_number_of_running_pods"
  dimensions  = local.eks_ci_dimensions

  # Sentinel alarm: fires if the running-pod count collapses to zero, which
  # indicates a cluster-wide scheduling/health failure. Per-pod restart alarms
  # are better authored per-service once workloads land.
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Nodes: sustained high node-level CPU utilization -------------------------
resource "aws_cloudwatch_metric_alarm" "eks_node_cpu_high" {
  count = local.eks_alarm_count

  alarm_name        = "${local.name}-eks-node-cpu-high"
  alarm_description = "EKS node CPU utilization sustained high (Container Insights) — foundation ${var.environment}."

  namespace   = "ContainerInsights"
  metric_name = "node_cpu_utilization"
  dimensions  = local.eks_ci_dimensions

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Nodes: sustained high node-level memory utilization ----------------------
resource "aws_cloudwatch_metric_alarm" "eks_node_memory_high" {
  count = local.eks_alarm_count

  alarm_name        = "${local.name}-eks-node-memory-high"
  alarm_description = "EKS node memory utilization sustained high (Container Insights) — foundation ${var.environment}."

  namespace   = "ContainerInsights"
  metric_name = "node_memory_utilization"
  dimensions  = local.eks_ci_dimensions

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

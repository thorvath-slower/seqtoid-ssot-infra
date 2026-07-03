# =============================================================================
# foundation/modules/eks/observability.tf — Container Insights (CZID-364)
# -----------------------------------------------------------------------------
# Enables the amazon-cloudwatch-observability EKS addon (Container Insights),
# which runs the CloudWatch agent + Fluent Bit as a daemonset and publishes
# node/pod metrics to the CloudWatch "ContainerInsights" namespace. Those
# metrics are the prerequisite for the pod/node baseline alarms in the
# foundation root monitoring.tf (they don't exist without this addon).
#
# Gated behind var.enable_container_insights (default false) because:
#   - it carries per-node CloudWatch cost (metrics + logs), and
#   - the addon can only reconcile once the node group is Ready,
# so it is opt-in per env and applied deliberately (Bucket B), not on the first
# foundation apply. The addon uses its own IRSA role (least privilege:
# CloudWatchAgentServerPolicy only) bound to the amazon-cloudwatch/cloudwatch-agent
# service account.
# =============================================================================

data "aws_iam_policy_document" "cw_agent_assume" {
  count = var.enable_container_insights ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }
  }
}

resource "aws_iam_role" "cw_agent" {
  count = var.enable_container_insights ? 1 : 0

  name               = "${var.name}-eks-cw-agent"
  assume_role_policy = data.aws_iam_policy_document.cw_agent_assume[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  count = var.enable_container_insights ? 1 : 0

  role       = aws_iam_role.cw_agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "observability" {
  count = var.enable_container_insights ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  service_account_role_arn    = aws_iam_role.cw_agent[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  # The addon's daemonset needs Ready nodes to schedule onto.
  depends_on = [aws_eks_node_group.default]
}

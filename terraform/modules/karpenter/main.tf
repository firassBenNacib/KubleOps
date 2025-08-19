resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })

  tags = {
    Name = "KarpenterNodeRole-${var.project_name}"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_role_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = aws_iam_role.karpenter_node_role.name
  role = aws_iam_role.karpenter_node_role.name
}

resource "aws_sqs_queue" "karpenter_interruptions_dlq" {
  name                    = "${var.project_name}-karpenter-dlq"
  sqs_managed_sse_enabled = true

  tags = {
    Name = "${var.project_name}-karpenter-dlq"
  }
}

resource "aws_sqs_queue" "karpenter_interruptions" {
  name                      = var.project_name
  message_retention_seconds = var.queue_retention_seconds
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.karpenter_interruptions_dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })

  tags = {
    Name = var.project_name
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruptions" {
  queue_url = aws_sqs_queue.karpenter_interruptions.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.karpenter_interruptions.arn
      },
      {
        Sid       = "DenyHTTP",
        Effect    = "Deny",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = aws_sqs_queue.karpenter_interruptions.arn,
        Condition = { Bool = { "aws:SecureTransport" : false } }
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name = "${var.project_name}-SpotInterruption"
  event_pattern = jsonencode({
    source        = ["aws.ec2"],
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name = "${var.project_name}-SpotInterruption"
  }
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruptions.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name = "${var.project_name}-RebalanceRecommendation"
  event_pattern = jsonencode({
    source        = ["aws.ec2"],
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = {
    Name = "${var.project_name}-RebalanceRecommendation"
  }
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule = aws_cloudwatch_event_rule.rebalance.name
  arn  = aws_sqs_queue.karpenter_interruptions.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name = "${var.project_name}-InstanceStateChange"
  event_pattern = jsonencode({
    source        = ["aws.ec2"],
    "detail-type" = ["EC2 Instance State-change Notification"]
  })

  tags = {
    Name = "${var.project_name}-InstanceStateChange"
  }
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruptions.arn
}

resource "aws_cloudwatch_event_rule" "awshealth" {
  name = "${var.project_name}-AWSHealth"
  event_pattern = jsonencode({
    source        = ["aws.health"],
    "detail-type" = ["AWS Health Event"]
  })

  tags = {
    Name = "${var.project_name}-AWSHealth"
  }
}

resource "aws_cloudwatch_event_target" "awshealth" {
  rule = aws_cloudwatch_event_rule.awshealth.name
  arn  = aws_sqs_queue.karpenter_interruptions.arn
}

resource "aws_iam_service_linked_role" "ec2_spot" {
  aws_service_name = "spot.amazonaws.com"
}

resource "aws_iam_service_linked_role" "ec2_fleet" {
  aws_service_name = "ec2fleet.amazonaws.com"
}

# ---------- Module 3: Kubernetes (optional - costs money; use minikube for free) ----------
resource "aws_iam_role" "eks_cluster" {
  count = var.enable_eks ? 1 : 0
  name  = "${local.name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  count    = var.enable_eks ? 1 : 0
  name     = "${local.name}-eks"
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = "1.30"
  vpc_config {
    subnet_ids = concat(aws_subnet.private_app[*].id, aws_subnet.public[*].id)
  }
  enabled_cluster_log_types = ["api", "audit"]
  depends_on                = [aws_iam_role_policy_attachment.eks_cluster]
  lifecycle {
    precondition {
      condition     = var.enable_nat
      error_message = "enable_nat must be true when enable_eks is true (private nodes need NAT to pull images)."
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count = var.enable_eks ? 1 : 0
  name  = "${local.name}-eks-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = var.enable_eks ? toset(["AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly"]) : toset([])
  role     = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

# Pods use the node role in this lab setup (production: use IRSA / Pod Identity)
resource "aws_iam_role_policy" "eks_node_app" {
  count = var.enable_eks ? 1 : 0
  role  = aws_iam_role.eks_node[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["kinesis:PutRecord", "kinesis:PutRecords"], Resource = aws_kinesis_stream.expenses.arn },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.receipts.arn}/receipts/*" }
    ]
  })
}

resource "aws_eks_node_group" "main" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.private_app[*].id
  instance_types  = ["t3.medium"]
  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }
  depends_on = [aws_iam_role_policy_attachment.eks_node]
}

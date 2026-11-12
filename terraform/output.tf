output "message" {
  value = "Creation successful..."
  #   sensitive   = true
  #   description = "description"
  #   depends_on  = []
}

output "cluster_name" {
  value = aws_eks_cluster.floci_eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.floci_eks.endpoint
}

output "cluster_status" {
  value = aws_eks_cluster.floci_eks.status
}

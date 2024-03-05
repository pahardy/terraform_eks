output "cluster_endpoint" {
  description = "URL of the EKS control plane"
  value = module.eks.cluster_endpoint
}

output "cluster_sg_id" {
  description = "SGs attached to the cluster control plane"
  value = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Name of the cluster"
  value = module.eks.cluster_name
}
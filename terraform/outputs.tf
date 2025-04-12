output "ec2_public_ip" {
  description = "Public IP of the worker node"
  value       = aws_instance.worker_node.public_ip
}

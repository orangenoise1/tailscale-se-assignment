# 1. Confirm both EC2 instances joined the tailnet
output "step_1_tailscale_status" {
  description = "Step 1: Verify both instances are connected to the tailnet."
  value       = "tailscale status"
}

# 2. Ping private IP BEFORE approving the route (expected to fail)
output "step_2_ping_ssh_node_private_IP_address_before_route_approval" {
  description = "Step 2: Ping the SSH node private IP BEFORE route approval (should fail)."
  value       = "ping ${aws_instance.ssh_node.private_ip}"
}

# 3. Approve the subnet route in the Admin Console
output "step_3_approve_route" {
  description = "Step 3: Approve the advertised subnet route in the Tailscale Admin Console."
  value       = "In the Admin Console: open the subnet router node and approve route 10.0.1.0/24"
}

# 4. Ping private IPs AFTER approval (should succeed)
output "step_4_ping_ssh_node_private_IP_address_after_route_approval" {
  description = "Step 4: Ping the SSH node private IP AFTER route approval (should succeed)."
  value       = "ping ${aws_instance.ssh_node.private_ip}"
}

# 5. SSH into the Tailscale SSH-enabled node
output "step_5_tailscale_ssh" {
  description = "Step 5: Tailscale SSH into the SSH node using Tailscale SSH."
  value       = "tailscale ssh root@${var.project_name}-ssh-node"
}
# Tailscale SE Take-Home – Subnet Router + SSH Node (AWS + Terraform)

This repo spins up a small AWS lab environment for the Tailscale SE take-home assignment:

- A throwaway AWS VPC (`10.0.1.0/24`) with private and public subnets
- A NAT Gateway on the public subnet for egress traffic to internet
- An EC2 instance acting as a Tailscale subnet router
- A second EC2 instance joined to the same tailnet with Tailscale SSH enabled

Everything is deployed using Terraform so you can bring it up or tear it down quickly and repeatably.  
I used a separate throwaway tailnet for this exercise to keep it isolated from my personal environment.

## Prerequisites

AWS Requirements
- An AWS account with permissions to create resources

Tailscale Requirements
- A personal Tailscale tailnet
- Ability to create Tailscale auth keys or have them already created for repeated use

Local Tools Required
- AWS CLI
- Terraform
- Tailscale client
- SSH client

## What This Builds

Subnet router instance (`<project_name>-subnet-router`)
- EC2 instance in a private subnet (no public IP)
- Runs Tailscale and advertises `10.0.1.0/24`
- IP forwarding enabled and `source_dest_check = false` so it can route VPC traffic

Tailscale SSH node instance (`<project_name>-ssh-node`)
- EC2 instance in the same private subnet (no public IP)
- Joins the tailnet with Tailscale SSH enabled
- Reachable via Tailscale SSH directly, and reachable by ICMP through the subnet router when targeting its private IP

Only outbound internet access is required.  
Tailscale doesn’t need any inbound security group rules. I only allowed ICMP within the VPC so I could demonstrate subnet routing using ping.

## Automating Subnet Route Approval (How I’d Do It in a Real Deployment)

For this lab, I manually approve the `10.0.1.0/24` subnet route in the Tailscale admin console after deployment.  
This keeps the exercise simple and avoids requiring any extra setup for the reviewer.

In a real customer environment, I would automate this with Tailscale ACLs using auto-approvers. That way, specific tagged nodes are allowed to advertise and auto-approve routes without manual intervention.

## Testing the Deployment

**Step** | **Command & Expected Output**
--------|------------------------------
Confirm both EC2 instances joined the tailnet | Run `tailscale status` — you should see `<project_name>-subnet-router` and `<project_name>-ssh-node` listed as **connected**
Approve the subnet route | In the Tailscale admin console, open the subnet router and approve the route `10.0.1.0/24`
Ping the subnet router’s private IP | Run `ping <subnet_router_private_ip>` — should succeed once the route is approved. Optionally, run the same command **before** approval to show it fails without the route.
Ping the SSH node’s private IP (via subnet router) | Run `ping <ssh_node_private_ip>` — should respond once the route is approved. ICMP is allowed within the VPC security group, so this confirms traffic is being routed through the subnet router.
SSH into the SSH node using Tailscale SSH | Run `ssh ec2-user@<project_name>-ssh-node` — should connect using Tailscale SSH (first connection may prompt browser-based auth)
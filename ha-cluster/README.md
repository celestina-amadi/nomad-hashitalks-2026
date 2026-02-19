# Nomad High Availability Cluster Setup

This guide sets up a 3-node Nomad cluster for high availability.

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Nomad Cluster (HA)          │
                    └─────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
        ▼                            ▼                            ▼
┌───────────────┐           ┌───────────────┐           ┌───────────────┐
│   Server 1    │           │   Server 2    │           │   Server 3    │
│   (Leader*)   │◄─────────►│  (Follower)   │◄─────────►│  (Follower)   │
│  <private-ip> │           │  <private-ip> │           │  <private-ip> │
└───────────────┘           └───────────────┘           └───────────────┘
        │                            │                            │
        └────────────────────────────┼────────────────────────────┘
                                     │
                              Raft Consensus
                         (Automatic Leader Election)

* Leader is automatically elected - any server can become leader
```

## Files in This Directory

| File | Purpose |
|------|---------|
| `ansible/` | **Start here** - Ansible playbook to set up all 3 servers at once |
| `setup-server.sh` | Bash script alternative (manual SSH into each server) |
| `server.hcl.example` | Server config template (for reference) |
| `client.hcl` | Client (worker) node config - for nodes that only run jobs |
| `secure-server.hcl` | Production config with TLS, ACLs, gossip encryption |
| `nomad.service` | Systemd service file (for reference) |
| `OCI_SETUP.md` | Guide for deploying on Oracle Cloud (OCI) |

## Quick Start with Ansible (Recommended)

Sets up all 3 servers from your local machine in one command.

### Prerequisites

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) installed on your Mac (`brew install ansible`)
- 3 Ubuntu/Debian servers with SSH access (e.g., OCI VMs - see `OCI_SETUP.md`)
- Each server's public IP (for SSH) and private IP (for cluster communication)

### Step 1: Edit the Inventory

Open `ansible/inventory.ini` and replace the placeholder IPs:

```ini
[nomad_servers]
server1 ansible_host=129.213.x.x server_name=server-1 private_ip=10.0.1.10
server2 ansible_host=129.213.x.x server_name=server-2 private_ip=10.0.1.11
server3 ansible_host=129.213.x.x server_name=server-3 private_ip=10.0.1.12

[nomad_servers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/your-oci-key
```

### Step 2: Test Connectivity

```bash
cd ha-cluster/ansible

# Ping all servers to verify SSH access
ansible -i inventory.ini nomad_servers -m ping
```

Expected output:
```
server1 | SUCCESS => { "ping": "pong" }
server2 | SUCCESS => { "ping": "pong" }
server3 | SUCCESS => { "ping": "pong" }
```

### Step 3: Run the Playbook

```bash
# Dry run first (shows what would change, doesn't actually change anything)
ansible-playbook -i inventory.ini playbook.yml --check

# Run for real - sets up all 3 servers
ansible-playbook -i inventory.ini playbook.yml
```

The playbook will:
1. Install Nomad and Docker on all 3 servers
2. Create the `nomad` system user and directories
3. Generate per-server configs with the correct IPs
4. Install the systemd service and start Nomad
5. Open firewall ports
6. Verify the cluster formed

### Step 4: Verify the Cluster

```bash
# SSH into any server and check
ssh ubuntu@<any-server-public-ip>
nomad server members
```

Expected output:
```
Name       Address       Port  Status  Leader  Protocol
server-1   10.0.1.10    4648  alive   true    3
server-2   10.0.1.11    4648  alive   false   3
server-3   10.0.1.12    4648  alive   false   3
```

### Step 5: Access the Web UI

Open in your browser: `http://<any-server-public-ip>:4646`

> If you can't access it, make sure port 4646 is open in your cloud provider's security list/firewall rules. See `OCI_SETUP.md` for OCI-specific instructions.

## Alternative: Manual Setup with Bash Script

If you prefer not to use Ansible, you can SSH into each server and run `setup-server.sh` manually:

```bash
# Copy to each server
scp setup-server.sh ubuntu@<server-public-ip>:~/

# SSH in and run
ssh ubuntu@<server-public-ip>
chmod +x setup-server.sh
sudo ./setup-server.sh server-1 10.0.1.10 10.0.1.10,10.0.1.11,10.0.1.12
```

Repeat for all 3 servers, then start Nomad on each:
```bash
sudo systemctl enable nomad && sudo systemctl start nomad
```

## Deploying Jobs to the Cluster

Once your cluster is running, you can deploy jobs from any server:

```bash
# Copy a job file to any server and run it
nomad job run webapp.nomad.hcl

# Check job status
nomad job status webapp

# See where it's running
nomad job status webapp | grep Allocations -A 10
```

## Adding Client-Only Nodes

If you want dedicated worker nodes that don't participate in scheduling:

```bash
# Copy client.hcl to /etc/nomad.d/nomad.hcl on the client node
# Update the server IPs in the config, then start
sudo nomad agent -config=/etc/nomad.d/
```

## Failover Testing

```bash
# Find the current leader
nomad operator raft list-peers

# Stop the leader node
sudo systemctl stop nomad  # on leader

# Watch automatic failover (on another node)
watch nomad server members

# A new leader will be elected automatically!
```

## Troubleshooting

### Servers can't find each other
```bash
# Check if Nomad is running
sudo systemctl status nomad

# Check logs for errors
sudo journalctl -u nomad -f

# Verify private IPs are correct in the config
cat /etc/nomad.d/nomad.hcl | grep retry_join
```

### Port connectivity issues
```bash
# Test if port 4648 is reachable between servers
nc -zv <other-server-private-ip> 4648

# Check firewall rules
sudo ufw status
```

### Cluster won't form
```bash
# Nomad needs all 3 servers running before it elects a leader
# (because bootstrap_expect = 3)
# Make sure all 3 are started:
sudo systemctl start nomad  # on all 3 servers
```

## Ports Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 4646 | TCP | HTTP API & Web UI |
| 4647 | TCP | RPC (server-to-server, client-to-server) |
| 4648 | TCP/UDP | Serf (gossip protocol for membership) |

## Security (Production)

See `secure-server.hcl` for a production-ready config with:

1. **ACLs** - Access control (who can submit jobs, read state)
2. **mTLS** - Encrypted server-to-server and client-to-server communication
3. **Gossip encryption** - Encrypted Serf membership traffic

## OCI Deployment

See `OCI_SETUP.md` for a complete guide on deploying to Oracle Cloud Infrastructure, including VCN setup, security lists, and firewall rules.

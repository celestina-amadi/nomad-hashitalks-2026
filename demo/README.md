# HashiTalks Nomad Demo

This directory contains all the demo files for the "Getting Started with HashiCorp Nomad" talk.

## Prerequisites

Before the demo, ensure you have:

1. **Nomad cluster running** (3-node HA cluster via `ha-cluster/ansible/`)
2. **Docker installed** on all nodes
3. **Nomad CLI** installed locally or access via SSH

### Quick Install (local)

```bash
# macOS
brew install nomad

# Linux (Debian/Ubuntu)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y nomad

# Verify
nomad version
```

## Demo Files Overview

| File | Job Type | Description |
|------|----------|-------------|
| `webapp.nomad.hcl` | **service** | Multi-service web app (nginx frontend + API) with Traefik tags |
| `batch-job.nomad.hcl` | **batch** | Data processing simulation — runs to completion |
| `traefik.nomad.hcl` | **system** | Traefik ingress controller — runs on every node |
| `sysbatch-job.nomad.hcl` | **sysbatch** | Security scan — runs once on every node |

## Nomad Job Types

| Type | Runs on | Lifecycle | Example |
|------|---------|-----------|---------|
| **service** | Scheduled nodes | Long-running, restarts on failure | Web apps, APIs |
| **batch** | Scheduled nodes | Runs to completion | Data processing, backups |
| **system** | Every node | Long-running on all nodes | Log collectors, ingress |
| **sysbatch** | Every node | Runs once on all nodes | Security scans, setup scripts |

## Demo Script

### Part 1: Cluster Overview (2 minutes)

```bash
# Show the cluster
nomad server members
nomad node status

# Open the Nomad UI
# http://<server-ip>:4646
```

### Part 2: Service Job — Web App (3 minutes)

```bash
# Show the job file — highlight multi-group, Traefik tags, dynamic ports
cat webapp.nomad.hcl

# Deploy
nomad job run webapp.nomad.hcl

# Check status
nomad job status webapp

# View logs
nomad alloc logs <allocation-id>
```

### Part 3: Batch Job — Data Processing (2 minutes)

```bash
# Deploy — runs to completion
nomad job run batch-job.nomad.hcl

# Watch it complete
nomad job status data-processor

# Check logs
nomad alloc logs <allocation-id>
```

### Part 4: System Job — Traefik Ingress (3 minutes)

```bash
# Deploy — automatically runs on ALL nodes
nomad job run traefik.nomad.hcl

# Show it's on every node
nomad job status traefik

# Access webapp through Traefik
curl http://<server-ip>/
curl http://<server-ip>/api
```

### Part 5: Sysbatch Job — Security Scan (2 minutes)

```bash
# Deploy — runs once on every node
nomad job run sysbatch-job.nomad.hcl

# Show it completed on all nodes
nomad job status security-scan

# Check scan results
nomad alloc logs <allocation-id>
```

### Part 6: Cleanup

```bash
nomad job stop webapp
nomad job stop traefik
nomad job stop data-processor
```

## CI/CD

This repo includes a GitHub Actions pipeline (`.github/workflows/nomad-deploy.yml`) that:

- **On PR**: Validates all job files with `nomad job validate`
- **On push to main**: Deploys all jobs to the cluster with `nomad job run`

## Useful Commands

```bash
# Cluster
nomad status                    # All jobs
nomad node status               # All nodes
nomad server members            # Server membership

# Jobs
nomad job run <file>            # Deploy a job
nomad job status <name>         # Job details
nomad job stop <name>           # Stop a job

# Allocations
nomad alloc status <id>         # Allocation details
nomad alloc logs <id>           # View logs
nomad alloc logs -f <id>        # Follow logs

# Node operations
nomad node drain -enable <id>   # Drain a node (migrates jobs)
nomad node drain -disable <id>  # Re-enable a node
```

## Tips for Live Demo

1. **Pre-pull Docker images** on all nodes to avoid slow downloads:
   ```bash
   docker pull nginx:alpine
   docker pull hashicorp/http-echo
   docker pull alpine:latest
   docker pull traefik:v3.0
   ```
2. **Have the Nomad UI open** — great visual for the audience
3. **Test everything beforehand** — run through the demo at least once
4. **Use larger terminal font** — ensure audience can read

# =============================================================================
# SYSBATCH JOB EXAMPLE - Security Scan
# =============================================================================
# Sysbatch jobs run ONCE on EVERY node, then stop.
# Combines "system" (every node) + "batch" (run to completion).
#
# Use cases: OS patching, security scans, log rotation, config audits.
# =============================================================================

job "security-scan" {
  datacenters = ["dc1"]

  # "sysbatch" type = run once on every node, then stop
  # Unlike "system" (runs forever) or "batch" (runs on one node)
  type = "sysbatch"

  group "scan" {
    task "audit" {
      driver = "docker"

      config {
        image   = "alpine:latest"
        command = "/bin/sh"
        args    = ["local/scan.sh"]

        volumes = [
          "local/scan.sh:/local/scan.sh",
        ]
      }

      # Generate the script using a template so we can use Nomad env vars
      template {
        destination = "local/scan.sh"
        data        = <<-EOF
#!/bin/sh
echo "=== Security Scan Started ==="
echo "Node: {{ env "NOMAD_NODE_NAME" }}"
echo "Datacenter: {{ env "NOMAD_DC" }}"
echo "Timestamp: $(date)"
echo ""
echo "Step 1: Checking open ports..."
sleep 2
echo "  - Port 22 (SSH): open"
echo "  - Port 4646 (Nomad API): open"
echo "  - Port 4647 (Nomad RPC): open"
echo "  - Port 4648 (Nomad Serf): open"
echo ""
echo "Step 2: Checking disk usage..."
df -h / | tail -1 | awk '{print "  - Disk usage: " $5 " (" $3 " used of " $2 ")"}'
echo ""
echo "Step 3: Checking running processes..."
echo "  - $(ps aux | wc -l) processes running"
echo ""
echo "=== Security Scan Complete ==="
echo "Result: PASS - No issues found"
EOF
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}

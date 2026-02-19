# =============================================================================
# BATCH JOB EXAMPLE
# =============================================================================
# Batch jobs run to completion and then stop (unlike service jobs).
# Use cases: data processing, backups, database migrations, reports.
# =============================================================================

job "data-processor" {
  # Which datacenter(s) can run this job
  datacenters = ["dc1"]

  # "batch" type = runs once to completion, then stops
  # (vs "service" which runs forever, or "system" which runs on every node)
  type = "batch"

  # A group of tasks that run together on the same node
  group "process" {
    # Number of instances of this group to run
    count = 1

    # What to do when the task fails
    restart {
      attempts = 3      # Retry up to 3 times before giving up
      delay    = "15s"   # Wait 15 seconds between retries
      mode     = "fail"  # After 3 attempts, mark the job as failed
    }

    # The actual workload to run
    task "analyze" {
      # Use Docker to run this task
      driver = "docker"

      config {
        image   = "alpine:latest"   # Lightweight Linux container
        command = "/bin/sh"          # Run a shell script
        args = [
          "-c",
          <<-EOF
          echo "=== Data Processing Job Started ==="
          echo "Timestamp: $(date)"
          echo ""
          echo "Step 1: Initializing..."
          sleep 2
          echo "Step 2: Processing data..."
          sleep 3
          echo "Step 3: Generating report..."
          sleep 2
          echo ""
          echo "=== Job Completed Successfully ==="
          echo "Processed 1,234 records in 7 seconds"
          EOF
        ]
      }

      # CPU and memory limits for this task
      resources {
        cpu    = 200  # 200 MHz of CPU
        memory = 128  # 128 MB of RAM
      }
    }
  }
}

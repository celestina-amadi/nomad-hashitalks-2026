# webapp.nomad.hcl
# A more realistic web application with multiple services
# Demonstrates: templates (like ConfigMaps), env vars, and multi-service deployment

job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  # Update strategy - how Nomad rolls out changes
  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
  }

  # Frontend web server
  group "frontend" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    # Register with Traefik for automatic routing
    service {
      name     = "webapp-frontend"
      provider = "nomad"
      port     = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.webapp.rule=PathPrefix(`/`)",
        "traefik.http.routers.webapp.entrypoints=web",
      ]
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
        # Mount the template-generated files into the container
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
          "local/style.css:/usr/share/nginx/html/style.css",
        ]
      }

      # ============================================
      # TEMPLATE STANZA - Like Kubernetes ConfigMap
      # ============================================
      # Templates render files into the task's local directory
      # They can include environment variables and Vault secrets

      # Main HTML page
      template {
        destination = "local/index.html"
        data        = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Nomad</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">
                <svg width="60" height="60" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M0 0H128V128H0V0Z" fill="#00CA8E"/>
                    <path d="M39 35.5L64 21L89 35.5V64.5L64 79L39 64.5V35.5Z" fill="white"/>
                    <path d="M64 50L89 35.5V64.5L64 79V50Z" fill="#00CA8E" fill-opacity="0.3"/>
                </svg>
                <h1>HashiCorp Nomad</h1>
            </div>
            <p class="tagline">Simple, flexible workload orchestration</p>
        </header>

        <main>
            <section class="hero">
                <h2>Your Application is Running!</h2>
                <p>This page is served by Nomad using the <code>template</code> stanza - similar to Kubernetes ConfigMaps.</p>
            </section>

            <section class="info-cards">
                <div class="card">
                    <h3>Allocation Info</h3>
                    <ul>
                        <li><strong>Job:</strong> {{ env "NOMAD_JOB_NAME" }}</li>
                        <li><strong>Task Group:</strong> {{ env "NOMAD_GROUP_NAME" }}</li>
                        <li><strong>Task:</strong> {{ env "NOMAD_TASK_NAME" }}</li>
                        <li><strong>Alloc ID:</strong> {{ env "NOMAD_SHORT_ALLOC_ID" }}</li>
                    </ul>
                </div>

                <div class="card">
                    <h3>Node Info</h3>
                    <ul>
                        <li><strong>Datacenter:</strong> {{ env "NOMAD_DC" }}</li>
                        <li><strong>Region:</strong> {{ env "NOMAD_REGION" }}</li>
                        <li><strong>Node:</strong> {{ env "NOMAD_NODE_NAME" }}</li>
                        <li><strong>Namespace:</strong> {{ env "NOMAD_NAMESPACE" }}</li>
                    </ul>
                </div>

                <div class="card">
                    <h3>Network</h3>
                    <ul>
                        <li><strong>Host IP:</strong> {{ env "NOMAD_HOST_IP_http" }}</li>
                        <li><strong>Port:</strong> {{ env "NOMAD_HOST_PORT_http" }}</li>
                        <li><strong>Alloc Port:</strong> {{ env "NOMAD_PORT_http" }}</li>
                    </ul>
                </div>
            </section>

            <section class="features">
                <h2>Why Nomad?</h2>
                <div class="feature-grid">
                    <div class="feature">
                        <span class="icon">📦</span>
                        <h4>Single Binary</h4>
                        <p>Easy to install and operate</p>
                    </div>
                    <div class="feature">
                        <span class="icon">🔧</span>
                        <h4>Multi-Workload</h4>
                        <p>Containers, VMs, binaries</p>
                    </div>
                    <div class="feature">
                        <span class="icon">🚀</span>
                        <h4>Scales</h4>
                        <p>From 1 to 10,000+ nodes</p>
                    </div>
                    <div class="feature">
                        <span class="icon">🔗</span>
                        <h4>Integrates</h4>
                        <p>Consul, Vault, Terraform</p>
                    </div>
                </div>
            </section>

            <section class="api-demo">
                <h2>API Status</h2>
                <p>Backend API routed via Traefik at: <a href="/api">/api</a></p>
                <pre id="api-response">Loading...</pre>
            </section>
        </main>

        <footer>
            <p>HashiTalks 2026 | Powered by HashiCorp Nomad</p>
            <p><a href="http://141.147.117.175:4646">Open Nomad UI</a></p>
        </footer>
    </div>

    <script>
        fetch('/api')
            .then(r => r.text())
            .then(data => {
                document.getElementById('api-response').textContent = data;
            })
            .catch(err => {
                document.getElementById('api-response').textContent = 'API not reachable: ' + err.message;
            });
    </script>
</body>
</html>
EOF
      }

      # CSS Stylesheet - another template file
      template {
        destination = "local/style.css"
        data        = <<-EOF
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
    min-height: 100vh;
    color: #e4e4e4;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

header {
    text-align: center;
    padding: 3rem 0;
}

.logo {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    margin-bottom: 1rem;
}

.logo h1 {
    font-size: 2.5rem;
    font-weight: 700;
    background: linear-gradient(90deg, #00CA8E, #00D4AA);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.tagline {
    font-size: 1.2rem;
    color: #8892b0;
}

.hero {
    text-align: center;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 16px;
    margin-bottom: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.hero h2 {
    font-size: 2rem;
    margin-bottom: 1rem;
    color: #00CA8E;
}

.hero code {
    background: rgba(0, 202, 142, 0.2);
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    color: #00CA8E;
}

.info-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.5rem;
    margin-bottom: 2rem;
}

.card {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
    transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
    transform: translateY(-4px);
    box-shadow: 0 10px 40px rgba(0, 202, 142, 0.1);
}

.card h3 {
    color: #00CA8E;
    margin-bottom: 1rem;
    font-size: 1.1rem;
}

.card ul {
    list-style: none;
}

.card li {
    padding: 0.5rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    font-size: 0.9rem;
}

.card li:last-child {
    border-bottom: none;
}

.card strong {
    color: #8892b0;
}

.features {
    margin-bottom: 2rem;
}

.features h2 {
    text-align: center;
    margin-bottom: 1.5rem;
    color: #fff;
}

.feature-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
}

.feature {
    text-align: center;
    padding: 1.5rem;
    background: rgba(255, 255, 255, 0.03);
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.05);
}

.feature .icon {
    font-size: 2rem;
    margin-bottom: 0.5rem;
    display: block;
}

.feature h4 {
    color: #00CA8E;
    margin-bottom: 0.5rem;
}

.feature p {
    color: #8892b0;
    font-size: 0.9rem;
}

.api-demo {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 2rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
}

.api-demo h2 {
    margin-bottom: 1rem;
    color: #fff;
}

.api-demo pre {
    background: #0d1117;
    padding: 1rem;
    border-radius: 8px;
    overflow-x: auto;
    color: #00CA8E;
    font-family: 'Monaco', 'Consolas', monospace;
}

footer {
    text-align: center;
    padding: 2rem;
    color: #8892b0;
}

footer a {
    color: #00CA8E;
    text-decoration: none;
}

footer a:hover {
    text-decoration: underline;
}

@media (max-width: 768px) {
    .logo h1 {
        font-size: 1.8rem;
    }

    .hero h2 {
        font-size: 1.5rem;
    }
}
EOF
      }

      # ============================================
      # ENV STANZA - Environment Variables
      # ============================================
      env {
        APP_NAME    = "Nomad Demo"
        ENVIRONMENT = "demo"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  # Backend API service
  group "api" {
    count = 1

    network {
      port "api" {
        to = 8080
      }
    }

    # Register with Traefik for automatic routing
    service {
      name     = "webapp-api"
      provider = "nomad"
      port     = "api"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.webapp-api.rule=PathPrefix(`/api`)",
        "traefik.http.routers.webapp-api.entrypoints=web",
      ]
    }

    task "api-server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        args = [
          "-listen", ":8080",
          "-text", "{\"status\": \"ok\", \"service\": \"api\", \"version\": \"1.0.0\", \"message\": \"Hello from Nomad API!\"}"
        ]
        ports = ["api"]
      }

      # Environment variables (like K8s env)
      env {
        LOG_LEVEL = "info"
        ENV       = "production"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}



# Kubernetes Monitoring with Prometheus & Grafana on Minikube

This guide documents a complete setup of a monitoring stack on a Minikube cluster (running on an Ubuntu server / EC2 instance). It includes:

- Installation of **Docker**, **kubectl**, **Minikube** and **Helm**
- Deployment of **Prometheus** and **Grafana** using the `kube-prometheus-stack` Helm chart
- Accessing and understanding dashboards
- Creating custom panels, saving dashboards, and sharing snapshots
- Troubleshooting common issues like missing container metrics and broken snapshot links

---

## 📋 Prerequisites

- Ubuntu 22.04 / 24.04 server (or an AWS EC2 instance) with internet access.
- A user with `sudo` privileges.
- Firewall (security group) allowing inbound TCP on ports `3000` and `9090` (if accessing from outside).

---

## 🤖 Automated Installation (Recommended)

Use the provided bash scripts for a quick, repeatable setup.

### 1. Install Minikube Only

Save the following as `install-minikube.sh`, make it executable and run it.

```bash
#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y curl wget apt-transport-https

# Docker
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
echo "Docker installed. Log out & back in or run 'newgrp docker'."

# kubectl
curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --driver=docker --memory=2500mb --cpus=2 --disk-size=20g
kubectl wait --for=condition=ready node --all --timeout=120s

echo "Minikube is ready!"
```

```bash
chmod +x install-minikube.sh
./install-minikube.sh
```

### 2. Install Prometheus & Grafana (on an existing Minikube cluster)

Save as `install-monitoring.sh`, run **after** Minikube is running.

```bash
#!/bin/bash
set -e

# Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# Add repo and install
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat <<EOF > custom-values.yaml
grafana:
  adminPassword: "Admin123!"
  service:
    type: ClusterIP
EOF

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f custom-values.yaml

kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

echo ""
echo "✅ Installation complete!"
echo "Grafana admin password: Admin123!"
echo "Run port-forward commands to access the dashboards (see manual section)."
```

```bash
chmod +x install-monitoring.sh
./install-monitoring.sh
```

---

## 🪜 Manual Step‑by‑Step (for Learning)

If you prefer to run each command manually, follow these sections.

### 1. Install Docker, kubectl, Minikube

```bash
sudo apt update
sudo apt install -y docker.io curl
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Log out and back in, or run: newgrp docker

# kubectl
curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --driver=docker --memory=2500mb --cpus=2 --disk-size=20g
kubectl get nodes
```

### 2. Install Helm

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### 3. Deploy Prometheus & Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# (Optional) set custom admin password
cat <<EOF > custom-values.yaml
grafana:
  adminPassword: "Admin123!"
  service:
    type: ClusterIP
EOF

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f custom-values.yaml

# Wait for pods to be ready
kubectl get pods -n monitoring -w
```

### 4. Access Grafana and Prometheus from your browser

Because the services are `ClusterIP`, you need to port‑forward to your EC2 public IP.

**Grafana (port 3000):**
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80
```

**Prometheus (port 9090):**
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

> ⚠️ **Security note:** Binding to `0.0.0.0` exposes the services to the internet – only for testing. Use an Ingress or VPN in production.

Now open:
- Grafana: `http://<YOUR_EC2_PUBLIC_IP>:3000`
- Prometheus: `http://<YOUR_EC2_PUBLIC_IP>:9090`

**Alternative (no port‑forward):**  
`minikube service -n monitoring monitoring-grafana` (and similarly for Prometheus).

### 5. Log into Grafana

If you used the custom password `Admin123!`, credentials are:
- Username: `admin`
- Password: `Admin123!`

Otherwise, retrieve the auto‑generated password:
```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

---

## 📊 Working with Dashboards

### Viewing Pre‑configured Dashboards

After logging in, click the **≡** (menu) → **Dashboards** → **Browse**.  
You will see dashboards like:

- `Kubernetes / Compute Resources / Cluster` – overall CPU & memory
- `Kubernetes / Compute Resources / Pod` – per‑pod metrics
- `Node Exporter / Nodes` – EC2 instance metrics

Click on any to open it. The graphs will show CPU utilisation, memory usage, etc.

> **Note:** Some panels may show “No data” – this is normal if your pods do not have resource requests/limits defined. The actual usage graphs work fine.

### Creating a Test Pod with CPU/Memory Requests

To see the “CPU Requests Commitment” and “Memory Limits Commitment” panels populate, create a pod with explicit requests:

```bash
kubectl run nginx2 --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "nginx2",
      "image": "nginx",
      "resources": {
        "requests": {"cpu": "100m", "memory": "128Mi"},
        "limits": {"cpu": "200m", "memory": "256Mi"}
      }
    }]
  }
}'
```

### Creating Custom Panels (Graph / Pie Chart)

1. From a dashboard, click **Add panel** → **Add a new panel**.
2. In the **Query** field, enter a PromQL query (examples below).
3. Change the visualization (Time series, Pie chart, etc.) using the dropdown on the right.
4. Click **Apply** → **Save dashboard**.

#### Example PromQL Queries

- **CPU usage per pod:**
  ```promql
  sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod)
  ```
- **Memory usage per pod:**
  ```promql
  sum(container_memory_working_set_bytes{container!=""}) by (pod)
  ```
- **Node memory used (on EC2):**
  ```promql
  node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes
  ```

### Saving and Finding Your Dashboards

- After adding panels, click the **Save dashboard** icon (floppy disk) at the top right.
- The dashboard will be saved in the **General** folder. Find it via:
  - Left sidebar → **Dashboards** → **Browse**
  - Search (`Ctrl+k`) by name
  - Check **Recently viewed** on the home page

### Sharing a Panel or Dashboard

You can share individual panels using **snapshots** or direct links.

#### Method 1: Direct Link (requires login)

1. Hover over the panel title → click **Share** → **Link** tab.
2. Copy the URL. Users must have Grafana access.

#### Method 2: Snapshot (public, no login required)

1. In the panel’s **Share** dialog, go to the **Snapshot** tab.
2. Click **Publish to snapshot**.
3. The snapshot URL will contain `localhost`. **Replace `localhost` with your EC2 public IP** before sharing.

Example:
```
Original: http://localhost:3000/dashboard/snapshot/7tFY7FIR7HpNmGd
Correct:  http://52.201.57.125:3000/dashboard/snapshot/7tFY7FIR7HpNmGd
```

Snapshots are static point‑in‑time copies – they do not require Prometheus to be running.

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `kubectl` commands return “connection refused” | Start Minikube: `minikube start` |
| Grafana login fails with the generated secret | Reinstall using a custom `adminPassword` as shown above. |
| “No data” in dashboards | Wait 2‑3 minutes for metrics to appear. Check that Prometheus targets are **UP** at `http://<EC2_IP>:9090/targets`. |
| Container metrics missing (e.g., `container_memory_working_set_bytes`) | This can happen with some container runtimes. Use node metrics (e.g., `node_memory_*`) instead, or reinstall the chart with `kubelet.serviceMonitor.cAdvisor: true`. |
| After reboot, cluster not responding | Run `minikube stop && minikube start` to restore the cluster. |
| Snapshot shows “localhost refused connection” | Replace `localhost` with your EC2 public IP in the snapshot URL. |
| Port‑forward stops after closing terminal | Use a terminal multiplexer (`tmux` or `screen`) or run the command with `nohup`. |

---

## 🧹 Clean Up

To remove everything and start fresh:

```bash
helm uninstall monitoring -n monitoring   # remove Helm release
kubectl delete namespace monitoring       # delete monitoring namespace
minikube delete                           # delete the entire cluster
```

Remove the installation scripts and downloaded binaries if desired.

---

## 📚 References

- [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## ✅ Conclusion

You now have a fully functional monitoring stack on Minikube. You can view CPU and memory usage, create custom dashboards, and share snapshots. The automated scripts allow you to replicate this setup on any Ubuntu server in minutes.

Happy monitoring! 🎯
```

This README includes every step from the conversation, the scripts, the snapshot fix, and the dashboard creation. You can now add it to your project repository.

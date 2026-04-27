# Monitoring Kubernetes (Minikube) with Prometheus & Grafana

This repository contains a complete guide to set up a monitoring stack on a local Minikube cluster (tested on Ubuntu 22.04/24.04, including AWS EC2). It includes:

- Installation of **Docker**, **kubectl**, **Minikube**, and **Helm**
- Deployment of **Prometheus** and **Grafana** using the `kube-prometheus-stack` Helm chart
- Automated bash scripts for quick installation
- Manual steps for understanding each component

After completion, you will be able to monitor CPU, memory, and other metrics of your Kubernetes cluster and pods.

---

## 📋 Prerequisites

- An Ubuntu server (or EC2 instance) with internet access.
- A user with `sudo` privileges.

---

## 🤖 Automated Installation (Recommended)

Use the provided bash scripts to get a fully working environment in minutes.

### 1. Install Minikube only

Save the following as `install-minikube.sh`, make it executable and run it:

```bash
#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y curl wget apt-transport-https

# Docker
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

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

Run:
```bash
chmod +x install-minikube.sh
./install-minikube.sh
```

> 💡 After installation, you may need to run `newgrp docker` or log out and back in to use Docker without `sudo`.

### 2. Install Prometheus & Grafana on an existing Minikube cluster

Save the following as `install-monitoring.sh` and run **after** Minikube is running:

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
echo "Run port-forward commands to access the dashboards (see manual section below)."
```

Run:
```bash
chmod +x install-monitoring.sh
./install-monitoring.sh
```

---

## 🪜 Manual Step‑by‑Step (for learning)

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

# Verify
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

Since the services are `ClusterIP`, you need to forward ports to your EC2 public IP (or localhost).

**Forward Grafana (port 3000):**
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80
```

**Forward Prometheus (port 9090):**
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

> ⚠️ Binding to `0.0.0.0` exposes services to the internet – use only for testing. In production, use an Ingress or a VPN.

Now open your browser:
- Grafana: `http://<YOUR_EC2_PUBLIC_IP>:3000` (user: `admin`, password: `Admin123!` or the one from secret)
- Prometheus: `http://<YOUR_EC2_PUBLIC_IP>:9090`

**Alternative using `minikube service` (no port‑forward needed):**
```bash
minikube service -n monitoring monitoring-grafana
minikube service -n monitoring monitoring-kube-prometheus-prometheus
```

### 5. Get the Grafana admin password (if you didn't set a custom one)

```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

---

## 📊 Viewing CPU and Memory Metrics

Once logged into Grafana:

1. Click the **≡** (menu) → **Dashboards** → **Browse**.
2. Look for the `kube-prometheus-stack` dashboards:
   - `Kubernetes / Compute Resources / Cluster` → overall CPU and RAM usage.
   - `Kubernetes / Compute Resources / Pod` → per‑pod CPU/memory.
   - `Node Exporter / Nodes` → EC2 instance metrics.
3. Use the **time picker** (top right) to adjust the range.
4. Some panels may show “No data” – this is normal if your pods do not have resource requests/limits defined. The actual utilisation graphs will still work.

To generate test metrics, run a simple nginx pod:

```bash
kubectl run nginx --image=nginx
```

Then observe its metrics in the `Kubernetes / Compute Resources / Pod` dashboard.

---

## 🧪 Testing with a Load (Optional)

Create a deployment with CPU/memory requests:

```bash
kubectl create deployment test --image=nginx --requests=cpu=100m,memory=128Mi
```

Or generate load on the nginx pod:

```bash
while true; do curl -s http://<nginx-pod-ip> > /dev/null; sleep 0.1; done
```

Watch the CPU graph spike.

---

## 🧹 Clean Up

To remove everything:

```bash
helm uninstall monitoring -n monitoring          # remove Prometheus/Grafana
kubectl delete namespace monitoring             # delete all monitoring resources
minikube delete                                 # delete the entire cluster
```

If you want to keep the cluster but only remove the monitoring stack, just run the `helm uninstall` command.

---

## 🐞 Troubleshooting

| Problem | Solution |
|---------|----------|
| `kubectl` commands fail with “connection refused” | Start Minikube: `minikube start` |
| Grafana login fails | Use the custom password `Admin123!` or retrieve the secret as shown above. If still failing, reinstall with the custom password. |
| “No data” in dashboards | Wait a few minutes. Check that Prometheus is scraping targets at `http://EC2_IP:9090/targets`. |
| Port‑forward stops after closing terminal | Use `nohup` or run the command inside `screen`/`tmux`. Alternatively, use `minikube service`. |

---

## 🔗 References

- [kube-prometheus-stack Helm chart](https://github.com/premetheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## ✅ Conclusion

You now have a fully functional monitoring stack for your Minikube cluster. You can visualise CPU, memory, network, and disk metrics, set up alerts, and explore Prometheus queries. The automated scripts can be reused to set up the same environment on any Ubuntu server.

Happy monitoring! 🎯
```

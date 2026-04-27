# Monitoring Kubernetes (Minikube) with Prometheus & Grafana

This guide documents the step‑by‑step setup of a monitoring stack on a local Minikube cluster (running on an EC2 instance). It includes installing Docker, Minikube, `kubectl`, Helm, and deploying the `kube-prometheus-stack` (Prometheus + Grafana). After the setup, you will be able to monitor CPU, memory, and other metrics of your cluster and pods.

---

## 📦 Prerequisites

- An Ubuntu server (or EC2 instance) with internet access.
- User with `sudo` privileges.

---

## 🧰 1. Install Docker, kubectl, and Minikube

Run the following commands **one by one**:

```bash
# Install Docker
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube
```

**Verify installations:**

```bash
docker --version
kubectl version --client
minikube version
```

---

## 🚀 2. Start Minikube Cluster

Start the cluster with Docker as the driver (adjust resources as needed):

```bash
minikube start --driver=docker --memory=2500mb --cpus=2 --disk-size=20g
```

Check that the cluster is running:

```bash
kubectl get nodes
```

You should see a single node named `minikube` with `Ready` status.

---

## 📈 3. Install Helm (Kubernetes Package Manager)

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
```

---

## 🛠️ 4. Deploy the Prometheus & Grafana Stack (kube-prometheus-stack)

### Add the Prometheus community Helm repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### (Optional) Create a custom values file to set a known Grafana admin password

```bash
cat <<EOF > custom-values.yaml
grafana:
  adminPassword: "Admin123!"
  service:
    type: ClusterIP
EOF
```

### Install the chart

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f custom-values.yaml   # omit -f if you didn't create the file
```

### Verify that all pods are running

```bash
kubectl get pods -n monitoring -w
```

Wait until you see all pods in `Running` state (especially `monitoring-grafana-*` with `3/3`). Press `Ctrl+C` to stop watching.

---

## 🌐 5. Access Grafana and Prometheus from your Browser

Because the services are of type `ClusterIP`, you need to forward their ports to your EC2’s public interface.

### Forward Grafana (port 3000)

```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80
```

Do **not** close this terminal. Run the next command in a **separate terminal** or use `&` to background it.

### Forward Prometheus (port 9090)

```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

> 🔓 **Security note:** Binding to `0.0.0.0` exposes these services to the internet. Use only for testing. In production, use Ingress or a VPN.

### Open the web interfaces

- **Grafana:** `http://<YOUR_EC2_PUBLIC_IP>:3000`
- **Prometheus:** `http://<YOUR_EC2_PUBLIC_IP>:9090`

---

## 🔑 6. Log into Grafana

If you created the `custom-values.yaml` with `adminPassword: "Admin123!"`, use:

- **Username:** `admin`
- **Password:** `Admin123!`

If you did **not** set a custom password, retrieve the auto‑generated one:

```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

---

## 🧪 7. Create a Test Nginx Pod (to generate metrics)

```bash
kubectl run nginx --image=nginx
kubectl get pods
```

You can also create a deployment with resource requests to see more data in Grafana:

```bash
kubectl create deployment test --image=nginx --requests=cpu=100m,memory=128Mi
```

---

## 📊 8. View CPU and Memory Metrics in Grafana

1. In Grafana, click the **≡** (menu) → **Dashboards** → **Browse**.
2. Look for dashboards from the `kube-prometheus-stack`:
   - `Kubernetes / Compute Resources / Cluster` – overall CPU/RAM.
   - `Kubernetes / Compute Resources / Pod` – per‑pod metrics.
   - `Node Exporter / Nodes` – EC2 instance metrics.
3. Click on any dashboard to open it. You will see graphs for **CPU Utilisation** and **Memory Utilisation**.
4. Use the **time picker** (top right) to adjust the time range.

> **Note:** Some panels may show “No data” because your pods do not have resource requests/limits defined. The actual CPU and memory usage panels will still work.

---

## 🧹 9. Troubleshooting Common Issues

| Problem | Solution |
|---------|----------|
| `kubectl` commands fail with “connection refused” | Ensure Minikube is running: `minikube status`. Start it if needed. |
| Grafana login fails even with correct secret | Reinstall with a custom `adminPassword` as shown in step 4. |
| “No data” in Prometheus/Grafana | Wait a few minutes for metrics to appear. Check that Prometheus is scraping: `kubectl port-forward` and visit `http://EC2_IP:9090/targets`. |
| Port‑forward stops after terminal closes | Use `nohup` or run the command inside a `screen`/`tmux` session. Alternatively, use `minikube service` (see tip below). |

### 💡 Minikube Shortcut

Instead of `kubectl port-forward`, you can use:

```bash
minikube service -n monitoring monitoring-grafana
minikube service -n monitoring monitoring-kube-prometheus-prometheus
```

This automatically opens the browser.

---

## 🗑️ 10. Clean Up (Optional)

To remove everything:

```bash
helm uninstall monitoring -n monitoring          # remove Helm release
kubectl delete namespace monitoring             # delete all monitoring resources
minikube delete                                 # delete the entire cluster
```

---

## 📚 References

- [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## ✅ Summary

You have successfully:
- Installed Minikube and kubectl
- Deployed Prometheus and Grafana using Helm
- Accessed Grafana and Prometheus from your browser
- Visualised CPU and memory metrics
- Learned how to troubleshoot common issues

Now you can monitor your Kubernetes cluster’s health and performance.

```

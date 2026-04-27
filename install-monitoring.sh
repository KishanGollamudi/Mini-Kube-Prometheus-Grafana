#!/bin/bash
set -e  # Exit on any error

# -------------------------------
# 1. System update & prerequisites
# -------------------------------
echo "📦 Updating system packages..."
sudo apt update -y
sudo apt install -y curl wget apt-transport-https

# -------------------------------
# 2. Install Docker
# -------------------------------
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. You may need to log out and back in for group changes, but the script will continue."
else
    echo "✅ Docker already installed."
fi

# -------------------------------
# 3. Install kubectl
# -------------------------------
if ! command -v kubectl &> /dev/null; then
    echo "☸️ Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "✅ kubectl installed."
else
    echo "✅ kubectl already installed."
fi

# -------------------------------
# 4. Install Minikube
# -------------------------------
if ! command -v minikube &> /dev/null; then
    echo "🚀 Installing Minikube..."
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    chmod +x minikube-linux-amd64
    sudo mv minikube-linux-amd64 /usr/local/bin/minikube
    echo "✅ Minikube installed."
else
    echo "✅ Minikube already installed."
fi

# -------------------------------
# 5. Start Minikube (with Docker driver)
# -------------------------------
echo "⏳ Starting Minikube (this may take a few minutes)..."
minikube start --driver=docker --memory=2500mb --cpus=2 --disk-size=20g

# Wait for cluster to be ready
kubectl wait --for=condition=ready node --all --timeout=120s

# -------------------------------
# 6. Install Helm
# -------------------------------
if ! command -v helm &> /dev/null; then
    echo "🧢 Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    echo "✅ Helm installed."
else
    echo "✅ Helm already installed."
fi

# -------------------------------
# 7. Deploy Prometheus & Grafana using Helm
# -------------------------------
echo "📊 Adding Prometheus community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create a values file with a fixed admin password (change if desired)
cat <<EOF > custom-values.yaml
grafana:
  adminPassword: "Admin123!"
  service:
    type: ClusterIP
EOF

echo "🚀 Installing kube-prometheus-stack..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f custom-values.yaml

# -------------------------------
# 8. Wait for all pods to be ready
# -------------------------------
echo "⏳ Waiting for all monitoring pods to become ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

echo ""
echo "✅✅✅ INSTALLATION COMPLETE ✅✅✅"
echo ""
echo "====================================================="
echo "🔐 Grafana admin password: Admin123!"
echo "====================================================="
echo ""
echo "🌐 To access Grafana and Prometheus from your browser:"
echo ""
echo "1. Keep this terminal open (or run in background) for port-forwarding:"
echo "   kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-grafana 3000:80"
echo "   kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo ""
echo "2. Open your browser at:"
echo "   http://<YOUR_SERVER_PUBLIC_IP>:3000   (Grafana)"
echo "   http://<YOUR_SERVER_PUBLIC_IP>:9090   (Prometheus)"
echo ""
echo "3. You can also use Minikube's built-in service launcher:"
echo "   minikube service -n monitoring monitoring-grafana"
echo "   minikube service -n monitoring monitoring-kube-prometheus-prometheus"
echo ""
echo "🎯 To test with an nginx pod:"
echo "   kubectl run nginx --image=nginx"
echo ""
echo "====================================================="

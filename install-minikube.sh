#!/bin/bash
set -e  # Exit immediately if any command fails

# -------------------------------
# Colors for pretty output
# -------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Minikube installation on Ubuntu...${NC}"

# -------------------------------
# 1. Update system
# -------------------------------
echo -e "${YELLOW}📦 Updating package lists...${NC}"
sudo apt update -y

# -------------------------------
# 2. Install dependencies
# -------------------------------
echo -e "${YELLOW}🔧 Installing required packages (curl, wget, apt-transport-https)...${NC}"
sudo apt install -y curl wget apt-transport-https

# -------------------------------
# 3. Install Docker
# -------------------------------
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker already installed.${NC}"
else
    echo -e "${YELLOW}🐳 Installing Docker...${NC}"
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker installed. You may need to log out and back in for group changes to take effect.${NC}"
fi

# -------------------------------
# 4. Install kubectl
# -------------------------------
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✅ kubectl already installed.${NC}"
else
    echo -e "${YELLOW}☸️ Installing kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo -e "${GREEN}✅ kubectl installed.${NC}"
fi

# -------------------------------
# 5. Install Minikube
# -------------------------------
if command -v minikube &> /dev/null; then
    echo -e "${GREEN}✅ Minikube already installed.${NC}"
else
    echo -e "${YELLOW}🚀 Installing Minikube...${NC}"
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    chmod +x minikube-linux-amd64
    sudo mv minikube-linux-amd64 /usr/local/bin/minikube
    echo -e "${GREEN}✅ Minikube installed.${NC}"
fi

# -------------------------------
# 6. Start Minikube cluster
# -------------------------------
echo -e "${YELLOW}⏳ Starting Minikube cluster (this may take a few minutes)...${NC}"
minikube start --driver=docker --memory=2500mb --cpus=2 --disk-size=20g

# Wait for node to become ready
echo -e "${YELLOW}⏳ Waiting for node to be ready...${NC}"
kubectl wait --for=condition=ready node --all --timeout=120s

# -------------------------------
# 7. Verify installation
# -------------------------------
echo -e "${GREEN}✅ Minikube is running!${NC}"
kubectl get nodes

# -------------------------------
# 8. Print useful information
# -------------------------------
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}🎉 MINIKUBE INSTALLATION COMPLETE 🎉${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo "📌 To interact with your cluster:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo ""
echo "📌 To stop Minikube:"
echo "   minikube stop"
echo ""
echo "📌 To delete the cluster:"
echo "   minikube delete"
echo ""
echo "📌 To access the Kubernetes dashboard:"
echo "   minikube dashboard"
echo ""
echo "📌 If you need to re-apply Docker group permissions (without logout):"
echo "   newgrp docker"
echo ""
echo -e "${GREEN}=====================================================${NC}"

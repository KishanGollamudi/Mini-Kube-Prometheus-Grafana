# Installing Argo CD on Minikube

This guide walks you through installing **Argo CD** on a Minikube cluster using **Helm**, accessing the dashboard, and deploying your first GitOps application.

---

## 📋 Prerequisites

- A running **Minikube** cluster (with at least 2 CPUs and 4GB RAM).
- `kubectl` configured to point to your cluster.
- `helm` installed (see [Helm installation](#install-helm-if-missing) if needed).
- (Optional) `argocd` CLI – useful for automation.

---

## 🧰 1. Install Helm (if not already installed)

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Verify:
```bash
helm version
```

---

## 📦 2. Add the Argo CD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

---

## 🚀 3. Create a Namespace for Argo CD

```bash
kubectl create namespace argocd
```

---

## 🛠️ 4. Install Argo CD Using Helm

We install with the service type `ClusterIP`, then use `port‑forward` for secure access.

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP
```

Wait for all pods to become ready:
```bash
kubectl get pods -n argocd -w
```
Press `Ctrl+C` when you see `argocd-server‑xxxx` in `Running` state.

---

## 🔐 5. Retrieve the Initial Admin Password

Argo CD generates a random password for the `admin` user. Get it with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Save this password – you’ll need it for the first login.

---

## 🌐 6. Access the Argo CD Dashboard

Since we used `ClusterIP`, we must forward a local port to the Argo CD server.

### Port‑Forward the Server

Run this in a **separate terminal** (keep it open):

```bash
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443
```

> If you are on a local Minikube (not a remote EC2), you can omit `--address 0.0.0.0` and use `localhost`.

### Open Your Browser

- **Local Minikube**: `http://localhost:8080`
- **Remote EC2 server**: `http://<PUBLIC_IP>:8080`

Accept the security warning (self‑signed certificate).

### Log In

- **Username:** `admin`
- **Password:** (the password retrieved in step 5)

After the first login, you will be prompted to **change your password**. Choose a strong new password and save it.

> 💡 Once you change the password, the initial secret is no longer used. You can delete it:
> ```bash
> kubectl delete secret argocd-initial-admin-secret -n argocd
> ```

---

## 🖥️ 7. (Optional) Install the Argo CD CLI

The CLI allows you to manage applications from your terminal.

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

Verify:
```bash
argocd version --client
```

Login to your Argo CD server from the CLI:
```bash
argocd login <PUBLIC_IP>:8080 --insecure
```
Enter your admin username and the password you set.

---

## 📦 8. Deploy a Sample Application

Now let’s deploy the official **Guestbook** example application.

### Using the UI

1. Click **New App**.
2. Fill in:
   - **Application Name:** `guestbook`
   - **Project:** `default`
   - **Sync Policy:** `Manual` (or `Automatic` if you want auto‑sync)
   - **Repository URL:** `https://github.com/argoproj/argocd-example-apps.git`
   - **Revision:** `HEAD`
   - **Path:** `guestbook`
   - **Destination:** `https://kubernetes.default.svc`, namespace `default`
3. Click **Create**.
4. Click **Sync** → **Synchronize** to deploy.

### Using the CLI (if installed)

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

argocd app sync guestbook
```

### Verify the Deployment

```bash
kubectl get pods,svc -n default -l app=guestbook
```

You should see a `guestbook-ui` pod and a `guestbook-ui` service.

To access the actual app:
```bash
kubectl port-forward --address 0.0.0.0 svc/guestbook-ui 8081:80
```
Then open `http://<PUBLIC_IP>:8081` in your browser – you’ll see the Guestbook web interface.

---

## 🧹 9. Cleanup (Optional)

To remove Argo CD and all related resources:

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

To also delete the sample application:
```bash
argocd app delete guestbook --cascade
```

---

## 🧪 Troubleshooting

| Problem | Solution |
|---------|----------|
| `kubectl port-forward` fails with “address already in use” | Kill the process using port 8080 (`lsof -i :8080` and `kill <PID>`). |
| Browser shows “Connection refused” | Ensure the port‑forward is still running. Restart it if needed. |
| Login says “Invalid credentials” | If you lost the new password, reset the admin password as described in the [Argo CD docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#reset-admin-password). |
| The `guestbook` app stays `OutOfSync` | Click **Sync** again, or check the logs (`argocd app logs guestbook`). |

---

## 📚 References

- [Argo CD Official Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## ✅ Conclusion

You now have Argo CD running on Minikube, and you’ve deployed your first GitOps application. The dashboard gives you a powerful view of your cluster’s state, while the CLI enables automation.

Next steps:
- Enable **auto‑sync** for your applications.
- Explore **App‑of‑Apps** pattern to manage multiple microservices.
- Integrate with **Argo Rollouts** for progressive delivery.

Happy GitOps! 🚀

This documentation can be used as a standalone guide or included in your project’s `README`. Let me know if you want to add any specific sections (e.g., Ingress setup or multi‑cluster management).

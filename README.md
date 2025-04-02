# Load-Balanced URL Shortener using Docker & Kubernetes

A scalable URL shortener application deployed with Kubernetes featuring multiple instances and load balancing.

## Architecture

- **URL Shortener Service**: Flask application that creates and resolves shortened URLs
- **Redis**: Key-value store for URL mappings
- **Kubernetes**: Container orchestration with load balancing

## Prerequisites

- Docker
- Kubernetes cluster (Minikube/Docker Desktop)
- kubectl CLI tool

## Deployment Options

### Option 1: Automated Setup

```bash
# Make the script executable
chmod +x setup.sh

# Run the setup script
./setup.sh
```

The script will:
- Clean up existing resources
- Deploy Redis and URL shortener
- Create port forwarding
- Let you interactively create shortened URLs

### Option 2: Manual Deployment

1. Build the Docker image:
```bash
docker build -t url-shortener:latest .
```

2. Deploy the Kubernetes resources:
```bash
# Create directory if needed
mkdir -p k8s

# Apply ConfigMap first
kubectl apply -f k8s/configmap.yaml

# Deploy Redis
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/redis-service.yaml

# Deploy URL shortener
kubectl apply -f k8s/url-shortener-deployment.yaml
kubectl apply -f k8s/url-shortener-service.yaml
```

3. Set up port forwarding:
```bash
kubectl port-forward svc/url-shortener-service 8080:5000
```

4. Test the application:
```bash
# Create a shortened URL
curl -X POST -H "Content-Type: application/json" -d '{"url":"https://example.com"}' http://localhost:8080/shorten

# Access the shortened URL
curl -L http://localhost:8080/<short_code>
```

## Scaling

Scale the application to increase throughput:
```bash
kubectl scale deployment/url-shortener-deployment --replicas=5
```

## Monitoring

```bash
# Check pod status
kubectl get pods

# View logs
kubectl logs -l app=url-shortener
```

## Cleanup

Remove all resources:
```bash
kubectl delete -f k8s/
```

## Implementation Details

- Flask application using Redis for persistence
- 3 URL shortener replicas for high availability
- Internal Redis service with ClusterIP
- External URL shortener service
- Connection retry logic and fallback storage

# Kubernetes Deployment for URL Shortener

This directory contains Kubernetes manifests for deploying the URL Shortener application with Redis.

## Components

1. **URL Shortener Deployment**: Runs multiple instances of the Flask application
2. **Redis Deployment**: Stores the shortened URLs
3. **ConfigMap**: Contains environment variables
4. **Services**: Exposes the applications internally and externally

## Deployment Instructions

### 1. Build and Push the Docker Image

```bash
# From the root directory
docker build -t url-shortener:latest .
# If using a custom registry, tag and push the image
# docker tag url-shortener:latest your-registry/url-shortener:latest
# docker push your-registry/url-shortener:latest
```

### 2. Apply the Kubernetes Manifests

```bash
# Apply the ConfigMap first
kubectl apply -f k8s/configmap.yaml

# Deploy Redis
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/redis-service.yaml

# Deploy URL Shortener
kubectl apply -f k8s/url-shortener-deployment.yaml
kubectl apply -f k8s/url-shortener-service.yaml
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc
```

### 4. Test the Application

The URL Shortener is exposed via NodePort on port 30000. You can access it using:

```
http://<node-ip>:30000/
```

To create a shortened URL, send a POST request:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"url":"https://example.com"}' http://<node-ip>:30000/shorten
```

## Scaling the Application

You can scale the URL Shortener by changing the number of replicas:

```bash
kubectl scale deployment/url-shortener-deployment --replicas=5
``` 
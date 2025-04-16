# URL Shortener with Kubernetes Load Balancing

A scalable URL shortener service deployed on Kubernetes with multiple replicas, load balancing, and auto-scaling capabilities.

## Features

- URL shortening with validation
- Redis-based storage
- Kubernetes deployment with multiple replicas
- Horizontal Pod Autoscaling (HPA)
- Load balancing through Ingress
- Monitoring and logging
- Stress testing capabilities

## Architecture

- **URL Shortener**: Flask application (3+ replicas) with auto-scaling
- **Redis**: In-memory key-value store for URL mappings
- **Kubernetes Components**:
  - HPA for automatic scaling
  - Ingress for load balancing
  - ConfigMap for configuration
  - NodePort Service for external access
  - ClusterIP Service for Redis

## Prerequisites

- Docker
- Minikube
- kubectl
- curl (for testing)
- hey (for stress testing)

## Quick Start

1. Start Minikube:
```bash
minikube start --driver=docker
```

2. Make the setup script executable and run it:
```bash
chmod +x setup.sh
./setup.sh
```

The script will:
- Set up Minikube and enable ingress
- Create all necessary Kubernetes resources
- Build and deploy the Docker containers
- Configure networking
- Set up monitoring
- Verify the deployment

## Testing the Service

1. Test URL shortening:
```bash
# Valid URL
curl -X POST -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' \
  http://localhost:8080/shorten

# Invalid URL
curl -X POST -H "Content-Type: application/json" \
  -d '{"url":"not-a-url"}' \
  http://localhost:8080/shorten
```

2. Test URL redirection:
```bash
# Use the short_code from the previous response
curl -L http://localhost:8080/<short_code>
```

## Monitoring

1. Check pod status:
```bash
kubectl get pods
```

2. Check HPA status:
```bash
kubectl get hpa
```

3. View logs:
```bash
# View logs for all URL shortener pods
kubectl logs -l app=url-shortener

# View logs for a specific pod
kubectl logs <pod-name>
```

4. Check resource usage:
```bash
kubectl top pods
```

## Stress Testing

Run a stress test using hey:
```bash
hey -n 1000 -c 50 -m POST \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' \
  http://localhost:8080/shorten
```

This will:
- Send 1000 requests
- Use 50 concurrent connections
- Measure response times and success rates

## Scaling

The system automatically scales based on CPU usage:
- Minimum replicas: 3
- Maximum replicas: 10
- Target CPU utilization: 50%

## Cleanup

To clean up all resources:
```bash
# Delete all Kubernetes resources
kubectl delete -f k8s/

# Stop Minikube
minikube stop
minikube delete
```

## Implementation Details

### URL Shortening Process

1. Client sends a POST request with a URL to `/shorten`
2. Application validates the URL format
3. If valid, generates a 6-character hash using MD5
4. Stores mapping in Redis (short_code → original_url)
5. Returns short URL to the client
6. When short URL is accessed, user is redirected to original URL

### Kubernetes Configuration

- **URL Shortener Deployment**: 3+ replicas with auto-scaling
- **Redis Deployment**: Single instance for data store
- **Service Types**:
  - ClusterIP for Redis (internal access)
  - NodePort for URL Shortener (external access)
- **HPA**: Automatic scaling based on CPU usage
- **Ingress**: Load balancing and routing

## Troubleshooting

1. If pods are in Pending state:
```bash
kubectl describe pod <pod-name>
```

2. If port forwarding fails:
```bash
# Kill existing port-forward process
pkill -f "port-forward"

# Start new port-forward
kubectl port-forward svc/url-shortener-service 8080:5000
```

3. If service is not accessible:
```bash
# Check service status
kubectl get svc

# Get Minikube IP
minikube ip
```

## Files

- `app.py`: Flask application for URL shortening
- `Dockerfile`: Container definition
- `setup.sh`: Automated deployment script
- `k8s/`: Kubernetes manifest files
  - `configmap.yaml`: Environment variables
  - `redis-deployment.yaml`: Redis database
  - `redis-service.yaml`: Internal Redis access
  - `url-shortener-deployment.yaml`: URL shortener with 3 replicas
  - `url-shortener-service.yaml`: External URL shortener access

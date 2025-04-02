
## Scaling

To scale the number of URL shortener replicas:

```bash
kubectl scale deployment/url-shortener-deployment --replicas=5
```

## Monitoring

Check the status of your pods:
```bash
kubectl get pods
```

View logs from the URL shortener pods:
```bash
kubectl logs -l app=url-shortener
```

## Cleanup

To remove all resources:
```bash
kubectl delete -f k8s/
```

## Implementation Details

This project implements a URL shortener service with the following technical features:

1. Flask web application that:
   - Generates short URLs using MD5 hashing
   - Stores URL mappings in Redis
   - Redirects users from short URLs to original URLs

2. Containerization with Docker

3. Kubernetes deployment with:
   - Multiple URL shortener replicas for high availability
   - ClusterIP service for internal Redis access
   - Service for external URL shortener access
   - ConfigMap for environment variables

4. Fault tolerance:
   - Connection retry logic for Redis
   - Fallback in-memory storage if Redis is unavailable
   - Detailed logging for troubleshooting

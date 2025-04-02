#!/bin/bash
set -e

# Function to check if port is in use
check_port() {
  local port=$1
  nc -z localhost $port &>/dev/null
  return $?
}

# Function to ensure port forwarding is working
ensure_port_forwarding() {
  local attempts=0
  local max_attempts=5
  
  echo "Setting up port forwarding to URL shortener on port 8080..."
  
  # Kill any existing port forwarding on port 8080
  lsof -ti:8080 | xargs kill -9 2>/dev/null || true
  
  # Start port forwarding
  kubectl port-forward svc/url-shortener-service 8080:5000 &
  PF_PID=$!
  
  # Wait a moment for port forwarding to establish
  sleep 3
  
  # Check if port forwarding is working
  while ! check_port 8080; do
    attempts=$((attempts+1))
    if [ $attempts -ge $max_attempts ]; then
      echo "❌ Port forwarding failed after $max_attempts attempts."
      echo "Killing process $PF_PID and exiting."
      kill $PF_PID 2>/dev/null || true
      exit 1
    fi
    
    echo "Port 8080 not responding. Retrying port forwarding ($attempts/$max_attempts)..."
    kill $PF_PID 2>/dev/null || true
    kubectl port-forward svc/url-shortener-service 8080:5000 &
    PF_PID=$!
    sleep 3
  done
  
  echo "✅ Port forwarding established successfully (PID: $PF_PID)"
  echo "To stop port forwarding manually, run: kill $PF_PID"
}

# Function to shorten a URL
shorten_url() {
  local url=$1
  
  echo "Shortening URL: $url"
  curl -s -X POST -H "Content-Type: application/json" -d "{\"url\":\"$url\"}" http://localhost:8080/shorten | json_pp || {
    echo "❌ Failed to shorten URL. Checking if port forwarding is still active..."
    if ! ps -p $PF_PID > /dev/null; then
      echo "Port forwarding is no longer active. Reestablishing..."
      ensure_port_forwarding
      echo "Retrying URL shortening..."
      curl -s -X POST -H "Content-Type: application/json" -d "{\"url\":\"$url\"}" http://localhost:8080/shorten | json_pp
    else
      echo "Port forwarding is active but request failed. There might be a problem with the service."
    fi
  }
}

# Check for a URL argument or prompt for one
if [ $# -eq 1 ] && [[ $1 == http* ]]; then
  URL_TO_SHORTEN=$1
else
  # Main setup
  echo "=== STEP 1: CLEANUP ==="
  echo "Cleaning up existing resources..."
  kubectl delete deployments --all 2>/dev/null || true
  kubectl delete services --all 2>/dev/null || true
  kubectl delete configmaps --all 2>/dev/null || true
  sleep 3

  echo "=== STEP 2: SETUP FILES ==="
  # Create directory structure
  mkdir -p k8s

  # Create ConfigMap for environment variables
  echo "Creating ConfigMap..."
  cat > k8s/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: url-shortener-config
data:
  BASE_URL: "http://localhost:8080/"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
EOF

  # Create Redis deployment
  echo "Creating Redis deployment..."
  cat > k8s/redis-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:latest
        ports:
        - containerPort: 6379
EOF

  # Create Redis service
  echo "Creating Redis service..."
  cat > k8s/redis-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

  # Update app.py for correct environment variables
  echo "Updating app.py..."
  cat > app.py << 'EOF'
from flask import Flask, request, redirect, jsonify
import redis
import hashlib
import os
import time
import socket

app = Flask(__name__)

# Get environment variables with defaults
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
BASE_URL = os.environ.get('BASE_URL', "http://localhost:5000/")

# Print information for debugging
print(f"[INFO] Starting URL shortener app")
print(f"[INFO] Hostname: {socket.gethostname()}")
print(f"[INFO] BASE_URL: {BASE_URL}")
print(f"[INFO] REDIS_HOST: {REDIS_HOST}")
print(f"[INFO] REDIS_PORT: {REDIS_PORT}")

# Connect to Redis with retry logic
def get_redis_connection(max_retries=5, retry_delay=3):
    retries = 0
    while retries < max_retries:
        try:
            print(f"[INFO] Attempting to connect to Redis at {REDIS_HOST}:{REDIS_PORT} (attempt {retries+1})")
            redis_client = redis.StrictRedis(
                host=REDIS_HOST, 
                port=REDIS_PORT, 
                db=0, 
                decode_responses=True,
                socket_timeout=5
            )
            redis_client.ping()  # Test if connection works
            print("[INFO] Successfully connected to Redis")
            return redis_client
        except redis.exceptions.ConnectionError as e:
            print(f"[ERROR] Failed to connect to Redis: {e}")
            retries += 1
            if retries < max_retries:
                print(f"[INFO] Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print("[ERROR] Max retries reached. Using fallback mode.")
                return None

# Try to connect to Redis, or use fallback
redis_client = get_redis_connection()

# Dictionary to store URLs if Redis is not available
fallback_store = {}

def generate_short_url(long_url):
    """Generate a short hash for the given long URL."""
    short_hash = hashlib.md5(long_url.encode()).hexdigest()[:6]
    return short_hash

@app.route('/', methods=['GET'])
def index():
    """Basic health check endpoint."""
    hostname = socket.gethostname()
    redis_status = "connected" if redis_client else "disconnected"
    return jsonify({
        "status": "healthy",
        "message": "URL Shortener API is running",
        "hostname": hostname,
        "redis_status": redis_status
    })

@app.route('/shorten', methods=['POST'])
def shorten_url():
    """Accept a long URL and return a shortened version."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
            
        long_url = data.get("url")
        if not long_url:
            return jsonify({"error": "URL is required"}), 400

        short_url = generate_short_url(long_url)
        
        # Try to store in Redis, fall back to local dict if Redis is unavailable
        if redis_client:
            redis_client.set(short_url, long_url)
        else:
            fallback_store[short_url] = long_url
            print(f"[INFO] Stored in fallback: {short_url} -> {long_url}")
        
        return jsonify({
            "original_url": long_url,
            "short_url": BASE_URL + short_url,
            "short_code": short_url
        })
    except Exception as e:
        print(f"[ERROR] Error in /shorten: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/<short_url>', methods=['GET'])
def redirect_to_original(short_url):
    """Redirect users from the short URL to the original long URL."""
    try:
        long_url = None
        if redis_client:
            long_url = redis_client.get(short_url)
        else:
            long_url = fallback_store.get(short_url)
            
        if long_url:
            return redirect(long_url, code=302)
        return jsonify({"error": "Short URL not found"}), 404
    except Exception as e:
        print(f"[ERROR] Error in redirect: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)
EOF

  # Create Dockerfile
  echo "Updating Dockerfile..."
  cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY . .

RUN pip install flask redis

EXPOSE 5000

CMD ["python", "app.py"]
EOF

  # Create URL shortener deployment
  echo "Creating URL shortener deployment..."
  cat > k8s/url-shortener-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: url-shortener-deployment
  labels:
    app: url-shortener
spec:
  replicas: 3
  selector:
    matchLabels:
      app: url-shortener
  template:
    metadata:
      labels:
        app: url-shortener
    spec:
      containers:
      - name: url-shortener
        image: url-shortener:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        env:
        - name: REDIS_HOST
          value: "redis-service"
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: url-shortener-config
              key: REDIS_PORT
        - name: BASE_URL
          valueFrom:
            configMapKeyRef:
              name: url-shortener-config
              key: BASE_URL
EOF

  # Create URL shortener service
  echo "Creating URL shortener service..."
  cat > k8s/url-shortener-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: url-shortener-service
spec:
  selector:
    app: url-shortener
  ports:
  - port: 5000
    targetPort: 5000
EOF

  echo "=== STEP 3: DEPLOY EVERYTHING ==="
  echo "Building Docker image..."
  docker build -t url-shortener:latest .

  echo "Applying Kubernetes manifests..."
  kubectl apply -f k8s/configmap.yaml
  kubectl apply -f k8s/redis-deployment.yaml
  kubectl apply -f k8s/redis-service.yaml
  kubectl apply -f k8s/url-shortener-deployment.yaml
  kubectl apply -f k8s/url-shortener-service.yaml

  echo "Waiting for pods to be ready..."
  echo "Checking Redis pods..."
  kubectl wait --for=condition=Ready pods --selector=app=redis --timeout=90s || true
  echo "Checking URL shortener pods..."
  kubectl wait --for=condition=Ready pods --selector=app=url-shortener --timeout=90s || true

  # Set up port forwarding
  ensure_port_forwarding

  # Test health check
  echo "Testing health endpoint:"
  curl -s http://localhost:8080/ | json_pp || echo "Health check failed"
  
  echo -e "\n=== ENTER URL TO SHORTEN ==="
  read -p "Enter a URL to shorten (including http:// or https://): " URL_TO_SHORTEN
fi

# If we have a URL to shorten, do it
if [ -n "$URL_TO_SHORTEN" ]; then
  # Make sure port forwarding is working
  if ! check_port 8080; then
    ensure_port_forwarding
  fi
  
  # Shorten the URL
  shorten_url "$URL_TO_SHORTEN"
  
  # Ask if user wants to shorten another URL
  while true; do
    echo ""
    read -p "Do you want to shorten another URL? (y/n): " ANSWER
    case $ANSWER in
      [Yy]* )
        read -p "Enter a URL to shorten (including http:// or https://): " URL_TO_SHORTEN
        shorten_url "$URL_TO_SHORTEN"
        ;;
      [Nn]* )
        echo "Exiting URL shortener. Port forwarding is still active (PID: $PF_PID)."
        echo "To stop port forwarding, run: kill $PF_PID"
        break
        ;;
      * ) 
        echo "Please answer yes (y) or no (n)."
        ;;
    esac
  done
fi
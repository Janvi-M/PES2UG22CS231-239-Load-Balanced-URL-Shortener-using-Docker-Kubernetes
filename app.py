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

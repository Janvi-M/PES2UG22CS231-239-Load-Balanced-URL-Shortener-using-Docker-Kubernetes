from flask import Flask, request, redirect, jsonify
import redis
import hashlib
import os
from urllib.parse import urlparse
import re

app = Flask(__name__)

# Get environment variables with defaults
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))
BASE_URL = os.environ.get('BASE_URL', "http://localhost:5000/")

# Connect to Redis
redis_client = redis.StrictRedis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

def is_valid_url(url):
    """Validate if the given string is a valid URL."""
    try:
        # Check if URL is a string
        if not isinstance(url, str):
            return False
            
        # Check if URL starts with http:// or https://
        if not url.startswith(('http://', 'https://')):
            return False
            
        # Parse the URL
        result = urlparse(url)
        
        # Check if scheme and netloc are present
        if not all([result.scheme, result.netloc]):
            return False
            
        # Check if domain is valid (contains at least one dot and valid characters)
        domain_pattern = r'^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](\.[a-zA-Z]{2,})+$'
        if not re.match(domain_pattern, result.netloc):
            return False
            
        # Additional check to ensure the URL is not just a string without a valid domain
        if '.' not in result.netloc:
            return False
            
        # Check if the URL is not just a string without a valid domain
        if len(result.netloc.split('.')) < 2:
            return False
            
        return True
    except:
        return False

def generate_short_url(long_url):
    """Generate a short hash for the given long URL."""
    short_hash = hashlib.md5(long_url.encode()).hexdigest()[:6]
    return short_hash

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "status": "ok",
        "message": "URL Shortener API is running"
    })

@app.route('/shorten', methods=['POST'])
def shorten_url():
    """Accept a long URL and return a shortened version."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON data provided"}), 400
        
    long_url = data.get("url")
    if not long_url:
        return jsonify({"error": "URL is required"}), 400

    if not is_valid_url(long_url):
        return jsonify({"error": "Invalid URL provided. URL must start with http:// or https:// and contain a valid domain name"}), 400

    short_url = generate_short_url(long_url)
    redis_client.set(short_url, long_url)
    
    return jsonify({
        "original_url": long_url,
        "short_url": BASE_URL + short_url,
        "short_code": short_url
    })

@app.route('/<short_url>', methods=['GET'])
def redirect_to_original(short_url):
    """Redirect users from the short URL to the original long URL."""
    long_url = redis_client.get(short_url)
    if long_url:
        return redirect(long_url, code=302)
    return jsonify({"error": "Short URL not found"}), 404

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)

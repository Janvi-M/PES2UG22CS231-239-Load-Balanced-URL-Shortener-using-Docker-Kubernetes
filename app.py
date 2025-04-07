from flask import Flask, request, redirect, jsonify
import redis
import hashlib

app = Flask(__name__)
redis_client = redis.StrictRedis(host='localhost', port=6381, db=0, decode_responses=True)

BASE_URL = "http://localhost:5000/" 

def generate_short_url(long_url):
    """Generate a short hash for the given long URL."""
    short_hash = hashlib.md5(long_url.encode()).hexdigest()[:6]
    return short_hash

@app.route('/shorten', methods=['POST'])
def shorten_url():
    """Accept a long URL and return a shortened version."""
    data = request.get_json()
    long_url = data.get("url")

    if not long_url:
        return jsonify({"error": "URL is required"}), 400

    short_url = generate_short_url(long_url)
    redis_client.set(short_url, long_url)  # Store mapping in Redis

    return jsonify({"short_url": BASE_URL + short_url})

@app.route('/<short_url>', methods=['GET'])
def redirect_to_original(short_url):
    """Redirect users from the short URL to the original long URL."""
    long_url = redis_client.get(short_url)
    if long_url:
        return redirect(long_url, code=302)
    return jsonify({"error": "Short URL not found"}), 404

@app.route('/list', methods=['GET'])
def list_urls():
    """List all short-long URL pairs."""
    keys = redis_client.keys('*')
    url_map = {}

    for key in keys:
        url_map[key] = redis_client.get(key)
    
    return jsonify(url_map)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)


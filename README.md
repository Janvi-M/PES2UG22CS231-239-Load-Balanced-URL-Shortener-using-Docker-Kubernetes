#COMMANDS TO RUN THIS PROJECT- 

docker pull redis

docker run --name redis-server -d -p 6381:6379 redis

docker ps

python3 -m venv venv

source venv/bin/activate

pip install flask redis

python app.py

IN ANOTHER TERMINAL
curl -X POST http://localhost:5000/shorten -H "Content-Type: application/json" -d '{"url": "https://www.google.com"}'

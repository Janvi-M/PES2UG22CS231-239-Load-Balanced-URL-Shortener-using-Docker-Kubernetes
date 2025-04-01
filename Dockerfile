# Use an official Python image as a base
FROM python:3.9

# Set the working directory inside the container
WORKDIR /app

# Copy the current directory contents into the container
COPY . .

# Install dependencies
RUN pip install flask redis

# Expose the Flask app port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]

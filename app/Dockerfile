# Import python Base image
FROM python:3.11-slim

# Install nginx web server
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

# Set working directory inside container filesystem
WORKDIR /app

# Copy Python dependencies file and install them
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . /app/

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Document that the container listens on port 8000
EXPOSE 8000

# Start FastAPI backend and nginx reverse proxy
CMD uvicorn main:app --host 127.0.0.1 --port 8001 & nginx -g 'daemon off;'

# First part starts the FastAPI application server.
# main        → file main.py
# app         → FastAPI object inside main.py
# 127.0.0.1   → listen only inside the container
# 8001        → backend application port
# & symbol    → run the first process in background
# So FastAPI runs internally on: localhost:8001


# Second part starts nginx.
# nginx -g 'daemon off;'
# Meaning:
# start nginx
# run in foreground
# daemon off is required because Docker containers must keep one main foreground process running.
# If nginx ran in background, the container would exit.

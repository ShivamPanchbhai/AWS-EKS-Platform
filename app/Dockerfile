FROM python:3.11-slim

# install nginx
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

# create non-root user
RUN useradd -m appuser

WORKDIR /app

# copy requirements and install
COPY app/requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# copy app code
COPY app/ /app/

# copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# expose nginx port
EXPOSE 8000

# start uvicorn on 8001 and nginx on 8000
CMD uvicorn main:app --host 127.0.0.1 --port 8001 & nginx -g 'daemon off;'

FROM python:3.11-slim

# create non-root user
RUN useradd -m appuser

WORKDIR /app

COPY app/requirements.txt /app/

# install python libraries
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /app/

# switch to non-root user
USER appuser

# the port the app listens on
EXPOSE 8000

# 0.0.0.0 = accept traffic from outside container
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

# CMD -> When this container starts, run this process

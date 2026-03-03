# Use slim Python base image
FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy test script
COPY test.py .

# Default command: run the test script
CMD ["python", "test.py"]

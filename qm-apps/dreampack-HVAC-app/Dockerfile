FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Set environment variables
ENV PYTHONPATH=/app/src
ENV KUKSA_ADDRESS=localhost
ENV KUKSA_PORT=55555

# Create non-root user for security
RUN useradd -m -u 1000 hvacapp && chown -R hvacapp:hvacapp /app
USER hvacapp

# Health check - test imports
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "from src.databroker_client import DataBrokerClient; print('Health check passed')" || exit 1

# Run the simplified DataBroker application
CMD ["python", "src/main.py"]
#!/bin/bash

# Setup script for Ollama server with Open WebUI and Cloudflare tunnel
# ---------------------------------------------------------------------

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting setup process..."

# Create a directory for logs
mkdir -p logs
LOG_FILE="logs/setup_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Check if .env file exists and ask to overwrite
if [ -f .env ]; then
    read -p "An .env file already exists. Overwrite it? (y/n): " overwrite
    if [[ $overwrite != "y" && $overwrite != "Y" ]]; then
        log "Using existing .env file"
        source .env
    else
        # Get required information
        log "Creating new .env file..."
        rm -f .env
        touch .env

        # Ask for local IP address
        read -p "Enter your local IP address (e.g., 192.168.1.100): " LOCAL_IP
        echo "LOCAL_IP=$LOCAL_IP" >> .env
        log "Local IP set to: $LOCAL_IP"

        # Ask for Cloudflared token
        read -p "Enter your Cloudflared tunnel token: " CLOUDFLARED_KEY
        echo "CLOUDFLARED_KEY=$CLOUDFLARED_KEY" >> .env
        log "Cloudflared token saved to .env file"
    fi
else
    # Get required information
    log "Creating .env file..."
    touch .env

    # Ask for local IP address
    read -p "Enter your local IP address (e.g., 192.168.1.100): " LOCAL_IP
    echo "LOCAL_IP=$LOCAL_IP" >> .env
    log "Local IP set to: $LOCAL_IP"

    # Ask for Cloudflared token
    read -p "Enter your Cloudflared tunnel token: " CLOUDFLARED_KEY
    echo "CLOUDFLARED_KEY=$CLOUDFLARED_KEY" >> .env
    log "Cloudflared token saved to .env file"
fi

# Source the .env file to get variables
source .env

# Create docker-compose.yml file
log "Creating docker-compose.yml file..."
cat > docker-compose.yml << EOL
version: '3'

networks:
  docker_bridge:
    driver: bridge

volumes:
  ollama:
  open-webui:

services:
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    volumes:
      - ollama:/root/.ollama
    ports:
      - "11434:11434"
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    restart: always
    networks:
      - docker_bridge
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui:/app/backend/data
    ports:
      - "3000:8080"
    restart: always
    networks:
      - docker_bridge
    depends_on:
      - ollama

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    command: tunnel --no-autoupdate run --token \${CLOUDFLARED_KEY} --url=\${LOCAL_IP}
    restart: always
    networks:
      - docker_bridge
    depends_on:
      - open-webui

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: -i 300 open-webui
    restart: always
EOL

log "docker-compose.yml created successfully"

# Stop and remove any existing containers with the same names
log "Stopping and removing any existing containers..."
docker stop open-webui cloudflared watchtower ollama 2>/dev/null || true
docker rm open-webui cloudflared watchtower ollama 2>/dev/null || true
log "Containers stopped and removed"

# Run docker-compose
log "Starting services using docker-compose..."
if docker-compose up -d; then
    log "All services started successfully!"
    log "Container status:"
    docker-compose ps
else
    log "ERROR: Failed to start services. Check the logs above for details."
    exit 1
fi

# Print success message and next steps
log "Setup completed successfully!"
log "You can access the Open WebUI at http://localhost:3000"
log "Your Cloudflare tunnel should be active and connecting to: $LOCAL_IP"
log "To view logs, run: docker-compose logs -f"
log "To stop all services, run: docker-compose down"

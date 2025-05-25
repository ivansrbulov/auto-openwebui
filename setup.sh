#!/bin/bash

# Setup script for Ollama server with Open WebUI and Cloudflare tunnel
# ---------------------------------------------------------------------

# Function to log messages
log() {
    echo "[INFO] $1"
}

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    # Create new .env file
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
else
    # If .env exists, check if all required variables are set
    if grep -q "LOCAL_IP=" .env && grep -q "CLOUDFLARED_KEY=" .env; then
        log "Using existing .env file with complete configuration."
    else
        read -p ".env file is incomplete. Recreate it? (y/n): " recreate_env
        if [[ $recreate_env == "y" || $recreate_env == "Y" ]]; then
            rm -f .env
            touch .env

            # Ask for local IP address again
            read -p "Enter your local IP address (e.g., 192.168.1.100): " LOCAL_IP
            echo "LOCAL_IP=$LOCAL_IP" >> .env
            log "Local IP set to: $LOCAL_IP"

            # Ask for Cloudflared token again
            read -p "Enter your Cloudflared tunnel token: " CLOUDFLARED_KEY
            echo "CLOUDFLARED_KEY=$CLOUDFLARED_KEY" >> .env
            log "Cloudflared token saved to .env file"
        else
            log "Using existing incomplete .env file."
        fi
    fi
fi

# Source the .env file to get variables
source .env

# Ask for GPU type
read -p "Is your system using an NVIDIA or AMD GPU? (Enter 'nvidia' or 'amd'): " GPU_TYPE

# Set Ollama image based on GPU type
if [ "$GPU_TYPE" == "nvidia" ]; then
    OLLAMA_IMAGE="ollama/ollama:main"
    DEVICE_SETTINGS="- driver: nvidia
      - count: all
      - capabilities: [gpu]"
elif [ "$GPU_TYPE" == "amd" ]; then
    OLLAMA_IMAGE="ollama/ollama:rocm"
    DEVICE_SETTINGS="- /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri"
else
    log "ERROR: Invalid GPU type. Please enter 'nvidia' or 'amd'."
    exit 1
fi

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
    image: $OLLAMA_IMAGE
    container_name: ollama
    volumes:
      - ollama:/root/.ollama
    ports:
      - "11434:11434"
    devices:
      $DEVICE_SETTINGS
    restart: always
    networks:
      - docker_bridge

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
    environment:
      - OLLAMA_BASE_URL=http://$LOCAL_IP:11434

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

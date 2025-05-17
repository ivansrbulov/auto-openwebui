#!/bin/bash
set -e

# Configuration - You can modify these variables
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

# Default operation is to start
OPERATION="start"

# Process command-line arguments
if [ $# -gt 0 ]; then
  OPERATION=$1
fi

# Function to detect GPU type (NVIDIA CUDA or AMD ROCm)
function detect_gpu_type() {
  # Check for NVIDIA GPU
  if command -v nvidia-smi &>/dev/null; then
    echo "NVIDIA CUDA detected"
    return 1
  fi

  # Check for AMD ROCm
  if [ -d "/dev/dri" ] && [ -c "/dev/kfd" ]; then
    echo "AMD ROCm detected"
    return 2
  fi

  # No GPU or unsupported GPU
  echo "No compatible GPU detected. Using CPU-only configuration."
  return 0
}

# Create .env file if it doesn't exist
if [ ! -f "$ENV_FILE" ]; then
  echo "Creating example .env file. Please edit it with your actual values."
  cat > "$ENV_FILE" << EOF
# Docker environment variables
# Replace with your actual Cloudflare tunnel token
CLOUDFLARED_KEY=your_cloudflare_tunnel_token

# Your local IP address for Cloudflare tunnel to connect to
# Replace with your actual local IP (try `ifconfig` or `ip addr show` in the terminal)
LOCAL_IP=192.168.1.1
EOF
  echo "Created $ENV_FILE"
  echo "Please edit the $ENV_FILE file with your actual values before continuing."
  exit 1
fi

# Source environment variables
source "$ENV_FILE"

# Create docker-compose.yml file if it doesn't exist
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Creating docker-compose.yml file..."

  # Detect GPU type
  detect_gpu_type
  GPU_TYPE=$?

  # Base common services
  BASE_SERVICES=$(cat << 'EOF'
version: '3'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    volumes:
      - open-webui:/app/backend/data
    networks:
      - docker_bridge
    depends_on:
      - ollama

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: always
    command: tunnel --no-autoupdate run --token ${CLOUDFLARED_KEY} --url=${LOCAL_IP}
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

networks:
  docker_bridge:
    driver: bridge

volumes:
  ollama:
  open-webui:
EOF
)

  # NVIDIA CUDA configuration
  NVIDIA_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

  # AMD ROCm configuration
  ROCM_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    devices:
      - /dev/kfd
      - /dev/dri
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

  # CPU-only configuration
  CPU_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

  # Generate the appropriate docker-compose.yml based on GPU type
  if [ "$GPU_TYPE" -eq 1 ]; then
    # NVIDIA CUDA
    echo "Configuring for NVIDIA CUDA..."
    echo "$BASE_SERVICES" | sed "/services:/a\\$NVIDIA_CONFIG" > "$COMPOSE_FILE"
  elif [ "$GPU_TYPE" -eq 2 ]; then
    # AMD ROCm
    echo "Configuring for AMD ROCm..."
    echo "$BASE_SERVICES" | sed "/services:/a\\$ROCM_CONFIG" > "$COMPOSE_FILE"
  else
    # CPU only
    echo "Configuring for CPU only..."
    echo "$BASE_SERVICES" | sed "/services:/a\\$CPU_CONFIG" > "$COMPOSE_FILE"
  fi

  echo "Created $COMPOSE_FILE with appropriate GPU configuration"
fi

function show_help() {
  echo "Usage: $0 [operation]"
  echo ""
  echo "Operations:"
  echo "  start    - Start all containers (default)"
  echo "  stop     - Stop all containers"
  echo "  restart  - Restart all containers"
  echo "  status   - Show container status"
  echo "  clean    - Stop and remove containers, networks, and volumes"
  echo "  recreate - Recreate docker-compose.yml file with current GPU detection"
  echo "  help     - Show this help message"
  echo ""
}

function create_network() {
  # Check if the docker_bridge network exists, if not create it
  if ! docker network inspect docker_bridge &>/dev/null; then
    echo "Creating docker_bridge network..."
    docker network create docker_bridge
  fi
}

function start_containers() {
  echo "Starting containers with Docker Compose..."
  create_network
  docker compose up -d
  echo ""
  show_status
}

function stop_containers() {
  echo "Stopping containers..."
  docker compose down
  echo "Containers stopped."
}

function restart_containers() {
  echo "Restarting containers..."
  docker compose restart
  echo "Containers restarted."
  echo ""
  show_status
}

function show_status() {
  echo "Container status:"
  docker compose ps
  echo ""
  echo "Access the WebUI at:"
  echo "- Local: http://localhost:3000"
  # Try to get IP address for better display
  IP_ADDR=$(hostname -I | awk '{print $1}')
  if [ -n "$IP_ADDR" ]; then
    echo "- Network: http://$IP_ADDR:3000"
  fi
  echo "- Cloudflare tunnel will be accessible via your configured domain"
}

function clean_all() {
  echo "Stopping and removing containers, networks, and volumes..."
  docker compose down -v
  # Additional cleanup for any leftovers
  docker stop ollama open-webui cloudflared watchtower 2>/dev/null || true
  docker rm ollama open-webui cloudflared watchtower 2>/dev/null || true
  docker volume rm ollama open-webui 2>/dev/null || true
  echo "Cleanup complete!"
}

function recreate_compose() {
  echo "Recreating docker-compose.yml file with current GPU detection..."
  if [ -f "$COMPOSE_FILE" ]; then
    mv "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"
    echo "Backed up existing file to ${COMPOSE_FILE}.bak"
  fi
  # Remove the file to force recreation
  rm -f "$COMPOSE_FILE"
  # Call this function again to create a new file
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Creating docker-compose.yml file..."

    # Detect GPU type
    detect_gpu_type
    GPU_TYPE=$?

    # Base common services
    BASE_SERVICES=$(cat << 'EOF'
version: '3'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    volumes:
      - open-webui:/app/backend/data
    networks:
      - docker_bridge
    depends_on:
      - ollama

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: always
    command: tunnel --no-autoupdate run --token ${CLOUDFLARED_KEY} --url=${LOCAL_IP}
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

networks:
  docker_bridge:
    driver: bridge

volumes:
  ollama:
  open-webui:
EOF
)

    # NVIDIA CUDA configuration
    NVIDIA_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

    # AMD ROCm configuration
    ROCM_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    devices:
      - /dev/kfd
      - /dev/dri
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

    # CPU-only configuration
    CPU_CONFIG=$(cat << 'EOF'
  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal
    networks:
      - docker_bridge
EOF
)

    # Generate the appropriate docker-compose.yml based on GPU type
    if [ "$GPU_TYPE" -eq 1 ]; then
      # NVIDIA CUDA
      echo "Configuring for NVIDIA CUDA..."
      echo "$BASE_SERVICES" | sed "/services:/a\\$NVIDIA_CONFIG" > "$COMPOSE_FILE"
    elif [ "$GPU_TYPE" -eq 2 ]; then
      # AMD ROCm
      echo "Configuring for AMD ROCm..."
      echo "$BASE_SERVICES" | sed "/services:/a\\$ROCM_CONFIG" > "$COMPOSE_FILE"
    else
      # CPU only
      echo "Configuring for CPU only..."
      echo "$BASE_SERVICES" | sed "/services:/a\\$CPU_CONFIG" > "$COMPOSE_FILE"
    fi

    echo "Created $COMPOSE_FILE with appropriate GPU configuration"
  fi
}

# Main logic based on operation
case "$OPERATION" in
  "start")
    start_containers
    ;;
  "stop")
    stop_containers
    ;;
  "restart")
    restart_containers
    ;;
  "status")
    show_status
    ;;
  "clean")
    clean_all
    ;;
  "recreate")
    recreate_compose
    ;;
  "help")
    show_help
    ;;
  *)
    echo "Unknown operation: $OPERATION"
    show_help
    exit 1
    ;;
esac

exit 0

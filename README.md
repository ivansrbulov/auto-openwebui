# Ollama Server with Open WebUI and Cloudflare Tunnel

This repository provides a streamlined setup for running an Ollama server with Open WebUI, securely accessible over the internet through a Cloudflare tunnel.

## Compatibility

This script is confirmed to work on Debian 12 with a 7900XTX. Other distros and GPUs may work but is not (yet!) confirmed. If anybody else is able to test this and let me know then please do!

## Overview

This setup script automates the deployment of:

1. **Ollama** - A local LLM server with ROCm support for AMD GPUs
2. **Open WebUI** - A user-friendly web interface for interacting with Ollama models
3. **Cloudflare Tunnel** - Secure remote access without exposing your local network
4. **Watchtower** - Automatic updates for the Open WebUI container

## Requirements

- Docker and Docker Compose installed on your system
- A Cloudflare account with a tunnel token
- Your local IP address
- AMD GPU with ROCm support or NVIDIA GPU with CUDA support (the setup uses appropriate images for Ollama based on your choice)

## Quick Start

1. Clone this repository
   ```bash
   git clone https://github.com/ivansrbulov/auto-openwebui.git
   cd auto-openwebui
   ```

2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
The setup script will:
- Create a `.env` file with your configuration
- Generate a `docker-compose.yml` file with services properly configured
- Stop and remove any existing containers with the same names
- Log all actions to a timestamped file in the `logs/` directory

3. After setup, you can start or stop the services by running:
   ```bash
   docker compose up -d
   docker compose down
   ```

4. Once logged into Open WebUI, go to Admin Panel -> Settings -> Connections -> and under "Manage Ollama API Connections" replace `http://host.docker.internal:11434` with `http://<your-local-ip>:11434`; it may already be listed there. Delete `http://host.docker.internal:11434` if it exists.

## Service Configuration

### Ollama
- Uses the ROCm-enabled image for AMD GPU support or the main CUDA-enabled image for NVIDIA GPU support
- Exposes port 11434
- Persists models and data in a Docker volume

### Open WebUI
- Provides a modern interface for managing and using LLMs
- Accessible locally at http://localhost:3000
- Persists data in a Docker volume

### Cloudflare Tunnel
- Creates a secure tunnel to your Open WebUI
- No port forwarding or public IP required
- Access your LLM server securely from anywhere

### Watchtower
- Automatically checks for and applies updates to Open WebUI
- Runs checks every 300 seconds

## Usage

After setup is complete:

1. Access Open WebUI locally at http://localhost:3000
2. Access remotely through your Cloudflare tunnel URL
3. Pull models through the Open WebUI interface

It's fine to run `./setup.sh` to automate the setup process again if needed. But if there are no changes it is probably better to manage your deployment as below instead.

## Managing Your Deployment

- **View logs**: `docker-compose logs -f`
- **Stop services**: `docker-compose down`
- **Restart services**: `docker-compose restart`
- **Update configuration**: Edit `.env` file and restart services

## Troubleshooting

- Check the logs directory for detailed setup logs
- Ensure your Cloudflare tunnel token is valid
- Verify that your local IP address is correct
- Make sure that ports 11434 and 3000 are not in use by other services

## Contributors

With thanks to [Synthetic451](https://www.reddit.com/user/Synthetic451/) and [throwawayacc201711](https://www.reddit.com/user/throwawayacc201711/) on Reddit for their feedback and suggestions!

# Automatic Ollama with Open WebUI and Cloudflare Tunnel

A bash script to automate running Open WebUI on Linux systems with Ollama and Cloudflare via Docker 

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
- AMD GPU with ROCm support (the setup uses the ROCm image for Ollama)

## Quick Start

1. Clone this repository
2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
3. Follow the prompts to enter your local IP address and Cloudflare tunnel token

## What the Script Does

The `setup.sh` script:

- Creates a `.env` file with your configuration
- Generates a `docker-compose.yml` file with services properly configured
- Stops and removes any existing containers with the same names
- Starts all services using Docker Compose
- Logs all actions to a timestamped file in the `logs/` directory

## Service Configuration

### Ollama
- Uses the ROCm-enabled image for AMD GPU support
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

## Security Considerations

- The Cloudflare tunnel provides secure access without exposing local ports
- Consider setting up authentication in Open WebUI for additional security
- Model weights are stored locally in Docker volumes

## Contributors

With thanks to [Synthetic451](https://www.reddit.com/user/Synthetic451/) and [throwawayacc201711](https://www.reddit.com/user/throwawayacc201711/) on Reddit for their feedback and suggestions!

## Acknowledgements

- [Ollama](https://github.com/ollama/ollama)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

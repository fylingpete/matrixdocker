# Matrix Deployment Files

This directory contains all the configuration files needed to deploy your Matrix server.

## Files

- **deploy.sh** - Main deployment script that automates the entire installation
- **nginx-default.conf** - Nginx configuration with Matrix federation endpoints
- **turnserver.conf** - Coturn (TURN server) configuration for voice/video calls

## Quick Deployment

On your server, run:

```bash
git clone https://github.com/kamyargerami/matrix-docker.git
cd matrix-docker
sudo ./deploy/deploy.sh
```

## Configuration Details

- **Domain**: pmfhackers.com
- **Matrix Homeserver**: matrix.pmfhackers.com
- **Element Web Client**: web.pmfhackers.com
- **Server IP**: 167.235.231.9

## After Deployment

Create your first user:
```bash
docker exec -it matrix-synapse-1 register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008
```

## Required Ports

Make sure these ports are open in your firewall:
- 80 (HTTP)
- 443 (HTTPS)
- 3478 (TURN)
- 5349 (TURN TLS)
- 49160-49200/udp (TURN relay)

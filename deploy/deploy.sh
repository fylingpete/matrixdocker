#!/bin/bash
set -e

echo "=========================================="
echo "Matrix Server Deployment Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"
echo ""

echo -e "${BLUE}Step 2: Stopping any existing containers...${NC}"
cd matrix
docker-compose down || true
cd ..
echo -e "${GREEN}✓ Containers stopped${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating Docker volumes...${NC}"
docker volume create matrix_traefik_certs
docker volume create matrix_nginx_conf
docker volume create matrix_synapse_data
docker volume create matrix_synapse_db_data
docker volume create matrix_coturn
docker volume create matrix_element
echo -e "${GREEN}✓ Docker volumes created${NC}"
echo ""

echo -e "${BLUE}Step 4: Configuring Nginx...${NC}"
docker run --rm -v matrix_nginx_conf:/data alpine sh -c "cat > /data/default.conf" < deploy/nginx-default.conf
echo -e "${GREEN}✓ Nginx configured${NC}"
echo ""

echo -e "${BLUE}Step 5: Configuring Coturn...${NC}"
docker run --rm -v matrix_coturn:/data alpine sh -c "cat > /data/turnserver.conf" < deploy/turnserver.conf
echo -e "${GREEN}✓ Coturn configured${NC}"
echo ""

echo -e "${BLUE}Step 6: Starting containers for initial setup...${NC}"
cd matrix
docker-compose up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

echo -e "${BLUE}Step 7: Waiting for database to initialize (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Database initialized${NC}"
echo ""

echo -e "${BLUE}Step 8: Generating Synapse configuration...${NC}"
docker-compose down
docker run --rm -v matrix_synapse_data:/data -e SYNAPSE_SERVER_NAME=pmfhackers.com -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:latest generate
echo -e "${GREEN}✓ Synapse configuration generated${NC}"
echo ""

echo -e "${BLUE}Step 9: Configuring Synapse database and TURN...${NC}"
docker run --rm -v matrix_synapse_data:/data python:3-alpine sh -c '
pip install -q PyYAML && python3 << "EOF"
import yaml

# Read the homeserver.yaml
with open("/data/homeserver.yaml", "r") as f:
    config = yaml.safe_load(f)

# Replace database configuration
config["database"] = {
    "name": "psycopg2",
    "txn_limit": 10000,
    "args": {
        "user": "synapse",
        "password": "aComplexPassphraseNobodyCanGuess",
        "database": "synapse",
        "host": "matrix-synapse_db-1",
        "port": 5432,
        "cp_min": 5,
        "cp_max": 10
    }
}

# Add TURN configuration
config["turn_uris"] = [
    "turn:matrix.pmfhackers.com:3478?transport=udp",
    "turn:matrix.pmfhackers.com:3478?transport=tcp",
    "turns:matrix.pmfhackers.com:3478?transport=udp",
    "turns:matrix.pmfhackers.com:3478?transport=tcp"
]
config["turn_shared_secret"] = "5cFkgRRQ8J1PXlJmXIPFEWBoL0eo94mazzj/rwwh/dw="
config["turn_user_lifetime"] = 86400000
config["turn_allow_guests"] = False

# Write back
with open("/data/homeserver.yaml", "w") as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print("Configuration updated successfully!")
EOF
'
echo -e "${GREEN}✓ Synapse configured${NC}"
echo ""

echo -e "${BLUE}Step 10: Starting all containers...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ All containers started${NC}"
echo ""

echo -e "${BLUE}Step 11: Waiting for services to be ready (60 seconds)...${NC}"
sleep 60
echo ""

echo -e "${BLUE}Step 12: Checking container status...${NC}"
docker-compose ps
echo ""

echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "Your Matrix server is now running!"
echo ""
echo "Services:"
echo "  - Matrix Synapse: https://matrix.pmfhackers.com"
echo "  - Element Web: https://web.pmfhackers.com"
echo ""
echo "Next steps:"
echo "  1. Create your first user:"
echo "     docker exec -it matrix-synapse-1 register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
echo ""
echo "  2. Test federation at:"
echo "     https://federationtester.matrix.org/"
echo ""
echo "  3. View logs:"
echo "     docker-compose logs -f"
echo ""

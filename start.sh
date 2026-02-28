#!/bin/bash

# --- 1. Colors for logs ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting EFX Latency Monitoring Stack...${NC}"

# --- 2. Start Infrastructure (Docker) ---
echo -e "${GREEN}📦 Bringing up Prometheus, Grafana, and Pushgateway...${NC}"
docker-compose up -d

# --- 3. Setup AI Model (Ollama) ---
echo -e "${GREEN}🧠 Checking for Llama 3.2 model...${NC}"
if ! ollama list | grep -q "llama3.2"; then
    echo "Model not found. Pulling llama3.2 (this may take a minute)..."
    ollama pull llama3.2
else
    echo "✅ Llama 3.2 is ready."
fi

# --- 4. Setup Python Environment ---
echo -e "${GREEN}🐍 Preparing Python environment...${NC}"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install -q prometheus_client requests ollama

# --- 5. Launch Data Feed and Analyst ---
echo -e "${GREEN}⚡ Launching EFX Trade Feed...${NC}"
# Run the generator in the background
python3 trade_gen.py &
FEED_PID=$!

echo -e "${GREEN}🤖 System Online. Opening AI Analyst...${NC}"
echo "------------------------------------------------"
# Run the analyst in the foreground so you can interact with it
python3 ai_analyst.py

# --- 6. Cleanup on exit ---
trap "kill $FEED_PID; echo -e '${BLUE}Terminating Feed...${NC}'; exit" SIGINT SIGTERM

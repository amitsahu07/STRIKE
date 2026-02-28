To automate your entire EFX Latency Monitoring Stack, we can wrap the infrastructure, model management, and script execution into a single `start.sh` file. This script will ensure Docker is running, Ollama has the correct model, and your Python environment is ready before launching the feed and the analyst.

### The Unified `start.sh` Script

Create a file named `start.sh` in your project root and paste the following:

```bash
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

```

---

### Step-by-Step Build Instructions

Follow these exact steps to build the project from a blank folder.

#### 1. Setup the Folder Structure

Open your terminal and create the project files:

```bash
mkdir efx-stack && cd efx-stack
touch docker-compose.yml prometheus.yml trade_gen.py ai_analyst.py start.sh
chmod +x start.sh

```

#### 2. Define the Infrastructure (`docker-compose.yml` & `prometheus.yml`)

**docker-compose.yml**:

```yaml
services:
  prometheus:
    image: prom/prometheus
    ports: ["9090:9090"]
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml"]
  pushgateway:
    image: prom/pushgateway
    ports: ["9091:9091"]
  grafana:
    image: grafana/grafana
    ports: ["3000:3000"]
    environment: ["GF_SECURITY_ADMIN_PASSWORD=admin"]

```

**prometheus.yml**:

```yaml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']

```

#### 3. Create the Data Generator (`trade_gen.py`)

This script pushes simulated latency data to the Pushgateway.

```python
import time, random
from prometheus_client import CollectorRegistry, Histogram, push_to_gateway

registry = CollectorRegistry()
latency_histo = Histogram('efx_latency_seconds', 'Trade Latency', 
                          labelnames=['venue', 'pair'], registry=registry)

venues, pairs = ['LMAX', 'EBS', 'Currenex'], ['EUR/USD', 'USD/JPY']

while True:
    v, p = random.choice(venues), random.choice(pairs)
    lat = random.uniform(0.005, 0.050) # Normal 5-50ms
    latency_histo.labels(venue=v, pair=p).observe(lat)
    push_to_gateway('localhost:9091', job='efx_generator', registry=registry)
    time.sleep(1)

```

#### 4. Create the AI Analyst (`ai_analyst.py`)

The "Brain" that translates your English questions into PromQL queries.

```python
import ollama, requests, json

def query_prom(query):
    r = requests.get("http://localhost:9090/api/v1/query", params={'query': query})
    return str(r.json()['data']['result'])

def run_analyst():
    prompt = input("How can I help with your EFX monitoring? ")
    res = ollama.chat(model='llama3.2', messages=[
        {'role': 'system', 'content': "You are an EFX expert. Use query_prometheus to check metrics. Metric: efx_latency_seconds."},
        {'role': 'user', 'content': prompt}
    ], tools=[{
        'type': 'function',
        'function': {
            'name': 'query_prometheus',
            'description': 'Get live metrics',
            'parameters': {'type': 'object', 'properties': {'query': {'type': 'string'}}}
        }
    }])

    if res.message.tool_calls:
        for tool in res.message.tool_calls:
            args = json.loads(tool.function.arguments)
            result = query_prom(args['query'])
            final = ollama.chat(model='llama3.2', messages=[
                {'role': 'user', 'content': prompt},
                res.message,
                {'role': 'tool', 'content': result}
            ])
            print(f"\n🤖 Analyst: {final.message.content}")

if __name__ == "__main__":
    run_analyst()

```

---

### How to use the setup

1. **Run the script:** `./start.sh`
2. **Wait for the green logs:** It will launch Docker, verify your Llama model, and start the feed.
3. **Interaction:** The terminal will wait for your prompt.
* *Test Prompt:* "What is the average latency for EUR/USD on LMAX right now?"


4. **Visualize:** Open `http://localhost:3000` to see the metrics in Grafana.

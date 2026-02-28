Building an **EFX Latency Monitoring Stack** with an AI Analyst from scratch is a multi-stage engineering project. It involves setting up an observability pipeline (Prometheus + Grafana) and a reasoning layer (Llama 3.2 via Ollama).

Here are the detailed, step-by-step instructions.

---

## Phase 1: Infrastructure Setup (Docker)

We will use Docker to run the monitoring "engine." This ensures all services can talk to each other without polluting your Mac's system files.

1. **Create a Project Directory:**
```bash
mkdir efx-monitoring && cd efx-monitoring

```


2. **Create the `docker-compose.yml`:**
This file defines your metrics database and dashboard.
```yaml
services:
  prometheus:
    image: prom/prometheus
    ports: ["9090:9090"]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  pushgateway:
    image: prom/pushgateway
    ports: ["9091:9091"]

  grafana:
    image: grafana/grafana
    ports: ["3000:3000"]
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

```


3. **Create `prometheus.yml`:**
This tells Prometheus to scrape the Pushgateway every 5 seconds.
```yaml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']

```


4. **Launch the Stack:**
```bash
docker-compose up -d

```



---

## Phase 2: Llama Model & Python Setup

Now we set up the "Brain" on your Mac Mini.

1. **Install & Start Ollama:**
* Download from [ollama.com](https://ollama.com).
* Open your terminal and pull the optimized model:
```bash
ollama pull llama3.2

```




2. **Set up the Python Environment:**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install prometheus_client requests ollama

```



---

## Phase 3: Mock Data Generation (`trade_gen.py`)

This script acts as your "Trading Engine," simulating real-time market activity.

```python
import time, random
from prometheus_client import CollectorRegistry, Histogram, push_to_gateway

registry = CollectorRegistry()
latency_histo = Histogram('efx_latency_seconds', 'Trade Latency', 
                          labelnames=['venue', 'pair'], registry=registry)

venues = ['LMAX', 'EBS', 'Currenex']
pairs = ['EUR/USD', 'USD/JPY']

print("🚀 Simulating EFX Market Feed...")
while True:
    v, p = random.choice(venues), random.choice(pairs)
    # Normal latency 5-50ms; Random 1s spike every 20 trades
    lat = 1.0 if random.random() > 0.95 else random.uniform(0.005, 0.050)
    
    latency_histo.labels(venue=v, pair=p).observe(lat)
    push_to_gateway('localhost:9091', job='efx_engine', registry=registry)
    time.sleep(1)

```

---

## Phase 4: The AI Analyst (`ai_analyst.py`)

This script is the **Tool-Calling Agent**. It doesn't just "chat"—it knows how to query Prometheus.

```python
import ollama, requests, json

def query_prometheus(promql):
    """Executes a PromQL query against the local Prometheus server."""
    r = requests.get("http://localhost:9090/api/v1/query", params={'query': promql})
    return str(r.json()['data']['result'])

def ask_analyst(user_prompt):
    # 1. Define the tool for Llama
    tools = [{
        'type': 'function',
        'function': {
            'name': 'query_prometheus',
            'description': 'Retrieve live EFX latency metrics using PromQL.',
            'parameters': {
                'type': 'object',
                'properties': {
                    'promql': {'type': 'string', 'description': 'The PromQL query string'}
                },
                'required': ['promql']
            }
        }
    }]

    # 2. Initial Chat
    messages = [{'role': 'user', 'content': user_prompt}]
    response = ollama.chat(model='llama3.2', messages=messages, tools=tools)

    # 3. Process Tool Call
    if response.message.tool_calls:
        for tool in response.message.tool_calls:
            if tool.function.name == 'query_prometheus':
                args = json.loads(tool.function.arguments)
                print(f"🔍 AI Querying: {args['promql']}")
                result = query_prometheus(args['promql'])
                
                # 4. Final Reasoning
                messages.append(response.message)
                messages.append({'role': 'tool', 'content': result})
                final_res = ollama.chat(model='llama3.2', messages=messages)
                print(f"\n🤖 Analyst: {final_res.message.content}")

# Example Usage
ask_analyst("Which venue has the highest average latency right now?")

```

---

## Phase 5: Testing & Mock Prompts

Once `trade_gen.py` and the Docker containers are running, test your setup with these specific prompts in `ai_analyst.py`:

* **Health Check:** *"Is the EBS venue seeing any latency spikes above 500ms?"*
* **Performance Comparison:** *"Compare the trade volume of EUR/USD across all venues."*
* **Root Cause Analysis:** *"I'm seeing a slowdown. Identify the specific venue and currency pair causing it."*

---

## Phase 6: Visualization (Grafana)

1. Navigate to `http://localhost:3000` (admin/admin).
2. Add **Data Source**: Select **Prometheus** and use URL `http://prometheus:9090`.
3. **New Dashboard**: Add a "Time Series" panel using this query to see latency by venue:
`avg by (venue) (rate(efx_latency_seconds_sum[1m]) / rate(efx_latency_seconds_count[1m]))`

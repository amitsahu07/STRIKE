
## Phase 1: Infrastructure Setup (Docker)

We need a place to store metrics (Prometheus), a dashboard (Grafana), and a "mailbox" for our Python script to drop data (Pushgateway).

1. **Create a project folder:** `mkdir my-llama-project && cd my-llama-project`
2. **Create `docker-compose.yml**`:

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
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

```

3. **Create `prometheus.yml**` (Crucial: This tells Prometheus to look at the Pushgateway):

```yaml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']

```

4. **Launch:** `docker-compose up -d`

---

## Phase 2: The EFX Data Generator

This script simulates trades across venues like LMAX and EBS and pushes them to our stack.

1. **Setup Python:**

```bash
python -m venv .venv
source .venv/bin/activate
pip install prometheus_client requests ollama

```

2. **Create `trade_gen.py**`:

```python
import time, random
from prometheus_client import CollectorRegistry, Histogram, push_to_gateway

registry = CollectorRegistry()
latency_histo = Histogram('efx_latency_seconds', 'Trade Latency', 
                          labelnames=['venue', 'pair'], registry=registry)

venues = ['LMAX', 'EBS', 'Currenex']
pairs = ['EUR/USD', 'USD/JPY']

print("🚀 Starting EFX Data Feed...")
while True:
    v, p = random.choice(venues), random.choice(pairs)
    # Simulate 5ms to 50ms latency
    lat = random.uniform(0.005, 0.050) 
    latency_histo.labels(venue=v, pair=p).observe(lat)
    
    push_to_gateway('localhost:9091', job='efx_generator', registry=registry)
    time.sleep(1) # One trade per second

```

*Run this in a separate terminal window: `python trade_gen.py*`

---

## Phase 3: The Llama AI Analyst

Now we build the "Brain" that can read these metrics.

1. **Pull the Model:** `ollama pull llama3.2`
2. **Create `ai_analyst.py**`:

```python
import ollama, requests, json

def query_prom(query):
    r = requests.get("http://localhost:9090/api/v1/query", params={'query': query})
    return str(r.json()['data']['result'])

def run_analyst(user_prompt):
    model = 'llama3.2'
    system_msg = "You are an EFX expert. Use 'query_prometheus' to check latencies. Metric: efx_latency_seconds."
    
    # 1. Ask Llama
    res = ollama.chat(model=model, messages=[
        {'role': 'system', 'content': system_msg},
        {'role': 'user', 'content': user_prompt}
    ], tools=[{
        'type': 'function',
        'function': {
            'name': 'query_prometheus',
            'description': 'Get live EFX metrics',
            'parameters': {'type': 'object', 'properties': {'query': {'type': 'string'}}}
        }
    }])

    # 2. Execute Tool if Llama asks
    if res.message.tool_calls:
        for tool in res.message.tool_calls:
            args = json.loads(tool.function.arguments)
            result = query_prom(args['query'])
            
            # 3. Get Final Answer
            final = ollama.chat(model=model, messages=[
                {'role': 'user', 'content': user_prompt},
                res.message,
                {'role': 'tool', 'content': result}
            ])
            print(f"\n🤖 Analyst: {final.message.content}")

run_analyst("Which venue has the highest latency right now?")

```

---

## Phase 4: Visualization (Grafana)

1. Open `http://localhost:3000` (User: `admin` / Pass: `admin`).
2. **Add Data Source:** Select **Prometheus** and set URL to `http://prometheus:9090`.
3. **Create Dashboard:** Add a "Time Series" panel.
4. **Query:** `rate(efx_latency_seconds_sum[1m]) / rate(efx_latency_seconds_count[1m])`
* This shows the **Average Latency per Venue** in real-time.



---

## Phase 5: Mock Prompts for Testing

Once the setup is running, try these prompts in your `ai_analyst.py`:

* **Connectivity Check:** *"Is the Prometheus server currently scraping data?"*
* **Latency Analysis:** *"Compare the P95 latency between LMAX and EBS for the last minute."*
* **Troubleshooting:** *"I'm seeing a slowdown on USD/JPY. Can you identify which venue is responsible?"*

### Summary Checklist for GitHub README:

1. **Prerequisites:** Install Docker & Ollama.
2. **Step 1:** `docker-compose up`.
3. **Step 2:** Start `trade_gen.py` (The Feed).
4. **Step 3:** Run `ai_analyst.py` (The Brain).

**Would you like me to show you how to add an "Alerting" function to the Python script so Llama sends you a message if latency exceeds 100ms?**


# AI powered eTrading observability

This project implements a real-time monitoring pipeline for Electronic Foreign Exchange (EFX) trade latencies across multiple venues, featuring an **AI-powered Trading Assistant** (Llama 3.2) that can query metrics using natural language.

## 🚀 System Overview

The architecture consists of three core layers:

1. **Data Layer:** A Python-based simulator generating synthetic EFX trades (LMAX, EBS, etc.) with realistic latency jitter.
2. **Infrastructure Layer:** Prometheus for metric storage and a Pushgateway to handle high-frequency event ingestion.
3. **Intelligence Layer:** A Llama 3.2 "Agent" that uses Function Calling to execute PromQL queries and analyze venue performance.

## 🛠️ Setup Instructions

### 1. Infrastructure (Docker)

Spin up the Prometheus stack using the provided `docker-compose.yml`:

```bash
docker-compose up -d

```

* **Prometheus:** `http://localhost:9090`
* **Pushgateway:** `http://localhost:9091`

### 2. Environment Setup

Create a virtual environment and install the required Python dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install prometheus_client ollama requests

```

### 3. Start the Data Pipeline

Run the trade generator to begin pushing latency metrics to the gateway:

```bash
python trade_data_gen1.py

```

### 4. Run the AI Analyst

Ensure you have **Ollama** installed and the Llama 3.2 model pulled:

```bash
ollama pull llama3.2
python query_prom.py

```

## 📊 Key Metrics Tracked

| Metric Name | Labels | Description |
| --- | --- | --- |
| `efx_trade_latency_seconds` | `venue`, `pair`, `side` | Histogram of execution times. |
| `up` | `instance`, `job` | Health status of the monitoring targets. |

## 🤖 Example AI Queries

You can ask the Assistant questions like:

* *"Which venue currently has the highest P95 latency?"*
* *"Is there a latency spike on EUR/USD trades in LMAX?"*
* *"Summarize the last 5 minutes of trade volume across all venues."*

## 📜 License

MIT License - feel free to use this for your own trading infrastructure research.

---

### Pro-Tip for your GitHub:

If you want to make this look even more "Pro," I can help you write a **`docker-compose.yml`** section for your README that includes **Grafana**, so you can show a screenshot of a dashboard alongside the AI chat. **Would you like me to add that?**

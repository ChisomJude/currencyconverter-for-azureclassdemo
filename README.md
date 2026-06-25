# Currency Converter

A simple Flask web app that converts between currencies using live exchange
rates. Built as the running hands-on project for the **Azure & Azure DevOps
3-Day Intensive Training** — across the course, this same app gets
versioned (Day 1), containerized and deployed to Azure (Day 2), and
monitored/secured (Day 3).

![status](https://img.shields.io/badge/status-training%20project-d4af37)
![python](https://img.shields.io/badge/python-3.11-blue)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Table of Contents

- [What This App Does](#what-this-app-does)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Running Locally (Python)](#running-locally-python)
- [Running Locally (Docker)](#running-locally-docker)
- [Running Tests](#running-tests)
- [Environment Variables](#environment-variables)
- [Deploying to Azure](#deploying-to-azure)
  - [1. Provision Infrastructure with Bicep](#1-provision-infrastructure-with-bicep)
  - [2. Build & Push the Docker Image](#2-build--push-the-docker-image)
  - [3. Deploy via Azure CLI](#3-deploy-via-azure-cli)
  - [4. Deploy via the CI/CD Pipeline](#4-deploy-via-the-cicd-pipeline)
- [Enabling Monitoring (Application Insights)](#enabling-monitoring-application-insights)
- [Securing Secrets with Azure Key Vault](#securing-secrets-with-azure-key-vault)
- [Troubleshooting](#troubleshooting)
- [Course Day Mapping](#course-day-mapping)
- [License](#license)

---

## What This App Does

1. The user enters an amount and picks a source/target currency on a simple web form.
2. The Flask backend calls a free, public exchange-rate API ([open.er-api.com](https://www.exchangerate-api.com/docs/free)) — no API key required.
3. The converted amount is calculated and displayed back to the user.

That's it. No database, no user accounts — intentionally minimal so the
focus stays on the **DevOps tooling** around the app (Git, CI/CD,
containers, IaC, monitoring, security), not the app's business logic.

---

## Project Structure

```
CurrencyConverter/
├── app.py                    # Flask application (routes + conversion logic)
├── requirements.txt          # Python dependencies
├── Dockerfile                # Container image definition
├── .dockerignore
├── .gitignore
├── .env.example               # Template for local environment variables
├── azure-pipelines.yml       # CI/CD pipeline (Azure Pipelines)
├── infra/
│   └── main.bicep            # Infrastructure as Code (ACR, Container Apps, Log Analytics)
├── templates/
│   └── index.html            # Single-page UI (form + result)
├── tests/
│   ├── __init__.py
│   └── test_convert.py       # Unit tests for the conversion logic
└── README.md                 # You are here
```

---

## Prerequisites

| Tool | Why you need it | Install |
|---|---|---|
| Python 3.11+ | Run the app locally | [python.org/downloads](https://www.python.org/downloads/) |
| Git | Version control | [git-scm.com](https://git-scm.com/downloads) |
| Docker Desktop | Build/run the container locally | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| Azure CLI (`az`) | Deploy to Azure | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| An Azure subscription | Day 2–3 deployment steps | [Free trial](https://azure.microsoft.com/free/) |

You do **not** need Docker or Azure CLI just to run the app locally with Python — see the next section.

---

## Running Locally (Python)

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd CurrencyConverter

# 2. Create and activate a virtual environment (recommended)
python -m venv .venv
source .venv/bin/activate        # On Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. (Optional) copy the example env file and adjust if needed
cp .env.example .env

# 5. Run the app
python app.py
```

The app starts on **http://localhost:8000**. Open that URL in your browser,
enter an amount, pick currencies, and click **Convert**.

> **Note:** `python app.py` runs Flask's built-in development server — fine
> for local testing, but never use it in production (see the Docker section
> below, which uses `gunicorn` instead).

To stop the server, press `Ctrl+C`.

---

## Running Locally (Docker)

This mirrors exactly what runs in Azure, so it's the most accurate way to
test before deploying.

```bash
# 1. Build the image
docker build -t currencyconverter .

# 2. Run the container, mapping port 8000
docker run -p 8000:8000 currencyconverter
```

Open **http://localhost:8000** — same app, now running inside a container
via `gunicorn` (the production server), exactly as the Dockerfile specifies.

To pass environment variables (e.g. an Application Insights connection
string) into the container:

```bash
docker run -p 8000:8000 \
  -e APPLICATIONINSIGHTS_CONNECTION_STRING="<your-connection-string>" \
  currencyconverter
```

To stop the container: `Ctrl+C`, or `docker ps` + `docker stop <container_id>` from another terminal.

---

## Running Tests

Unit tests cover the pure `convert()` calculation logic — they don't call
the real exchange-rate API, so they run instantly and need no network access.

```bash
# Make sure dependencies are installed first (see above)
pytest -v
```

Expected output:

```
tests/test_convert.py::test_convert_basic PASSED
tests/test_convert.py::test_convert_zero_amount PASSED
tests/test_convert.py::test_convert_rounding PASSED
tests/test_convert.py::test_convert_large_amount PASSED
tests/test_convert.py::test_convert_parametrized[50-2.0-100.0] PASSED
tests/test_convert.py::test_convert_parametrized[1-1.0-1.0] PASSED
tests/test_convert.py::test_convert_parametrized[200-0.5-100.0] PASSED

7 passed
```

These same tests run automatically in the `Build` stage of
`azure-pipelines.yml` and **block deployment** if any test fails.

---

## Environment Variables

All variables are optional for local development — the app has sensible defaults.

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8000` | Port the Flask dev server binds to (ignored by Docker/gunicorn, which is hardcoded to 8000) |
| `FLASK_DEBUG` | `true` | Enables Flask's debug/auto-reload mode. Set to `false` in anything resembling production |
| `EXCHANGE_API_BASE` | `https://open.er-api.com/v6/latest` | Override if you switch exchange-rate providers |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | _(unset)_ | If set, enables Azure Monitor request + dependency tracking (Day 3) |

Copy `.env.example` to `.env` to customize these locally. The app does not
currently auto-load `.env` files — either `export` the variables in your
shell, or add `python-dotenv` if you want that behavior.

---

## Deploying to Azure

This section mirrors **Day 2** of the training. Run these once interactively
to understand each step, then let the pipeline (`azure-pipelines.yml`)
automate it going forward.

### 1. Provision Infrastructure with Bicep

```bash
# Log in and select your subscription
az login
az account set --subscription "<your-subscription-id-or-name>"

# Create a resource group
az group create --name rg-currencyconverter --location eastus

# Deploy the Bicep template
az deployment group create \
  --resource-group rg-currencyconverter \
  --template-file infra/main.bicep \
  --parameters environmentName=dev
```

This provisions:
- A **Log Analytics Workspace** (telemetry backend)
- An **Azure Container Registry (ACR)** (private image storage)
- An **Azure Container Apps Environment** + a placeholder **Container App**
  (initially running a "hello world" image until you push your own)

### 2. Build & Push the Docker Image

```bash
# Get your ACR name from the Bicep output, or check the portal
az acr build \
  --registry acrcurrencyconvdev \
  --image currencyconverter:latest \
  .
```

`az acr build` builds the image **in Azure** (no local Docker required) and
pushes it directly to your registry in one step.

### 3. Deploy via Azure CLI

```bash
az containerapp update \
  --name currencyconverter-app \
  --resource-group rg-currencyconverter \
  --image acrcurrencyconvdev.azurecr.io/currencyconverter:latest
```

Get the live app URL:

```bash
az containerapp show \
  --name currencyconverter-app \
  --resource-group rg-currencyconverter \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

Open that URL in your browser — your app is now live on Azure.

### 4. Deploy via the CI/CD Pipeline

Once infrastructure exists, let `azure-pipelines.yml` handle builds and
deployments automatically on every push to `main`:

1. In Azure DevOps, go to **Project Settings → Service connections** and
   create a new **Azure Resource Manager** service connection named
   `currency-converter-sp`, scoped to `rg-currencyconverter` (least privilege
   — not subscription-wide Owner).
2. Go to **Pipelines → Environments**, create one named `production`.
   Optionally add an approval check here for a manual gate before deploy.
3. Go to **Pipelines → New Pipeline**, point it at this repo and the
   existing `azure-pipelines.yml` file.
4. Update the `acrName` variable at the top of `azure-pipelines.yml` to
   match the ACR name from your Bicep deployment.
5. Push to `main` (or run the pipeline manually) — it will install
   dependencies, run tests, build the image, push to ACR, and deploy to
   Container Apps automatically.

---

## Enabling Monitoring (Application Insights)

This mirrors **Day 3, Module 9**.

1. Create an Application Insights resource (or let your Bicep template
   provision one — extend `infra/main.bicep` with a
   `Microsoft.Insights/components` resource).
2. Copy its **Connection String** from the Azure Portal.
3. Set it as an environment variable on your Container App:

   ```bash
   az containerapp update \
     --name currencyconverter-app \
     --resource-group rg-currencyconverter \
     --set-env-vars APPLICATIONINSIGHTS_CONNECTION_STRING="<your-connection-string>"
   ```

4. That's it — `app.py` automatically detects the environment variable and
   enables request + dependency tracking (including every outbound call to
   the exchange-rate API) via `azure-monitor-opentelemetry`.

To verify it's working, generate some traffic (convert a few currencies),
then check **Application Insights → Transaction Search** in the Azure
Portal — you should see both the inbound request and the outbound
dependency call to `open.er-api.com`.

---

## Securing Secrets with Azure Key Vault

This app currently has no real secrets (the exchange-rate API needs no key).
If you swap to a paid provider that requires an API key, this is how to
store and use it securely — mirrors **Day 3, Module 10**.

```bash
# Create a Key Vault
az keyvault create --name kv-currencyconv-dev --resource-group rg-currencyconverter

# Store the secret
az keyvault secret set --vault-name kv-currencyconv-dev \
  --name ExchangeRateApiKey --value "<your-real-api-key>"

# Grant your Container App's managed identity access (least privilege —
# Key Vault Secrets User, not Owner or Contributor)
az keyvault set-policy --name kv-currencyconv-dev \
  --object-id <containerAppPrincipalId-from-bicep-output> \
  --secret-permissions get list
```

Then reference it as a secret-backed environment variable on the Container
App (via `az containerapp secret set` + `secretRef`), rather than ever
hardcoding the key in `app.py`, `.env`, or pipeline YAML.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: No module named 'flask'` | Dependencies not installed | Run `pip install -r requirements.txt` (inside your activated virtualenv) |
| App starts but conversion always errors with "Could not reach the exchange rate service" | No internet access, or the free API is rate-limited/down | Check your network connection; confirm `https://open.er-api.com` is reachable |
| `docker build` fails on `pip install` | No internet access inside the Docker build context | Check your Docker Desktop network settings / proxy config |
| Pipeline fails at the `AzureCLI@2` step | Service connection missing or lacks permissions | Re-check the `currency-converter-sp` service connection scope and role assignment |
| Container App shows "hello world" instead of your app | You haven't pushed/deployed your built image yet | Run Step 2 and 3 under [Deploying to Azure](#deploying-to-azure) |
| `az acr build` fails with "registry not found" | ACR name typo, or Bicep deployment didn't complete | Run `az acr list --resource-group rg-currencyconverter --output table` to confirm the exact name |
| Port 8000 already in use locally | Another process is using it | `lsof -i :8000` (Mac/Linux) to find and stop it, or run with `PORT=8001 python app.py` |

---

## Course Day Mapping

| Day | What Happens to This Repo |
|---|---|
| **Day 1** | Repo is created in Azure Repos, code is pushed, feature-branched, PR'd. Work items for its backlog are planned on Azure Boards. |
| **Day 2** | `Dockerfile` is built and run. `infra/main.bicep` provisions Azure resources. `azure-pipelines.yml` builds, tests, and deploys the app live to Azure Container Apps. |
| **Day 3** | Application Insights is wired in for monitoring. Azure Key Vault pattern is introduced for secrets. OWASP ZAP and Azure Policy concepts are applied against the live deployment. |

---

## License

MIT — free to use and adapt for your own training sessions.

---

Built by **Godstime Chisom** — Senior DevOps & SRE Engineer, Founder of Spice Technologies.
[www.GodstimeChisom.tech](https://www.godstimechisom.tech) · LinkedIn: Godstime Chisom

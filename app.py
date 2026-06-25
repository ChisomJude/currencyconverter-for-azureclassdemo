"""
Currency Converter — Flask Frontend
-------------------------------------
A simple web app that takes an amount + currency pair from the user,
calls a free public exchange-rate API, and displays the converted value.

Used as the running hands-on project for the 3-Day Azure & Azure DevOps
training (Day 1: Git/Boards, Day 2: CI/CD/Docker/Bicep, Day 3: Monitoring/Security).
"""

import logging
import os

import requests
from flask import Flask, render_template, request

app = Flask(__name__)

# --- Configuration -----------------------------------------------------
# Free, no-API-key-required exchange rate API — good fit for a training
# environment. Swap for a paid provider + API key in real production use.
EXCHANGE_API_BASE = os.environ.get(
    "EXCHANGE_API_BASE", "https://open.er-api.com/v6/latest"
)

CURRENCIES = ["USD", "EUR", "GBP", "NGN", "JPY", "CAD", "ZAR", "GHS", "KES", "INR"]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("currency-converter")

# --- Optional: Azure Application Insights (Day 3) -----------------------
# If APPLICATIONINSIGHTS_CONNECTION_STRING is set, requests + outbound
# dependency calls (the exchange-rate API call below) are automatically
# tracked. Safe to leave unset for local development.
APPINSIGHTS_CONN_STRING = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
if APPINSIGHTS_CONN_STRING:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor(connection_string=APPINSIGHTS_CONN_STRING)
        logger.info("Application Insights monitoring enabled.")
    except ImportError:
        logger.warning(
            "APPLICATIONINSIGHTS_CONNECTION_STRING is set but the monitoring "
            "package isn't installed. Run: pip install -r requirements.txt"
        )


def convert(amount: float, rate: float) -> float:
    """Pure calculation function — multiply amount by exchange rate.

    Kept separate from the Flask route so it can be unit tested in
    isolation, without needing network access. See tests/test_convert.py.
    """
    return round(amount * rate, 2)


def get_exchange_rate(base_currency: str, target_currency: str) -> float:
    """Calls the external exchange-rate API and returns the conversion rate.

    This is the outbound call that Application Insights "dependency
    tracking" (Day 3, Module 9) automatically observes once instrumented.
    """
    url = f"{EXCHANGE_API_BASE}/{base_currency}"
    response = requests.get(url, timeout=5)
    response.raise_for_status()
    data = response.json()

    if data.get("result") != "success":
        raise ValueError(f"Exchange rate API returned an error: {data}")

    rates = data["rates"]
    if target_currency not in rates:
        raise ValueError(f"Unsupported currency: {target_currency}")

    return rates[target_currency]


@app.route("/", methods=["GET", "POST"])
def index():
    result = None
    error = None
    form_data = {"amount": "", "from_currency": "USD", "to_currency": "NGN"}

    if request.method == "POST":
        form_data["amount"] = request.form.get("amount", "")
        form_data["from_currency"] = request.form.get("from_currency", "USD")
        form_data["to_currency"] = request.form.get("to_currency", "NGN")

        try:
            amount = float(form_data["amount"])
            if amount < 0:
                raise ValueError("Amount must be a positive number.")

            rate = get_exchange_rate(
                form_data["from_currency"], form_data["to_currency"]
            )
            result = convert(amount, rate)
            logger.info(
                "Converted %s %s -> %s %s",
                amount,
                form_data["from_currency"],
                result,
                form_data["to_currency"],
            )
        except ValueError as exc:
            error = str(exc)
        except requests.RequestException as exc:
            logger.exception("Exchange rate API request failed")
            error = "Could not reach the exchange rate service. Please try again shortly."
        except Exception as exc:  # noqa: BLE001 - surfaced to the user intentionally
            logger.exception("Unexpected error during conversion")
            error = f"Something went wrong: {exc}"

    return render_template(
        "index.html",
        currencies=CURRENCIES,
        result=result,
        error=error,
        form_data=form_data,
    )


@app.route("/healthz")
def healthz():
    """Liveness/readiness probe — used by Azure Container Apps health checks."""
    return {"status": "ok"}, 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    debug = os.environ.get("FLASK_DEBUG", "true").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)

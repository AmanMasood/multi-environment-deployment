"""Environment-aware demo service used to exercise dev -> staging -> production promotion."""
import os

from flask import Flask, jsonify

app = Flask(__name__)
BROKEN = os.environ.get("APP_BROKEN", "false").lower() == "true"


@app.get("/")
def index():
    env = os.environ.get("APP_ENV", "dev")
    colour = {"dev": "#6c757d", "staging": "#fd7e14", "production": "#198754"}.get(env, "#0d6efd")
    return (f"<body style='font-family:sans-serif;border-top:8px solid {colour}'>"
            f"<h1>{env.upper()}</h1><p>version {os.environ.get('APP_VERSION', 'dev')}</p>"
            f"<p>debug={os.environ.get('DEBUG', 'false')} · log level={os.environ.get('LOG_LEVEL', 'info')}</p></body>")


@app.get("/health")
def health():
    if BROKEN:  # lets CI simulate a bad release and prove the rollback
        return jsonify(status="broken"), 500
    return jsonify(status="ok", environment=os.environ.get("APP_ENV", "dev"),
                   version=os.environ.get("APP_VERSION", "dev"))

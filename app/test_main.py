import importlib

import main


def test_health_reports_environment(monkeypatch):
    monkeypatch.setenv("APP_ENV", "staging")
    monkeypatch.setenv("APP_VERSION", "1.2.0")
    body = main.app.test_client().get("/health").get_json()
    assert body == {"status": "ok", "environment": "staging", "version": "1.2.0"}


def test_broken_build_fails_health(monkeypatch):
    monkeypatch.setenv("APP_BROKEN", "true")
    broken = importlib.reload(main)
    assert broken.app.test_client().get("/health").status_code == 500
    monkeypatch.setenv("APP_BROKEN", "false")
    importlib.reload(main)

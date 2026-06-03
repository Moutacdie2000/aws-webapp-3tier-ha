"""Tests unitaires de l'application (tier applicatif).

Ces tests n'exigent aucune base de données : ils valident le routage HTTP et
le comportement du health check. La route ``/db`` est testée pour son chemin
d'erreur (base injoignable) afin de garantir un code HTTP 503 propre.
"""

import app as webapp


def _client():
    webapp.app.config.update(TESTING=True)
    return webapp.app.test_client()


def test_health_returns_200():
    """La sonde de santé répond 200 et ne dépend pas de la base."""
    resp = _client().get("/health")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "ok"


def test_index_renders_demo_page():
    """La page d'accueil contient le titre de la démo."""
    resp = _client().get("/")
    assert resp.status_code == 200
    assert "Démo 3-tiers" in resp.get_data(as_text=True)


def test_db_route_handles_unreachable_database(monkeypatch):
    """Si la base est injoignable, /db répond 503 plutôt que de planter."""

    import psycopg2

    def _boom(*_args, **_kwargs):
        raise psycopg2.OperationalError("connexion refusée")

    monkeypatch.setattr(webapp.psycopg2, "connect", _boom)

    resp = _client().get("/db")
    assert resp.status_code == 503
    assert resp.get_json()["status"] == "error"

"""Application web de démonstration pour l'architecture 3-tiers haute disponibilité.

Cette petite application Flask incarne le « tier applicatif » déployé sur ECS
Fargate. Elle expose trois routes :

* ``/``       : page HTML de présentation (servie via CloudFront → ALB → Fargate).
* ``/health`` : sonde de santé légère consommée par le health check de l'ALB.
* ``/db``     : vérifie la connectivité au « tier données » (RDS PostgreSQL).

Les identifiants de la base ne sont jamais lus depuis le code : ils sont injectés
par AWS Secrets Manager dans l'environnement du conteneur par la task definition
ECS (voir ``terraform/modules/ecs``). En local, ils proviennent de
``docker-compose.yml``.
"""

from __future__ import annotations

import logging
import os
import socket
from typing import Any

import psycopg2
from flask import Flask, jsonify, render_template

# -----------------------------------------------------------------------------
# Configuration & journalisation
# -----------------------------------------------------------------------------
# Les logs sont envoyés sur la sortie standard : le driver `awslogs` de Fargate
# les achemine ensuite vers CloudWatch Logs.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("webapp")

app = Flask(__name__)

# Métadonnées d'affichage. APP_VERSION est typiquement le SHA de commit injecté
# au moment du build par la CI.
APP_VERSION = os.environ.get("APP_VERSION", "dev")
AWS_REGION = os.environ.get("AWS_REGION", "eu-west-3")


def _db_config() -> dict[str, Any]:
    """Construit la configuration de connexion PostgreSQL depuis l'environnement.

    Les variables sont alimentées par Secrets Manager en production (clés du
    secret JSON éclatées en variables d'environnement par la task definition).
    """
    return {
        "host": os.environ.get("DB_HOST", "localhost"),
        "port": int(os.environ.get("DB_PORT", "5432")),
        "dbname": os.environ.get("DB_NAME", "appdb"),
        "user": os.environ.get("DB_USER", "appuser"),
        "password": os.environ.get("DB_PASSWORD", ""),
        # Délais courts : on veut un échec rapide et lisible côté health check.
        "connect_timeout": 5,
    }


@app.route("/")
def index() -> str:
    """Page d'accueil de la démo 3-tiers."""
    return render_template(
        "index.html",
        version=APP_VERSION,
        region=AWS_REGION,
        hostname=socket.gethostname(),
    )


@app.route("/health")
def health() -> Any:
    """Sonde de santé pour l'Application Load Balancer.

    Volontairement minimaliste : elle ne touche PAS la base de données afin de
    ne pas désinscrire toutes les tâches du target group en cas d'incident RDS
    transitoire. La connectivité base est testée séparément via ``/db``.
    """
    return jsonify(status="ok", version=APP_VERSION), 200


@app.route("/db")
def db_check() -> Any:
    """Teste la connexion au tier données (RDS PostgreSQL).

    Retourne la version du serveur PostgreSQL et l'Availability Zone (lorsque
    l'extension renvoie cette information) afin d'illustrer la bascule Multi-AZ.
    """
    try:
        conn = psycopg2.connect(**_db_config())
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT version();")
                row = cur.fetchone()
                version = row[0] if row else "inconnue"
                cur.execute("SELECT inet_server_addr();")
                addr_row = cur.fetchone()
                server_addr = str(addr_row[0]) if addr_row and addr_row[0] else "n/a"
        finally:
            conn.close()

        logger.info("Connexion base réussie (serveur=%s)", server_addr)
        return (
            jsonify(
                status="ok",
                database="postgresql",
                server_version=version,
                server_address=server_addr,
            ),
            200,
        )
    except psycopg2.OperationalError as exc:
        # Erreur attendue lorsque la base est injoignable (bascule en cours,
        # mauvais identifiants, SG mal configuré...).
        logger.error("Échec de connexion à la base : %s", exc)
        return jsonify(status="error", message=str(exc)), 503


if __name__ == "__main__":
    # En production, l'application est servie par Gunicorn (voir le Dockerfile).
    # Ce bloc ne sert qu'au lancement direct en développement.
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)

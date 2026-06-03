# =============================================================================
# Makefile — raccourcis pour le développement local et le cycle de vie AWS.
# =============================================================================

# Variables surchargeable en ligne de commande : make deploy IMAGE_TAG=abc123
SHELL          := /bin/bash
APP_DIR        := app
TF_DIR         := terraform
IMAGE_NAME     ?= webapp-3tier-app
IMAGE_TAG      ?= local
AWS_REGION     ?= eu-west-3

.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# Aide
# -----------------------------------------------------------------------------
.PHONY: help
help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Application — build / test / exécution locale
# -----------------------------------------------------------------------------
.PHONY: build
build: ## Construit l'image Docker de l'application
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) $(APP_DIR)

.PHONY: install-dev
install-dev: ## Installe les dépendances de développement (flake8, pytest)
	cd $(APP_DIR) && python -m pip install -r requirements-dev.txt

.PHONY: lint
lint: ## Analyse statique du code Python (flake8)
	cd $(APP_DIR) && python -m flake8 .

.PHONY: test
test: ## Lance les tests applicatifs (pytest)
	cd $(APP_DIR) && python -m pytest -v

.PHONY: docker-run-local
docker-run-local: ## Lance l'app + Postgres en local via docker compose
	docker compose up --build

.PHONY: docker-stop-local
docker-stop-local: ## Arrête et supprime la pile locale (avec volumes)
	docker compose down -v

# -----------------------------------------------------------------------------
# Infrastructure — Terraform
# -----------------------------------------------------------------------------
.PHONY: fmt
fmt: ## Formate les fichiers Terraform
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: validate
validate: ## Initialise et valide la configuration Terraform
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

.PHONY: plan
plan: ## Génère un plan Terraform
	cd $(TF_DIR) && terraform plan -var="image_tag=$(IMAGE_TAG)"

.PHONY: deploy
deploy: ## Applique l'infrastructure Terraform (auto-approve)
	cd $(TF_DIR) && terraform apply -auto-approve -var="image_tag=$(IMAGE_TAG)"

.PHONY: destroy
destroy: ## Détruit toute l'infrastructure (auto-approve)
	cd $(TF_DIR) && terraform destroy -auto-approve

# -----------------------------------------------------------------------------
# Déploiement applicatif — push image + redéploiement du service ECS
# -----------------------------------------------------------------------------
.PHONY: ecr-login
ecr-login: ## Authentifie Docker auprès d'ECR
	aws ecr get-login-password --region $(AWS_REGION) \
		| docker login --username AWS --password-stdin \
		$$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: push
push: ## Construit et pousse l'image vers le dépôt ECR (REPO_URL requis)
	@test -n "$(REPO_URL)" || (echo "Renseignez REPO_URL (cf. output terraform ecr_repository_url)"; exit 1)
	docker build -t $(REPO_URL):$(IMAGE_TAG) $(APP_DIR)
	docker push $(REPO_URL):$(IMAGE_TAG)

.PHONY: redeploy
redeploy: ## Force un nouveau déploiement du service ECS (CLUSTER et SERVICE requis)
	@test -n "$(CLUSTER)" -a -n "$(SERVICE)" || (echo "Renseignez CLUSTER et SERVICE"; exit 1)
	aws ecs update-service --cluster $(CLUSTER) --service $(SERVICE) \
		--force-new-deployment --region $(AWS_REGION)

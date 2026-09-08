ENV ?= dev

ifeq ($(ENV),dev)
	COMPOSE_FILE := docker-compose.yml
else
	COMPOSE_FILE := docker-compose.prod.yml
endif

COMPOSE = docker compose -f $(COMPOSE_FILE)

POSTGRES_USER ?= $(shell grep '^POSTGRES_USER=' .env 2>/dev/null | cut -d= -f2-)
POSTGRES_PASSWORD ?= $(shell grep '^POSTGRES_PASSWORD=' .env 2>/dev/null | cut -d= -f2-)
POSTGRES_DB ?= $(shell grep '^POSTGRES_DB=' .env 2>/dev/null | cut -d= -f2-)

.PHONY: help
help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: infra-up
infra-up: ## Start infrastructure (Postgres/Redis/MinIO)
	$(COMPOSE) up -d

.PHONY: infra-down
infra-down: ## Stop infrastructure containers
	$(COMPOSE) down

.PHONY: infra-down-volumes
infra-down-volumes: ## Stop and remove containers with volumes
	$(COMPOSE) down -v

.PHONY: infra-logs
infra-logs: ## Follow infrastructure logs
	$(COMPOSE) logs -f

.PHONY: infra-ps
infra-ps: ## Show container status
	$(COMPOSE) ps

.PHONY: postgres
postgres: ## Connect to psql
	$(COMPOSE) exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

.PHONY: redis
redis: ## Open redis-cli
	$(COMPOSE) exec redis redis-cli

.PHONY: minio-logs
minio-logs: ## Follow MinIO logs
	$(COMPOSE) logs -f minio

.PHONY: backend
backend: ## Run backend with Air (hot-reload)
	cd tandem-backend && air

.PHONY: frontend
frontend: ## Run frontend (Vite dev server)
	cd tandem-frontend && npm run dev

.PHONY: build
build: ## Build backend and frontend
	cd tandem-backend && go build ./...
	cd tandem-frontend && npm run build

.PHONY: test
test: ## Run backend tests
	cd tandem-backend && go test ./...

.PHONY: test-integration
test-integration: ## Run backend repo tests against local Postgres (require TEST_DATABASE_URL or .env)
	cd tandem-backend && \
		TEST_DATABASE_URL="postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:5432/$(POSTGRES_DB)?sslmode=disable" \
		go test ./internal/repository/ -count=1

.PHONY: prod-up
prod-up: COMPOSE_FILE := docker-compose.prod.yml
prod-up: ## Start production stack (infra + apps)
	$(COMPOSE) up -d

.PHONY: prod-down
prod-down: COMPOSE_FILE := docker-compose.prod.yml
prod-down: ## Stop production stack
	$(COMPOSE) down

.PHONY: build-images
build-images: ## Build backend and frontend Docker images
	docker build -t ghcr.io/k1rvl07/tandem-backend:latest tandem-backend
	docker build -t ghcr.io/k1rvl07/tandem-frontend:latest tandem-frontend

.PHONY: swag
swag: ## Generate OpenAPI 3.1 docs (backend)
	cd tandem-backend && swag init -g ./cmd/server/main.go -o ./docs --v3.1

.PHONY: dev
dev: ## Launch dev environment (zellij: app/infra logs + DB/API TUIs)
	@fish scripts/dev.fish

.PHONY: dev-down
dev-down: ## Stop app processes and free app ports (8080/5173)
	@fuser -k 8080/tcp 5173/tcp 2>/dev/null || true
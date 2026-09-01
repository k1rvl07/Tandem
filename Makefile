ENV ?= dev

ifeq ($(ENV),dev)
	COMPOSE_FILE := docker-compose.yml
else
	COMPOSE_FILE := docker-compose.prod.yml
endif

COMPOSE := docker compose -f $(COMPOSE_FILE)

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

.PHONY: swag
swag: ## Generate Swagger docs (backend)
	cd tandem-backend && swag init -g ./cmd/server/main.go -o ./docs
ENV ?= dev
ENV_FILE := .env.$(ENV)

ifeq ($(ENV),dev)
	COMPOSE_FILE := docker-compose.yml
else
	COMPOSE_FILE := docker-compose.prod.yml
endif

COMPOSE = docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

POSTGRES_USER ?= $(shell grep '^POSTGRES_USER=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
POSTGRES_PASSWORD ?= $(shell grep '^POSTGRES_PASSWORD=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
POSTGRES_DB ?= $(shell grep '^POSTGRES_DB=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
POSTGRES_PORT ?= $(shell grep '^POSTGRES_PORT=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)

POSTGRES_TEST_DB ?= $(shell grep '^POSTGRES_TEST_DB=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
ifeq ($(strip $(POSTGRES_TEST_DB)),)
	POSTGRES_TEST_DB := tandem_test
endif

# dashed to avoid collisions with postgres vars
REDIS_ADDR ?= $(shell grep '^REDIS_ADDR=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
REDIS_PASSWORD ?= $(shell grep '^REDIS_PASSWORD=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)

MINIO_ENDPOINT ?= $(shell grep '^MINIO_ENDPOINT=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
MINIO_ROOT_USER ?= $(shell grep '^MINIO_ROOT_USER=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
MINIO_ROOT_PASSWORD ?= $(shell grep '^MINIO_ROOT_PASSWORD=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)
MINIO_BUCKET ?= $(shell grep '^MINIO_BUCKET=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)

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

.PHONY: swag
swag: ## Generate OpenAPI 3.1 docs (backend)
	cd tandem-backend && swag init -g ./cmd/server/main.go -o ./docs --v3.1

.PHONY: ensure-docs
ensure-docs: ## Generate OpenAPI docs when missing on a fresh clone
	@test -f tandem-backend/docs/swagger.json || (cd tandem-backend && swag init -g ./cmd/server/main.go -o ./docs --v3.1)

.PHONY: build
build: ensure-docs ## Build backend and frontend
	cd tandem-backend && go build ./...
	cd tandem-frontend && npm run build

.PHONY: test
test: ## Run backend tests
	cd tandem-backend && go test ./...

.PHONY: test-coverage
test-coverage: ## Run backend tests with coverage report
	cd tandem-backend && go test ./... -coverprofile=coverage.out -covermode=atomic -count=1 && \
		go tool cover -func=coverage.out | tail -5

COVER_THRESHOLD ?= 85

.PHONY: test-db-create
test-db-create: ## Create the dedicated integration test database (POSTGRES_TEST_DB)
	$(COMPOSE) exec -T postgres createdb -U $(POSTGRES_USER) -O $(POSTGRES_USER) $(POSTGRES_TEST_DB) || true

.PHONY: cover
cover: test-db-create ## Run all tests (unit + integration on tandem_test) and enforce the coverage gate
	cd tandem-backend && \
		TEST_DATABASE_URL="postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(POSTGRES_PORT)/$(POSTGRES_TEST_DB)?sslmode=disable" \
		TEST_REDIS_ADDR="$(REDIS_ADDR)" \
		TEST_REDIS_PASSWORD="$(REDIS_PASSWORD)" \
		TEST_MINIO_ENDPOINT="$(MINIO_ENDPOINT)" \
		TEST_MINIO_ROOT_USER="$(MINIO_ROOT_USER)" \
		TEST_MINIO_ROOT_PASSWORD="$(MINIO_ROOT_PASSWORD)" \
		TEST_MINIO_BUCKET="$(MINIO_BUCKET)" \
		go test ./... -coverpkg=./... -covermode=atomic -coverprofile=coverage.out -count=1 && \
		go tool cover -html=coverage.out -o coverage.html && \
		COVERAGE=$$(go tool cover -func=coverage.out | tail -1 | awk '{print $$NF}' | sed 's/%//') && \
		awk -v got="$$COVERAGE" -v want="$(COVER_THRESHOLD)" 'BEGIN { if (got+0 < want+0) { printf "COVERAGE GATE FAILED: %.2f%% < %.2f%%\n", got+0, want+0; exit 1 } printf "COVERAGE GATE PASSED: %.2f%% >= %.2f%%\n", got+0, want+0 }'

.PHONY: test-integration
test-integration: test-db-create ## Run backend integration tests against the dedicated test database (never the live DB)
	cd tandem-backend && \
		TEST_DATABASE_URL="postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(POSTGRES_PORT)/$(POSTGRES_TEST_DB)?sslmode=disable" \
		TEST_REDIS_ADDR="$(REDIS_ADDR)" \
		TEST_REDIS_PASSWORD="$(REDIS_PASSWORD)" \
		TEST_MINIO_ENDPOINT="$(MINIO_ENDPOINT)" \
		TEST_MINIO_ROOT_USER="$(MINIO_ROOT_USER)" \
		TEST_MINIO_ROOT_PASSWORD="$(MINIO_ROOT_PASSWORD)" \
		TEST_MINIO_BUCKET="$(MINIO_BUCKET)" \
		go test ./internal/repository/... ./internal/app/ ./internal/pkg/migrations/... -count=1

.PHONY: prod-up
prod-up: COMPOSE_FILE := docker-compose.prod.yml
prod-up: ENV_FILE := .env.prod
prod-up: ## Start production stack (infra + apps)
	$(COMPOSE) up -d

.PHONY: prod-down
prod-down: COMPOSE_FILE := docker-compose.prod.yml
prod-down: ENV_FILE := .env.prod
prod-down: ## Stop production stack
	$(COMPOSE) down

.PHONY: build-images
build-images: ## Build backend and frontend Docker images
	docker build -t ghcr.io/k1rvl07/tandem-backend:latest tandem-backend
	docker build -t ghcr.io/k1rvl07/tandem-frontend:latest tandem-frontend

.PHONY: dev
dev: ## Launch dev environment (zellij: app/infra logs + DB/API TUIs)
	@fish scripts/dev.fish

.PHONY: dev-down
dev-down: ## Stop app processes and free app ports (8080/5173)
	@fuser -k 8080/tcp 5173/tcp 2>/dev/null || true
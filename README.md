# Tandem

Коллаборативная система управления задачами для команд разработчиков с
синхронизацией в реальном времени (ВКР / дипломный проект).

Backend — Go (Gin + PostgreSQL + Redis + MinIO), фронтенд — Vue 3
(Vite + Pinia + Tailwind). Подробнее о каждом уровне — в их README.

## Возможности

- Авторизация и регистрация (JWT), профили и аватары;
- администрирование пользователей (роли, поиск, пагинация);
- воркспейсы: темы, роли участников (owner/editor/member), одноразовые
  инвайты, передача владения;
- доски и канбан-колонки (main/archive, drag & drop, переупорядочивание);
- задачи: подзадачи, фильтры, удаление;
- вложения задач через MinIO (presigned URL);
- избранное (воркспейсы и доски), дерево «воркспейс → доска → колонка → задача»;
- WebSocket: присутствие и события в реальном времени;
- кеширование ответов в Redis, версионная инвалидация кеша.

## Структура репозитория

Проект разделён на три уровня git: корень хранит общую инфраструктуру
разработки, backend и frontend — независимые репозитории, подключённые
как git-submodule.

| Уровень | Каталог | Содержимое | VCS |
|---------|---------|-----------|-----|
| Корневой | `./` | `docker-compose*.yml`, `Makefile`, `scripts/`, `AGENTS.md` | `k1rvl07/Tandem` |
| Backend | `tandem-backend/` | Go-приложение (см. `tandem-backend/README.md`) | `k1rvl07/tandem-backend` |
| Frontend | `tandem-frontend/` | Vue-приложение (см. `tandem-frontend/README.md`) | `k1rvl07/tandem-frontend` |

Коммиты вносятся внутри соответствующего подрепозитория, затем в корне
фиксируется новая версия submodule.

## Технологический стек

- Backend: Go 1.27, Gin, GORM (PostgreSQL 15), Redis 7, MinIO, JWT, gorilla/websocket.
- Frontend: Vue 3 (Composition API), Vite, Pinia, Vue Router 4, axios, Tailwind CSS 3, Biome.
- Инфраструктура: Docker Compose (Postgres/Redis/MinIO).

## Требования

- Go 1.27+;
- Node.js 20+ и npm;
- Docker + Docker Compose v2;
- zellij — опционально, для `make dev`.

## Быстрый старт

```sh
cp .env.example .env     # параметры docker-compose
make infra-up            # поднять Postgres/Redis/MinIO
make swag                # сгенерировать OpenAPI-доки backend (обязательно на свежем клоне)
make backend             # backend на :8080 (Air, hot-reload)
make frontend            # frontend на :5173 (Vite)
```

Файлы конфигурации: корневой `.env` подхватывается docker-compose,
`tandem-backend/.env.dev` (dev) / `.env.prod` (prod) — для Go-приложения.
Администратор создаётся при старте backend из `ADMIN_LOGIN`/`ADMIN_PASSWORD`.

Альтернатива — `make dev`: zellij-сессия с инфраструктурой, обоими
приложениями и TUI для БД/API.

## Команды (Makefile)

| Команда | Описание |
|---------|----------|
| `make infra-up` | Поднять Postgres/Redis/MinIO |
| `make infra-down` | Остановить инфраструктуру |
| `make infra-down-volumes` | Остановить и удалить контейнеры с томами |
| `make infra-logs` | Логи инфраструктуры |
| `make infra-ps` | Статус контейнеров |
| `make postgres` | Подключиться к psql |
| `make redis` | Открыть redis-cli |
| `make minio-logs` | Логи MinIO |
| `make backend` | Запустить backend через Air |
| `make frontend` | Запустить frontend (Vite) |
| `make build` | Собрать backend и frontend |
| `make test` | Прогнать тесты backend |
| `make swag` | Сгенерировать OpenAPI-доки backend |
| `make dev` | Dev-окружение (zellij) |
| `make dev-down` | Остановить приложения, освободить порты 8080/5173 |
| `make help` | Список всех таргетов |

## Тестирование

Backend — unit-тесты прикладного слоя и хендлеров (фейки в
`tandem-backend/internal/usecase/testutil`):

```sh
make test        # то же, что go test ./... в tandem-backend
```

Frontend — unit/интеграционные (Vitest + jsdom) и E2E (Playwright + Chromium):

```sh
cd tandem-frontend
npm run test:run         # unit/интеграционные: 13 файлов, 91 тест
npm run test:coverage    # то же с отчётом покрытия
npm run test:e2e         # E2E-спеки: auth, workspace, profile, admin
```

E2E запускаются против dev-серверов (backend :8080, Vite :5173; в
`tandem-frontend/tests/e2e/playwright.config.ts` используется
`reuseExistingServer`) и требуют Chromium:
`npx playwright install chromium` (в `tandem-frontend`).

## Порты

| Служба | Порт |
|--------|------|
| Postgres | 5432 |
| Redis | 6379 |
| MinIO API | 9000 |
| MinIO Console | 9001 |
| Backend | 8080 |
| Frontend (Vite) | 5173 |

Swagger-UI: http://localhost:8080/swagger

## Переменные окружения (`.env` для docker-compose)

| Переменная | Значение по умолчанию |
|------------|----------------------|
| `ENV` | `dev` |
| `COMPOSE_PROJECT_NAME` | `tandem` |
| `POSTGRES_HOST` / `POSTGRES_PORT` | `localhost` / `5432` |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `tandem` / `change_me` / `tandem` |
| `POSTGRES_IMAGE` | `postgres:15.4-alpine` |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` | `localhost` / `6379` / пусто |
| `REDIS_IMAGE` | `redis:7.2-alpine` |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | `tandem` / `change_me_minio` |
| `MINIO_API_PORT` / `MINIO_CONSOLE_PORT` | `9000` / `9001` |
| `MINIO_BUCKET` | `tandem-files` |
| `MINIO_IMAGE` | `minio/minio:RELEASE.2024-05-27T19-17-46Z` |
| `*_IMAGE_PROD` | образы для `docker-compose.prod.yml` |

## Работа с submodule

Клонирование со всеми уровнями:

```sh
git clone --recurse-submodules git@github.com:k1rvl07/Tandem.git
# либо после обычного clone:
git submodule update --init --recursive
```

Порядок коммитов: сначала внутри `tandem-backend/` или `tandem-frontend/`,
затем в корне фиксируется новая версия submodule:

```sh
git add tandem-backend     # (или tandem-frontend)
git commit -m "chore: bump backend submodule"
```
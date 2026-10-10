#!/usr/bin/env bash
# Обёртка для вкладки api: ждёт готовности сервера и запускает posting
# с коллекцией .posting (импортируется из OpenAPI-спеки в dev.fish).
# Токен захватывается автоматически при выполнении запроса «Логин»/«Вход»
# внутри клиента (on_response-скрипт scripts/token_capture.py).
set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

BASE_URL="${BASE_URL:-http://localhost:8080}"

if [[ ! -d .posting ]] || ! find .posting -name '*.posting.yaml' -print -quit 2>/dev/null | grep -q .; then
    echo "posting-run: коллекция .posting отсутствует." >&2
    echo "posting-run: импортируйте спеку: posting import tandem-backend/docs/swagger.json -o .posting" >&2
    exit 1
fi

echo "posting-run: жду готовности сервера ($BASE_URL/healthz)..."
ready=''
for _ in $(seq 1 60); do
    if curl -sf "$BASE_URL/healthz" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 0.5
done

if [[ -z "${ready:-}" ]]; then
    echo "posting-run: сервер недоступен за 30с — запускаю posting всё равно (запросы упадут)." >&2
fi

exec posting default -c .posting -e localhost_8080.env
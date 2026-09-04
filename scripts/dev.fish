#!/usr/bin/env fish
set -l ROOT (dirname (dirname (realpath (status filename))))
cd $ROOT

fuser -k 8080/tcp 5173/tcp 2>/dev/null

docker compose up -d
docker compose ps

cd tandem-backend
swag init -g ./cmd/server/main.go -o ./docs --v3.1
cd $ROOT

set -l PG_USER ""
set -l PG_PASS ""
set -l PG_HOST ""
set -l PG_PORT ""
set -l PG_DB ""
set -l REDIS_PASS ""

for line in (grep -E '^(POSTGRES_USER|POSTGRES_PASSWORD|POSTGRES_HOST|POSTGRES_PORT|POSTGRES_DB|REDIS_PASSWORD)=' .env)
    set -l key (string replace -r '=.*' '' $line)
    set -l val (string replace -r '^[^=]+=' '' $line)
    switch $key
        case POSTGRES_USER
            set PG_USER $val
        case POSTGRES_PASSWORD
            set PG_PASS $val
        case POSTGRES_HOST
            set PG_HOST $val
        case POSTGRES_PORT
            set PG_PORT $val
        case POSTGRES_DB
            set PG_DB $val
        case REDIS_PASSWORD
            set REDIS_PASS $val
    end
end

set -l SABIQL_DIR "$HOME/.config/sabiql"
mkdir -p $SABIQL_DIR

set -l CONN_ID "yn0m-rand0m-id-tandem-dev"

if test -n "$PG_USER" -a -n "$PG_PASS" -a -n "$PG_HOST" -a -n "$PG_PORT" -a -n "$PG_DB"
    printf 'version = 3\n\n[[connections]]\nid = "%s"\nname = "%s"\ndb_type = "postgresql"\nhost = "%s"\nport = %s\ndatabase = "%s"\nusername = "%s"\npassword = "%s"\nssl_mode = "prefer"\n' $CONN_ID "tandem-dev" $PG_HOST $PG_PORT $PG_DB $PG_USER $PG_PASS > $SABIQL_DIR/connections.toml
end

sed -e "s|__REDIS_PASS__|$REDIS_PASS|" scripts/zellij.template.kdl > /tmp/tandem.kdl

zellij delete-session tandem 2>/dev/null
zellij kill-session tandem 2>/dev/null
sleep 1
pkill -f 'zellij.*/tandem' 2>/dev/null

zellij -n /tmp/tandem.kdl -s tandem
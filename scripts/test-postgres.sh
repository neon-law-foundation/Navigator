#!/usr/bin/env bash
# Run the Navigator test suite against a local Postgres 16 container,
# reproducing the CI Postgres job byte-for-byte.
#
# Usage:
#   ./scripts/test-postgres.sh
#
# The script boots a disposable postgres:16 Docker container, exports
# the same APP_ENV and DATABASE_URL the CI matrix job uses, runs
# `swift test`, and tears the container down — pass or fail.
set -euo pipefail

CONTAINER_NAME="navigator-test-postgres"
HOST_PORT="${NAVIGATOR_TEST_POSTGRES_PORT:-5433}"

cleanup() {
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup

echo "Starting postgres:16 container on host port $HOST_PORT..."
docker run --rm -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    -p "$HOST_PORT:5432" \
    postgres:16 >/dev/null

echo -n "Waiting for Postgres to accept connections"
for _ in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
        echo " — ready."
        break
    fi
    echo -n "."
    sleep 1
done

if ! docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
    echo
    echo "Postgres never became ready inside container '$CONTAINER_NAME'." >&2
    exit 1
fi

export APP_ENV=production
export DATABASE_URL="postgres://postgres:postgres@localhost:$HOST_PORT/postgres"

echo "Running swift test with APP_ENV=$APP_ENV"
swift test

#!/bin/bash
set -e

# Start PostgreSQL
service postgresql start

# Wait for PostgreSQL to be ready
until pg_isready -q; do
  sleep 0.5
done

# Configurable thread count (default 8)
THREADS=${ICHIRAN_THREADS:-8}
PORT=${ICHIRAN_PORT:-80}

echo "Starting ichiran server (port=$PORT, threads=$THREADS)"

exec sbcl --eval '(load "~/quicklisp/setup.lisp")' \
     --eval '(ql:quickload :ichiran-server)' \
     --eval "(ichiran/server:start :port $PORT :num-threads $THREADS)"

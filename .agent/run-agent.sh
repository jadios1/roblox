#!/usr/bin/env bash

set -u

ROLE="$1"
MODEL="$2"
CTX="$3"
PORT="$4"
TOOLS="$5"
PROMPT_FILE="$6"
SERVER_LOG="$7"
PID_FILE="$8"

echo "$$ $(ps -o pgid= -p $$ | tr -d ' ')" > "$PID_FILE"

LLAMA_PID=""

cleanup() {
    if [ -n "${LLAMA_PID:-}" ]; then
        kill -TERM "$LLAMA_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$LLAMA_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

unset LLAMA_API_KEY
unset OPENAI_API_KEY

llama serve \
    -hf "$MODEL" \
    --jinja \
    --reasoning off \
    --ctx-size "$CTX" \
    --fit on \
    --flash-attn on \
    --host 127.0.0.1 \
    --port "$PORT" \
    > "$SERVER_LOG" 2>&1 &

LLAMA_PID=$!

READY=0

for _ in $(seq 1 120); do
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        READY=1
        break
    fi

    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "ERROR: llama server died during startup."
        exit 70
    fi

    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: llama server did not become ready."
    exit 71
fi

export LLAMA_BASE_URL="http://127.0.0.1:$PORT/v1"

PROMPT="$(cat "$PROMPT_FILE")"

pi --no-session -p \
    --provider llama-cpp \
    --model "$MODEL" \
    --thinking off \
    --tools "$TOOLS" \
    "$PROMPT"

exit $?

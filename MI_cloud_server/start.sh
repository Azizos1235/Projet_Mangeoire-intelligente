#!/bin/sh
SOCK=/tmp/tailscaled.sock
PI_HOST="${PI_TAILSCALE_HOST:-100.109.169.109}"   # Pi's Tailscale IP or MagicDNS name

if [ -z "${TS_AUTHKEY:-}" ]; then
  echo "ERROR: TS_AUTHKEY is not set in the Render environment" >&2
fi

tailscaled --tun=userspace-networking --state=mem: --socket="$SOCK" &

# tailscaled needs a moment to start, so retry the login instead of one blind sleep
i=0
until tailscale --socket="$SOCK" up --authkey="${TS_AUTHKEY:-}" --hostname=render-ingest --accept-dns=false; do
  i=$((i + 1))
  if [ "$i" -ge 10 ]; then
    echo "ERROR: tailscale up failed after 10 tries (check TS_AUTHKEY: expired, single-use, or wrong?)" >&2
    break
  fi
  sleep 3
done

# local 127.0.0.1:5672 -> Pi's RabbitMQ through Tailscale
socat TCP-LISTEN:5672,fork,reuseaddr,bind=127.0.0.1 \
  EXEC:"tailscale --socket=$SOCK nc $PI_HOST 5672" &
sleep 2

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-10000}"
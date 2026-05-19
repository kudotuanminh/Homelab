ARG CADDY_VERSION

FROM caddy:${CADDY_VERSION:-2.8}-builder-alpine AS builder

RUN caddy-builder github.com/caddy-dns/cloudflare

FROM caddy:${CADDY_VERSION:-2.8}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

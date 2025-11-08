## Build Crawlab backend binary (multi-arch friendly)
FROM --platform=$BUILDPLATFORM golang:1.22 AS backend-build
WORKDIR /go/src/app
COPY ./backend ./backend
COPY ./core ./core
COPY ./db ./db
COPY ./fs ./fs
COPY ./grpc ./grpc
COPY ./trace ./trace
COPY ./vcs ./vcs
COPY ./template-parser ./template-parser
WORKDIR /go/src/app/backend
ENV GO111MODULE=on
RUN go mod tidy && CGO_ENABLED=0 go install -v ./...

## Build Crawlab frontend (Node/Vite -> dist)
FROM --platform=$BUILDPLATFORM node:18-alpine AS frontend-build
WORKDIR /app
COPY ./frontend /app
RUN rm -f /app/.npmrc || true
RUN npm i -g pnpm@7 && pnpm install --no-frozen-lockfile && pnpm run build:docker

## Runtime image (alpine arm64 friendly) with nginx, python and seaweedfs
FROM alpine:3.18
WORKDIR /app
RUN apk add --no-cache bash nginx python3 curl openrc \
 && ln -sf /usr/bin/python3 /usr/bin/python

# Install SeaweedFS (weed) for Alpine arm64
# Using prebuilt binary via GitHub release if available; fallback to skip if fails
RUN set -eux; \
  raw_arch="$(apk --print-arch)"; \
  case "$raw_arch" in \
    aarch64) arch=arm64 ;; \
    x86_64) arch=amd64 ;; \
    *) arch="$raw_arch" ;; \
  esac; \
  version="3.63"; \
  url="https://github.com/seaweedfs/seaweedfs/releases/download/${version}/linux_${arch}.tar.gz"; \
  if curl -fsSL "$url" -o /tmp/weed.tgz; then \
    tar -xzf /tmp/weed.tgz -C /usr/local/bin weed; \
    chmod +x /usr/local/bin/weed; \
  else \
    echo "Skipping SeaweedFS install (no binary for ${arch})"; \
  fi

# Prepare directories
RUN mkdir -p /var/log /var/log/nginx /run/nginx /data /data/seaweedfs

# Copy runtime files
COPY ./backend/conf /app/conf
COPY ./nginx /app/nginx
COPY ./bin /app/bin
COPY --from=backend-build /go/bin/crawlab /usr/local/bin/crawlab-server
COPY --from=frontend-build /app/dist /app/dist

# Configure nginx
RUN rm -f /etc/nginx/conf.d/*
COPY ./nginx/crawlab.conf /etc/nginx/conf.d/crawlab.conf
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf

# Provide 'service' wrapper for OpenRC to match Debian-style usage
RUN printf "#!/bin/sh\nexec rc-service \"$@\"\n" > /usr/sbin/service && chmod +x /usr/sbin/service

# Expose ports
EXPOSE 8080 8000

# Entrypoint
CMD ["/bin/bash", "/app/bin/docker-init.sh"]

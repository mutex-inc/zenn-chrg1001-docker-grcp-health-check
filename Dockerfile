# syntax=docker/dockerfile:1
# check=error=true
#-------------------------------------------------------
# Variables
#-------------------------------------------------------
ARG BUILDER_APP_DIR=/build
ARG RUNNER_APP_DIR=/app

###=======================================================
### Builder image
###=======================================================
FROM debian:bookworm-slim@sha256:b1211f6d19afd012477bd34fdcabb6b663d680e0f4b0537da6e6b0fd057a3ec3 AS builder

ARG BUILDER_APP_DIR

WORKDIR ${BUILDER_APP_DIR}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup
RUN <<EOF
apt-get update
apt-get -y --no-install-recommends install wget \
  sudo curl git ca-certificates build-essential
rm -rf /var/lib/apt/lists/*
EOF

# grpc_health_probe のダウンロード
RUN <<EOF
GRPC_HEALTH_PROBE_VERSION=v0.4.37
wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-arm64
chmod +x /bin/grpc_health_probe
EOF

# Setup mise
# SEE: https://mise.jdx.dev/mise-cookbook/docker.html
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:$PATH"

RUN <<EOF
curl https://mise.run | sh
EOF

# Install toolchain
COPY mise.toml ./

RUN <<EOF
  mise trust
  mise install
EOF

# 依存関係のインストール
RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=yarn.lock,target=yarn.lock \
  --mount=type=bind,source=.yarnrc.yml,target=.yarnrc.yml \
  --mount=type=cache,target=./node_modules \
  <<EOF
yarn install --immutable
EOF

# ビルド
RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=yarn.lock,target=yarn.lock \
  --mount=type=bind,source=.yarnrc.yml,target=.yarnrc.yml \
  --mount=type=bind,source=tsconfig.json,target=tsconfig.json \
  --mount=type=bind,source=tsup.config.ts,target=tsup.config.ts \
  --mount=type=bind,source=src,target=src \
  --mount=type=cache,target=./node_modules \
  <<EOF
yarn build
EOF

# 実行時に必要な依存関係のみを再インストール
RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=yarn.lock,target=yarn.lock \
  --mount=type=bind,source=.yarnrc.yml,target=.yarnrc.yml \
  <<EOF
yarn workspaces focus --all --production
EOF

###=======================================================
### Runner image
###=======================================================
FROM gcr.io/distroless/nodejs22-debian12:nonroot@sha256:28a71222ea7ab7d16a2abb888484cf40d43d86e053069a624ddb371cc9efdec2 AS runner

ARG BUILDER_APP_DIR
ARG RUNNER_APP_DIR

WORKDIR ${RUNNER_APP_DIR}

COPY --from=builder ${BUILDER_APP_DIR}/dist ./dist
COPY --from=builder ${BUILDER_APP_DIR}/node_modules ./node_modules

COPY --from=builder /bin/grpc_health_probe /bin/grpc_health_probe

ENV NODE_ENV=production
ENV NODE_OPTS="--no-warnings --enable-source-maps"

EXPOSE 8080

# grpc_health_probe でのヘルスチェック
HEALTHCHECK --interval=5s --timeout=5s --start-period=5s --retries=2 \
  CMD ["/bin/grpc_health_probe", "-addr=:8080"]

ENTRYPOINT [ "/nodejs/bin/node", "dist/index.js" ]

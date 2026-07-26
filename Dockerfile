# Multi-stage build for a Phoenix release (the standard phx.gen.release Dockerfile,
# pinned to a verified hexpm/elixir base image).
ARG ELIXIR_VERSION=1.18.2
# OTP 26 on purpose: OTP 27's stricter TLS validation rejects hex.pm's CDN cert
# during `mix local.hex`. The release bundles ERTS, so prod runtime is unaffected.
ARG OTP_VERSION=26.1.1
ARG DEBIAN_VERSION=bookworm-20260610-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile first so LiveView's colocated hooks (phoenix-colocated/peoplemedia) exist
# before esbuild bundles them.
RUN mix compile

# Build the minified, digested assets (esbuild + tailwind + phx.digest).
RUN mix assets.deploy

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ---- runtime image ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/peoplemedia ./

USER nobody

CMD ["/app/bin/server"]

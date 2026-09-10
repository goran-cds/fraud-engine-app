ARG ELIXIR_VERSION=1.20.0
ARG OTP_VERSION=29.0
ARG DEBIAN_VERSION=bookworm-20260610-slim
ARG GIT_SHA="undefined"

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"
ARG DEFAULT_MIX_ENV="dev"

# Tini is a tiny init system for Linux containers (does signal forwarding for graceful shutdown)
ARG DEFAULT_TINI_VERSION=v0.19.0

# Builder image -------------------------------------------------------------- START --------------------------------------------------------------

FROM ${BUILDER_IMAGE} as builder

# Set Erlang flags to disable TTY requirement (needed for Docker builds)
ENV ERL_FLAGS="-nouser -noinput +JMsingle true"
ENV TERM=dumb

# Inherit & set local env

ARG DEFAULT_MIX_ENV

ARG GIT_SHA
ENV APP_REVISION=${GIT_SHA}

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl wget nodejs npm bash libnss3-tools inotify-tools \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app/risk_engine

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=${DEFAULT_MIX_ENV}

# Configure Hex HTTP settings for more reliable package fetching
# Reduce concurrency and increase timeout to handle network issues
ENV HEX_HTTP_CONCURRENCY=1
ENV HEX_HTTP_TIMEOUT=120

# install mix dependencies
COPY risk_engine/mix.exs ./
COPY shared_contracts /app/shared_contracts

RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY risk_engine/config/config.exs risk_engine/config/runtime.exs risk_engine/config/${MIX_ENV}.exs config/

RUN mix deps.compile

COPY risk_engine/lib lib

# Format check
COPY risk_engine/.formatter.exs ./

RUN mix format --check-formatted

# Compile the release
RUN mix compile --warnings-as-errors

RUN mix release

# Builder image -------------------------------------------------------------- END --------------------------------------------------------------

# Runner image -------------------------------------------------------------- START --------------------------------------------------------------
# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} as runner

ARG DEFAULT_TINI_VERSION
ENV TINI_VERSION=${DEFAULT_TINI_VERSION}

# Inherit & set local env
ARG DEFAULT_MIX_ENV

ARG GIT_SHA
ENV APP_REVISION=${GIT_SHA}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libnss3-tools libncurses5 locales ca-certificates curl jq erlang-os-mon inotify-tools tini \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV=${DEFAULT_MIX_ENV}

# Copy the final Elixir release from the build stage
COPY --from=builder --chown=nobody:root /app/risk_engine/_build/${MIX_ENV}/rel/risk_engine ./

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
USER nobody

# Start server
CMD ["/app/bin/risk_engine", "start"]

# Runner image -------------------------------------------------------------- END --------------------------------------------------------------

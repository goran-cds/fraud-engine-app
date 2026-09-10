ARG ELIXIR_VERSION=1.20.0
ARG OTP_VERSION=29.0
ARG DEBIAN_VERSION=bookworm-20260610-slim
ARG GIT_SHA="undefined"

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"
ARG DEFAULT_MIX_ENV="dev"
ARG DEFAULT_TINI_VERSION=v0.19.0

# Builder image -------------------------------------------------------------- START 


FROM ${BUILDER_IMAGE} as builder

ENV ERL_FLAGS="-nouser -noinput +JMsingle true"
ENV TERM=dumb

ARG DEFAULT_MIX_ENV
ARG GIT_SHA
ENV APP_REVISION=${GIT_SHA}

RUN apt-get update -y && apt-get install -y build-essential cmake git curl wget nodejs npm bash libnss3-tools inotify-tools \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app/stream_processor

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=${DEFAULT_MIX_ENV}
ENV HEX_HTTP_CONCURRENCY=1
ENV HEX_HTTP_TIMEOUT=120

COPY stream_processor/mix.exs ./
COPY shared_contracts /app/shared_contracts

RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY stream_processor/config/config.exs stream_processor/config/runtime.exs stream_processor/config/${MIX_ENV}.exs config/

RUN mix deps.compile

COPY stream_processor/lib lib

COPY stream_processor/.formatter.exs ./

RUN mix format --check-formatted

RUN mix compile --warnings-as-errors

RUN mix release

# Builder image -------------------------------------------------------------- END 


# Runner image -------------------------------------------------------------- START 


FROM ${RUNNER_IMAGE} as runner

ARG DEFAULT_TINI_VERSION
ENV TINI_VERSION=${DEFAULT_TINI_VERSION}

ARG DEFAULT_MIX_ENV
ARG GIT_SHA
ENV APP_REVISION=${GIT_SHA}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libnss3-tools libncurses5 locales ca-certificates curl jq erlang-os-mon inotify-tools tini \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV=${DEFAULT_MIX_ENV}

COPY --from=builder --chown=nobody:root /app/stream_processor/_build/${MIX_ENV}/rel/stream_processor ./

ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
USER nobody

CMD ["/app/bin/stream_processor", "start"]

# Runner image -------------------------------------------------------------- END 

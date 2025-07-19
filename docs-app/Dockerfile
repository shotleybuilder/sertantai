# Multi-stage Dockerfile for Sertantai Documentation App
# Based on Elixir Alpine for smaller image size

# Build stage
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

# Set build environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy and build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm ci --production=false

COPY priv priv
COPY assets assets
RUN mix assets.deploy

# Copy source code
COPY config config
COPY lib lib

# Compile application
RUN mix compile

# Create release
RUN mix release

# Runtime stage
FROM alpine:3.18 AS runtime

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++ && \
    adduser -D app

# Set work directory
WORKDIR /app

# Copy release from build stage
COPY --from=build --chown=app:app /app/_build/prod/rel/sertantai_docs ./

# Create content directory
RUN mkdir -p priv/static/docs && chown -R app:app priv

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Set default environment variables
ENV PHX_SERVER=true
ENV MIX_ENV=prod

# Start the application
CMD ["./bin/sertantai_docs", "start"]
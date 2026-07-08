FROM rust:alpine AS parinfer-builder
RUN cargo install parinfer-rust

FROM alpine:3.21
RUN apk add --no-cache bash lua5.4 curl && \
    ln -s /usr/bin/lua5.4 /usr/local/bin/lua && \
    curl -fsSL https://fennel-lang.org/downloads/fennel-1.6.1 \
    -o /usr/local/bin/fennel && chmod +x /usr/local/bin/fennel

COPY --from=parinfer-builder /usr/local/cargo/bin/parinfer-rust /usr/local/bin/parinfer-rust

RUN mkdir -p /usr/local/lib/fennel-kit
COPY lib/parinfer.fnl /usr/local/lib/fennel-kit/parinfer.fnl
COPY lib/json.lua /usr/local/lib/fennel-kit/json.lua
COPY lib/fnlfmt.fnl /usr/local/lib/fennel-kit/fnlfmt.fnl
COPY lib/fnlfmt-cli.fnl /usr/local/lib/fennel-kit/fnlfmt-cli.fnl

RUN printf '#!/usr/bin/env lua\n' > /usr/local/bin/fnlfmt && \
    cd /usr/local/lib/fennel-kit && \
    fennel --require-as-include --compile fnlfmt-cli.fnl >> /usr/local/bin/fnlfmt && \
    chmod +x /usr/local/bin/fnlfmt

COPY bin/fennel-paren-repair /usr/local/bin/fennel-paren-repair
COPY bin/fennel-paren-repair-hook /usr/local/bin/fennel-paren-repair-hook

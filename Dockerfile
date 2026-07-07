FROM rust:alpine AS parinfer-builder
RUN cargo install parinfer-rust

FROM alpine:3.21
RUN apk add --no-cache bash
COPY --from=parinfer-builder /usr/local/cargo/bin/parinfer-rust /usr/local/bin/parinfer-rust
COPY bin/fennel-paren-repair /usr/local/bin/fennel-paren-repair
COPY bin/fennel-paren-repair-hook /usr/local/bin/fennel-paren-repair-hook

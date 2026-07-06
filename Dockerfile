FROM alpine:3.21

RUN apk add --no-cache \
    lua5.4 \
    lua5.4-dev \
    luarocks5.4 \
    build-base \
    git \
    curl \
    && ln -s /usr/bin/lua5.4 /usr/local/bin/lua

# Install fennel
RUN curl -fsSL https://fennel-lang.org/downloads/fennel-1.6.1 \
    -o /usr/local/bin/fennel && chmod +x /usr/local/bin/fennel

# Build tree-sitter C library (required by ltreesitter)
RUN curl -fsSL https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.26.8.tar.gz \
    | tar -xz -C /tmp \
    && cd /tmp/tree-sitter-0.26.8 \
    && make && make install \
    && rm -rf /tmp/tree-sitter-0.26.8

# Install Lua packages
RUN luarocks-5.4 config variables.LUA_INCDIR /usr/include/lua5.4 && \
    luarocks-5.4 install lua-cjson && \
    luarocks-5.4 install ltreesitter

# Compile tree-sitter-fennel grammar
RUN git clone --depth 1 https://github.com/alexmozaidze/tree-sitter-fennel /tmp/ts-fennel \
    && cd /tmp/ts-fennel \
    && cc -shared -fPIC -o /usr/local/lib/fennel-ts.so \
       -I./src ./src/parser.c ./src/scanner.c \
    && rm -rf /tmp/ts-fennel

ENV FENNEL_TS_PATH=/usr/local/lib/fennel-ts.so

WORKDIR /app
COPY . .

CMD ["fennel", "server.fnl"]

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y wget xz-utils && rm -rf /var/lib/apt/lists/*

# Install Zig 0.12.0
RUN wget https://ziglang.org/download/0.12.0/zig-linux-x86_64-0.12.0.tar.xz \
    && tar -xf zig-linux-x86_64-0.12.0.tar.xz \
    && mv zig-linux-x86_64-0.12.0 /usr/local/zig \
    && rm zig-linux-x86_64-0.12.0.tar.xz

ENV PATH="/usr/local/zig:$PATH"

WORKDIR /app
COPY . .

RUN zig build -Doptimize=ReleaseFast

# ── Stage 2: Run ─────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=builder /app/zig-out/bin/zig-url-shortener ./server
COPY --from=builder /app/static ./static

# Render sets PORT automatically; default to 8080
ENV PORT=8080
ENV HOST=your-app.onrender.com

EXPOSE 8080

CMD ["./server"]

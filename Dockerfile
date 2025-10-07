# Build stage for wx WebAssembly runtime
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN curl -L https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz -o zig.tar.xz && \
    tar -xf zig.tar.xz && \
    mv zig-linux-x86_64-0.15.1 /usr/local/zig && \
    rm zig.tar.xz

ENV PATH="/usr/local/zig:${PATH}"

# Set working directory
WORKDIR /build

# Copy source files
COPY . .

# Build the wx runtime
RUN zig build

# Runtime stage
FROM alpine:3.19

# Copy built binary from builder stage
COPY --from=builder /build/zig-out/bin/wx /usr/local/bin/wx

# Create a directory for WASM files
WORKDIR /wasm

# Set the entrypoint
ENTRYPOINT ["wx"]

# Default command (show help)
CMD ["--help"]

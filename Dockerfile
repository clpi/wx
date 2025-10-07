# Multi-stage build for wx WebAssembly runtime

# Build stage
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    xz-utils \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Zig
ARG ZIG_VERSION=0.15.1
RUN wget -q https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz && \
    tar -xf zig-linux-x86_64-${ZIG_VERSION}.tar.xz && \
    mv zig-linux-x86_64-${ZIG_VERSION} /usr/local/zig && \
    rm zig-linux-x86_64-${ZIG_VERSION}.tar.xz

ENV PATH="/usr/local/zig:${PATH}"

# Set working directory
WORKDIR /build

# Copy source files
COPY build.zig .build.zig.zon ./
COPY src ./src

# Build the wx runtime
RUN zig build -Doptimize=ReleaseFast

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies (libc)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libc6 && \
    rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /build/zig-out/bin/wx /usr/local/bin/wx

# Set working directory
WORKDIR /workspace

# Default command
ENTRYPOINT ["/usr/local/bin/wx"]
CMD ["--help"]

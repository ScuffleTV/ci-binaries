# syntax = docker/dockerfile:1.4
FROM ubuntu:latest

LABEL org.opencontainers.image.source=https://github.com/scuffletv/ci
LABEL org.opencontainers.image.description="Build for ScuffleTV"
LABEL org.opencontainers.image.licenses=BSD-4-Clause

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:/usr/local/yarn/bin:$PATH

ARG RUST_VERSION=1.72.0

RUN <<eot
    set -eux

    apt-get update
    apt-get install -y --no-install-recommends \
            libssl-dev \
            libgnutls30 \
            libssl3 \
            libsystemd0 \
            libudev1 \
            tar \
            build-essential \
            zip \
            unzip \
            curl \
            wget \
            git \
            ssh \
            ca-certificates \
            pkg-config \
            gnupg2 \
            ffmpeg \
            cmake \
            clang-format

    # Compile protobuf v22.2
    git clone https://github.com/protocolbuffers/protobuf.git -b v22.2 /tmp/protobuf --depth 1 --recurse-submodules
    mkdir /tmp/protobuf/build
    cd /tmp/protobuf/build
    cmake -Dprotobuf_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release ..
    cmake --build . --target install -j $(nproc) --config Release
    ldconfig
    cd -
    rm -rf /tmp/protobuf


    curl -sL https://deb.nodesource.com/setup_18.x | bash -
    apt-get update
    apt-get install -y nodejs --no-install-recommends

    npm install -g pnpm 

    # Install Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain=$RUST_VERSION

    # Install Rust tools
    rustup update
    rustup target add wasm32-unknown-unknown
    rustup component add clippy rustfmt llvm-tools-preview

    cargo install sqlx-cli --features native-tls,postgres --no-default-features --git https://github.com/launchbadge/sqlx --branch main
    cargo install cargo-llvm-cov
    cargo install cargo-nextest
    cargo install wasm-bindgen-cli
    cargo install mask
    cargo install cargo-sweep --git https://github.com/holmgr/cargo-sweep --branch master

    # Install Wasm tools
    wget https://github.com/WebAssembly/binaryen/releases/download/version_114/binaryen-version_114-x86_64-linux.tar.gz -O /tmp/binaryen.tar.gz
    tar -xvf /tmp/binaryen.tar.gz -C /tmp
    mv /tmp/binaryen-version_114/bin/* /usr/local/bin/
    rm -rf /tmp/binaryen.tar.gz /tmp/binaryen-version_114

    # Clean up 
    rm -rf /usr/local/cargo/registry /usr/local/cargo/git 
    apt-get autoremove -y
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Remove SSH host keys, for some reason they are generated on build.
    rm -rf /etc/ssh/ssh_host_* 
eot

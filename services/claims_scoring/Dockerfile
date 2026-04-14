FROM rust:1.77-slim AS builder

WORKDIR /usr/src/app
COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /usr/src/app/target/release/claims_scoring .

EXPOSE 8080
CMD ["./claims_scoring"]

FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o kg_cache main.go handlers.go cache.go

FROM alpine:latest
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/kg_cache .
USER appuser
EXPOSE 8080
CMD ["./kg_cache"]

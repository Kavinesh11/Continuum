FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o kg_cache main.go handlers.go cache.go

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/kg_cache .

EXPOSE 8080
CMD ["./kg_cache"]

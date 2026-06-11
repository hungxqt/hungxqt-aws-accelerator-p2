# Stage 1: Build the Go binary
FROM golang:1.21-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o backend .

# Stage 2: Minimal runtime environment
FROM alpine:3.18

WORKDIR /app

COPY --from=builder /app/backend .

EXPOSE 5000

CMD ["./backend"]

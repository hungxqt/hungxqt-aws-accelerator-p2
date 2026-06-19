# Stage 1: Build the Go binary natively on build platform
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o backend .


# Stage 2: Minimal runtime environment
FROM alpine:3.18

WORKDIR /app

COPY --from=builder /app/backend .

EXPOSE 5000

CMD ["./backend"]

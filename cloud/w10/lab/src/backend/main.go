package main

// Trigger CI build to generate and sign the new image digests.
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

/*

Section: Test the rollout canary

*/

var (
	ctx = context.Background()
	rdb *redis.Client

	// Custom metrics
	visitRequests200 uint64
	visitRequests400 uint64
	visitRequests401 uint64
	visitRequests500 uint64

	// Tracer
	tracer trace.Tracer
)

type VisitRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type VisitResponse struct {
	Username string `json:"username"`
	Visits   int64  `json:"visits"`
	Message  string `json:"message"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

func initTracer() (*sdktrace.TracerProvider, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "jaeger:4317"
	}

	conn, err := grpc.DialContext(ctx, endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to OTLP collector: %w", err)
	}

	exporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
	if err != nil {
		return nil, fmt.Errorf("failed to create OTLP trace exporter: %w", err)
	}

	envName := os.Getenv("ENVIRONMENT")
	if envName == "" {
		envName = "development"
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("backend"),
			attribute.String("environment", envName),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	tracer = otel.Tracer("backend-tracer")

	return tp, nil
}

func main() {
	// Initialize Tracer
	tp, err := initTracer()
	if err != nil {
		log.Printf("Warning: Failed to initialize tracer (proceeding without tracing): %v", err)
	} else {
		defer func() {
			if err := tp.Shutdown(context.Background()); err != nil {
				log.Printf("Error shutting down tracer provider: %v", err)
			}
		}()
		log.Println("OpenTelemetry Tracer initialized successfully.")
	}

	// Connect to Redis database
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "database"
	}
	redisPort := os.Getenv("REDIS_PORT")
	if redisPort == "" {
		redisPort = "6379"
	}
	redisPassword := os.Getenv("REDIS_PASSWORD")
	if redisPassword == "" {
		log.Fatalf("Fatal: REDIS_PASSWORD environment variable is missing")
	}

	rdb = redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", redisHost, redisPort),
		Password: redisPassword,
	})

	// Test connection
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	fmt.Println("Connected to Redis successfully.")

	// Route Handlers
	http.HandleFunc("/api/v1/visit", handleVisit)
	http.HandleFunc("/api/v1/metrics", handleMetrics)
	http.HandleFunc("/healthz", handleHealthz)

	log.Println("Backend server starting on :5000...")
	if err := http.ListenAndServe(":5000", nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func handleVisit(w http.ResponseWriter, r *http.Request) {
	// Configure CORS headers to allow browser requests
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Start a trace span if tracer is initialized
	var rCtx context.Context = r.Context()
	var span trace.Span
	if tracer != nil {
		rCtx, span = tracer.Start(r.Context(), "handleVisit")
		defer span.End()
		span.SetAttributes(
			attribute.String("http.method", r.Method),
			attribute.String("http.url", r.URL.Path),
		)
	}

	if r.Method != "POST" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Method not allowed"})
		if span != nil {
			span.SetAttributes(attribute.Int("http.status_code", http.StatusMethodNotAllowed))
		}
		return
	}

	var req VisitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid JSON request body"})
		atomic.AddUint64(&visitRequests400, 1)
		if span != nil {
			span.RecordError(err)
			span.SetAttributes(attribute.Int("http.status_code", http.StatusBadRequest))
		}
		return
	}

	if req.Username == "" || req.Password == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Username and password are required"})
		atomic.AddUint64(&visitRequests400, 1)
		if span != nil {
			span.SetAttributes(
				attribute.Int("http.status_code", http.StatusBadRequest),
				attribute.String("error.message", "missing credentials"),
			)
		}
		return
	}

	usernameClean := strings.TrimSpace(req.Username)
	userKey := fmt.Sprintf("user:%s", usernameClean)

	w.Header().Set("Content-Type", "application/json")
	if span != nil {
		span.SetAttributes(attribute.String("user.username", usernameClean))
	}

	// Check if user exists with a child span
	var redisCtx context.Context = rCtx
	var redisSpan trace.Span
	if tracer != nil {
		redisCtx, redisSpan = tracer.Start(rCtx, "Redis Exists")
	}
	exists, err := rdb.Exists(redisCtx, userKey).Result()
	if redisSpan != nil {
		if err != nil {
			redisSpan.RecordError(err)
		}
		redisSpan.End()
	}
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Database lookup error"})
		atomic.AddUint64(&visitRequests500, 1)
		if span != nil {
			span.RecordError(err)
			span.SetAttributes(attribute.Int("http.status_code", http.StatusInternalServerError))
		}
		return
	}

	if exists == 0 {
		// Create user and set initial visits to 1
		var redisHSetCtx context.Context = rCtx
		var redisHSetSpan trace.Span
		if tracer != nil {
			redisHSetCtx, redisHSetSpan = tracer.Start(rCtx, "Redis HSet")
		}
		err = rdb.HSet(redisHSetCtx, userKey, map[string]interface{}{
			"password": req.Password,
			"visits":   1,
		}).Err()
		if redisHSetSpan != nil {
			if err != nil {
				redisHSetSpan.RecordError(err)
			}
			redisHSetSpan.End()
		}
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "Failed to create user"})
			atomic.AddUint64(&visitRequests500, 1)
			if span != nil {
				span.RecordError(err)
				span.SetAttributes(attribute.Int("http.status_code", http.StatusInternalServerError))
			}
			return
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(VisitResponse{
			Username: usernameClean,
			Visits:   1,
			Message:  fmt.Sprintf("Welcome, %s! Account created and visit recorded.", usernameClean),
		})
		atomic.AddUint64(&visitRequests200, 1)
		if span != nil {
			span.SetAttributes(
				attribute.Int("http.status_code", http.StatusOK),
				attribute.Bool("user.new_account", true),
			)
		}
		return
	}

	// Verify password
	var redisHGetCtx context.Context = rCtx
	var redisHGetSpan trace.Span
	if tracer != nil {
		redisHGetCtx, redisHGetSpan = tracer.Start(rCtx, "Redis HGet")
	}
	storedPassword, err := rdb.HGet(redisHGetCtx, userKey, "password").Result()
	if redisHGetSpan != nil {
		if err != nil {
			redisHGetSpan.RecordError(err)
		}
		redisHGetSpan.End()
	}
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Database read error"})
		atomic.AddUint64(&visitRequests500, 1)
		if span != nil {
			span.RecordError(err)
			span.SetAttributes(attribute.Int("http.status_code", http.StatusInternalServerError))
		}
		return
	}

	if storedPassword != req.Password {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Incorrect password for this user."})
		atomic.AddUint64(&visitRequests401, 1)
		if span != nil {
			span.SetAttributes(
				attribute.Int("http.status_code", http.StatusUnauthorized),
				attribute.String("error.message", "incorrect password"),
			)
		}
		return
	}

	// Increment visits count
	var redisHIncrCtx context.Context = rCtx
	var redisHIncrSpan trace.Span
	if tracer != nil {
		redisHIncrCtx, redisHIncrSpan = tracer.Start(rCtx, "Redis HIncrBy")
	}
	visits, err := rdb.HIncrBy(redisHIncrCtx, userKey, "visits", 1).Result()
	if redisHIncrSpan != nil {
		if err != nil {
			redisHIncrSpan.RecordError(err)
		}
		redisHIncrSpan.End()
	}
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Failed to record visit"})
		atomic.AddUint64(&visitRequests500, 1)
		if span != nil {
			span.RecordError(err)
			span.SetAttributes(attribute.Int("http.status_code", http.StatusInternalServerError))
		}
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(VisitResponse{
		Username: usernameClean,
		Visits:   visits,
		Message:  fmt.Sprintf("Welcome back, %s! Your visit count has been updated.", usernameClean),
	})
	atomic.AddUint64(&visitRequests200, 1)
	if span != nil {
		span.SetAttributes(
			attribute.Int("http.status_code", http.StatusOK),
			attribute.Int64("user.visits", visits),
		)
	}
}

func handleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")

	var activeUsers int
	if rdb != nil {
		keys, err := rdb.Keys(ctx, "user:*").Result()
		if err == nil {
			activeUsers = len(keys)
		} else {
			log.Printf("Failed to fetch keys from Redis for metrics: %v", err)
		}
	}

	fmt.Fprintf(w, "# HELP go_visit_requests_total Total number of visit requests.\n")
	fmt.Fprintf(w, "# TYPE go_visit_requests_total counter\n")
	fmt.Fprintf(w, "go_visit_requests_total{status=\"200\"} %d\n", atomic.LoadUint64(&visitRequests200))
	fmt.Fprintf(w, "go_visit_requests_total{status=\"400\"} %d\n", atomic.LoadUint64(&visitRequests400))
	fmt.Fprintf(w, "go_visit_requests_total{status=\"401\"} %d\n", atomic.LoadUint64(&visitRequests401))
	fmt.Fprintf(w, "go_visit_requests_total{status=\"500\"} %d\n", atomic.LoadUint64(&visitRequests500))
	fmt.Fprintf(w, "\n")
	fmt.Fprintf(w, "# HELP go_visit_users_active_total Total number of registered users in database.\n")
	fmt.Fprintf(w, "# TYPE go_visit_users_active_total gauge\n")
	fmt.Fprintf(w, "go_visit_users_active_total %d\n", activeUsers)
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if err := rdb.Ping(ctx).Err(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"status":"unhealthy"}`))
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy"}`))
}

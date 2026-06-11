package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"

	"github.com/redis/go-redis/v9"
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

func main() {
	// Connect to Redis database
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		redisHost = "database"
	}
	redisPort := os.Getenv("REDIS_PORT")
	if redisPort == "" {
		redisPort = "6379"
	}

	rdb = redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", redisHost, redisPort),
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

	if r.Method != "POST" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Method not allowed"})
		return
	}

	var req VisitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid JSON request body"})
		atomic.AddUint64(&visitRequests400, 1)
		return
	}

	if req.Username == "" || req.Password == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Username and password are required"})
		atomic.AddUint64(&visitRequests400, 1)
		return
	}

	usernameClean := strings.TrimSpace(req.Username)
	userKey := fmt.Sprintf("user:%s", usernameClean)

	w.Header().Set("Content-Type", "application/json")

	// Check if user exists
	exists, err := rdb.Exists(ctx, userKey).Result()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Database lookup error"})
		atomic.AddUint64(&visitRequests500, 1)
		return
	}

	if exists == 0 {
		// Create user and set initial visits to 1
		err = rdb.HSet(ctx, userKey, map[string]interface{}{
			"password": req.Password,
			"visits":   1,
		}).Err()
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "Failed to create user"})
			atomic.AddUint64(&visitRequests500, 1)
			return
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(VisitResponse{
			Username: usernameClean,
			Visits:   1,
			Message:  fmt.Sprintf("Welcome, %s! Account created and visit recorded.", usernameClean),
		})
		atomic.AddUint64(&visitRequests200, 1)
		return
	}

	// Verify password
	storedPassword, err := rdb.HGet(ctx, userKey, "password").Result()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Database read error"})
		atomic.AddUint64(&visitRequests500, 1)
		return
	}

	if storedPassword != req.Password {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Incorrect password for this user."})
		atomic.AddUint64(&visitRequests401, 1)
		return
	}

	// Increment visits count
	visits, err := rdb.HIncrBy(ctx, userKey, "visits", 1).Result()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Failed to record visit"})
		atomic.AddUint64(&visitRequests500, 1)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(VisitResponse{
		Username: usernameClean,
		Visits:   visits,
		Message:  fmt.Sprintf("Welcome back, %s! Your visit count has been updated.", usernameClean),
	})
	atomic.AddUint64(&visitRequests200, 1)
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

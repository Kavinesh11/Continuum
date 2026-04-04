package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	webIntelURL := getEnv("WEB_INTEL_URL", "http://web_intelligence:8003")
	port := getEnv("PORT", "8080")

	cache := NewCache(webIntelURL)

	mux := http.NewServeMux()
	registerHandlers(mux, cache)

	addr := ":" + port
	log.Printf("Knowledge Graph Cache starting on %s (web_intel_url=%s)", addr, webIntelURL)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// getEnv returns the value of the environment variable named by key,
// or fallback if the variable is not set or empty.
func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

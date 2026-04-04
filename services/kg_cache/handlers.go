package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"
)

// parseZoneEventKey extracts zone_id and event_type from a path like
// /cache/{zone_id}/{event_type} and returns the composite key "{zone_id}:{event_type}".
// Returns ("", false) if the path does not have the expected structure.
func parseZoneEventKey(path string) (string, bool) {
	// Strip leading slash and split.
	parts := strings.Split(strings.TrimPrefix(path, "/"), "/")
	// Expected: ["cache", "{zone_id}", "{event_type}"]
	if len(parts) != 3 || parts[0] != "cache" || parts[1] == "" || parts[2] == "" {
		return "", false
	}
	return parts[1] + ":" + parts[2], true
}

// registerHandlers wires all routes onto the given mux.
func registerHandlers(mux *http.ServeMux, cache *Cache) {
	mux.HandleFunc("/cache/", func(w http.ResponseWriter, r *http.Request) {
		key, ok := parseZoneEventKey(r.URL.Path)
		if !ok {
			http.Error(w, "invalid path: expected /cache/{zone_id}/{event_type}", http.StatusBadRequest)
			return
		}

		switch r.Method {
		case http.MethodGet:
			handleGet(w, r, cache, key)
		case http.MethodPut:
			handlePut(w, r, cache, key)
		case http.MethodDelete:
			handleDelete(w, r, cache, key)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/health", handleHealth)
}

// GET /cache/{zone_id}/{event_type}
// Returns 200 + JSON body if found, 404 if not found or expired.
func handleGet(w http.ResponseWriter, _ *http.Request, cache *Cache, key string) {
	value, ok := cache.Get(key)
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte(value)); err != nil {
		log.Printf("handleGet: write error for key %q: %v", key, err)
	}
}

// PUT /cache/{zone_id}/{event_type}
// Body: raw JSON string (DisruptionEvent). Returns 201.
func handlePut(w http.ResponseWriter, r *http.Request, cache *Cache, key string) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Validate that the body is valid JSON.
	if !json.Valid(body) {
		http.Error(w, "request body must be valid JSON", http.StatusBadRequest)
		return
	}

	cache.Set(key, string(body))
	w.WriteHeader(http.StatusCreated)
}

// DELETE /cache/{zone_id}/{event_type}
// Returns 204.
func handleDelete(w http.ResponseWriter, _ *http.Request, cache *Cache, key string) {
	cache.Delete(key)
	w.WriteHeader(http.StatusNoContent)
}

// GET /health
// Returns 200 {"status": "ok"}.
func handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte(`{"status":"ok"}`)); err != nil {
		log.Printf("handleHealth: write error: %v", err)
	}
}

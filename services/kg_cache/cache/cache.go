// Feature: continuum-ml-pipelines
// Package cache provides the Knowledge Graph Cache with 15-minute TTL per entry.
// Validates: Requirements 11.4, 11.5, 11.6
package cache

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

// TTL is the time-to-live for every cache entry (15 minutes per Requirement 11.4).
const TTL = 15 * time.Minute

// Entry holds a JSON-encoded DisruptionEvent and its expiry time.
type Entry struct {
	Value     string // JSON-encoded DisruptionEvent
	ExpiresAt time.Time
}

// Cache is a thread-safe in-memory TTL cache keyed by "{zone_id}:{event_type}".
type Cache struct {
	mu          sync.RWMutex
	entries     map[string]Entry
	WebIntelURL string
}

// New creates a new Cache with the given Web_Intelligence_Service callback URL.
func New(webIntelURL string) *Cache {
	return &Cache{
		entries:     make(map[string]Entry),
		WebIntelURL: webIntelURL,
	}
}

// Set stores a value under key with a fresh TTL (ExpiresAt = now + 15 min).
func (c *Cache) Set(key, value string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[key] = Entry{
		Value:     value,
		ExpiresAt: time.Now().Add(TTL),
	}
}

// SetWithExpiry stores a value under key with an explicit expiry time.
// This is intended for testing so that tests can inject past or future expiry
// without sleeping for 15 minutes.
func (c *Cache) SetWithExpiry(key, value string, expiresAt time.Time) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[key] = Entry{Value: value, ExpiresAt: expiresAt}
}

// Get retrieves a value by key.
// Returns ("", false) if the key is missing or the entry has expired.
// On expiry: evicts the entry and triggers an async re-scrape.
func (c *Cache) Get(key string) (string, bool) {
	// Fast path: read lock to check existence and expiry.
	c.mu.RLock()
	entry, ok := c.entries[key]
	c.mu.RUnlock()

	if !ok {
		return "", false
	}

	if time.Now().After(entry.ExpiresAt) {
		// Entry is stale — evict and trigger re-scrape.
		c.mu.Lock()
		// Re-check under write lock to avoid a race where another goroutine
		// already evicted or refreshed the entry.
		if e, still := c.entries[key]; still && time.Now().After(e.ExpiresAt) {
			delete(c.entries, key)
		}
		c.mu.Unlock()
		go c.triggerRescrape(key)
		return "", false
	}

	return entry.Value, true
}

// Delete removes an entry from the cache.
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.entries, key)
}

// triggerRescrape fires an async HTTP POST to WebIntelURL/rescrape with {"key": key}.
// Errors are logged but never panic.
func (c *Cache) triggerRescrape(key string) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("triggerRescrape panic recovered for key %q: %v", key, r)
		}
	}()

	body, err := json.Marshal(map[string]string{"key": key})
	if err != nil {
		log.Printf("triggerRescrape: failed to marshal payload for key %q: %v", key, err)
		return
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Post(c.WebIntelURL+"/rescrape", "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("triggerRescrape: HTTP POST failed for key %q: %v", key, err)
		return
	}
	defer resp.Body.Close()
	log.Printf("triggerRescrape: re-scrape triggered for key %q, status %s", key, resp.Status)
}

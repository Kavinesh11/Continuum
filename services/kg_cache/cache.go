package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

const TTL = 15 * time.Minute

// CacheEntry holds a JSON-encoded DisruptionEvent and its expiry time.
type CacheEntry struct {
	Value     string // JSON-encoded DisruptionEvent
	ExpiresAt time.Time
}

// Cache is a thread-safe in-memory TTL cache.
type Cache struct {
	mu          sync.RWMutex
	entries     map[string]CacheEntry
	webIntelURL string
}

// NewCache creates a new Cache with the given Web_Intelligence_Service callback URL.
func NewCache(webIntelURL string) *Cache {
	return &Cache{
		entries:     make(map[string]CacheEntry),
		webIntelURL: webIntelURL,
	}
}

// Set stores a value under key with a fresh TTL.
// Key format: "{zone_id}:{event_type}"
func (c *Cache) Set(key, value string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[key] = CacheEntry{
		Value:     value,
		ExpiresAt: time.Now().Add(TTL),
	}
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

// triggerRescrape fires an async HTTP POST to webIntelURL/rescrape with {"key": key}.
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
	resp, err := client.Post(c.webIntelURL+"/rescrape", "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("triggerRescrape: HTTP POST failed for key %q: %v", key, err)
		return
	}
	defer resp.Body.Close()
	log.Printf("triggerRescrape: re-scrape triggered for key %q, status %s", key, resp.Status)
}

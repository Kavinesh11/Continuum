// Feature: continuum-ml-pipelines
// Lightweight HTTP server exposing /metrics for Prometheus scraping
// Requirements: 8.3, 16.1, 16.3

'use strict';

const http = require('http');
const { getMetrics, contentType, refreshQueueDepths } = require('./metrics');
const { getQueue, QUEUE_NAMES } = require('./queues');

const METRICS_PORT = parseInt(process.env.BULLMQ_METRICS_PORT || '9102', 10);
// Refresh queue depth gauges every 15 seconds (matches Prometheus scrape interval)
const DEPTH_REFRESH_INTERVAL_MS = 15 * 1000;

let server = null;
let refreshIntervalId = null;

/**
 * Start the Prometheus metrics HTTP server on METRICS_PORT.
 * Exposes GET /metrics in Prometheus exposition format.
 *
 * @returns {{ server: http.Server, stop: Function }}
 */
function startMetricsServer() {
  const queueNames = Object.values(QUEUE_NAMES);

  // Periodically refresh queue depth gauges
  refreshIntervalId = setInterval(() => {
    refreshQueueDepths(getQueue, queueNames).catch((err) => {
      console.error('[metricsServer] Depth refresh error:', err.message);
    });
  }, DEPTH_REFRESH_INTERVAL_MS);

  server = http.createServer(async (req, res) => {
    if (req.method === 'GET' && req.url === '/metrics') {
      try {
        const metrics = await getMetrics();
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(metrics);
      } catch (err) {
        res.writeHead(500);
        res.end(`Error collecting metrics: ${err.message}`);
      }
    } else if (req.method === 'GET' && req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
    } else {
      res.writeHead(404);
      res.end('Not found');
    }
  });

  server.listen(METRICS_PORT, () => {
    console.log(`[metricsServer] Prometheus /metrics available on port ${METRICS_PORT}`);
  });

  function stop() {
    clearInterval(refreshIntervalId);
    return new Promise((resolve) => {
      if (server) {
        server.close(resolve);
      } else {
        resolve();
      }
    });
  }

  return { server, stop };
}

module.exports = { startMetricsServer };

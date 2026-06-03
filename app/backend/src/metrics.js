const client = require('prom-client');

client.collectDefaultMetrics();

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const cacheHitsTotal = new client.Counter({
  name: 'cache_hits_total',
  help: 'Total number of Redis cache hits',
});

const cacheMissesTotal = new client.Counter({
  name: 'cache_misses_total',
  help: 'Total number of Redis cache misses',
});

module.exports = { client, httpRequestDuration, httpRequestsTotal, cacheHitsTotal, cacheMissesTotal };

/**
 * Demo Node.js Microservice
 * This is the skeleton app that gets scaffolded by the Backstage template.
 * Production-ready with health endpoints, graceful shutdown, and structured logging.
 */
const http = require('http');

const PORT = process.env.PORT || 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || 'my-service';
const VERSION = process.env.VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// Simple structured logger
const log = (level, message, data = {}) => {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    service: SERVICE_NAME,
    version: VERSION,
    environment: ENVIRONMENT,
    message,
    ...data
  }));
};

// Track request count (replace with Prometheus in production)
let requestCount = 0;
let isReady = false;

// Simulate startup delay (db connection, etc.)
setTimeout(() => {
  isReady = true;
  log('info', 'Service ready to accept traffic');
}, 1000);

const server = http.createServer((req, res) => {
  requestCount++;
  const start = Date.now();

  // Health check endpoint — used by Kubernetes liveness probe
  if (req.url === '/health' || req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime() }));
    return;
  }

  // Readiness probe — Kubernetes won't send traffic until this returns 200
  if (req.url === '/ready' || req.url === '/readyz') {
    if (isReady) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ready' }));
    } else {
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'not ready' }));
    }
    return;
  }

  // Main route
  if (req.url === '/' && req.method === 'GET') {
    const response = {
      service: SERVICE_NAME,
      version: VERSION,
      environment: ENVIRONMENT,
      message: `Hello from ${SERVICE_NAME}! Deployed via IDP 🚀`,
      requestCount,
      timestamp: new Date().toISOString()
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(response, null, 2));
    log('info', 'Request handled', { method: req.method, url: req.url, duration: Date.now() - start });
    return;
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found', path: req.url }));
});

// Start server
server.listen(PORT, () => {
  log('info', `${SERVICE_NAME} started`, { port: PORT, pid: process.pid });
});

// Graceful shutdown — Kubernetes sends SIGTERM before killing the pod
const shutdown = (signal) => {
  log('info', `Received ${signal}, shutting down gracefully...`);
  server.close(() => {
    log('info', 'Server closed. Exiting.');
    process.exit(0);
  });
  // Force exit after 10 seconds if something hangs
  setTimeout(() => process.exit(1), 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

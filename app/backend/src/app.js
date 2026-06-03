require('dotenv').config();
const express = require('express');
const connectDB = require('./db');
const connectRedis = require('./redis');
const todoRoutes = require('./routes/todo.routes');
const cors = require('cors');
const { client, httpRequestDuration, httpRequestsTotal } = require('./metrics');

const app = express();

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const rawRoute = req.route ? req.baseUrl + req.route.path : req.path;
    const route = rawRoute.replace(/\/$/, '') || '/';
    const labels = { method: req.method, route, status_code: res.statusCode };
    end(labels);
    httpRequestsTotal.inc(labels);
  });
  next();
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// ALLOWED_ORIGIN supports a single origin or comma-separated list
const rawOrigin = process.env.ALLOWED_ORIGIN || '*';
const allowedOrigin = rawOrigin.includes(',')
  ? rawOrigin.split(',').map(o => o.trim())
  : rawOrigin;

app.use(cors({
  origin: allowedOrigin,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
}));

app.use(express.json());

(async () => {
  const db = await connectDB();
  const redis = await connectRedis();

  app.use((req, _res, next) => {
    req.db = db;
    req.redis = redis;
    next();
  });

  // Routes — mounted at /api/todos to match frontend calls and ALB /api prefix
  app.use('/api/todos', todoRoutes);

  app.get('/health', (req, res) => {
    res.json({ status: 'OK', version: 'v4' });
  });

  // Global error handler — returns JSON for all unhandled errors
  app.use((err, _req, res, _next) => {
    console.error('Unhandled error:', err.message);
    res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
  });

  app.listen(process.env.PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${process.env.PORT}`);
  });
})();

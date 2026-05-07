require('dotenv').config();
const express = require('express');
const connectDB = require('./db');
const connectRedis = require('./redis');
const todoRoutes = require('./routes/todo.routes');
const cors = require('cors');

const app = express();

const allowedOrigin = process.env.ALLOWED_ORIGIN || '*';

app.use(cors({
  origin: allowedOrigin,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
}));

app.use(express.json());

(async () => {
  const db = await connectDB();
  const redis = await connectRedis();

  app.use((req, res, next) => {
    req.db = db;
    req.redis = redis;
    next();
  });

  app.use('/todos', todoRoutes);

  app.get('/health', (req, res) => {
    res.json({ status: "OK", version: "v4" });
  });

  app.listen(process.env.PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${process.env.PORT}`);
  });
})(); 
// pipeline test
// webhook test 2

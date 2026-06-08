const Redis = require('ioredis');

const connectRedis = async () => {
  const client = new Redis({
    host: process.env.REDIS_HOST,
    port: 6379,
    password: process.env.REDIS_PASSWORD || undefined,
    lazyConnect: true,
    // ElastiCache in-transit encryption requires TLS. The certificate is signed
    // by AWS's CA which is included in Node.js's default trust store.
    tls: {},
  });

  client.on('error', (err) => {
    console.error('Redis error:', err.message);
  });

  await client.connect();
  console.log('✅ Connected to Redis');
  return client;
};

module.exports = connectRedis;

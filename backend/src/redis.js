const Redis = require('ioredis');

const connectRedis = async () => {
  const client = new Redis({
    host: process.env.REDIS_HOST,
    port: 6379,
    lazyConnect: true,
  });

  await client.connect();
  console.log('✅ Connected to Redis');
  return client;
};

module.exports = connectRedis;

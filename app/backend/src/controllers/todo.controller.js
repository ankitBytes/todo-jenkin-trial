const { cacheHitsTotal, cacheMissesTotal } = require('../metrics');

const CACHE_KEY = 'todos:all';
const CACHE_TTL = 60; // seconds — why not infinite? RDS could be updated outside the app

exports.getTodos = async (req, res) => {
  const redis = req.redis;

  const cached = await redis.get(CACHE_KEY);
  if (cached) {
    cacheHitsTotal.inc();
    return res.json(JSON.parse(cached));
  }

  cacheMissesTotal.inc();
  const [rows] = await req.db.execute("SELECT * FROM todos");

  // Step 3: Populate cache for next request
  await redis.set(CACHE_KEY, JSON.stringify(rows), 'EX', CACHE_TTL);

  res.json(rows);
};

exports.createTodo = async (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: "Title required" });
  await req.db.execute("INSERT INTO todos (title) VALUES (?)", [title]);

  // Invalidate cache — data changed
  await req.redis.del(CACHE_KEY);

  res.json({ message: "Todo created" });
};

exports.updateTodo = async (req, res) => {
  const { id } = req.params;
  await req.db.execute(
    "UPDATE todos SET status='completed' WHERE id=?",
    [id]
  );

  // Invalidate cache — data changed
  await req.redis.del(CACHE_KEY);

  res.json({ message: "Todo updated" });
};

exports.deleteTodo = async (req, res) => {
  const { id } = req.params;
  await req.db.execute("DELETE FROM todos WHERE id=?", [id]);

  // Invalidate cache — data changed
  await req.redis.del(CACHE_KEY);

  res.json({ message: "Todo deleted" });
}; 

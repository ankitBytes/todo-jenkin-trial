const mysql = require('mysql2/promise');

const connectDB = async () => {
  let retries = 15;
  while (retries) {
    try {
      const pool = await mysql.createPool({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
      });

      // Verify connectivity before returning
      const conn = await pool.getConnection();
      await conn.execute(`
        CREATE TABLE IF NOT EXISTS todos (
          id INT AUTO_INCREMENT PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          status ENUM('pending', 'completed') DEFAULT 'pending',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      conn.release();

      console.log("✅ Connected to MySQL (pool)");
      return pool;
    } catch (err) {
      console.log("⏳ DB not ready, retrying...", err.message);
      retries--;
      await new Promise(res => setTimeout(res, 5000));
    }
  }
  throw new Error("❌ Could not connect to DB");
};

module.exports = connectDB; 

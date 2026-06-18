require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./connection');

async function migrate() {
  const migrationsDir = path.join(__dirname, '..', '..', 'migrations');
  const files = fs.readdirSync(migrationsDir).sort();

  for (const file of files) {
    if (!file.endsWith('.sql')) continue;

    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

    try {
      await pool.query(sql);
      console.log(`✓ ${file} applied successfully`);
    } catch (err) {
      console.error(`✗ ${file} failed:`, err.message);
      throw err;
    }
  }

  console.log('All migrations applied.');
  await pool.end();
}

migrate().catch((err) => {
  console.error('Migration error:', err);
  process.exit(1);
});

const { Pool } = require('pg');

// Configuración: Si hay Nube usa Nube, si no, usa tu PC con tu clave
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:Admin123@localhost:5432/urbanos_db',
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

module.exports = pool;
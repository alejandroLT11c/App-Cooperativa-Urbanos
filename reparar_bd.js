const { Pool } = require('pg');

// Tu enlace de la nube (Render)
const connectionString = 'postgresql://urbanos_db_user:Xood4W2p6n8FxD8paL1JTmQ3nQK4CEEe@dpg-d500ivre5dus73aor62g-a.virginia-postgres.render.com/urbanos_db';

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false }
});

const fixDatabase = async () => {
  try {
    console.log('⏳ Iniciando reparación de la base de datos...');

    // 1. Habilitar funciones avanzadas (para los IDs raros)
    await pool.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto";');

    // 2. BORRAR la tabla vieja de Usuarios (Reset)
    await pool.query('DROP TABLE IF EXISTS users CASCADE;');
    console.log('🗑️ Tabla antigua eliminada.');

    // 3. CREAR la tabla NUEVA (Versión Correcta)
    await pool.query(`
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,  -- Ahora sí se llama password_hash
        full_name TEXT,               -- Y agregamos el nombre completo
        role TEXT DEFAULT 'CLIENTE',
        wallet_balance DECIMAL(10,2) DEFAULT 0
      );
    `);
    console.log('✅ Tabla Users creada correctamente.');

    // 4. Restaurar el Administrador
    await pool.query(`
      INSERT INTO users (email, password_hash, full_name, role)
      VALUES ('admin@urbanos.com', 'Admin123', 'Administrador Principal', 'admin');
    `);
    console.log('✅ Usuario Admin restaurado (admin@urbanos.com / Admin123)');

    // 5. Asegurar las otras tablas
    await pool.query(`
      CREATE TABLE IF NOT EXISTS buses (
        id SERIAL PRIMARY KEY,
        status TEXT DEFAULT 'ACTIVO',
        last_latitude DOUBLE PRECISION,
        last_longitude DOUBLE PRECISION,
        last_updated TIMESTAMP DEFAULT NOW()
      );
      CREATE TABLE IF NOT EXISTS tickets (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id INTEGER REFERENCES users(id),
        status TEXT DEFAULT 'DISPONIBLE',
        purchase_date TIMESTAMP DEFAULT NOW(),
        used_at TIMESTAMP,
        bus_id_used INTEGER
      );
      CREATE TABLE IF NOT EXISTS transactions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        amount DECIMAL(10,2),
        payment_method TEXT,
        date TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('🚀 ¡REPARACIÓN COMPLETADA! Ya puedes entrar.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
};

fixDatabase();
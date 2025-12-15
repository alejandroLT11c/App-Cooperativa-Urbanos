const { Pool } = require('pg');

// Tu enlace de la nube (Render)
const connectionString = 'postgresql://urbanos_db_user:Xood4W2p6n8FxD8paL1JTmQ3nQK4CEEe@dpg-d500ivre5dus73aor62g-a.virginia-postgres.render.com/urbanos_db';

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false } // Requisito obligatorio para Render
});

const createTables = async () => {
  try {
    console.log('⏳ Conectando a la nube en Virginia...');
    
    // 1. Crear Tabla de Usuarios
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT DEFAULT 'driver'
      );
    `);
    console.log('✅ Tabla Users creada.');

    // 2. Crear Tabla de Buses
    await pool.query(`
      CREATE TABLE IF NOT EXISTS buses (
        id SERIAL PRIMARY KEY,
        placa TEXT UNIQUE NOT NULL,
        lat DOUBLE PRECISION,
        lng DOUBLE PRECISION,
        active BOOLEAN DEFAULT false,
        last_updated TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✅ Tabla Buses creada.');

    // 3. Crear tu Usuario Admin (Para que puedas entrar)
    // Cambia 'admin' y '123456' si quieres otra contraseña
    await pool.query(`
      INSERT INTO users (email, password, role)
      VALUES ('admin@urbanos.com', 'Admin123', 'admin')
      ON CONFLICT (email) DO NOTHING;
    `);
    console.log('✅ Usuario Admin creado (admin@urbanos.com / Admin123)');

    console.log('🚀 ¡LISTO! La base de datos en la nube ya tiene estructura.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
};

createTables();
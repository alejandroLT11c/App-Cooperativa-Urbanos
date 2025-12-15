const express = require('express');
const pool = require('./db'); // ✅ Esta es la única conexión que necesitamos
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// --- RUTA 1: REGISTRO INTELIGENTE (LOGIN O REGISTRO) ---
app.post('/register', async (req, res) => {
  try {
    const { email, password, full_name, role } = req.body;

    // 1. Intentamos CREAR el usuario
    const newUser = await pool.query(
      "INSERT INTO users (email, password_hash, full_name, role) VALUES ($1, $2, $3, $4) RETURNING *",
      [email, password, full_name, role || 'CLIENTE']
    );
    
    // Si funciona, respondemos éxito
    res.json({ message: '¡Usuario creado con éxito!', user: newUser.rows[0] });

  } catch (error) {
    // 2. Si falla porque YA EXISTE (Código de error PostgreSQL '23505'), entonces lo buscamos
    if (error.code === '23505') {
      try {
        const existingUser = await pool.query("SELECT * FROM users WHERE email = $1", [req.body.email]);
        
        return res.json({ 
          message: '¡Bienvenido de nuevo! (Sesión Iniciada)', 
          user: existingUser.rows[0] 
        });
      } catch (e) {
        return res.status(500).json({ error: 'Error al iniciar sesión' });
      }
    }

    console.error(error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// --- RUTA 2: CREAR BUS ---
app.post('/buses', async (req, res) => {
  try {
    const { id, status, lat, lng } = req.body;
    const newBus = await pool.query(
      "INSERT INTO buses (id, status, last_latitude, last_longitude, last_updated) VALUES ($1, $2, $3, $4, NOW()) RETURNING *",
      [id, status || 'ACTIVO', lat || 4.813, lng || -75.694]
    );
    res.json({ message: '¡Bus registrado!', bus: newBus.rows[0] });
  } catch (error) { console.error(error); res.status(500).json({ error: 'Error al crear bus' }); }
});

// --- RUTA 3: MOVER BUS (GPS) - VERSIÓN MEJORADA (AUTO-CREACIÓN) ---
app.put('/buses/:id/location', async (req, res) => {
  try {
    const { id } = req.params;
    const { lat, lng } = req.body;

    // 1. Intentamos ACTUALIZAR la ubicación del bus
    const updatedBus = await pool.query(
      "UPDATE buses SET last_latitude = $1, last_longitude = $2, last_updated = NOW() WHERE id = $3 RETURNING *",
      [lat, lng, id]
    );

    // 2. Si el bus YA EXISTÍA, respondemos normal
    if (updatedBus.rows.length > 0) {
      return res.json({ message: '📍 Ubicación actualizada', bus: updatedBus.rows[0] });
    }

    // 3. Si NO EXISTÍA (fue borrado o es nuevo), lo CREAMOS automáticamente
    const newBus = await pool.query(
      "INSERT INTO buses (id, status, last_latitude, last_longitude, last_updated) VALUES ($1, 'ACTIVO', $2, $3, NOW()) RETURNING *",
      [id, lat, lng]
    );

    res.json({ message: '🆕 ¡Bus nuevo creado y ubicado!', bus: newBus.rows[0] });

  } catch (error) { console.error(error); res.status(500).json({ error: 'Error GPS' }); }
});

// ==========================================
// NUEVAS RUTAS DE PAGO Y PASAJES (BILLETERA)
// ==========================================

// --- RUTA 4: RECARGAR SALDO (Simular Nequi) ---
app.post('/wallet/recharge', async (req, res) => {
  try {
    const { user_id, amount } = req.body;
    // 1. Actualizar saldo del usuario
    const updatedUser = await pool.query(
      "UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2 RETURNING wallet_balance",
      [amount, user_id]
    );
    // 2. Guardar registro de la transacción
    await pool.query(
      "INSERT INTO transactions (user_id, amount, payment_method) VALUES ($1, $2, 'NEQUI')",
      [user_id, amount]
    );
    res.json({ message: '¡Recarga exitosa!', nuevo_saldo: updatedUser.rows[0].wallet_balance });
  } catch (error) { console.error(error); res.status(500).json({ error: 'Error en recarga' }); }
});

// --- RUTA 5: COMPRAR PASAJE (Generar QR) ---
app.post('/tickets/buy', async (req, res) => {
  try {
    const { user_id } = req.body;
    const PRECIO_PASAJE = 2800; // Precio ejemplo Urbanos Pereira

    // 1. Verificar si tiene saldo suficiente
    const userCheck = await pool.query("SELECT wallet_balance FROM users WHERE id = $1", [user_id]);
    if (userCheck.rows[0].wallet_balance < PRECIO_PASAJE) {
      return res.status(400).json({ error: '🚫 Saldo insuficiente. Recarga tu billetera.' });
    }

    // 2. Descontar dinero
    await pool.query("UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2", [PRECIO_PASAJE, user_id]);

    // 3. Crear el Ticket (QR)
    const newTicket = await pool.query(
      "INSERT INTO tickets (user_id, status) VALUES ($1, 'DISPONIBLE') RETURNING id, purchase_date",
      [user_id]
    );

    res.json({ 
      message: '¡Pasaje comprado!', 
      qr_code: newTicket.rows[0].id, // <--- ESTE ES EL CÓDIGO QUE MOSTRARÁ EL CELULAR
      saldo_restante: userCheck.rows[0].wallet_balance - PRECIO_PASAJE
    });

  } catch (error) { console.error(error); res.status(500).json({ error: 'Error comprando pasaje' }); }
});

// --- RUTA 6: VALIDAR PASAJE (Tablet del Conductor) ---
app.post('/tickets/validate', async (req, res) => {
  try {
    const { qr_code, bus_id } = req.body;

    // 1. Buscar si el ticket existe y está DISPONIBLE
    const ticket = await pool.query("SELECT * FROM tickets WHERE id = $1", [qr_code]);

    if (ticket.rows.length === 0) {
      return res.status(404).json({ status: 'ERROR', message: 'Ticket no existe (Falso)' });
    }
    if (ticket.rows[0].status === 'USADO') {
      return res.status(400).json({ status: 'ERROR', message: '⚠️ ¡Ticket YA FUE USADO!' });
    }

    // 2. Marcarlo como usado
    await pool.query(
      "UPDATE tickets SET status = 'USADO', used_at = NOW(), bus_id_used = $1 WHERE id = $2",
      [bus_id, qr_code]
    );

    res.json({ status: 'OK', message: '✅ ¡Bienvenido a bordo! (Pasaje Válido)' });

  } catch (error) { console.error(error); res.status(500).json({ error: 'Error validando' }); }
});

// --- RUTA 7: OBTENER TODOS LOS BUSES (Para pintar en el mapa) ---
app.get('/buses', async (req, res) => {
  try {
    // Solo pedimos los que estén ACTIVOS (Ignoramos los dañados)
    const allBuses = await pool.query("SELECT * FROM buses WHERE status = 'ACTIVO'");
    res.json(allBuses.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error al pedir buses' });
  }
});

// INICIAR
const PORT = process.env.PORT || 3000; // <--- Importante: Usar el puerto que nos dé la Nube
app.listen(PORT, () => { console.log(`🚀 Sistema Urbanos Completo corriendo en puerto ${PORT}`); });
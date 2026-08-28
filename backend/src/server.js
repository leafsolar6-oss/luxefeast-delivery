require('dotenv').config();
// Patches Express 4 to forward async route rejections to the error handler
// below — without this, ANY unhandled async error (e.g. a bad order id like
// /api/orders/null) crashes the whole process and drops every socket.
require('express-async-errors');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { migrateAndSeed } = require('./db/bootstrap');
const realtime = require('./realtime/events');
const push = require('./services/push');

const app = express();
const server = http.createServer(app);

app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL || '*', credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/shops', require('./routes/shops'));
app.use('/api/riders', require('./routes/riders'));

app.get('/api/health', (_req, res) =>
  res.json({
    status: 'healthy',
    version: '2.0.0',
    service: 'Nature Fete',
    database: 'postgres (Neon)',
    push: push.ready() ? 'firebase' : 'disabled',
  })
);

// JSON error handler — async rejections land here instead of killing the process.
app.use((err, _req, res, _next) => {
  console.error('Route error:', err.message);
  const status = err.code === '22P02' || err.code === '23503' ? 400 : 500; // bad input / FK violation
  res.status(status).json({ message: status === 400 ? 'Invalid request data' : 'Internal server error' });
});

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  // Allow Socket.IO v2 protocol clients (Flutter socket_io_client 2.0.3+1
  // used by the released APKs) to connect. Without this the apps' sockets
  // silently fail and no real-time events (order:placed, delivery:offer,
  // rider:location, …) are ever delivered.
  allowEIO3: true,
});
realtime.init(io);

const PORT = process.env.PORT || 5000;

migrateAndSeed()
  .then(() => {
    server.listen(PORT, '0.0.0.0', () => console.log(`LuxFeast Server v2 (Postgres) running on port ${PORT}`));
  })
  .catch((err) => {
    console.error('Failed to initialize database:', err.message);
    process.exit(1);
  });

module.exports = { app, server, io };

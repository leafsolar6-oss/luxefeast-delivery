require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { migrateAndSeed } = require('./db/bootstrap');
const realtime = require('./realtime/events');

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
  res.json({ status: 'healthy', version: '2.0.0', service: 'LuxFeast', database: 'postgres (Neon-ready)' })
);

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
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

require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const connectDB = require('./config/db');
const seedData = require('./utils/seed');

connectDB();

const app = express();
const server = http.createServer(app);

// Middleware
app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL || '*', credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/shops', require('./routes/shops'));
app.use('/api/riders', require('./routes/riders'));

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'healthy', version: '1.0.0', service: 'LuxFeast' }));

// Socket.IO Setup
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
});

// Real-time order tracking
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('join-order', (orderId) => {
    socket.join(`order-${orderId}`);
    console.log(`Client joined order room: order-${orderId}`);
  });

  socket.on('update-order-status', ({ orderId, status, riderId }) => {
    io.to(`order-${orderId}`).emit('order-status-updated', { orderId, status, riderId, timestamp: new Date() });
    console.log(`Order ${orderId} updated to ${status}`);
  });

  socket.on('rider-assigned', ({ orderId, rider }) => {
    io.to(`order-${orderId}`).emit('rider-assigned', { orderId, rider });
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`LuxFeast Server running on port ${PORT}`);
  seedData();
});

module.exports = { app, server, io };

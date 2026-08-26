const mongoose = require('mongoose');

const riderSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: String,
  vehicleType: { type: String, enum: ['Bicycle', 'Motorcycle', 'Car'], default: 'Motorcycle' },
  isActive: { type: Boolean, default: true },
  currentLocation: {
    latitude: Number,
    longitude: Number,
  },
  rating: { type: Number, default: 5.0, min: 0, max: 5 },
  totalDeliveries: { type: Number, default: 0 },
  totalEarnings: { type: Number, default: 0 },
  paymentHistory: [{
    date: Date,
    amount: Number,
    orderId: mongoose.Schema.Types.ObjectId,
    status: String,
  }],
  createdAt: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.model('Rider', riderSchema);

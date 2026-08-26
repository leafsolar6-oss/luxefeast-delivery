const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  shopId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
  riderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Rider' },
  items: [{
    name: String,
    quantity: Number,
    price: Number,
  }],
  totalAmount: { type: Number, required: true },
  deliveryFee: { type: Number, default: 2.5 },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'in_transit', 'delivered', 'cancelled'],
    default: 'pending',
  },
  paymentStatus: { type: String, enum: ['pending', 'paid', 'refunded'], default: 'pending' },
  deliveryAddress: String,
  estimatedTime: Date,
  tracking: [{ status: String, timestamp: Date, note: String }],
  createdAt: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.model('Order', orderSchema);

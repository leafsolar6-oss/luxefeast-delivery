const mongoose = require('mongoose');

const shopSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: String,
  address: { type: String, required: true },
  cuisine: [String],
  logo: String,
  rating: { type: Number, default: 0, min: 0, max: 5 },
  isActive: { type: Boolean, default: true },
  menu: [{
    name: String,
    price: Number,
    category: String,
    image: String,
  }],
  createdAt: { type: Date, default: Date.now },
}, { timestamps: true });

module.exports = mongoose.model('Shop', shopSchema);

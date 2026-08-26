const User = require('../models/User');
const Order = require('../models/Order');
const Shop = require('../models/Shop');
const Rider = require('../models/Rider');

// Seed initial data for demo
const seedData = async () => {
  try {
    await User.deleteMany();
    await Order.deleteMany();
    await Shop.deleteMany();
    await Rider.deleteMany();

    // Create demo shop
    const shop = await Shop.create({
      name: 'Mama Nkem Amala Palace',
      email: 'shop@goldencrust.com',
      phone: '+2348012345678',
      address: 'Plot 17, Lekki Phase 1, Lagos, Nigeria',
      cuisine: ['Nigerian', 'Continental', 'Swallow & Soup'],
      rating: 4.8,
      isActive: true,
    });

    // Create demo customer
    const customer = await User.create({
      name: 'Amara Okonkwo',
      email: 'customer@luxefeast.com',
      phone: '+2348011112222',
      address: 'Lekki Phase 1, Lagos',
      role: 'customer',
      password: 'demo123',
    });

    // Create demo rider
    const rider = await Rider.create({
      name: 'Daniel Okoro',
      email: 'rider@luxefeast.com',
      phone: '+2348033334444',
      vehicleType: 'Motorcycle',
      isActive: true,
      currentLocation: { latitude: 6.5244, longitude: 3.3792 },
    });

    console.log('Demo data seeded successfully');
  } catch (err) {
    console.error('Seed error:', err);
  }
};

module.exports = seedData;

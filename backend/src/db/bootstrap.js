const fs = require('fs');
const path = require('path');
const { query } = require('../config/db');

async function migrateAndSeed() {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await query(schema);

  const { rows } = await query(`SELECT COUNT(*)::int AS n FROM shops`);
  if (rows[0].n > 0) {
    console.log('Database already seeded');
    return;
  }

  await query(
    `INSERT INTO shops (name, email, phone, address, city, cuisines, rating, avg_prep_minutes) VALUES
     ('Mama Nkem Amala Palace', 'orders@mamankem.ng',   '+2348012345678', 'Plot 17, Lekki Phase 1, Lagos', 'Lagos', '{Amala,"Ewedu & Gbegiri","Swallow & Soup"}', 4.8, 25),
     ('Jollof Republic Lagos',  'hello@jollofrepublic.ng','+2348023456789','12 Admiralty Way, Lekki, Lagos','Lagos', '{"Jollof Rice","Fried Rice","Nigerian Street Food"}', 4.7, 18),
     ('Suya Palace Abuja',      'crew@suyapalace.ng',    '+2348034567890', '3 Aminu Kano Crescent, Wuse 2, Abuja', 'Abuja', '{Suya,Grills,"Pepper Soup"}', 4.9, 15)`
  );

  await query(
    `INSERT INTO users (name, email, phone, address, role) VALUES
     ('Amara Okonkwo', 'customer@luxefeast.com', '+2348011112222', 'Lekki Phase 1, Lagos', 'customer')`
  );

  await query(
    `INSERT INTO riders (name, email, phone, vehicle_type, status, lat, lng) VALUES
     ('Daniel Okoro', 'rider@luxefeast.com',  '+2348033334444', 'Motorcycle', 'available', 6.5244, 3.3792),
     ('Chika Eze',    'chika@luxefeast.com',  '+2348055556666', 'Motorcycle', 'available', 6.4550, 3.4737)`
  );

  console.log('Demo data seeded (3 shops, 1 customer, 2 riders)');
}

module.exports = { migrateAndSeed };

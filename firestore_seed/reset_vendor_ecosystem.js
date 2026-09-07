'use strict';

const fs = require('fs');
const https = require('https');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  FieldValue,
  GeoPoint,
  Timestamp,
} = require('firebase-admin/firestore');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Missing firestore_seed/serviceAccountKey.json');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const auth = getAuth();
const CONFIRM_TOKEN = 'RESET_VENDOR_ECOSYSTEM';
const confirmed = process.argv.includes('--confirm') &&
  process.argv.includes(CONFIRM_TOKEN);
const geoapifyKey = String(process.env.GEOAPIFY_API_KEY || '').trim();
const defaultPassword = String(
  process.env.SEED_VENDOR_PASSWORD || 'Vendor123!',
);

const reviewerNames = [
  'Aina Rahman', 'Daniel Lim', 'Nur Izzati', 'Marcus Lee', 'Siti Hajar',
  'Wei Jian', 'Farah Nadia', 'Harith Iskandar', 'Mei Ling', 'Jason Tan',
  'Amirah Yusuf', 'Bryan Wong', 'Priya Nair', 'Adam Chong', 'Hui Min',
  'Kavitha Raj', 'Muhammad Aqil', 'Chloe Ng', 'Raymond Goh', 'Nadia Azman',
];

const realVendorTypes = {
  heritage: {
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture', 'Local Business'],
    highlight: 'real heritage interpretation, preserved architecture and visitor-friendly cultural storytelling',
    task: 'Photograph one heritage detail and write one fact learned at this real Penang place.',
    photoTarget: 'heritage_feature',
    voucher: 'Heritage Visit Reward',
  },
  culture: {
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Local Business'],
    highlight: 'real cultural displays, local stories and respectful visitor learning',
    task: 'Photograph a cultural object or exhibit and describe its meaning respectfully.',
    photoTarget: 'cultural_object',
    voucher: 'Cultural Experience Reward',
  },
  nature: {
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    highlight: 'real nature education, conservation learning and guided outdoor visitor experiences',
    task: 'Photograph one plant, landscape or conservation feature and explain why it should be protected.',
    photoTarget: 'nature_feature',
    voucher: 'Eco Experience Discount',
  },
  food: {
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    highlight: 'real Penang food, established local service and map-searchable dining locations',
    task: 'Photograph one local Penang dish and describe the cultural ingredient or preparation method.',
    photoTarget: 'local_food',
    voucher: 'RM10 Dining Discount',
  },
  cafe: {
    category: 'Cafe',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    highlight: 'real cafe service, heritage setting and locally inspired drinks or desserts',
    task: 'Photograph a locally inspired drink or dessert and identify its Penang connection.',
    photoTarget: 'local_drink',
    voucher: 'Free Local Drink Upgrade',
  },
  craft: {
    category: 'Craft',
    plannerCategories: ['Culture', 'Art', 'Local Business'],
    highlight: 'real handmade products, local materials and a clear making or retail experience',
    task: 'Photograph a handmade item and explain the local craft technique used to create it.',
    photoTarget: 'local_craft',
    voucher: '15% Craft Purchase Discount',
  },
  art: {
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    highlight: 'real art displays, public artworks and visitor-friendly creative culture',
    task: 'Photograph one artwork, mural or exhibition detail and describe the local story behind it.',
    photoTarget: 'local_art',
    voucher: 'Art Visit Reward',
  },
  retail: {
    category: 'Retail',
    plannerCategories: ['Local Business', 'Food'],
    highlight: 'real locally produced goods, transparent pricing and helpful product explanations',
    task: 'Photograph a locally made product and identify where or how it was produced.',
    photoTarget: 'local_product',
    voucher: 'RM8 Local Product Discount',
  },
};

const realVendorPlaces = [
  {
    businessName: 'Pinang Peranakan Mansion',
    type: 'heritage',
    areaName: 'George Town',
    address: '29 Church Street, 10200 George Town, Penang, Malaysia',
    lat: 5.41758,
    lng: 100.34262,
    phone: '+604-264 2929',
    website: 'https://www.pinangperanakanmansion.com.my/',
    businessHours: 'Mon-Sun 09:30-17:30',
    budget: 'Medium',
    tags: ['peranakan', 'museum', 'heritage', 'mansion'],
  },
  {
    businessName: 'Cheong Fatt Tze - The Blue Mansion',
    type: 'heritage',
    areaName: 'George Town',
    address: '14 Leith Street, 10200 George Town, Penang, Malaysia',
    lat: 5.42157,
    lng: 100.33407,
    phone: '+604-262 0006',
    website: 'https://www.cheongfatttzemansion.com/',
    businessHours: 'Mon-Sun 11:00-18:00',
    budget: 'High',
    tags: ['blue mansion', 'heritage', 'architecture', 'museum'],
  },
  {
    businessName: 'Leong San Tong Khoo Kongsi',
    type: 'heritage',
    areaName: 'George Town',
    address: '18 Cannon Square, 10200 George Town, Penang, Malaysia',
    lat: 5.4165,
    lng: 100.3373,
    phone: '+604-261 4609',
    website: 'https://www.khookongsi.com.my/',
    businessHours: 'Mon-Sun 09:00-17:00',
    budget: 'Medium',
    tags: ['clan house', 'temple', 'heritage', 'museum'],
  },
  {
    businessName: 'Wonderfood Museum Penang',
    type: 'culture',
    areaName: 'George Town',
    address: '49 Lebuh Pantai, 10200 George Town, Penang, Malaysia',
    lat: 5.4172,
    lng: 100.3419,
    phone: '+604-251 9095',
    website: 'https://www.facebook.com/Wonderfoodmuseum',
    businessHours: 'Mon-Sun 09:00-18:00',
    budget: 'Medium',
    tags: ['food museum', 'culture', 'family', 'photo spot'],
  },
  {
    businessName: 'Fort Cornwallis',
    type: 'heritage',
    areaName: 'George Town',
    address: 'Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang, Malaysia',
    lat: 5.4206,
    lng: 100.3439,
    phone: '+604-263 9855',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 09:00-22:00',
    budget: 'Low',
    tags: ['fort', 'history', 'heritage', 'colonial'],
  },
  {
    businessName: 'Chew Jetty',
    type: 'heritage',
    areaName: 'George Town',
    address: 'Pengkalan Weld, 10300 George Town, Penang, Malaysia',
    lat: 5.4138,
    lng: 100.3406,
    phone: '',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 09:00-21:00',
    budget: 'Low',
    tags: ['clan jetty', 'waterfront', 'heritage', 'village'],
  },
  {
    businessName: 'Kek Lok Si Temple',
    type: 'heritage',
    areaName: 'Air Itam',
    address: 'Kek Lok Si Temple, 11500 Air Itam, Penang, Malaysia',
    lat: 5.3999,
    lng: 100.2732,
    phone: '+604-828 3317',
    website: 'https://kekloksitemple.com/',
    businessHours: 'Mon-Sun 08:30-17:30',
    budget: 'Low',
    tags: ['temple', 'buddhist', 'heritage', 'air itam'],
  },
  {
    businessName: 'The Habitat Penang Hill',
    type: 'nature',
    areaName: 'Air Itam',
    address: 'Penang Hill, Jalan Stesen Bukit Bendera, Air Itam, 11300 Penang, Malaysia',
    lat: 5.424,
    lng: 100.2698,
    phone: '+6019-645 7741',
    website: 'https://www.thehabitat.my/',
    businessHours: 'Mon-Sun 09:00-17:30',
    budget: 'High',
    tags: ['rainforest', 'canopy walk', 'nature', 'penang hill'],
  },
  {
    businessName: 'Entopia by Penang Butterfly Farm',
    type: 'nature',
    areaName: 'Teluk Bahang',
    address: '830 Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    lat: 5.4477,
    lng: 100.215,
    phone: '+604-888 8111',
    website: 'https://www.entopia.com/',
    businessHours: 'Mon-Sun 09:00-18:00',
    budget: 'High',
    tags: ['butterfly', 'nature', 'family', 'teluk bahang'],
  },
  {
    businessName: 'Tropical Spice Garden',
    type: 'nature',
    areaName: 'Teluk Bahang',
    address: 'Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    lat: 5.4637,
    lng: 100.2387,
    phone: '+604-881 3799',
    website: 'https://tropicalspicegarden.com/',
    businessHours: 'Mon-Thu 09:00-16:30; Fri-Sun 09:00-18:00',
    budget: 'Medium',
    tags: ['spice garden', 'nature', 'plants', 'cafe'],
  },
  {
    businessName: 'Tropical Fruit Farm',
    type: 'nature',
    areaName: 'Teluk Bahang',
    address: '18th Mile Stone, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    lat: 5.415081,
    lng: 100.216906,
    phone: '+6012-497 1931',
    website: 'https://tropicalfruitfarm.com.my/',
    businessHours: 'Mon-Sun 09:00-17:00',
    budget: 'Medium',
    tags: ['fruit farm', 'nature', 'local product', 'tour'],
  },
  {
    businessName: 'ESCAPE Penang',
    type: 'nature',
    areaName: 'Teluk Bahang',
    address: '828 Jalan Teluk Bahang, 11050 Penang, Malaysia',
    lat: 5.4494,
    lng: 100.2146,
    phone: '+6017-797 7529',
    website: 'https://www.escape.my/park/pg',
    businessHours: 'Tue-Sun 10:00-18:00',
    budget: 'High',
    tags: ['outdoor', 'theme park', 'water park', 'adventure'],
  },
  {
    businessName: 'Penang Batik Factory',
    type: 'craft',
    areaName: 'Teluk Bahang',
    address: '669 Mk. 2, Teluk Bahang, 11050 Penang, Malaysia',
    lat: 5.4525,
    lng: 100.2157,
    phone: '+604-885 1284',
    website: 'https://www.penangbatik.com.my/',
    businessHours: 'Mon-Sun 09:00-17:30',
    budget: 'Medium',
    tags: ['batik', 'craft', 'showroom', 'handmade'],
  },
  {
    businessName: 'Craft Batik',
    type: 'craft',
    areaName: 'Teluk Bahang',
    address: '651 Mk. 2, Teluk Bahang, 11050 Penang, Malaysia',
    lat: 5.4522,
    lng: 100.2149,
    phone: '+6019-423 1953',
    website: 'https://craftbatik.com.my/',
    businessHours: 'Mon-Sun 08:30-17:00',
    budget: 'Medium',
    tags: ['batik', 'craft', 'handmade', 'textile'],
  },
  {
    businessName: 'Hin Bus Depot',
    type: 'art',
    areaName: 'George Town',
    address: '31A Jalan Gurdwara, 10300 George Town, Penang, Malaysia',
    lat: 5.4116,
    lng: 100.3262,
    phone: '',
    website: 'https://hinbusdepot.com/',
    businessHours: 'Mon-Sun 10:00-22:00',
    budget: 'Low',
    tags: ['art', 'market', 'workshop', 'community'],
  },
  {
    businessName: 'Jawi House Cafe Gallery',
    type: 'food',
    areaName: 'George Town',
    address: '85 Lebuh Armenian, 10200 George Town, Penang, Malaysia',
    lat: 5.4163,
    lng: 100.3377,
    phone: '+604-261 3680',
    website: 'https://www.jawihouse.com/',
    businessHours: 'Sun-Mon 11:00-21:30; Wed-Sat 11:00-21:30',
    budget: 'Medium',
    tags: ['jawi peranakan', 'cafe', 'gallery', 'food'],
  },
  {
    businessName: 'ChinaHouse Penang',
    type: 'cafe',
    areaName: 'George Town',
    address: '153 & 155 Beach Street, 10300 George Town, Penang, Malaysia',
    lat: 5.4149,
    lng: 100.3409,
    phone: '+604-263 7299',
    website: 'https://chinahouse.com.my/',
    businessHours: 'Sun-Thu 09:00-24:00; Fri-Sat 09:00-01:00',
    budget: 'Medium',
    tags: ['cafe', 'gallery', 'bakery', 'heritage building'],
  },
  {
    businessName: 'Tek Sen Restaurant',
    type: 'food',
    areaName: 'George Town',
    address: '18 & 20 Carnarvon Street, 10100 George Town, Penang, Malaysia',
    lat: 5.4153,
    lng: 100.335,
    phone: '+6012-981 5117',
    website: 'https://ericatengkz.wixsite.com/tek-sen',
    businessHours: 'Mon 12:00-15:00 18:00-21:00; Wed-Sun 12:00-15:00 18:00-21:00',
    budget: 'Medium',
    tags: ['restaurant', 'local food', 'george town', 'heritage shophouse'],
  },
  {
    businessName: 'Hameediyah Restaurant',
    type: 'food',
    areaName: 'George Town',
    address: '164A Lebuh Campbell, 10020 George Town, Penang, Malaysia',
    lat: 5.4188,
    lng: 100.3338,
    phone: '+604-261 1095',
    website: 'https://www.facebook.com/OLDESTNASIKANDARINMALAYSIA',
    businessHours: 'Mon-Sun 10:00-22:00',
    budget: 'Low',
    tags: ['nasi kandar', 'murtabak', 'heritage food', 'restaurant'],
  },
  {
    businessName: 'Penang Road Famous Teochew Chendul',
    type: 'food',
    areaName: 'George Town',
    address: '27 & 29 Lebuh Keng Kwee, 10100 George Town, Penang, Malaysia',
    lat: 5.4183,
    lng: 100.331,
    phone: '+604-262 6002',
    website: 'https://chendul.my/',
    businessHours: 'Mon-Sun 09:00-18:30',
    budget: 'Low',
    tags: ['dessert', 'chendul', 'street food', 'local food'],
  },
  {
    businessName: 'Ghee Hiang Macalister Road',
    type: 'retail',
    areaName: 'George Town',
    address: '216 Jalan Macalister, 10400 George Town, Penang, Malaysia',
    lat: 5.4178,
    lng: 100.3196,
    phone: '+604-227 2222',
    website: 'https://ghee-hiang.com/',
    businessHours: 'Sun-Thu 09:00-19:00; Fri-Sat 09:00-21:00',
    budget: 'Medium',
    tags: ['tau sar piah', 'sesame oil', 'local product', 'souvenir'],
  },
  {
    businessName: 'Chowrasta Market',
    type: 'retail',
    areaName: 'George Town',
    address: 'Jalan Penang, 10000 George Town, Penang, Malaysia',
    lat: 5.4201,
    lng: 100.3314,
    phone: '',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 06:30-18:00',
    budget: 'Low',
    tags: ['market', 'local product', 'food', 'souvenir'],
  },
  {
    businessName: 'Penang Street Art (Armenian Street Murals)',
    type: 'art',
    areaName: 'George Town',
    address: 'Armenian Street, 10200 George Town, Penang, Malaysia',
    lat: 5.4148,
    lng: 100.3368,
    phone: '',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 24 Hours',
    budget: 'Low',
    tags: ['street art', 'murals', 'ernest zacharevic', 'heritage'],
  },
  {
    businessName: 'Penang State Museum & Art Gallery',
    type: 'art',
    areaName: 'George Town',
    address: '57 Jalan Macalister, 10400 George Town, Penang, Malaysia',
    lat: 5.4162,
    lng: 100.3268,
    phone: '+604-226 1462',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Sat-Thu 09:00-17:00',
    budget: 'Low',
    tags: ['museum', 'art gallery', 'history', 'george town'],
  },
  {
    businessName: 'Pekan Bukit Mertajam Old Market Street',
    type: 'food',
    areaName: 'Bukit Mertajam',
    address: 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    lat: 5.3635,
    lng: 100.4608,
    phone: '',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 06:00-14:00',
    budget: 'Low',
    tags: ['market', 'street food', 'heritage street', 'bukit mertajam', 'bm'],
  },
  {
    businessName: 'Butterworth Art Walk',
    type: 'art',
    areaName: 'Butterworth',
    address: '1 Lorong Bagan Luar 1, 12000 Butterworth, Penang, Malaysia',
    lat: 5.3995,
    lng: 100.3645,
    phone: '',
    website: 'https://mypenang.gov.my/',
    businessHours: 'Mon-Sun 24 Hours',
    budget: 'Low',
    tags: ['murals', 'street art', 'butterworth', 'heritage'],
  },
];

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function staticMapUrl(lat, lng) {
  if (!geoapifyKey) return '';
  const params = new URLSearchParams({
    style: 'osm-bright',
    width: '640',
    height: '420',
    center: `lonlat:${lng},${lat}`,
    zoom: '16',
    scaleFactor: '1',
    format: 'jpeg',
    apiKey: geoapifyKey,
  });
  return `https://maps.geoapify.com/v1/staticmap?${params.toString()}`;
}

function googleMapSearchUrl(businessName, address, lat, lng) {
  const query = [businessName, address].filter(Boolean).join(', ') ||
    `${lat},${lng}`;
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`;
}

function openStreetMapUrl(lat, lng) {
  return `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=18/${lat}/${lng}`;
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(
      url,
      {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'MyHeritageExplorer/1.0 real vendor map seed',
        },
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => { body += chunk; });
        response.on('end', () => {
          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(new Error(`HTTP ${response.statusCode} for ${url}`));
            return;
          }
          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(error);
          }
        });
      },
    );
    request.setTimeout(12000, () => {
      request.destroy(new Error('Geoapify lookup timed out'));
    });
    request.on('error', reject);
  });
}

async function resolveRealVendorPlace(place) {
  if (!geoapifyKey) {
    return {
      lat: place.lat,
      lng: place.lng,
      address: place.address,
      mapProvider: 'fallback_manual',
      mapMatchedName: place.businessName,
      mapPlaceId: '',
    };
  }

  const params = new URLSearchParams({
    text: `${place.businessName}, ${place.address}`,
    filter: 'countrycode:my',
    limit: '5',
    format: 'json',
    apiKey: geoapifyKey,
  });
  const url = `https://api.geoapify.com/v1/geocode/search?${params.toString()}`;

  try {
    const decoded = await fetchJson(url);
    const results = Array.isArray(decoded.results) ? decoded.results : [];
    const selected = results.find((item) => {
      const text = [
        item.formatted,
        item.name,
        item.city,
        item.county,
        item.state,
      ].join(' ').toLowerCase();
      return text.includes('penang') || text.includes('pulau pinang');
    }) || results[0];

    if (!selected || typeof selected.lat !== 'number' ||
        typeof selected.lon !== 'number') {
      throw new Error('No usable Geoapify result');
    }

    return {
      lat: Number(selected.lat.toFixed(6)),
      lng: Number(selected.lon.toFixed(6)),
      address: selected.formatted || place.address,
      mapProvider: 'geoapify',
      mapMatchedName: selected.name || place.businessName,
      mapPlaceId: selected.place_id || '',
    };
  } catch (error) {
    console.warn(`Map lookup fallback used for ${place.businessName}: ${error.message}`);
    return {
      lat: place.lat,
      lng: place.lng,
      address: place.address,
      mapProvider: 'fallback_manual',
      mapMatchedName: place.businessName,
      mapPlaceId: '',
    };
  }
}

function serialize(value) {
  if (value == null) return value;
  if (value instanceof Timestamp) {
    return { __type: 'Timestamp', value: value.toDate().toISOString() };
  }
  if (value instanceof GeoPoint) {
    return { __type: 'GeoPoint', latitude: value.latitude, longitude: value.longitude };
  }
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === 'object') {
    const result = {};
    for (const [key, item] of Object.entries(value)) {
      result[key] = serialize(item);
    }
    return result;
  }
  return value;
}

async function backupAndDeleteSeededVendorUsers() {
  const snapshot = await db.collection('users')
    .where('role', '==', 'vendor')
    .get();
  const seededVendorDocs = snapshot.docs.filter((doc) => {
    const data = doc.data();
    return data.seededForTesting === true ||
      String(data.source || '').includes('vendor_seed') ||
      String(data.email || '').endsWith('@myheritage.test');
  });

  if (seededVendorDocs.length === 0) return 0;

  const backup = seededVendorDocs.map((doc) => ({
    id: doc.id,
    data: serialize(doc.data()),
  }));
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(
    __dirname,
    `backup_seeded_vendor_users_${timestamp}.json`,
  );
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log(`Seeded vendor user-profile backup written to ${backupPath}`);

  for (let start = 0; start < seededVendorDocs.length; start += 250) {
    const batch = db.batch();
    for (const doc of seededVendorDocs.slice(start, start + 250)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  return seededVendorDocs.length;
}

async function backupAndDeleteSeededVendorEcosystemDocs() {
  const targets = [
    {
      collection: 'vendors',
      matches: (data) => data.seededForTesting === true ||
        String(data.source || '').includes('vendor_seed') ||
        String(data.email || '').endsWith('@myheritage.test'),
    },
    {
      collection: 'reviews',
      matches: (data) => data.seededForTesting === true ||
        String(data.source || '') === 'vendor_seed',
    },
    {
      collection: 'cultural_tasks',
      matches: (data) => data.seededForTesting === true ||
        String(data.createdBy || '') === 'system_seed',
    },
    {
      collection: 'vouchers',
      matches: (data) => data.seededForTesting === true,
    },
  ];
  const backup = {};
  const counts = {};

  for (const target of targets) {
    const snapshot = await db.collection(target.collection).get();
    const docs = snapshot.docs.filter((doc) => target.matches(doc.data()));
    counts[target.collection] = docs.length;
    backup[target.collection] = docs.map((doc) => ({
      id: doc.id,
      data: serialize(doc.data()),
    }));

    if (docs.length === 0) continue;
    console.log(`Deleting ${docs.length} seeded docs from ${target.collection}...`);
    for (let start = 0; start < docs.length; start += 250) {
      const batch = db.batch();
      for (const doc of docs.slice(start, start + 250)) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(
    __dirname,
    `backup_seeded_vendor_ecosystem_${timestamp}.json`,
  );
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log(`Seeded vendor ecosystem backup written to ${backupPath}`);

  return counts;
}

async function ensureVendorAuth(email, displayName) {
  try {
    const existing = await auth.getUserByEmail(email);
    return auth.updateUser(existing.uid, {
      displayName,
      password: defaultPassword,
      disabled: false,
      emailVerified: true,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return auth.createUser({
      email,
      password: defaultPassword,
      displayName,
      emailVerified: true,
      disabled: false,
    });
  }
}

const reviewProfiles = [
  {
    label: 'excellent',
    reviews: [
      {
        rating: 5,
        sentiment: 'positive',
        comment: (vendor, definition) =>
          `${vendor.businessName} delivered ${definition.highlight} with warm service, clear guidance and strong local character.`,
      },
      {
        rating: 5,
        sentiment: 'positive',
        comment: (vendor, definition) =>
          `One of the best ${definition.category.toLowerCase()} stops in ${vendor.areaName}. The visit was smooth, memorable and worth recommending.`,
      },
      {
        rating: 5,
        sentiment: 'positive',
        comment: (vendor) =>
          `The staff at ${vendor.businessName} were attentive from start to finish and helped visitors understand the Penang context.`,
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'Very good overall, with only minor crowding during the busiest period.',
      },
      {
        rating: 5,
        sentiment: 'positive',
        comment: () =>
          'Everything felt well prepared, clean and visitor friendly.',
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'A reliable place to recommend, especially for travelers who want a polished local experience.',
      },
    ],
  },
  {
    label: 'good',
    reviews: [
      {
        rating: 5,
        sentiment: 'positive',
        comment: (vendor, definition) =>
          `${vendor.businessName} offered ${definition.highlight} and the team made the visit easy to enjoy.`,
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: (vendor) =>
          `The location in ${vendor.areaName} was convenient and the service was friendly.`,
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'Good value for the time spent, with clear information and a pleasant atmosphere.',
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'The experience matched the description and felt suitable for visitors.',
      },
      {
        rating: 3,
        sentiment: 'neutral',
        comment: () =>
          'A decent stop, though the pace slowed when more visitors arrived.',
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'Helpful staff and a generally smooth visit.',
      },
    ],
  },
  {
    label: 'mixed',
    reviews: [
      {
        rating: 5,
        sentiment: 'positive',
        comment: (vendor, definition) =>
          `${vendor.businessName} had a strong highlight in ${definition.highlight}, especially for first-time visitors.`,
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: () =>
          'The main experience was enjoyable and the staff were polite.',
      },
      {
        rating: 3,
        sentiment: 'neutral',
        comment: () =>
          'Some parts were useful, but the explanation could be more detailed.',
      },
      {
        rating: 2,
        sentiment: 'negative',
        comment: () =>
          'The waiting time was longer than expected and the flow felt a bit confusing.',
      },
      {
        rating: 4,
        sentiment: 'positive',
        comment: (vendor) =>
          `Still a worthwhile stop in ${vendor.areaName} if the timing is right.`,
      },
      {
        rating: 3,
        sentiment: 'neutral',
        comment: () =>
          'Average overall, with both helpful moments and a few rough edges.',
      },
    ],
  },
  {
    label: 'low',
    reviews: [
      {
        rating: 2,
        sentiment: 'negative',
        comment: (vendor) =>
          `${vendor.businessName} was hard to follow because the staff gave limited guidance and the visit felt rushed.`,
      },
      {
        rating: 1,
        sentiment: 'negative',
        comment: () =>
          'The service was disappointing, the waiting time was too long and I would not return soon.',
      },
      {
        rating: 2,
        sentiment: 'negative',
        comment: () =>
          'The place has potential, but the information provided was unclear and the experience felt poorly organised.',
      },
      {
        rating: 3,
        sentiment: 'neutral',
        comment: () =>
          'Some parts were acceptable, but the overall visit needs better coordination.',
      },
      {
        rating: 2,
        sentiment: 'negative',
        comment: () =>
          'The facilities and visitor flow did not meet expectations.',
      },
      {
        rating: 1,
        sentiment: 'negative',
        comment: () =>
          'I left frustrated because several advertised details were missing during the visit.',
      },
    ],
  },
];

function validReviewTexts(vendor, definition, vendorIndex) {
  const profile = reviewProfiles[vendorIndex % reviewProfiles.length];
  return profile.reviews.map((review) => ({
    rating: review.rating,
    sentiment: review.sentiment,
    comment: review.comment(vendor, definition),
    profile: profile.label,
  }));
}

function mismatchReviews(vendor) {
  return [
    {
      rating: 5,
      sentiment: 'negative',
      comment: `The service at ${vendor.businessName} was slow, the instructions were confusing and I left disappointed.`,
      reason: 'ML sentiment does not match the selected star rating',
      negativeProbability: 0.91,
      positiveProbability: 0.04,
    },
    {
      rating: 1,
      sentiment: 'positive',
      comment: `The staff were excellent, the experience was enjoyable and I would happily visit ${vendor.businessName} again.`,
      reason: 'ML sentiment does not match the selected star rating',
      negativeProbability: 0.03,
      positiveProbability: 0.94,
    },
  ];
}

async function seedVendorEcosystem() {
  const vendors = [];
  const credentials = [['email', 'password', 'businessName', 'uid']];
  const now = new Date();
  const expiry = Timestamp.fromDate(new Date(now.getTime() + 240 * 86400000));
  const deadline = Timestamp.fromDate(new Date(now.getTime() + 180 * 86400000));

  for (let index = 0; index < realVendorPlaces.length; index += 1) {
    const place = realVendorPlaces[index];
    const definition = realVendorTypes[place.type] || realVendorTypes.heritage;
    const businessName = place.businessName;
    const email = `vendor${String(index + 1).padStart(3, '0')}@myheritage.test`;
    const user = await ensureVendorAuth(email, businessName);
    const mapMatch = await resolveRealVendorPlace(place);
    const mapPreview = staticMapUrl(mapMatch.lat, mapMatch.lng);
    const address = mapMatch.address || place.address;
    const phone = place.phone || '';
    const budget = place.budget || ['Low', 'Medium', 'Medium', 'High'][index % 4];
    const mapUrl = googleMapSearchUrl(businessName, address, mapMatch.lat, mapMatch.lng);
    const imageCandidates = Array.isArray(place.imageCandidates)
      ? place.imageCandidates.filter((url) => String(url).startsWith('https://'))
      : [];
    const vendor = {
      uid: user.uid,
      businessName,
      areaName: place.areaName,
      category: definition.category,
      plannerCategories: definition.plannerCategories,
      lat: mapMatch.lat,
      lng: mapMatch.lng,
      address,
      phone,
      budget,
      definition,
      imageUrl: imageCandidates[0] || '',
      imageCandidates,
      businessHours: place.businessHours,
      website: place.website,
      tags: place.tags || [],
      mapUrl,
      mapPreview,
      mapProvider: mapMatch.mapProvider,
      mapMatchedName: mapMatch.mapMatchedName,
      mapPlaceId: mapMatch.mapPlaceId,
    };
    vendors.push(vendor);
    credentials.push([email, defaultPassword, businessName, user.uid]);

    await db.collection('vendors').doc(user.uid).set({
      uid: user.uid,
      email,
      displayName: businessName,
      businessName,
      ownerName: `${businessName} Manager`,
      businessCategory: definition.category,
      plannerCategories: definition.plannerCategories,
      tags: vendor.tags,
      contactNumber: phone,
      shopLocation: address,
      businessHours: place.businessHours,
      businessDescription: `${businessName} is a real map-searchable Penang vendor/place offering ${definition.highlight}.`,
      role: 'vendor',
      status: 'active',
      vendorStatus: 'verified',
      emailVerified: true,
      verificationDocumentUrl: 'seeded-real-map-vendor-verification',
      location: new GeoPoint(mapMatch.lat, mapMatch.lng),
      latitude: mapMatch.lat,
      longitude: mapMatch.lng,
      state: 'Penang',
      country: 'Malaysia',
      mapUrl,
      openStreetMapUrl: openStreetMapUrl(mapMatch.lat, mapMatch.lng),
      website: place.website,
      websiteUrl: place.website,
      mapProvider: mapMatch.mapProvider,
      mapMatchedName: mapMatch.mapMatchedName,
      mapPlaceId: mapMatch.mapPlaceId,
      mapVerified: true,
      source: 'real_map_vendor_seed',
      imageUrl: imageCandidates[0] || '',
      imageCandidates,
      fallbackImageUrl: mapPreview,
      mapPreviewUrl: mapPreview,
      imageType: imageCandidates.length ? 'real_place_photo' : '',
      budgetLevel: budget,
      seededForTesting: true,
      seededVendorNumber: index + 1,
      migratedToThreeRoles: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  const reviewBatchSize = 350;
  let pendingWrites = [];
  async function flush() {
    if (pendingWrites.length === 0) return;
    const batch = db.batch();
    for (const write of pendingWrites) batch.set(write.ref, write.data);
    await batch.commit();
    pendingWrites = [];
  }

  let validReviews = 0;
  let flaggedReviews = 0;
  let taskCount = 0;
  let voucherCount = 0;

  for (let index = 0; index < vendors.length; index += 1) {
    const vendor = vendors[index];
    const definition = vendor.definition;
    const placeId = `vendor_${vendor.uid}`;
    const placeNameKey = normalize(vendor.businessName);

    const validReviewsForVendor = validReviewTexts(vendor, definition, index);
    const flaggedForVendor = mismatchReviews(vendor);
    const reviews = [...validReviewsForVendor, ...flaggedForVendor];

    for (let reviewIndex = 0; reviewIndex < reviews.length; reviewIndex += 1) {
      const review = reviews[reviewIndex];
      const flagged = reviewIndex >= validReviewsForVendor.length;
      const createdAt = Timestamp.fromDate(
        new Date(now.getTime() - (index * 2 + reviewIndex + 5) * 86400000),
      );
      const ref = db.collection('reviews').doc(
        `vendor_seed_${String(index + 1).padStart(3, '0')}_${reviewIndex + 1}`,
      );
      pendingWrites.push({
        ref,
        data: {
          userId: `seed_traveler_${(index + reviewIndex) % 60 + 1}`,
          reviewerName: reviewerNames[(index + reviewIndex) % reviewerNames.length],
          vendorId: vendor.uid,
          placeId,
          placeName: vendor.businessName,
          placeNameKey,
          source: 'vendor_seed',
          reviewProfile: review.profile ?? null,
          rating: review.rating,
          comment: review.comment,
          status: flagged ? 'flagged' : 'valid',
          flagReason: flagged ? review.reason : null,
          flagReasons: flagged ? [review.reason] : [],
          mlModelVersion: 'tfidf_sentiment_suspicious_v2',
          mlSentiment: review.sentiment,
          mlSentimentConfidence: flagged ? 0.92 : 0.86,
          mlNegativeProbability: review.negativeProbability ?? (review.sentiment === 'negative' ? 0.84 : 0.07),
          mlNeutralProbability: review.sentiment === 'neutral' ? 0.76 : 0.08,
          mlPositiveProbability: review.positiveProbability ?? (review.sentiment === 'positive' ? 0.86 : 0.08),
          mlRatingMismatch: flagged,
          mlSuspiciousProbability: flagged ? 0.91 : 0.12,
          mlDecision: flagged ? 'flagged' : 'valid',
          seededForTesting: true,
          createdAt,
          updatedAt: Timestamp.now(),
        },
      });
      if (flagged) flaggedReviews += 1;
      else validReviews += 1;
      if (pendingWrites.length >= reviewBatchSize) await flush();
    }

    const taskRef = db.collection('cultural_tasks').doc(
      `vendor_task_${String(index + 1).padStart(3, '0')}`,
    );
    pendingWrites.push({
      ref: taskRef,
      data: {
        vendorId: vendor.uid,
        vendorName: vendor.businessName,
        placeId,
        title: `${definition.category} Discovery at ${vendor.businessName}`,
        description: definition.task,
        category: definition.plannerCategories[0],
        locationName: vendor.businessName,
        location: new GeoPoint(vendor.lat, vendor.lng),
        mapUrl: vendor.mapUrl,
        requiredPhotoCategory: definition.photoTarget,
        rewardPoints: 80 + (index % 6) * 20,
        deadline,
        status: 'active',
        optional: true,
        seededForTesting: true,
        createdBy: 'system_seed',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
    taskCount += 1;

    const voucherRef = db.collection('vouchers').doc(
      `vendor_voucher_${String(index + 1).padStart(3, '0')}_1`,
    );
    pendingWrites.push({
      ref: voucherRef,
      data: {
        vendorId: vendor.uid,
        vendorName: vendor.businessName,
        vendorCategory: definition.category,
        vendorAddress: vendor.address,
        mapUrl: vendor.mapUrl,
        title: definition.voucher,
        description: `Reward available only at ${vendor.businessName}.`,
        terms: 'One redemption per traveler. Present the in-app QR code before payment.',
        pointCost: 100 + (index % 5) * 40,
        inventoryLimit: 80,
        inventoryRemaining: 80,
        claimCount: 0,
        expiresAt: expiry,
        location: new GeoPoint(vendor.lat, vendor.lng),
        notificationRadiusMeters: 900,
        status: 'active',
        seededForTesting: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
    voucherCount += 1;

    if (index % 3 === 0) {
      const secondVoucherRef = db.collection('vouchers').doc(
        `vendor_voucher_${String(index + 1).padStart(3, '0')}_2`,
      );
      pendingWrites.push({
        ref: secondVoucherRef,
        data: {
          vendorId: vendor.uid,
          vendorName: vendor.businessName,
          vendorCategory: definition.category,
          vendorAddress: vendor.address,
          mapUrl: vendor.mapUrl,
          title: `Bonus Reward at ${vendor.businessName}`,
          description: 'A second vendor reward for travelers who earn additional cultural-task points.',
          terms: 'Subject to inventory. One claim per account.',
          pointCost: 220 + (index % 4) * 40,
          inventoryLimit: 40,
          inventoryRemaining: 40,
          claimCount: 0,
          expiresAt: expiry,
          location: new GeoPoint(vendor.lat, vendor.lng),
          notificationRadiusMeters: 900,
          status: 'active',
          seededForTesting: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
      voucherCount += 1;
    }

    if (pendingWrites.length >= reviewBatchSize) await flush();
  }
  await flush();

  const csvPath = path.join(__dirname, 'seeded_vendor_accounts.csv');
  fs.writeFileSync(
    csvPath,
    credentials.map((row) => row.map((item) => `"${String(item).replace(/"/g, '""')}"`).join(',')).join('\n'),
    'utf8',
  );

  return {
    vendors: vendors.length,
    validReviews,
    flaggedReviews,
    tasks: taskCount,
    vouchers: voucherCount,
    credentialsPath: csvPath,
  };
}

async function main() {
  const collections = (await db.listCollections()).map((item) => item.id);
  console.log('Current top-level collections:');
  console.log(collections.length ? collections.join(', ') : '(none)');
  console.log('Existing traveler/admin/member data is preserved.');
  console.log('Only seeded vendor ecosystem docs are replaced.');
  console.log('Old seeded vendor user-docs will be removed from users/.');
  console.log('Real map-matched vendor profiles will be reseeded in vendors/.');

  if (!confirmed) {
    console.log('');
    console.log('DRY RUN ONLY. Nothing was deleted or created.');
    console.log(`Run with: node reset_vendor_ecosystem.js --confirm ${CONFIRM_TOKEN}`);
    return;
  }

  if (!geoapifyKey) {
    console.warn('Warning: GEOAPIFY_API_KEY is empty. Real vendors will use curated fallback coordinates instead of live map matching.');
  }

  const deletedSeededDocs = await backupAndDeleteSeededVendorEcosystemDocs();
  const deletedVendorUsers = await backupAndDeleteSeededVendorUsers();
  const result = await seedVendorEcosystem();

  console.log('');
  console.log('Vendor-only Penang ecosystem created successfully.');
  console.log('Seeded docs removed before reseeding:');
  for (const [collection, count] of Object.entries(deletedSeededDocs)) {
    console.log(`- ${collection}: ${count}`);
  }
  console.log(`Old seeded vendor user-docs removed: ${deletedVendorUsers}`);
  console.log(`Registered/verified vendors: ${result.vendors}`);
  console.log(`Valid vendor reviews: ${result.validReviews}`);
  console.log(`Flagged vendor reviews: ${result.flaggedReviews}`);
  console.log(`Total vendor reviews: ${result.validReviews + result.flaggedReviews}`);
  console.log(`Optional cultural tasks: ${result.tasks}`);
  console.log(`Vendor-linked vouchers: ${result.vouchers}`);
  console.log(`Vendor login list: ${result.credentialsPath}`);
  console.log(`Default vendor password: ${defaultPassword}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Vendor ecosystem reset failed.');
    console.error(error);
    process.exit(1);
  });

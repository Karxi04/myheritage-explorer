'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const {
  getFirestore,
  Timestamp,
} = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const places = [
  {
    "id": "armenian_street",
    "name": "Armenian Street",
    "aliases": [
      "Lebuh Armenian",
      "Armenian Street George Town"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Art",
      "Culture"
    ],
    "priority": 100,
    "highlights": [
      "street art",
      "heritage shophouses",
      "walkable lanes",
      "nearby cultural landmarks"
    ],
    "description": "Armenian Street is a central George Town heritage street known for its historic streetscape, public art and nearby cultural attractions."
  },
  {
    "id": "cheong_fatt_tze_mansion",
    "name": "Cheong Fatt Tze Mansion",
    "aliases": [
      "The Blue Mansion",
      "Blue Mansion"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Culture"
    ],
    "priority": 98,
    "highlights": [
      "blue exterior",
      "restored architecture",
      "interior details",
      "guided heritage experience"
    ],
    "description": "Cheong Fatt Tze Mansion is a prominent George Town heritage building recognised for its blue exterior and restored architectural details."
  },
  {
    "id": "pinang_peranakan_mansion",
    "name": "Pinang Peranakan Mansion",
    "aliases": [
      "Penang Peranakan Mansion",
      "Peranakan Mansion"
    ],
    "category": "Culture",
    "area": "George Town",
    "recommendedFor": [
      "Culture",
      "Heritage"
    ],
    "priority": 98,
    "highlights": [
      "Peranakan collections",
      "decorated rooms",
      "traditional furniture",
      "cultural history"
    ],
    "description": "Pinang Peranakan Mansion presents Peranakan material culture through furnished rooms, decorative objects and heritage collections."
  },
  {
    "id": "clan_jetties",
    "name": "Clan Jetties",
    "aliases": [
      "Clan Jetties of Penang",
      "Chew Jetty",
      "Chew Jetty Penang"
    ],
    "category": "Culture",
    "area": "George Town",
    "recommendedFor": [
      "Culture",
      "Heritage"
    ],
    "priority": 96,
    "highlights": [
      "wooden walkways",
      "waterfront settlement",
      "living heritage",
      "sea views"
    ],
    "description": "The Clan Jetties are historic waterfront settlements on stilts and remain an important part of George Town's living heritage."
  },
  {
    "id": "khoo_kongsi",
    "name": "Khoo Kongsi",
    "aliases": [
      "Leong San Tong Khoo Kongsi"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Culture"
    ],
    "priority": 96,
    "highlights": [
      "clanhouse architecture",
      "ornate carvings",
      "courtyard",
      "Chinese heritage"
    ],
    "description": "Khoo Kongsi is a historic Chinese clanhouse complex in George Town with ornate architecture, carvings and a traditional courtyard."
  },
  {
    "id": "fort_cornwallis",
    "name": "Fort Cornwallis",
    "aliases": [
      "Kota Cornwallis"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage"
    ],
    "priority": 91,
    "highlights": [
      "fort walls",
      "historic cannons",
      "open grounds",
      "colonial history"
    ],
    "description": "Fort Cornwallis is a historic fort in central George Town with preserved walls, open grounds and displays connected to Penang's colonial history."
  },
  {
    "id": "kek_lok_si_temple",
    "name": "Kek Lok Si Temple",
    "aliases": [
      "Kek Lok Si",
      "Temple of Supreme Bliss"
    ],
    "category": "Culture",
    "area": "Air Itam",
    "recommendedFor": [
      "Culture",
      "Heritage"
    ],
    "priority": 100,
    "highlights": [
      "temple complex",
      "pagoda",
      "hillside setting",
      "religious architecture"
    ],
    "description": "Kek Lok Si Temple is a major hillside Buddhist temple complex in Air Itam with layered religious architecture and panoramic surroundings."
  },
  {
    "id": "penang_hill",
    "name": "Penang Hill",
    "aliases": [
      "Bukit Bendera",
      "Penang Hill Upper Station"
    ],
    "category": "Nature",
    "area": "Air Itam",
    "recommendedFor": [
      "Nature",
      "Culture"
    ],
    "priority": 100,
    "highlights": [
      "funicular journey",
      "hilltop views",
      "cooler air",
      "walking trails"
    ],
    "description": "Penang Hill offers elevated views, cooler surroundings, walking trails and access by the well-known funicular railway."
  },
  {
    "id": "penang_botanic_gardens",
    "name": "Penang Botanic Gardens",
    "aliases": [
      "Penang Botanical Gardens",
      "Botanical Garden Penang"
    ],
    "category": "Nature",
    "area": "George Town",
    "recommendedFor": [
      "Nature"
    ],
    "priority": 96,
    "highlights": [
      "tropical greenery",
      "walking paths",
      "garden landscape",
      "quiet morning atmosphere"
    ],
    "description": "Penang Botanic Gardens provides tropical greenery, landscaped grounds and walking paths near the base of Penang Hill."
  },
  {
    "id": "tropical_spice_garden",
    "name": "Tropical Spice Garden",
    "aliases": [
      "Tropical Spice Garden Penang"
    ],
    "category": "Nature",
    "area": "Teluk Bahang",
    "recommendedFor": [
      "Nature",
      "Culture"
    ],
    "priority": 88,
    "highlights": [
      "spice plants",
      "shaded garden trails",
      "plant interpretation",
      "natural setting"
    ],
    "description": "Tropical Spice Garden is a landscaped attraction in Teluk Bahang focused on tropical plants, spices and shaded garden walks."
  },
  {
    "id": "penang_national_park",
    "name": "Penang National Park",
    "aliases": [
      "Taman Negara Pulau Pinang",
      "Penang National Park Teluk Bahang"
    ],
    "category": "Nature",
    "area": "Teluk Bahang",
    "recommendedFor": [
      "Nature"
    ],
    "priority": 95,
    "highlights": [
      "coastal trails",
      "forest environment",
      "beaches",
      "outdoor hiking"
    ],
    "description": "Penang National Park combines coastal scenery, forest trails and access to beaches from the Teluk Bahang area."
  },
  {
    "id": "batu_ferringhi_beach",
    "name": "Batu Ferringhi Beach",
    "aliases": [
      "Pantai Batu Ferringhi",
      "Batu Ferringhi"
    ],
    "category": "Nature",
    "area": "Batu Ferringhi",
    "recommendedFor": [
      "Nature"
    ],
    "priority": 89,
    "highlights": [
      "sandy shoreline",
      "sunset views",
      "seafront atmosphere",
      "evening activity"
    ],
    "description": "Batu Ferringhi Beach is a popular Penang shoreline area with a long sandy stretch, seafront views and an active evening atmosphere."
  },
  {
    "id": "entopia",
    "name": "Entopia by Penang Butterfly Farm",
    "aliases": [
      "Entopia",
      "Penang Butterfly Farm"
    ],
    "category": "Nature",
    "area": "Teluk Bahang",
    "recommendedFor": [
      "Nature",
      "Culture"
    ],
    "priority": 87,
    "highlights": [
      "butterfly habitat",
      "indoor exhibits",
      "educational displays",
      "family-friendly experience"
    ],
    "description": "Entopia is a nature-focused attraction in Teluk Bahang featuring butterfly habitats and educational exhibits about insects and biodiversity."
  },
  {
    "id": "gurney_drive_hawker_centre",
    "name": "Gurney Drive Hawker Centre",
    "aliases": [
      "Gurney Drive Food Court",
      "Anjung Gurney"
    ],
    "category": "Food",
    "area": "George Town",
    "recommendedFor": [
      "Food"
    ],
    "priority": 95,
    "highlights": [
      "hawker stalls",
      "local dishes",
      "evening dining",
      "wide food choice"
    ],
    "description": "Gurney Drive Hawker Centre is a well-known evening food stop offering a broad selection of Penang hawker dishes."
  },
  {
    "id": "new_lane_street_food",
    "name": "New Lane Street Foodstalls",
    "aliases": [
      "New Lane Hawker Centre",
      "Lorong Baru Food Court",
      "New Lane Street Food"
    ],
    "category": "Food",
    "area": "George Town",
    "recommendedFor": [
      "Food"
    ],
    "priority": 92,
    "highlights": [
      "street-food stalls",
      "night atmosphere",
      "local dishes",
      "compact walking area"
    ],
    "description": "New Lane Street Foodstalls form a busy evening food area in George Town with numerous local hawker choices."
  },
  {
    "id": "chulia_street_hawker",
    "name": "Chulia Street Night Hawker Stalls",
    "aliases": [
      "Chulia Street Hawker Food",
      "Lebuh Chulia Night Hawker"
    ],
    "category": "Food",
    "area": "George Town",
    "recommendedFor": [
      "Food",
      "Culture"
    ],
    "priority": 94,
    "highlights": [
      "night hawker stalls",
      "street dining",
      "central location",
      "local noodles and snacks"
    ],
    "description": "Chulia Street's night hawker area is a central George Town food stop with roadside stalls and a lively evening atmosphere."
  },
  {
    "id": "air_itam_market",
    "name": "Air Itam Market",
    "aliases": [
      "Ayer Itam Market",
      "Pasar Air Itam"
    ],
    "category": "Food",
    "area": "Air Itam",
    "recommendedFor": [
      "Food",
      "Culture"
    ],
    "priority": 91,
    "highlights": [
      "local market atmosphere",
      "breakfast food",
      "busy morning scene",
      "nearby temple route"
    ],
    "description": "Air Itam Market is a busy local market area that is useful for breakfast and food stops before visiting nearby attractions."
  },
  {
    "id": "hameediyah_restaurant",
    "name": "Hameediyah Restaurant",
    "aliases": [
      "Hameediyah Nasi Kandar",
      "Hameediyah Campbell Street"
    ],
    "category": "Food",
    "area": "George Town",
    "recommendedFor": [
      "Food",
      "Heritage"
    ],
    "priority": 93,
    "highlights": [
      "nasi kandar",
      "historic restaurant setting",
      "curry selection",
      "central George Town location"
    ],
    "description": "Hameediyah Restaurant is a long-established George Town nasi kandar restaurant known for rice, curries and a historic dining setting."
  },
  {
    "id": "teksen_restaurant",
    "name": "Teksen Restaurant",
    "aliases": [
      "Tek Sen Restaurant",
      "Tek Sen Penang"
    ],
    "category": "Food",
    "area": "George Town",
    "recommendedFor": [
      "Food"
    ],
    "priority": 90,
    "highlights": [
      "Chinese dishes",
      "shared dining",
      "busy meal periods",
      "central heritage area"
    ],
    "description": "Teksen Restaurant is a popular George Town dining option for Chinese dishes and shared meals in the heritage area."
  },
  {
    "id": "hin_bus_depot",
    "name": "Hin Bus Depot",
    "aliases": [
      "Hin Bus Depot Art Centre",
      "Hin Bus Depot Penang"
    ],
    "category": "Art",
    "area": "George Town",
    "recommendedFor": [
      "Art",
      "Culture"
    ],
    "priority": 94,
    "highlights": [
      "creative spaces",
      "art exhibitions",
      "courtyard events",
      "independent shops"
    ],
    "description": "Hin Bus Depot is a creative arts space in George Town with exhibition areas, independent businesses and event spaces."
  },
  {
    "id": "wonderfood_museum",
    "name": "Wonderfood Museum",
    "aliases": [
      "Wonder Food Museum",
      "Wonderfood Museum Penang"
    ],
    "category": "Art",
    "area": "George Town",
    "recommendedFor": [
      "Art",
      "Food",
      "Culture"
    ],
    "priority": 85,
    "highlights": [
      "large food models",
      "interactive displays",
      "photo opportunities",
      "Penang food themes"
    ],
    "description": "Wonderfood Museum uses oversized food models and interactive displays to present Penang food culture in a visual format."
  },
  {
    "id": "upside_down_museum",
    "name": "Upside Down Museum",
    "aliases": [
      "Upside Down Museum Penang"
    ],
    "category": "Art",
    "area": "George Town",
    "recommendedFor": [
      "Art"
    ],
    "priority": 79,
    "highlights": [
      "illusion rooms",
      "interactive photo setups",
      "indoor attraction",
      "creative scenes"
    ],
    "description": "Upside Down Museum is an indoor interactive attraction built around illusion rooms and staged photo scenes."
  },
  {
    "id": "penang_3d_trick_art",
    "name": "Penang 3D Trick Art Museum",
    "aliases": [
      "3D Trick Art Museum Penang",
      "Penang 3D Museum"
    ],
    "category": "Art",
    "area": "George Town",
    "recommendedFor": [
      "Art"
    ],
    "priority": 78,
    "highlights": [
      "3D artworks",
      "interactive photos",
      "indoor exhibits",
      "family activity"
    ],
    "description": "Penang 3D Trick Art Museum features perspective-based artworks designed for interactive photography."
  },
  {
    "id": "kapitan_keling_mosque",
    "name": "Kapitan Keling Mosque",
    "aliases": [
      "Masjid Kapitan Keling"
    ],
    "category": "Culture",
    "area": "George Town",
    "recommendedFor": [
      "Culture",
      "Heritage"
    ],
    "priority": 90,
    "highlights": [
      "mosque architecture",
      "historic neighbourhood",
      "religious heritage",
      "central location"
    ],
    "description": "Kapitan Keling Mosque is an important place of worship and heritage landmark within George Town's historic centre."
  },
  {
    "id": "st_georges_church",
    "name": "St. George's Church",
    "aliases": [
      "St Georges Church Penang",
      "Saint George's Church"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Culture"
    ],
    "priority": 86,
    "highlights": [
      "white colonial architecture",
      "church grounds",
      "historic district",
      "quiet interior"
    ],
    "description": "St. George's Church is a historic church in George Town with distinctive white architecture and landscaped grounds."
  },
  {
    "id": "goddess_of_mercy_temple",
    "name": "Goddess of Mercy Temple",
    "aliases": [
      "Kuan Yin Teng",
      "Goddess of Mercy Temple Penang"
    ],
    "category": "Culture",
    "area": "George Town",
    "recommendedFor": [
      "Culture",
      "Heritage"
    ],
    "priority": 88,
    "highlights": [
      "temple courtyard",
      "incense atmosphere",
      "religious practice",
      "historic setting"
    ],
    "description": "The Goddess of Mercy Temple is a longstanding Chinese place of worship in George Town with an active courtyard and religious atmosphere."
  },
  {
    "id": "cheah_kongsi",
    "name": "Cheah Kongsi",
    "aliases": [
      "Sek Tong Cheah Si Seh Tek Tong",
      "Cheah Clan Temple"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Culture"
    ],
    "priority": 84,
    "highlights": [
      "clan temple",
      "ornate roof details",
      "courtyard",
      "Armenian Street enclave"
    ],
    "description": "Cheah Kongsi is a historic clan temple in the Armenian Street heritage area with ornate details and a traditional courtyard."
  },
  {
    "id": "sia_boey",
    "name": "Sia Boey Urban Archaeological Park",
    "aliases": [
      "Sia Boey",
      "Prangin Canal Park"
    ],
    "category": "Heritage",
    "area": "George Town",
    "recommendedFor": [
      "Heritage",
      "Nature",
      "Culture"
    ],
    "priority": 86,
    "highlights": [
      "restored canal",
      "urban heritage",
      "green public space",
      "archaeological interpretation"
    ],
    "description": "Sia Boey Urban Archaeological Park combines restored heritage elements, a revitalised canal and public green space in central George Town."
  }
];

const reviewerNames = [
  'Aina Rahman', 'Daniel Lim', 'Nur Izzati', 'Wei Jian',
  'Farah Nadia', 'Harith Iskandar', 'Mei Ling', 'Jason Tan',
  'Amirah Yusuf', 'Bryan Wong', 'Priya Nair', 'Hui Min',
  'Kavitha Raj', 'Muhammad Aqil', 'Chloe Ng', 'Nadia Azman',
  'Kelvin Ooi', 'Shalini Devi', 'Marcus Lee', 'Siti Hajar',
  'Adrian Teoh', 'Nabilah Omar', 'Jia Wen', 'Arun Kumar',
  'Alicia Ong', 'Hafiz Zainal', 'Janice Goh', 'Irfan Hakim',
  'Michelle Lee', 'Aaron Khoo', 'Devi Raman', 'Syafiq Azmi',
];

function normalise(value) {
  return String(value || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
}

function wordSet(value) {
  return new Set(
    normalise(value)
        .split(' ')
        .filter((word) => word.length > 2),
  );
}

function overlapScore(first, second) {
  let score = 0;
  for (const word of first) {
    if (second.has(word)) score += 1;
  }
  return score;
}

async function wikipediaImage(place) {
  const searches = [
    `${place.name} Penang Malaysia`,
    ...(place.aliases || []).slice(0, 2).map(
      (alias) => `${alias} Penang Malaysia`,
    ),
  ];

  const targetWords = wordSet(place.name);
  let best = null;
  let bestScore = -100;

  for (const searchText of searches) {
    const params = new URLSearchParams({
      action: 'query',
      generator: 'search',
      gsrsearch: searchText,
      gsrnamespace: '0',
      gsrlimit: '6',
      prop: 'pageimages|pageterms',
      piprop: 'thumbnail|original',
      pithumbsize: '1200',
      wbptterms: 'description',
      format: 'json',
      formatversion: '2',
      origin: '*',
    });

    try {
      const response = await fetch(
        `https://en.wikipedia.org/w/api.php?${params.toString()}`,
        {
          headers: {
            'Accept': 'application/json',
            'User-Agent':
              'MyHeritageExplorer/1.0 (university tourism project)',
          },
        },
      );

      if (!response.ok) continue;

      const body = await response.json();
      const pages = body?.query?.pages || [];

      for (const page of pages) {
        const titleWords = wordSet(page.title);
        const descriptions = page?.terms?.description || [];
        const searchable = normalise(
          `${page.title || ''} ${descriptions.join(' ')}`,
        );

        let score = overlapScore(targetWords, titleWords) * 5;
        if (
          searchable.includes('penang') ||
          searchable.includes('george town') ||
          searchable.includes('malaysia')
        ) {
          score += 4;
        }
        if (normalise(page.title) === normalise(place.name)) {
          score += 8;
        }

        const imageUrl =
          page?.thumbnail?.source || page?.original?.source || '';

        if (!imageUrl || !imageUrl.startsWith('https://')) continue;

        if (score > bestScore) {
          bestScore = score;
          best = {
            imageUrl,
            imageType: 'wikipedia_place_photo',
            imageAttribution: 'Wikipedia / Wikimedia Commons',
            imageSourceUrl:
              `https://en.wikipedia.org/?curid=${page.pageid || ''}`,
          };
        }
      }
    } catch (_) {
      // Continue with the next alias or the map fallback.
    }

    if (bestScore >= 10) break;
  }

  return bestScore >= 4 ? best : null;
}

function validReviewComments(place) {
  const [first, second, third, fourth] = place.highlights;
  const name = place.name;
  const area = place.area;

  if (place.category === 'Food') {
    return [
      `The ${first} at ${name} gave us plenty of choices and fitted well into our Penang food itinerary.`,
      `${name} had a lively ${second}. We tried several local dishes and the waiting time was manageable.`,
      `I liked the ${third} at ${name}. The location was easy to combine with nearby attractions.`,
      `The ${fourth} made ${name} a convenient meal stop. Prices felt reasonable for ${area}.`,
      `${name} was busiest during the main meal period, but the variety of food made the visit worthwhile.`,
      `The food selection at ${name} suited a group with different preferences and the atmosphere felt local.`,
      `We added ${name} between two sightseeing stops. Service was efficient and the dining area was easy to locate.`,
      `The visit to ${name} was enjoyable because of the ${first} and ${second}.`,
      `The menu choices matched the place description and we found several dishes suitable for sharing.`,
      `${name} worked well as an evening food stop after visiting nearby attractions.`,
      `The seating area was active but organised, and the overall dining experience was comfortable.`,
      `I would keep ${name} in a food-focused itinerary because it gives travelers a useful local meal option.`,
      `The staff handled our order clearly and the food arrived within a reasonable period.`,
      `The ${third} made the stop feel different from a standard restaurant visit.`,
      `We enjoyed comparing several local items at ${name} before continuing our route.`,
      `The place was easy to find and the meal duration matched the time estimated by the planner.`,
    ];
  }

  if (place.category === 'Nature') {
    return [
      `The ${first} at ${name} made this a refreshing break from the city and the route was easy to follow.`,
      `${name} offered enjoyable ${second}. We spent enough time there without feeling rushed.`,
      `I appreciated the ${third} at ${name}. The surroundings were suitable for a relaxed visit.`,
      `The ${fourth} made ${name} a strong choice for travelers interested in Penang's natural side.`,
      `${name} was well suited to a morning visit and the scenery matched the information shown in the itinerary.`,
      `The walking experience at ${name} was comfortable and there were several places to pause.`,
      `We combined ${name} with another nearby attraction. Travel time was reasonable.`,
      `The ${first} and ${third} were the highlights of ${name}.`,
      `The environment felt calmer than the city centre and was suitable for a slower travel pace.`,
      `The visit duration was accurate and gave us enough time to explore the main area.`,
      `The route signs and paths made the visit easier for first-time travelers.`,
      `${name} gave our group a useful outdoor activity without making the itinerary feel too crowded.`,
      `The natural surroundings were enjoyable and the place was worth the travel time from George Town.`,
      `We visited during daylight and found the main viewpoints and paths easy to recognise.`,
      `The ${second} made ${name} one of the most relaxing stops in our plan.`,
      `I would recommend preparing water and comfortable shoes for a longer visit to ${name}.`,
    ];
  }

  if (place.category === 'Art') {
    return [
      `The ${first} at ${name} created several interesting photo opportunities.`,
      `${name} had engaging ${second} and added a creative element to our George Town itinerary.`,
      `I enjoyed the ${third} at ${name}. The space felt welcoming and was easy to navigate.`,
      `The ${fourth} made ${name} suitable for visitors who want an indoor creative activity.`,
      `${name} was a useful art stop between heritage attractions.`,
      `The displays at ${name} were visually interesting and worked well for a small group visit.`,
      `We spent more time than expected at ${name} because the ${first} and ${second} were enjoyable.`,
      `${name} provided a different experience from nearby historical sites.`,
      `The exhibits were arranged clearly and we could explore them without feeling rushed.`,
      `The place offered several memorable details that were worth photographing.`,
      `The estimated visit duration was suitable for seeing the main displays.`,
      `I would recommend ${name} to travelers who select Art as one of their interests.`,
      `The creative atmosphere made this stop feel different from the rest of our route.`,
      `The ${third} helped us understand more about Penang's contemporary creative scene.`,
      `The venue was easy to combine with food and heritage stops in the same area.`,
      `Our group enjoyed discussing the displays after leaving ${name}.`,
    ];
  }

  return [
    `The ${first} at ${name} made the visit memorable and fitted naturally into our George Town route.`,
    `${name} offered clear ${second}. We learned more about Penang while exploring the site.`,
    `I appreciated the ${third} at ${name}. The visit was informative without taking too much time.`,
    `The ${fourth} made ${name} a strong stop for travelers interested in local history and culture.`,
    `${name} was easy to combine with nearby heritage attractions and the walking distance was reasonable.`,
    `The details at ${name} were worth observing carefully.`,
    `We visited ${name} earlier in the day and had enough space to explore comfortably.`,
    `The ${first} and ${second} were the best parts of ${name}.`,
    `The place description prepared us well for the visit and the estimated duration was suitable.`,
    `The site helped connect several parts of Penang's cultural history in one stop.`,
    `The main features were easy to recognise and the surrounding area was convenient for walking.`,
    `I would recommend ${name} to first-time visitors interested in the heritage of ${area}.`,
    `The visit added useful historical context before we continued to another nearby location.`,
    `The architecture and interpretation made the stop feel worthwhile.`,
    `Our group found enough information to understand why ${name} is important to the local area.`,
    `The location worked well in a half-day heritage itinerary and did not require unnecessary travel.`,
  ];
}

function flaggedReviews(place) {
  const repeated = place.name.split(' ')[0].toLowerCase();
  const validDuplicate = validReviewComments(place)[0];

  return [
    {
      rating: 5,
      comment:
        `The ${place.highlights[0]} was disappointing, the visit was poorly organised and I would not return.`,
      reasons: ['Possible rating-comment mismatch'],
      probability: 0.94,
    },
    {
      rating: 1,
      comment:
        `Amazing place with excellent service, wonderful surroundings and a perfect experience.`,
      reasons: ['Possible rating-comment mismatch'],
      probability: 0.93,
    },
    {
      rating: 3,
      comment:
        `${repeated} ${repeated} ${repeated} ${repeated} ${repeated}`,
      reasons: ['Repeated word or phrase pattern'],
      probability: 0.97,
    },
    {
      rating: 4,
      comment: validDuplicate,
      reasons: ['Duplicate review text detected'],
      probability: 0.91,
    },
  ];
}

async function deleteExistingSeededReviews() {
  const snapshot = await db
      .collection('reviews')
      .where('seededForTesting', '==', true)
      .get();

  for (let start = 0; start < snapshot.docs.length; start += 400) {
    const batch = db.batch();
    for (const doc of snapshot.docs.slice(start, start + 400)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
  return snapshot.docs.length;
}

async function commitWrites(writes, chunkSize = 400) {
  for (let start = 0; start < writes.length; start += chunkSize) {
    const batch = db.batch();
    for (const write of writes.slice(start, start + chunkSize)) {
      batch.set(write.ref, write.data, write.options || {});
    }
    await batch.commit();
  }
}

async function seed() {
  const removed = await deleteExistingSeededReviews();
  const now = Date.now();
  const contentWrites = [];
  const reviewWrites = [];

  let reviewNumber = 0;
  let validCount = 0;
  let flaggedCount = 0;
  let imageCount = 0;

  for (let placeIndex = 0; placeIndex < places.length; placeIndex++) {
    const place = places[placeIndex];
    const media = await wikipediaImage(place);

    if (media?.imageUrl) imageCount += 1;

    contentWrites.push({
      ref: db.collection('place_content').doc(place.id),
      data: {
        name: place.name,
        placeNameKey: normalise(place.name),
        aliases: place.aliases,
        category: place.category,
        officialArea: place.area,
        recommendedFor: place.recommendedFor,
        penangPriority: place.priority,
        description: place.description,
        highlights: place.highlights,
        status: 'active',
        ...(media || {}),
        updatedAt: Timestamp.now(),
      },
      options: { merge: true },
    });

    const comments = validReviewComments(place);
    for (let index = 0; index < comments.length; index++) {
      reviewNumber += 1;
      validCount += 1;

      const rating =
        index < 4 ? 5 :
        index < 13 ? 4 :
        3;

      reviewWrites.push({
        ref: db.collection('reviews')
            .doc(`penang_more_${place.id}_valid_${index + 1}`),
        data: {
          userId: `penang_more_user_${reviewNumber}`,
          reviewerName:
              reviewerNames[reviewNumber % reviewerNames.length],
          placeId: `seed_${place.id}`,
          placeName: place.name,
          placeNameKey: normalise(place.name),
          source: 'penang_more_reviews_v4',
          rating,
          comment: comments[index],
          status: 'valid',
          flagReason: null,
          flagReasons: [],
          seededForTesting: true,
          createdAt: Timestamp.fromDate(
            new Date(
              now -
              (placeIndex * 18 + index + 1) *
                  7 * 60 * 60 * 1000,
            ),
          ),
          updatedAt: Timestamp.now(),
        },
      });
    }

    const suspicious = flaggedReviews(place);
    for (let index = 0; index < suspicious.length; index++) {
      reviewNumber += 1;
      flaggedCount += 1;
      const item = suspicious[index];

      reviewWrites.push({
        ref: db.collection('reviews')
            .doc(`penang_more_${place.id}_flagged_${index + 1}`),
        data: {
          userId: `penang_more_flag_user_${reviewNumber}`,
          reviewerName:
              reviewerNames[reviewNumber % reviewerNames.length],
          placeId: `seed_${place.id}`,
          placeName: place.name,
          placeNameKey: normalise(place.name),
          source: 'penang_more_reviews_v4',
          rating: item.rating,
          comment: item.comment,
          status: 'flagged',
          flagReason: item.reasons.join(' • '),
          flagReasons: item.reasons,
          mlModelVersion: 'tfidf_logreg_v1',
          mlSuspiciousProbability: item.probability,
          mlDecision: 'flagged',
          seededForTesting: true,
          createdAt: Timestamp.fromDate(
            new Date(
              now -
              (placeIndex * 18 + comments.length + index + 1) *
                  7 * 60 * 60 * 1000,
            ),
          ),
          updatedAt: Timestamp.now(),
        },
      });
    }

    await new Promise((resolve) => setTimeout(resolve, 80));
  }

  await commitWrites(contentWrites);
  await commitWrites(reviewWrites);

  console.log('');
  console.log('More Penang reviews and place images created successfully.');
  console.log(`Removed previous seeded reviews: ${removed}`);
  console.log(`Penang locations covered: ${places.length}`);
  console.log(`Wikipedia place images stored: ${imageCount}`);
  console.log(`Valid reviews created: ${validCount}`);
  console.log(`Flagged reviews created: ${flaggedCount}`);
  console.log(`Total reviews created: ${validCount + flaggedCount}`);
  console.log('');
  console.log(
    'Run npm run repair-itinerary-images to update older saved itineraries.',
  );
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exit(1);
  });

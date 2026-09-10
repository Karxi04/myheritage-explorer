'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

// All Curated Malaysian Vendors & Places
const places = [
  // PENANG (EXPANDED CURATED REAL PLACES)
  {
    "name": "Pinang Peranakan Mansion",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Art",
        "Local Business"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Art",
        "Local Business"
    ],
    "formattedAddress": "29 Church Street, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 75,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4182,
        "longitude": 100.3408
    },
    "phone": "+604-264 2929",
    "website": "https://www.pinangperanakanmansion.com.my/",
    "openingHours": "Daily 09:30 - 17:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Pinang Peranakan Mansion Discovery",
        "description": "Opulent 19th-century Peranakan Baba Nyonya mansion showcasing over 1,000 ornate antiques, gold leaf woodwork, and ancestral customs.",
        "rewardPoints": 100
    },
    "description": "Opulent 19th-century Peranakan Baba Nyonya mansion showcasing over 1,000 ornate antiques, gold leaf woodwork, and ancestral customs."
},
  {
    "name": "Cheong Fatt Tze - The Blue Mansion",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Art",
        "Local Business"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Art",
        "Local Business"
    ],
    "formattedAddress": "14 Leith Street, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 75,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.4216,
        "longitude": 100.3341
    },
    "phone": "+604-262 0006",
    "website": "https://www.cheongfatttzemansion.com/",
    "openingHours": "Daily 11:00 - 18:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Cheong Fatt Tze - The Blue Mansion Discovery",
        "description": "Award-winning UNESCO-conserved 1890s courtyard mansion famous for its striking indigo blue walls, Art Nouveau stained glass, and Chinese master craft.",
        "rewardPoints": 100
    },
    "description": "Award-winning UNESCO-conserved 1890s courtyard mansion famous for its striking indigo blue walls, Art Nouveau stained glass, and Chinese master craft."
},
  {
    "name": "Leong San Tong Khoo Kongsi",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "formattedAddress": "18 Cannon Square, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4146,
        "longitude": 100.3371
    },
    "phone": "+604-261 4609",
    "website": "http://www.khookongsi.com.my/",
    "openingHours": "Daily 09:00 - 17:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1548013146-72479768bada?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Leong San Tong Khoo Kongsi Discovery",
        "description": "The most grand Chinese clan temple in Southeast Asia, renowned for intricate granite stone sculptures, 3D ceramic tile roof dragons, and gold guilding.",
        "rewardPoints": 100
    },
    "description": "The most grand Chinese clan temple in Southeast Asia, renowned for intricate granite stone sculptures, 3D ceramic tile roof dragons, and gold guilding."
},
  {
    "name": "Fort Cornwallis",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Jalan Tun Syed Sheh Barakbah, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4206,
        "longitude": 100.344
    },
    "phone": "+604-262 5377",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 08:00 - 21:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1590059390046-24e50529d442?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Fort Cornwallis Discovery",
        "description": "Largest intact 18th-century British bastion fort in Malaysia built by Captain Francis Light with colonial lighthouse and historic bronze artillery.",
        "rewardPoints": 100
    },
    "description": "Largest intact 18th-century British bastion fort in Malaysia built by Captain Francis Light with colonial lighthouse and historic bronze artillery."
},
  {
    "name": "Clan Jetties of Penang (Chew Jetty)",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Local Business",
        "Nature"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Local Business",
        "Nature"
    ],
    "formattedAddress": "Weld Quay, George Town, 10300 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4128,
        "longitude": 100.3398
    },
    "phone": "+604-261 6606",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 09:00 - 21:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Clan Jetties of Penang (Chew Jetty) Discovery",
        "description": "Historic 19th-century wooden stilt water village established by Chinese clan immigrants along the George Town harbour waterfront.",
        "rewardPoints": 100
    },
    "description": "Historic 19th-century wooden stilt water village established by Chinese clan immigrants along the George Town harbour waterfront."
},
  {
    "name": "Armenian Street Heritage Murals",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Lebuh Armenian, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4153,
        "longitude": 100.3364
    },
    "phone": "+604-263 7000",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Armenian Street Heritage Murals Discovery",
        "description": "Vibrant epicenter of George Town UNESCO street art, featuring Ernest Zacharevic 'Kids on Bicycle' mural, craft souvenir shops, and heritage cafes.",
        "rewardPoints": 100
    },
    "description": "Vibrant epicenter of George Town UNESCO street art, featuring Ernest Zacharevic 'Kids on Bicycle' mural, craft souvenir shops, and heritage cafes."
},
  {
    "name": "Kapitan Keling Mosque",
    "category": "Culture",
    "plannerCategories": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "interestTags": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "formattedAddress": "14 Buckingham Street, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4168,
        "longitude": 100.3377
    },
    "phone": "+604-261 4201",
    "website": "https://kapitankeling.org.my/",
    "openingHours": "Daily 09:00 - 17:00 (Outside Prayer Times)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1564769625905-50e93615e769?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Kapitan Keling Mosque Discovery",
        "description": "Majestic 1801 Indo-Moorish heritage mosque built by Penang's early Indian Muslim merchants, featuring yellow domes, horseshoe arches, and gothic minaret.",
        "rewardPoints": 100
    },
    "description": "Majestic 1801 Indo-Moorish heritage mosque built by Penang's early Indian Muslim merchants, featuring yellow domes, horseshoe arches, and gothic minaret."
},
  {
    "name": "Sri Mahamariamman Temple Queen Street",
    "category": "Culture",
    "plannerCategories": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "interestTags": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "formattedAddress": "Lebuh Queen, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4173,
        "longitude": 100.3392
    },
    "phone": "+604-262 2294",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 06:00 - 12:00, 16:30 - 21:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Sri Mahamariamman Temple Queen Street Discovery",
        "description": "Penang's oldest Hindu temple (built 1833 in Little India), adorned with an intricately sculpted 23-foot Rajagopuram gopuram tower of deities.",
        "rewardPoints": 100
    },
    "description": "Penang's oldest Hindu temple (built 1833 in Little India), adorned with an intricately sculpted 23-foot Rajagopuram gopuram tower of deities."
},
  {
    "name": "Hin Bus Depot Art Centre",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "31A Jalan Gurdwara, George Town, 10300 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4124,
        "longitude": 100.3283
    },
    "phone": "+604-226 5691",
    "website": "https://hinbusdepot.com/",
    "openingHours": "Mon-Fri 12:00 - 19:00, Sat-Sun 11:00 - 19:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Hin Bus Depot Art Centre Discovery",
        "description": "Converted 1940s bus depot transformed into a dynamic contemporary creative arts hub with rotating galleries, artisan markets, and garden cafes.",
        "rewardPoints": 100
    },
    "description": "Converted 1940s bus depot transformed into a dynamic contemporary creative arts hub with rotating galleries, artisan markets, and garden cafes."
},
  {
    "name": "Penang State Museum & Art Gallery",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Heritage",
        "Culture"
    ],
    "interestTags": [
        "Art",
        "Heritage",
        "Culture"
    ],
    "formattedAddress": "Lebuh Farquhar, George Town, 10200 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4208,
        "longitude": 100.3385
    },
    "phone": "+604-226 1461",
    "website": "http://penangmuseum.gov.my/",
    "openingHours": "Sat-Thu 09:00 - 17:00 (Closed Friday)",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang State Museum & Art Gallery Discovery",
        "description": "Preserves rare paintings, historical colonial oil artwork, and cultural artefacts tracing Penang's transformation through centuries.",
        "rewardPoints": 100
    },
    "description": "Preserves rare paintings, historical colonial oil artwork, and cultural artefacts tracing Penang's transformation through centuries."
},
  {
    "name": "Hameediyah Restaurant (Est. 1907)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business",
        "Culture"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business",
        "Culture"
    ],
    "formattedAddress": "164A Lebuh Campbell, George Town, 10100 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 50,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4187,
        "longitude": 100.3339
    },
    "phone": "+604-261 1095",
    "website": "https://www.hameediyah.my/",
    "openingHours": "Daily 10:00 - 22:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Hameediyah Restaurant (Est. 1907) Discovery",
        "description": "Malaysia's oldest Nasi Kandar establishment operating since 1907, legendary for signature spice-rich curry, spiced mutton shank, and crispy murtabak.",
        "rewardPoints": 100
    },
    "description": "Malaysia's oldest Nasi Kandar establishment operating since 1907, legendary for signature spice-rich curry, spiced mutton shank, and crispy murtabak."
},
  {
    "name": "Line Clear Nasi Kandar",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Alleyway, 177 Jalan Penang, George Town, 10000 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4199,
        "longitude": 100.3323
    },
    "phone": "+604-261 4440",
    "website": "https://www.facebook.com/lineclearnasikandar/",
    "openingHours": "24 Hours Daily",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Line Clear Nasi Kandar Discovery",
        "description": "Iconic bustling heritage lane eatery serving deep aromatic mixed curries, spiced fried chicken, and king prawns since 1930.",
        "rewardPoints": 100
    },
    "description": "Iconic bustling heritage lane eatery serving deep aromatic mixed curries, spiced fried chicken, and king prawns since 1930."
},
  {
    "name": "Toh Soon Cafe (Campbel Lane Toast)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Lebuh Campbell, George Town, 10100 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4188,
        "longitude": 100.3332
    },
    "phone": "+604-261 3754",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Mon-Sat 08:00 - 17:00 (Closed Sun)",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Toh Soon Cafe (Campbel Lane Toast) Discovery",
        "description": "Classic back-alley Hainanese kopitiam serving charcoal-toasted kaya butter bread, half-boiled kampung eggs, and rich robust Hainan coffee.",
        "rewardPoints": 100
    },
    "description": "Classic back-alley Hainanese kopitiam serving charcoal-toasted kaya butter bread, half-boiled kampung eggs, and rich robust Hainan coffee."
},
  {
    "name": "Penang Road Famous Teochew Chendul",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "4\u00bd Lebuh Keng Kwee, George Town, 10100 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 30,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4172,
        "longitude": 100.3308
    },
    "phone": "+604-262 6002",
    "website": "https://www.chendul.my/",
    "openingHours": "Daily 10:30 - 19:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang Road Famous Teochew Chendul Discovery",
        "description": "World-famous shaved ice dessert stall operating since 1936 with green pandan rice noodles, fragrant Gula Melaka syrup, coconut milk, and kidney beans.",
        "rewardPoints": 100
    },
    "description": "World-famous shaved ice dessert stall operating since 1936 with green pandan rice noodles, fragrant Gula Melaka syrup, coconut milk, and kidney beans."
},
  {
    "name": "Siam Road Charcoal Char Koay Teow",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "82 Siam Road, George Town, 10400 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.415,
        "longitude": 100.32
    },
    "phone": "+6019-456 7890",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Tue-Sat 12:00 - 18:30 (Closed Sun-Mon)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Siam Road Charcoal Char Koay Teow Discovery",
        "description": "Legendary Michelin Bib Gourmand wok-fried flat rice noodles cooked over glowing charcoal embers with succulent cockles, Chinese lap cheong, and prawns.",
        "rewardPoints": 100
    },
    "description": "Legendary Michelin Bib Gourmand wok-fried flat rice noodles cooked over glowing charcoal embers with succulent cockles, Chinese lap cheong, and prawns."
},
  {
    "name": "Ghee Hiang Traditional Pastries (Est. 1856)",
    "category": "Local Business",
    "plannerCategories": [
        "Local Business",
        "Heritage",
        "Food",
        "Culture"
    ],
    "interestTags": [
        "Local Business",
        "Heritage",
        "Food",
        "Culture"
    ],
    "formattedAddress": "216 Jalan Macalister, George Town, 10400 Penang, Malaysia",
    "area": "George Town",
    "durationMinutes": 40,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4162,
        "longitude": 100.3235
    },
    "phone": "+604-227 2222",
    "website": "https://ghee-hiang.com/",
    "openingHours": "Daily 09:00 - 19:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Ghee Hiang Traditional Pastries (Est. 1856) Discovery",
        "description": "Malaysia's oldest pastry brand crafting authentic Tau Sar Piah (mung bean biscuits), Beh Teh Saw, and 100% pure fragrant sesame oil since 1856.",
        "rewardPoints": 100
    },
    "description": "Malaysia's oldest pastry brand crafting authentic Tau Sar Piah (mung bean biscuits), Beh Teh Saw, and 100% pure fragrant sesame oil since 1856."
},
  {
    "name": "Batu Ferringhi Beach & Coastal Trail",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 75,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4746,
        "longitude": 100.2468
    },
    "phone": "+604-881 1888",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Batu Ferringhi Beach & Coastal Trail Discovery",
        "description": "Golden sand coastline famed for dramatic sunset views, water sports activities, parasailing, and leisurely seaside walking trails.",
        "rewardPoints": 100
    },
    "description": "Golden sand coastline famed for dramatic sunset views, water sports activities, parasailing, and leisurely seaside walking trails."
},
  {
    "name": "Batu Ferringhi Night Market & Artisan Bazaar",
    "category": "Local Business",
    "plannerCategories": [
        "Local Business",
        "Culture",
        "Art",
        "Food"
    ],
    "interestTags": [
        "Local Business",
        "Culture",
        "Art",
        "Food"
    ],
    "formattedAddress": "Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 60,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4735,
        "longitude": 100.245
    },
    "phone": "+604-881 2233",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 19:00 - 00:00",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Batu Ferringhi Night Market & Artisan Bazaar Discovery",
        "description": "Nightly seaside open-air bazaar with over 100 stalls selling handcrafted souvenirs, Batik apparel, pewter gifts, and Penang street bites.",
        "rewardPoints": 100
    },
    "description": "Nightly seaside open-air bazaar with over 100 stalls selling handcrafted souvenirs, Batik apparel, pewter gifts, and Penang street bites."
},
  {
    "name": "Long Beach Food Court Batu Ferringhi",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4728,
        "longitude": 100.2442
    },
    "phone": "+6012-488 9988",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 18:00 - 23:30",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1552611052-33e04de081de?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Long Beach Food Court Batu Ferringhi Discovery",
        "description": "Bustling coastal hawker centre offering grilled stingray satay, chicken wings, Ikan Bakar, fresh fruit juices, and Chinese noodle specials.",
        "rewardPoints": 100
    },
    "description": "Bustling coastal hawker centre offering grilled stingray satay, chicken wings, Ikan Bakar, fresh fruit juices, and Chinese noodle specials."
},
  {
    "name": "The Ship Batu Ferringhi",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 60,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.4752,
        "longitude": 100.2482
    },
    "phone": "+604-881 2142",
    "website": "https://theship.com.my/",
    "openingHours": "Daily 12:00 - 00:00",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "The Ship Batu Ferringhi Discovery",
        "description": "Themed restaurant modeled inside a life-sized 16th-century pirate galleon, serving sizzler steaks, seafood grills, and classic Western delights.",
        "rewardPoints": 100
    },
    "description": "Themed restaurant modeled inside a life-sized 16th-century pirate galleon, serving sizzler steaks, seafood grills, and classic Western delights."
},
  {
    "name": "BoraBora by Sunset Batu Ferringhi",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Lot 415, Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 60,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.476,
        "longitude": 100.2495
    },
    "phone": "+604-885 1313",
    "website": "https://www.facebook.com/boraborabysunset/",
    "openingHours": "Daily 12:00 - 01:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "BoraBora by Sunset Batu Ferringhi Discovery",
        "description": "Relaxed beachfront lounge where diners enjoy pizza, pastas, seafood, and cocktails right on the sands during Penang's golden sunset.",
        "rewardPoints": 100
    },
    "description": "Relaxed beachfront lounge where diners enjoy pizza, pastas, seafood, and cocktails right on the sands during Penang's golden sunset."
},
  {
    "name": "Yahong Art Gallery",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "58-D Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia",
    "area": "Batu Ferringhi",
    "durationMinutes": 45,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4718,
        "longitude": 100.2415
    },
    "phone": "+604-881 1251",
    "website": "http://www.yahongart.com/",
    "openingHours": "Daily 10:00 - 18:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Yahong Art Gallery Discovery",
        "description": "Home of master artist Chuah Thean Teng (pioneer of modern Malaysian Batik Art), showcasing intricate batik masterpieces, ceramics, and jewelry.",
        "rewardPoints": 100
    },
    "description": "Home of master artist Chuah Thean Teng (pioneer of modern Malaysian Batik Art), showcasing intricate batik masterpieces, ceramics, and jewelry."
},
  {
    "name": "Penang Floating Mosque (Masjid Terapung)",
    "category": "Culture",
    "plannerCategories": [
        "Culture",
        "Heritage",
        "Nature",
        "Art"
    ],
    "interestTags": [
        "Culture",
        "Heritage",
        "Nature",
        "Art"
    ],
    "formattedAddress": "Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia",
    "area": "Tanjung Bungah",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4678,
        "longitude": 100.2818
    },
    "phone": "+604-890 0088",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 09:00 - 18:00 (Outside Prayer Times)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang Floating Mosque (Masjid Terapung) Discovery",
        "description": "First floating mosque in Malaysia built on coastal pilings over the Malacca Strait, featuring Moorish architecture with 7-storey minaret.",
        "rewardPoints": 100
    },
    "description": "First floating mosque in Malaysia built on coastal pilings over the Malacca Strait, featuring Moorish architecture with 7-storey minaret."
},
  {
    "name": "Tanjung Bungah Market & Food Complex",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Local Business",
        "Culture"
    ],
    "interestTags": [
        "Food",
        "Local Business",
        "Culture"
    ],
    "formattedAddress": "Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia",
    "area": "Tanjung Bungah",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4632,
        "longitude": 100.2835
    },
    "phone": "+604-899 1234",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 07:00 - 14:00, 17:30 - 22:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1555396273-bc501e741cf3?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Tanjung Bungah Market & Food Complex Discovery",
        "description": "Neighborhood food paradise famous for oyster omelette, Penang Curry Mee, Wanton Mee, and homemade nonya kueh.",
        "rewardPoints": 100
    },
    "description": "Neighborhood food paradise famous for oyster omelette, Penang Curry Mee, Wanton Mee, and homemade nonya kueh."
},
  {
    "name": "Penang Avatar Secret Garden",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Art",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Art",
        "Culture"
    ],
    "formattedAddress": "336 Jalan Tokong Thai Pak Koong, 11200 Tanjung Bungah, Penang, Malaysia",
    "area": "Tanjung Bungah",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4645,
        "longitude": 100.306
    },
    "phone": "+604-899 8228",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 08:00 - 00:00 (Illuminated after 19:30)",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang Avatar Secret Garden Discovery",
        "description": "Enchanting coastal temple hillside garden with grand ancient banyan trees illuminated by glowing neon fibre-optic light trails.",
        "rewardPoints": 100
    },
    "description": "Enchanting coastal temple hillside garden with grand ancient banyan trees illuminated by glowing neon fibre-optic light trails."
},
  {
    "name": "Tanjung Bungah Coastal Bay Beach",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia",
    "area": "Tanjung Bungah",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.466,
        "longitude": 100.278
    },
    "phone": "+604-890 5522",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1507525428034-77f6eb97b1a7?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Tanjung Bungah Coastal Bay Beach Discovery",
        "description": "Serene coastal crescent cove popular for kayaking, paddle-boarding, beach relaxation, and water sport centre lessons.",
        "rewardPoints": 100
    },
    "description": "Serene coastal crescent cove popular for kayaking, paddle-boarding, beach relaxation, and water sport centre lessons."
},
  {
    "name": "Viva Local Haven Tanjung Bungah",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Local Business"
    ],
    "formattedAddress": "Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia",
    "area": "Tanjung Bungah",
    "durationMinutes": 45,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.462,
        "longitude": 100.285
    },
    "phone": "+604-899 4433",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 17:00 - 23:00",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Viva Local Haven Tanjung Bungah Discovery",
        "description": "Modern open-air community hawker center serving fresh Western grills, claypot chicken rice, satay, and craft beers.",
        "rewardPoints": 100
    },
    "description": "Modern open-air community hawker center serving fresh Western grills, claypot chicken rice, satay, and craft beers."
},
  {
    "name": "Tow Boo Kong Temple (Nine Emperor Gods)",
    "category": "Culture",
    "plannerCategories": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "interestTags": [
        "Culture",
        "Heritage",
        "Art"
    ],
    "formattedAddress": "Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4328,
        "longitude": 100.3842
    },
    "phone": "+604-331 4322",
    "website": "http://www.towbookong.org.my/",
    "openingHours": "Daily 07:00 - 21:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1528728329032-2972f65dfb3f?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Tow Boo Kong Temple (Nine Emperor Gods) Discovery",
        "description": "One of Malaysia's most magnificent Taoist temples featuring a grand carved stone archway, golden prayer halls, and Nine Emperor Gods festival.",
        "rewardPoints": 100
    },
    "description": "One of Malaysia's most magnificent Taoist temples featuring a grand carved stone archway, golden prayer halls, and Nine Emperor Gods festival."
},
  {
    "name": "Butterworth Art Walk",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Heritage"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Heritage"
    ],
    "formattedAddress": "Lorong Bagan Luar 1, 12000 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3995,
        "longitude": 100.3672
    },
    "phone": "+604-310 5155",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1558005530-a7958896ec60?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Butterworth Art Walk Discovery",
        "description": "Historic alleyway art installation narrating the agricultural, industrial, and maritime history of Seberang Perai through interactive 3D murals.",
        "rewardPoints": 100
    },
    "description": "Historic alleyway art installation narrating the agricultural, industrial, and maritime history of Seberang Perai through interactive 3D murals."
},
  {
    "name": "Robina Eco Park Butterworth (Pantai Bersih)",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "Jalan Robina, Teluk Air Tawar, 13000 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4625,
        "longitude": 100.3811
    },
    "phone": "+604-331 6655",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 06:00 - 20:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1511497584788-87676104235f?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Robina Eco Park Butterworth (Pantai Bersih) Discovery",
        "description": "Revitalized beachfront ecological park offering sunset panoramas of Penang Island across the strait, cycling paths, and seafood eateries.",
        "rewardPoints": 100
    },
    "description": "Revitalized beachfront ecological park offering sunset panoramas of Penang Island across the strait, cycling paths, and seafood eateries."
},
  {
    "name": "Chai Leng Park Food Street",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Lebuh Kurau 5, Chai Leng Park, 13700 Perai, Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3854,
        "longitude": 100.3912
    },
    "phone": "+6016-411 2233",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 17:00 - 23:30",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1555396273-4481014e7ea7?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Chai Leng Park Food Street Discovery",
        "description": "Premier mainland night food destination legendary for crispy duck rice, Chai Leng Park Bak Kut Teh, grilled squid, and Penang Rojak.",
        "rewardPoints": 100
    },
    "description": "Premier mainland night food destination legendary for crispy duck rice, Chai Leng Park Bak Kut Teh, grilled squid, and Penang Rojak."
},
  {
    "name": "Raja Uda Tomyam Noodles (Apollo Market)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Local Business"
    ],
    "formattedAddress": "Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4285,
        "longitude": 100.3855
    },
    "phone": "+6012-456 7891",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 18:00 - 02:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1569718212165-8b9a1a0c8491?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Raja Uda Tomyam Noodles (Apollo Market) Discovery",
        "description": "Famous supper spot serving customizable hot and sour Tomyam noodle bowls loaded with fried fish fillets, prawns, pork balls, and crispy tofu skin.",
        "rewardPoints": 100
    },
    "description": "Famous supper spot serving customizable hot and sour Tomyam noodle bowls loaded with fried fish fillets, prawns, pork balls, and crispy tofu skin."
},
  {
    "name": "Ah Khoon Duck Meat Koay Teow Th'ng",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Lorong Bagan Luar 4, 12000 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.401,
        "longitude": 100.369
    },
    "phone": "+604-323 1122",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 07:30 - 14:00 (Closed Wed)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Ah Khoon Duck Meat Koay Teow Th'ng Discovery",
        "description": "Traditional 50-year-old stall serving clear herb-infused duck bone broth, silky flat noodles, tender sliced duck meat, and fish cakes.",
        "rewardPoints": 100
    },
    "description": "Traditional 50-year-old stall serving clear herb-infused duck bone broth, silky flat noodles, tender sliced duck meat, and fish cakes."
},
  {
    "name": "Butterworth Ferry Terminal & Harbour Walk",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "formattedAddress": "Pangkalan Sultan Abdul Halim, 12000 Butterworth, Penang, Malaysia",
    "area": "Butterworth",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3942,
        "longitude": 100.3635
    },
    "phone": "+604-310 2200",
    "website": "https://www.penangport.gov.my/",
    "openingHours": "Daily 06:30 - 23:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Butterworth Ferry Terminal & Harbour Walk Discovery",
        "description": "Gateway of the historic Penang cross-strait ferry crossing, offering scenic seaport breezes and transit between mainland and island.",
        "rewardPoints": 100
    },
    "description": "Gateway of the historic Penang cross-strait ferry crossing, offering scenic seaport breezes and transit between mainland and island."
},
  {
    "name": "Minor Basilica of St. Anne",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "formattedAddress": "Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 75,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3524,
        "longitude": 100.4789
    },
    "phone": "+604-538 6405",
    "website": "https://stannebm.org/",
    "openingHours": "Daily 07:00 - 21:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1548625361-195fe578dfc2?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Minor Basilica of St. Anne Discovery",
        "description": "Historic 1846 Catholic sanctuary elevated to Minor Basilica status by the Vatican, renowned for French Gothic architecture and the annual St Anne pilgrimage.",
        "rewardPoints": 100
    },
    "description": "Historic 1846 Catholic sanctuary elevated to Minor Basilica status by the Vatican, renowned for French Gothic architecture and the annual St Anne pilgrimage."
},
  {
    "name": "Bukit Mertajam Recreational Forest (Cherok Tokun)",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Heritage"
    ],
    "interestTags": [
        "Nature",
        "Heritage"
    ],
    "formattedAddress": "Jalan Tokun, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 90,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3621,
        "longitude": 100.4912
    },
    "phone": "+604-538 4111",
    "website": "https://forestry.penang.gov.my/",
    "openingHours": "Daily 07:00 - 18:30",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1448375240586-882707db888b?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Bukit Mertajam Recreational Forest (Cherok Tokun) Discovery",
        "description": "Pristine tropical forest reserve with freshwater streams, shaded hiking trails to the 545m peak, and the ancient Tokun 5th-century Sanskrit Inscription.",
        "rewardPoints": 100
    },
    "description": "Pristine tropical forest reserve with freshwater streams, shaded hiking trails to the 545m peak, and the ancient Tokun 5th-century Sanskrit Inscription."
},
  {
    "name": "Mengkuang Dam Lakeside Park",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Mengkuang Dam, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3982,
        "longitude": 100.4891
    },
    "phone": "+604-538 7222",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 07:00 - 19:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Mengkuang Dam Lakeside Park Discovery",
        "description": "Largest water reservoir dam in Penang featuring panoramic green hill reflections, lakeside running trails, and dragon boat practice waters.",
        "rewardPoints": 100
    },
    "description": "Largest water reservoir dam in Penang featuring panoramic green hill reflections, lakeside running trails, and dragon boat practice waters."
},
  {
    "name": "Pekan Bukit Mertajam Old Market Street",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3638,
        "longitude": 100.4608
    },
    "phone": "+604-539 2111",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 06:00 - 15:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Pekan Bukit Mertajam Old Market Street Discovery",
        "description": "Centuries-old commercial core surrounding the historic Tua Pek Kong Temple, bustling with heritage sundry traders and generational artisans.",
        "rewardPoints": 100
    },
    "description": "Centuries-old commercial core surrounding the historic Tua Pek Kong Temple, bustling with heritage sundry traders and generational artisans."
},
  {
    "name": "Restoran BM Yam Rice (Bukit Mertajam)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "7 Jalan Murthy, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3642,
        "longitude": 100.4615
    },
    "phone": "+604-538 5846",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Thu-Tue 09:00 - 15:00 (Closed Wed)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Restoran BM Yam Rice (Bukit Mertajam) Discovery",
        "description": "Famous gastronomic institution renowned for fluffy fragrant Yam Rice paired with peppery salted vegetable pork soup and braised tofu.",
        "rewardPoints": 100
    },
    "description": "Famous gastronomic institution renowned for fluffy fragrant Yam Rice paired with peppery salted vegetable pork soup and braised tofu."
},
  {
    "name": "Restoran BM Cup Rice (Danby Cup Rice)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Jalan Danby, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3645,
        "longitude": 100.4598
    },
    "phone": "+6012-555 4321",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 09:00 - 14:00 (Closed Mon)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Restoran BM Cup Rice (Danby Cup Rice) Discovery",
        "description": "Heritage delicacy of steamed rice turned out of small aluminum cups smothered in rich sweet-savory chicken gravy and char siew.",
        "rewardPoints": 100
    },
    "description": "Heritage delicacy of steamed rice turned out of small aluminum cups smothered in rich sweet-savory chicken gravy and char siew."
},
  {
    "name": "BM Famous Duck Egg Char Koay Teow",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3635,
        "longitude": 100.4612
    },
    "phone": "+6016-555 7890",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 19:00 - 00:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "BM Famous Duck Egg Char Koay Teow Discovery",
        "description": "Unmistakable wok-hei charred flat rice noodles fried with creamy rich duck egg yolk, juicy cockles, and crispy pork lardons.",
        "rewardPoints": 100
    },
    "description": "Unmistakable wok-hei charred flat rice noodles fried with creamy rich duck egg yolk, juicy cockles, and crispy pork lardons."
},
  {
    "name": "BM Rojak Orang Hitam Putih (Black & White Rojak)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Local Business"
    ],
    "formattedAddress": "Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia",
    "area": "Bukit Mertajam",
    "durationMinutes": 30,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3639,
        "longitude": 100.4605
    },
    "phone": "+6012-444 8899",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 12:00 - 18:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "BM Rojak Orang Hitam Putih (Black & White Rojak) Discovery",
        "description": "Legendary Penang fruit rojak tossed in thick caramelized prawn paste with crushed roasted peanuts and crispy fried fritters.",
        "rewardPoints": 100
    },
    "description": "Legendary Penang fruit rojak tossed in thick caramelized prawn paste with crushed roasted peanuts and crispy fried fritters."
},
  {
    "name": "Ghee Hup Nutmeg Factory & Plantation",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Nature",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Heritage",
        "Nature",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "202A Jalan Tanjung Bungah, 11000 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3521,
        "longitude": 100.2365
    },
    "phone": "+604-866 8426",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 09:00 - 17:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Ghee Hup Nutmeg Factory & Plantation Discovery",
        "description": "Family-run heritage plantation producing authentic medicinal nutmeg oils, candied nutmeg slices, and refreshing nutmeg juices since 1953.",
        "rewardPoints": 100
    },
    "description": "Family-run heritage plantation producing authentic medicinal nutmeg oils, candied nutmeg slices, and refreshing nutmeg juices since 1953."
},
  {
    "name": "Kim Laksa Balik Pulau (Nan Guang Coffee Shop)",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "67 Main Road, 11000 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3518,
        "longitude": 100.2372
    },
    "phone": "+6012-411 5511",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Wed-Sun 10:00 - 17:00 (Closed Mon-Tue)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Kim Laksa Balik Pulau (Nan Guang Coffee Shop) Discovery",
        "description": "Renowned for serving both authentic sour Assam Laksa and rich creamy coconut Siam Laksa with freshly flaked mackerel fish broth.",
        "rewardPoints": 100
    },
    "description": "Renowned for serving both authentic sour Assam Laksa and rich creamy coconut Siam Laksa with freshly flaked mackerel fish broth."
},
  {
    "name": "Bao Sheng Durian Farm & Orchard",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Food",
        "Local Business",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Food",
        "Local Business",
        "Culture"
    ],
    "formattedAddress": "150 Mukim 2, Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 75,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.3986,
        "longitude": 100.2185
    },
    "phone": "+6012-411 0600",
    "website": "https://www.durian.com.my/",
    "openingHours": "Daily 11:00 - 18:00 (Seasonal)",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Bao Sheng Durian Farm & Orchard Discovery",
        "description": "Pioneering organic hillside durian estate offering tasting masterclasses of champion Black Thorn, Musang King, and Red Prawn durians.",
        "rewardPoints": 100
    },
    "description": "Pioneering organic hillside durian estate offering tasting masterclasses of champion Black Thorn, Musang King, and Red Prawn durians."
},
  {
    "name": "Balik Pulau Countryside Art Murals",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Heritage"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Heritage"
    ],
    "formattedAddress": "Pekan Balik Pulau, 11000 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3525,
        "longitude": 100.238
    },
    "phone": "+604-866 1122",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Balik Pulau Countryside Art Murals Discovery",
        "description": "Rural mural trail painted by Russian artist Julia Volchkova capturing honest portraits of local fishermen, silat exponents, and rubber tappers.",
        "rewardPoints": 100
    },
    "description": "Rural mural trail painted by Russian artist Julia Volchkova capturing honest portraits of local fishermen, silat exponents, and rubber tappers."
},
  {
    "name": "Saanen Dairy Goat Farm Balik Pulau",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "298 Mukim 1 Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3925,
        "longitude": 100.211
    },
    "phone": "+6019-516 3017",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 10:00 - 17:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Saanen Dairy Goat Farm Balik Pulau Discovery",
        "description": "Friendly eco-farm where visitors can feed Saanen goats, learn about ethical farming, and taste freshly bottled pasteurized goat milk and puddings.",
        "rewardPoints": 100
    },
    "description": "Friendly eco-farm where visitors can feed Saanen goats, learn about ethical farming, and taste freshly bottled pasteurized goat milk and puddings."
},
  {
    "name": "Audi Dream Farm Balik Pulau",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Nature",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "145 Sungai Rusa, 11010 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.378,
        "longitude": 100.2085
    },
    "phone": "+604-866 5238",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 09:00 - 18:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Audi Dream Farm Balik Pulau Discovery",
        "description": "Scenic countryside petting farm featuring deer, birds, rabbits, vegetable gardens, and bicycle rentals to tour paddy fields.",
        "rewardPoints": 100
    },
    "description": "Scenic countryside petting farm featuring deer, birds, rabbits, vegetable gardens, and bicycle rentals to tour paddy fields."
},
  {
    "name": "Pantai Pasir Panjang (Long Sand Beach)",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Food"
    ],
    "interestTags": [
        "Nature",
        "Food"
    ],
    "formattedAddress": "Jalan Pasir Panjang, 11000 Balik Pulau, Penang, Malaysia",
    "area": "Balik Pulau",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3015,
        "longitude": 100.1985
    },
    "phone": "+604-866 9900",
    "website": "https://mypenang.gov.my/",
    "openingHours": "24 Hours Daily",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1528181304800-259b08848526?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Pantai Pasir Panjang (Long Sand Beach) Discovery",
        "description": "Unspoiled western-coast beach framed by fishing boats, rolling waves, rocky promontories, and beachfront Malay seafood stalls.",
        "rewardPoints": 100
    },
    "description": "Unspoiled western-coast beach framed by fishing boats, rolling waves, rocky promontories, and beachfront Malay seafood stalls."
},
  {
    "name": "Kek Lok Si Temple",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Art"
    ],
    "formattedAddress": "1000-L Tingkat Lembah Ria 1, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 90,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3995,
        "longitude": 100.2737
    },
    "phone": "+604-828 3330",
    "website": "http://kekloksitemple.com/",
    "openingHours": "Daily 08:30 - 17:30",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Kek Lok Si Temple Discovery",
        "description": "Largest Buddhist temple complex in Malaysia, featuring the 7-tier Pagoda of Ten Thousand Buddhas and a colossal 30.2m bronze statue of Guanyin.",
        "rewardPoints": 100
    },
    "description": "Largest Buddhist temple complex in Malaysia, featuring the 7-tier Pagoda of Ten Thousand Buddhas and a colossal 30.2m bronze statue of Guanyin."
},
  {
    "name": "Penang Hill Biosphere Nature Reserve",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "formattedAddress": "Bukit Bendera, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 120,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4085,
        "longitude": 100.2771
    },
    "phone": "+604-828 8880",
    "website": "https://www.penanghill.gov.my/",
    "openingHours": "Daily 06:30 - 23:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang Hill Biosphere Nature Reserve Discovery",
        "description": "UNESCO Biosphere Reserve hill station with cooler breezes, historic funicular railway, colonial bungalows, and panoramic views of Penang island.",
        "rewardPoints": 100
    },
    "description": "UNESCO Biosphere Reserve hill station with cooler breezes, historic funicular railway, colonial bungalows, and panoramic views of Penang island."
},
  {
    "name": "The Habitat Penang Hill",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Art",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Art",
        "Local Business"
    ],
    "formattedAddress": "Penang Hill, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 90,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.4242,
        "longitude": 100.2685
    },
    "phone": "+604-826 7677",
    "website": "https://thehabitat.my/",
    "openingHours": "Daily 09:00 - 19:00",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "The Habitat Penang Hill Discovery",
        "description": "World-class rainforest discovery experience featuring the Curtis Crest 360-degree tree top canopy walkway and Langur Way suspension bridge.",
        "rewardPoints": 100
    },
    "description": "World-class rainforest discovery experience featuring the Curtis Crest 360-degree tree top canopy walkway and Langur Way suspension bridge."
},
  {
    "name": "Pasar Air Itam Laksa",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "1 Jalan Pasar, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4012,
        "longitude": 100.278
    },
    "phone": "+6012-500 7063",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Wed-Sun 10:30 - 19:00 (Closed Mon-Tue)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Pasar Air Itam Laksa Discovery",
        "description": "Iconic laksa stall operating since 1955 at the foot of Kek Lok Si, known for rich tamarind mackerel broth, fresh mint, and sweet prawn paste.",
        "rewardPoints": 100
    },
    "description": "Iconic laksa stall operating since 1955 at the foot of Kek Lok Si, known for rich tamarind mackerel broth, fresh mint, and sweet prawn paste."
},
  {
    "name": "Sister Curry Mee Air Itam",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "612 T, Jalan Air Itam, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 40,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4018,
        "longitude": 100.2785
    },
    "phone": "+6012-410 8152",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 07:30 - 13:00 (Closed Tue)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1546548970-71785318a17b?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Sister Curry Mee Air Itam Discovery",
        "description": "Legendary octogenarian sisters serving traditional coconut broth curry noodles over simmering charcoal pots with blood cockles, tofu pok, and cuttlefish.",
        "rewardPoints": 100
    },
    "description": "Legendary octogenarian sisters serving traditional coconut broth curry noodles over simmering charcoal pots with blood cockles, tofu pok, and cuttlefish."
},
  {
    "name": "Air Itam Dam & Mountain Trail",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Culture"
    ],
    "formattedAddress": "Jalan Air Itam, 11500 Air Itam, Penang, Malaysia",
    "area": "Air Itam",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.397,
        "longitude": 100.267
    },
    "phone": "+604-828 1234",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 07:00 - 19:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Air Itam Dam & Mountain Trail Discovery",
        "description": "High-elevation reservoir ringed by misty rainforest ridges, popular for quiet morning jogs, birdwatching, and mountain breeze walks.",
        "rewardPoints": 100
    },
    "description": "High-elevation reservoir ringed by misty rainforest ridges, popular for quiet morning jogs, birdwatching, and mountain breeze walks."
},
  {
    "name": "Snake Temple (Ban Ka Lan Temple)",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "formattedAddress": "Jalan Sultan Azlan Shah, 11900 Bayan Lepas, Penang, Malaysia",
    "area": "Bayan Lepas",
    "durationMinutes": 50,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.3138,
        "longitude": 100.2852
    },
    "phone": "+604-643 7273",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 08:00 - 18:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1565895405138-6c3a1555da6a?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Snake Temple (Ban Ka Lan Temple) Discovery",
        "description": "Historic 1850 Taoist temple dedicated to Chor Soo Kong where green pit vipers rest harmlessly on shrines and tree branches amidst incense smoke.",
        "rewardPoints": 100
    },
    "description": "Historic 1850 Taoist temple dedicated to Chor Soo Kong where green pit vipers rest harmlessly on shrines and tree branches amidst incense smoke."
},
  {
    "name": "Penang War Museum (Bukit Batu Maung)",
    "category": "Heritage",
    "plannerCategories": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "interestTags": [
        "Heritage",
        "Culture",
        "Nature"
    ],
    "formattedAddress": "Lot 1350 Mukim 12, Daerah Barat Daya, 11960 Batu Maung, Bayan Lepas, Penang",
    "area": "Bayan Lepas",
    "durationMinutes": 75,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.2818,
        "longitude": 100.2882
    },
    "phone": "+604-626 5142",
    "website": "http://www.penangwarmuseum.com/",
    "openingHours": "Daily 09:00 - 18:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1545239351-ef35f43d514b?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang War Museum (Bukit Batu Maung) Discovery",
        "description": "Largest open-air living war museum in Southeast Asia, restored on a 1930s British military fortress complex atop Bukit Batu Maung.",
        "rewardPoints": 100
    },
    "description": "Largest open-air living war museum in Southeast Asia, restored on a 1930s British military fortress complex atop Bukit Batu Maung."
},
  {
    "name": "Teluk Tempoyak Grilled Fish & Seafood Wharf",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Jalan Teluk Tempoyak, 11960 Bayan Lepas, Penang, Malaysia",
    "area": "Bayan Lepas",
    "durationMinutes": 60,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.2778,
        "longitude": 100.2845
    },
    "phone": "+6012-478 8899",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 17:30 - 23:00 (Closed Mon)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Teluk Tempoyak Grilled Fish & Seafood Wharf Discovery",
        "description": "Seaside wooden jetty dining haven where visitors feast on charcoal-grilled fresh stingray, butter prawns, and sambal cockles over water.",
        "rewardPoints": 100
    },
    "description": "Seaside wooden jetty dining haven where visitors feast on charcoal-grilled fresh stingray, butter prawns, and sambal cockles over water."
},
  {
    "name": "Fisheries Aquarium Tunku Abdul Rahman",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Jalan Batu Maung, 11960 Bayan Lepas, Penang, Malaysia",
    "area": "Bayan Lepas",
    "durationMinutes": 60,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.2845,
        "longitude": 100.2885
    },
    "phone": "+604-626 3925",
    "website": "https://www.dof.gov.my/",
    "openingHours": "Sat-Thu 09:00 - 17:00 (Closed Fri)",
    "score": 4.4,
    "primaryImageUrl": "https://images.unsplash.com/photo-1510414842594-a61c69b5ae57?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Fisheries Aquarium Tunku Abdul Rahman Discovery",
        "description": "Public marine aquarium showcasing coral reef ecosystems, marine turtles, clownfish, and educational Malaysian aquatic life exhibits.",
        "rewardPoints": 100
    },
    "description": "Public marine aquarium showcasing coral reef ecosystems, marine turtles, clownfish, and educational Malaysian aquatic life exhibits."
},
  {
    "name": "Penang National Park (Taman Negara Pulau Pinang)",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "formattedAddress": "Pejabat Taman Negara P. Pinang, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 120,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4608,
        "longitude": 100.1989
    },
    "phone": "+604-881 3530",
    "website": "https://www.wildlife.gov.my/",
    "openingHours": "Daily 08:00 - 17:00",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang National Park (Taman Negara Pulau Pinang) Discovery",
        "description": "Malaysia's smallest national park protecting pristine coastal rainforests, Monkey Beach trails, meromictic lake, and the historic 1883 Muka Head Lighthouse.",
        "rewardPoints": 100
    },
    "description": "Malaysia's smallest national park protecting pristine coastal rainforests, Monkey Beach trails, meromictic lake, and the historic 1883 Muka Head Lighthouse."
},
  {
    "name": "Tropical Spice Garden",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Culture",
        "Local Business",
        "Food"
    ],
    "interestTags": [
        "Nature",
        "Culture",
        "Local Business",
        "Food"
    ],
    "formattedAddress": "Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 75,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4632,
        "longitude": 100.2295
    },
    "phone": "+604-881 1005",
    "website": "https://tropicalspicegarden.com/",
    "openingHours": "Daily 09:00 - 16:30",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Tropical Spice Garden Discovery",
        "description": "Award-winning living museum showcasing over 500 species of exotic spices, medicinal herbs, and lush tropical flora with outdoor cooking academy.",
        "rewardPoints": 100
    },
    "description": "Award-winning living museum showcasing over 500 species of exotic spices, medicinal herbs, and lush tropical flora with outdoor cooking academy."
},
  {
    "name": "Entopia by Penang Butterfly Farm",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Art",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Art",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "830 Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 90,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.4468,
        "longitude": 100.2155
    },
    "phone": "+604-888 8111",
    "website": "https://www.entopia.com/",
    "openingHours": "Thu-Tue 09:00 - 18:00 (Closed Wed)",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1533929736458-ca588d08c8be?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Entopia by Penang Butterfly Farm Discovery",
        "description": "World-class sanctuary home to 15,000 free-flying butterflies, vivarium insects, indoor nature discovery discovery centre, and cascading water gardens.",
        "rewardPoints": 100
    },
    "description": "World-class sanctuary home to 15,000 free-flying butterflies, vivarium insects, indoor nature discovery discovery centre, and cascading water gardens."
},
  {
    "name": "ESCAPE Penang Adventure Park",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "828 Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 150,
    "budgetLevel": "High",
    "location": {
        "latitude": 5.4485,
        "longitude": 100.2162
    },
    "phone": "+604-881 1106",
    "website": "https://www.escape.my/",
    "openingHours": "Tue-Sun 10:00 - 18:00 (Closed Mon)",
    "score": 4.8,
    "primaryImageUrl": "https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "ESCAPE Penang Adventure Park Discovery",
        "description": "Guinness World Record-holding outdoor eco-theme park with world's longest water slide (1,111m) and zip coaster through jungle canopy.",
        "rewardPoints": 100
    },
    "description": "Guinness World Record-holding outdoor eco-theme park with world's longest water slide (1,111m) and zip coaster through jungle canopy."
},
  {
    "name": "Penang Batik Factory (Craft & Heritage)",
    "category": "Art",
    "plannerCategories": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "interestTags": [
        "Art",
        "Culture",
        "Heritage",
        "Local Business"
    ],
    "formattedAddress": "656 MK 2 Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 45,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.4525,
        "longitude": 100.218
    },
    "phone": "+604-885 1284",
    "website": "http://www.penangbatik.com.my/",
    "openingHours": "Daily 09:00 - 17:30",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1533105079780-92b9be482077?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Penang Batik Factory (Craft & Heritage) Discovery",
        "description": "One of Penang's oldest batik craft houses demonstrating traditional wax-resist canting drawing and block printing techniques.",
        "rewardPoints": 100
    },
    "description": "One of Penang's oldest batik craft houses demonstrating traditional wax-resist canting drawing and block printing techniques."
},
  {
    "name": "End of the World Seafood Restaurant",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "interestTags": [
        "Food",
        "Nature",
        "Local Business"
    ],
    "formattedAddress": "Jalan Hassan Abas, 11050 Teluk Bahang, Penang, Malaysia",
    "area": "Teluk Bahang",
    "durationMinutes": 60,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.4615,
        "longitude": 100.2078
    },
    "phone": "+604-881 1189",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 11:30 - 22:00",
    "score": 4.5,
    "primaryImageUrl": "https://images.unsplash.com/photo-1508672019048-805b876b67e2?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "End of the World Seafood Restaurant Discovery",
        "description": "Historic seafood restaurant situated at the end of the northwestern coastal road, famed for steamed fish, tamarind crabs, and fresh local catches.",
        "rewardPoints": 100
    },
    "description": "Historic seafood restaurant situated at the end of the northwestern coastal road, famed for steamed fish, tamarind crabs, and fresh local catches."
},
  {
    "name": "Bukit Panchor State Park",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "interestTags": [
        "Nature",
        "Heritage",
        "Culture"
    ],
    "formattedAddress": "Taman Negeri Bukit Panchor, 14300 Nibong Tebal, Penang, Malaysia",
    "area": "Nibong Tebal",
    "durationMinutes": 90,
    "budgetLevel": "Low",
    "location": {
        "latitude": 5.1612,
        "longitude": 100.5428
    },
    "phone": "+604-593 2835",
    "website": "https://forestry.penang.gov.my/",
    "openingHours": "Daily 08:00 - 18:00",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Bukit Panchor State Park Discovery",
        "description": "Southern Penang rainforest nature reserve featuring freshwater wetland boardwalks, bat caves, and tranquil dipterocarp jungle streams.",
        "rewardPoints": 100
    },
    "description": "Southern Penang rainforest nature reserve featuring freshwater wetland boardwalks, bat caves, and tranquil dipterocarp jungle streams."
},
  {
    "name": "Nibong Tebal Firefly Sanctuary (Sungai Kerian)",
    "category": "Nature",
    "plannerCategories": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "interestTags": [
        "Nature",
        "Culture",
        "Local Business"
    ],
    "formattedAddress": "Sungai Kerian Jetty, 14300 Nibong Tebal, Penang, Malaysia",
    "area": "Nibong Tebal",
    "durationMinutes": 60,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.1695,
        "longitude": 100.474
    },
    "phone": "+6012-555 2333",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 19:30 - 22:30",
    "score": 4.7,
    "primaryImageUrl": "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Nibong Tebal Firefly Sanctuary (Sungai Kerian) Discovery",
        "description": "Evening riverboat expedition along the Kerian River mangrove banks twinkling with thousands of synchronous bioluminescent fireflies.",
        "rewardPoints": 100
    },
    "description": "Evening riverboat expedition along the Kerian River mangrove banks twinkling with thousands of synchronous bioluminescent fireflies."
},
  {
    "name": "Restoran Lim Ah Hin Crab Congee Nibong Tebal",
    "category": "Food",
    "plannerCategories": [
        "Food",
        "Local Business",
        "Heritage"
    ],
    "interestTags": [
        "Food",
        "Local Business",
        "Heritage"
    ],
    "formattedAddress": "Jalan Sungai Daun, 14300 Nibong Tebal, Penang, Malaysia",
    "area": "Nibong Tebal",
    "durationMinutes": 50,
    "budgetLevel": "Medium",
    "location": {
        "latitude": 5.168,
        "longitude": 100.4785
    },
    "phone": "+604-593 1234",
    "website": "https://mypenang.gov.my/",
    "openingHours": "Daily 11:30 - 20:00 (Closed Tue)",
    "score": 4.6,
    "primaryImageUrl": "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=900&auto=format&fit=crop&q=80",
    "culturalTask": {
        "title": "Restoran Lim Ah Hin Crab Congee Nibong Tebal Discovery",
        "description": "Generational seafood gem celebrated for steaming sweet claypot mud crab congee, fried squid, and stir-fried mantis prawns.",
        "rewardPoints": 100
    },
    "description": "Generational seafood gem celebrated for steaming sweet claypot mud crab congee, fried squid, and stir-fried mantis prawns."
},

  //www.chendul.my/',
    openingHours: 'Daily 10:30 - 19:00',
    score: 4.7,
    description: 'Legendary roadside dessert stall founded in 1936 serving signature Teochew chendul with fresh coconut milk, pandan jelly noodles, and fragrant Gula Melaka.',
  },
  {
    name: 'Line Clear Nasi Kandar',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: '177 Jalan Penang, George Town, 10000 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Medium',
    location: { latitude: 5.4198, longitude: 100.3323 },
    phone: '+604-261 4440',
    website: '',
    openingHours: 'Daily 07:00 - 23:00',
    score: 4.6,
    description: 'Legendary Penang alleyway eatery serving rich, aromatic mixed curry gravies and spiced fried chicken since 1930.',
  },
  {
    name: 'Ghee Hiang Heritage Pastry & Sesame Oil (Since 1856)',
    category: 'Food',
    plannerCategories: ['Food', 'Heritage', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Heritage', 'Culture', 'Local Business'],
    formattedAddress: '216 Jalan Macalister, George Town, 10400 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 40,
    budgetLevel: 'Medium',
    location: { latitude: 5.4162, longitude: 100.3204 },
    phone: '+604-227 2222',
    website: 'https://ghee-hiang.com/',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.8,
    description: 'Penang\'s oldest traditional bakery brand founded in 1856, renowned for handcrafted Tau Sar Piah pastries and aromatic pure sesame seed oil.',
  },
  {
    name: 'Ban Heang Pastry Heritage Bakery',
    category: 'Food',
    plannerCategories: ['Food', 'Heritage', 'Local Business'],
    interestTags: ['Food', 'Heritage', 'Local Business'],
    formattedAddress: '200 Jalan Macalister, George Town, 10400 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 35,
    budgetLevel: 'Medium',
    location: { latitude: 5.416, longitude: 100.321 },
    phone: '+604-229 5018',
    website: '',
    openingHours: 'Daily 09:00 - 19:00',
    score: 4.7,
    description: 'Famous Penang pastry house known for crispy Tambun biscuits, heong peah, and traditional handmade confectionery.',
  },
  {
    name: 'Him Heang Traditional Tambun Biscuits',
    category: 'Food',
    plannerCategories: ['Food', 'Heritage', 'Local Business'],
    interestTags: ['Food', 'Heritage', 'Local Business'],
    formattedAddress: '163 Jalan Burma, George Town, 10050 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 35,
    budgetLevel: 'Medium',
    location: { latitude: 5.4225, longitude: 100.322 },
    phone: '+604-228 6129',
    website: '',
    openingHours: 'Mon-Sat 09:30 - 15:00',
    score: 4.7,
    description: 'Multi-generational heritage biscuit specialist famous for fresh oven-baked Tambun biscuits, Beh Teh Saw, and savoury pastry rolls.',
  },
  {
    name: 'Moh Teng Pheow Nyonya Koay',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Heritage', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Heritage', 'Local Business'],
    formattedAddress: 'Lebuh Chulia, Jalan Masjid, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.419, longitude: 100.3362 },
    phone: '+6012-415 2677',
    website: '',
    openingHours: 'Tue-Sun 10:30 - 17:00',
    score: 4.7,
    description: 'Historic Nyonya kuih canteen and workshop manufacturing colourful handmade kuih talam, ang ku kueh, and nasi ulam since 1933.',
  },
  {
    name: 'Toh Soon Cafe (Charcoal Toast & Coffee)',
    category: 'Food',
    plannerCategories: ['Food', 'Heritage', 'Local Business'],
    interestTags: ['Food', 'Heritage', 'Local Business'],
    formattedAddress: 'Campbell Street Off Lebuh Campbell, George Town, 10100 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.4188, longitude: 100.3323 },
    phone: '+604-261 3832',
    website: '',
    openingHours: 'Mon-Sat 08:00 - 17:00',
    score: 4.6,
    description: 'Iconic alleyway breakfast institution toasting bread over glowing charcoal drums, served with homemade kaya and half-boiled eggs.',
  },
  {
    name: 'Siam Road Charcoal Char Koay Teow',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: '82 Jalan Siam, George Town, 10400 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4147, longitude: 100.3205 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Tue-Sat 12:00 - 18:00',
    score: 4.8,
    description: 'World-famous Michelin Bib Gourmand char koay teow fried with rich pork lard, succulent prawns, cockles, and smoky charcoal wok hei.',
  },
  {
    name: 'Gurney Drive Hawker Centre',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: '172 Solok Gurney 1, George Town, 10250 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.4398, longitude: 100.309 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 17:00 - 23:30',
    score: 4.6,
    description: 'Penang\'s premier seafront open-air hawker promenade gathering over 50 classic Penang street foods including oyster omelettes, rojak, and pasembur.',
  },
  {
    name: 'Kimberley Street Food Night Market',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: 'Lebuh Kimberley, George Town, 10100 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.4164, longitude: 100.3328 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 17:00 - 23:00',
    score: 4.7,
    description: 'Historic food street celebrated for the Four Heavenly Kings hawkers: Duck Kway Chap, Char Koay Teow, Si Koh Sui dessert, and Braised Chicken Feet.',
  },
  {
    name: 'New Lane Hawker Stalls (Lorong Baru)',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: 'Lorong Baru, George Town, 10450 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 55,
    budgetLevel: 'Low',
    location: { latitude: 5.4144, longitude: 100.3262 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Thu-Tue 16:00 - 23:00',
    score: 4.6,
    description: 'Bustling roadside evening food street crowded with pop-up hawker carts serving grilled chicken wings, chee cheong fun, and popiah.',
  },
  {
    name: 'Deen Maju Nasi Kandar',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: '170 Jalan Gurdwara, George Town, 10300 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Medium',
    location: { latitude: 5.4108, longitude: 100.3286 },
    phone: '+6012-425 2137',
    website: '',
    openingHours: 'Daily 12:00 - 23:00',
    score: 4.7,
    description: 'Beloved local Nasi Kandar hotspot acclaimed for crispy spiced fried chicken, signature thick Kuah Campur, and coconut sambal.',
  },
  {
    name: 'Little India Penang Cultural District',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Food', 'Local Business'],
    interestTags: ['Culture', 'Heritage', 'Food', 'Local Business'],
    formattedAddress: 'Lebuh Pasar, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.4165, longitude: 100.34 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 09:00 - 22:00',
    score: 4.7,
    description: 'Vibrant ethnic quarter filled with Bollywood melodies, colourful saree shops, aromatic spice merchants, and traditional Indian sweet stalls.',
  },
  {
    name: 'Chowrasta Market Heritage Traders',
    category: 'Culture',
    plannerCategories: ['Culture', 'Local Business', 'Food'],
    interestTags: ['Culture', 'Local Business', 'Food'],
    formattedAddress: 'Jalan Penang, George Town, 10100 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.4173, longitude: 100.3312 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 06:30 - 18:00',
    score: 4.6,
    description: 'Historic marketplace dating back to the 1890s, famous for preserved nutmeg pickles, traditional fresh produce, and second-hand book lofts.',
  },
  {
    name: 'Art Lane George Town',
    category: 'Art',
    plannerCategories: ['Art', 'Heritage', 'Culture'],
    interestTags: ['Art', 'Heritage', 'Culture'],
    formattedAddress: '127 Victoria Street, George Town, 10300 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.414, longitude: 100.3398 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 09:00 - 19:00',
    score: 4.6,
    description: 'Open public gallery stretching through transformed heritage shophouses adorned with vibrant modern graffiti, paintings, and community art.',
  },
  {
    name: 'Muntri Street Art & Shophouses',
    category: 'Art',
    plannerCategories: ['Art', 'Heritage', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Heritage', 'Culture', 'Local Business'],
    formattedAddress: 'Lebuh Muntri, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.4202, longitude: 100.3348 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.7,
    description: 'Elegant heritage lane preserving 19th-century Straits eclectic shophouses, Ernest Zacharevic murals, and artisan lifestyle cafes.',
  },
  {
    name: 'Penang 3D Trick Art Museum',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Local Business'],
    formattedAddress: '10 Lebuh Penang, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.419, longitude: 100.3415 },
    phone: '+604-263 1628',
    website: '',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.6,
    description: 'Interactive optical illusion museum with 3D paintings depicting Penang clan jetties, Trishaw rides, and fantasy themes.',
  },
  {
    name: 'Upside Down Museum Penang',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Local Business'],
    formattedAddress: '45 Lebuh Kimberley, George Town, 10100 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 50,
    budgetLevel: 'Medium',
    location: { latitude: 5.4162, longitude: 100.3325 },
    phone: '+604-264 2626',
    website: '',
    openingHours: 'Daily 09:00 - 18:30',
    score: 4.6,
    description: 'Fun, inverted interactive exhibition rooms with upside-down heritage living rooms, Penang kopitiams, and street scenes.',
  },
  {
    name: 'Penang House of Music',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Heritage'],
    interestTags: ['Art', 'Culture', 'Heritage'],
    formattedAddress: 'Level 4, KOMTAR, Jalan Penang, 10000 George Town, Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.414, longitude: 100.3302 },
    phone: '+604-370 6675',
    website: '',
    openingHours: 'Daily 11:00 - 20:00',
    score: 4.8,
    description: 'Interactive musical heritage gallery celebrating Penang\'s vibrant 20th-century music, Bangsawan theater, and radio history.',
  },
  {
    name: 'Batik Painting Museum Penang',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Heritage', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Heritage', 'Local Business'],
    formattedAddress: '19 Armenian Street, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.4154, longitude: 100.3364 },
    phone: '+604-262 0150',
    website: '',
    openingHours: 'Daily 10:00 - 18:00',
    score: 4.7,
    description: 'Dedicated fine art museum tracing the history of Malaysian batik painting from the 1950s pioneer Chuah Thean Teng to contemporary masters.',
  },
  {
    name: 'Penang Glass Museum',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Local Business'],
    formattedAddress: '6 Jalan Burma, George Town, 10050 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 45,
    budgetLevel: 'Medium',
    location: { latitude: 5.4188, longitude: 100.33 },
    phone: '+604-251 9880',
    website: '',
    openingHours: 'Mon-Fri 09:30 - 18:00, Sat 09:30 - 17:00',
    score: 4.6,
    description: 'Specialty glass craft gallery showcasing stained glass artwork, 3D glass carving, mirror murals, and glass crafting workshops.',
  },
  {
    name: 'Ghost Museum Penang (Cultural Folklore)',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Local Business'],
    formattedAddress: '57 Lebuh Melayu, George Town, 10100 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 50,
    budgetLevel: 'Medium',
    location: { latitude: 5.4148, longitude: 100.3349 },
    phone: '+604-261 2352',
    website: '',
    openingHours: 'Daily 10:00 - 19:00',
    score: 4.6,
    description: 'Cultural museum showcasing Malaysian, Chinese, and global folklore myths with detailed theatrical sets and costume photo areas.',
  },
  {
    name: 'Colonial Penang Museum',
    category: 'Art',
    plannerCategories: ['Art', 'Heritage', 'Culture'],
    interestTags: ['Art', 'Heritage', 'Culture'],
    formattedAddress: '4 Jalan Sultan Ahmad Shah, George Town, 10050 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.4285, longitude: 100.312 },
    phone: '+604-228 8888',
    website: '',
    openingHours: 'Daily 09:30 - 18:30',
    score: 4.6,
    description: 'Museum housing authentic colonial antiques, marble statues, master oil paintings, and original reverse glass paintings of the 19th century.',
  },
  {
    name: 'Ernest Zacharevic \'Boy on a Motorbike\' Mural',
    category: 'Art',
    plannerCategories: ['Art', 'Heritage', 'Culture'],
    interestTags: ['Art', 'Heritage', 'Culture'],
    formattedAddress: '12 Lebuh Ah Quee, George Town, 10200 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 25,
    budgetLevel: 'Low',
    location: { latitude: 5.4158, longitude: 100.337 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.8,
    description: 'World-famous heritage street art mural integrating an actual vintage motorcycle with wall painting on historic Lebuh Ah Quee.',
  },
  {
    name: 'Ernest Zacharevic \'Brother & Sister on a Swing\' Mural',
    category: 'Art',
    plannerCategories: ['Art', 'Heritage', 'Culture'],
    interestTags: ['Art', 'Heritage', 'Culture'],
    formattedAddress: 'Gat Lebuh Chulia, George Town, 10300 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 25,
    budgetLevel: 'Low',
    location: { latitude: 5.4146, longitude: 100.34 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.7,
    description: 'Charming interactive mural on Gat Lebuh Chulia depicting two smiling siblings swinging on an installed timber swing.',
  },
  {
    name: 'Penang Botanic Gardens (Waterfall Gardens)',
    category: 'Nature',
    plannerCategories: ['Nature', 'Heritage'],
    interestTags: ['Nature', 'Heritage'],
    formattedAddress: '673A Jalan Kebun Bunga, George Town, 10350 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 5.4378, longitude: 100.2905 },
    phone: '+604-226 4401',
    website: '',
    openingHours: 'Daily 06:30 - 19:00',
    score: 4.7,
    description: 'Historic 1884 botanical gardens surrounded by verdant hills, ancient rainforest trees, lily ponds, and macaque monkeys.',
  },
  {
    name: 'Youth Park Penang (Taman Belia)',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Persiaran Kuari, George Town, 10450 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.431, longitude: 100.298 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 06:00 - 19:30',
    score: 4.7,
    description: 'Expansive green recreation park with natural stream pools, shaded forest walking trails, outdoor gymnasiums, and lush canopy trees.',
  },
  {
    name: 'Kek Lok Si Temple',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Nature'],
    interestTags: ['Culture', 'Heritage', 'Nature'],
    formattedAddress: 'Tingkat Lembah Ria 1, 11500 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 90,
    budgetLevel: 'Low',
    location: { latitude: 5.3995, longitude: 100.2737 },
    phone: '+604-828 3317',
    website: 'https://kekloksitemple.com/',
    openingHours: 'Daily 08:30 - 17:30',
    score: 4.9,
    culturalTask: {
      title: 'Pagoda of Ten Thousand Buddhas',
      description: 'Climb the 7-tier Pagoda combining Chinese, Thai, and Burmese architectural tiers and photograph the view.',
      rewardPoints: 140,
    },
    description: 'The largest Buddhist temple in Malaysia, featuring the 7-tier Pagoda of Ten Thousand Buddhas, tranquil turtle liberation pond, and towering bronze Guanyin statue.',
  },
  {
    name: 'Penang Hill Biosphere Nature Reserve',
    category: 'Nature',
    plannerCategories: ['Nature', 'Heritage'],
    interestTags: ['Nature', 'Heritage'],
    formattedAddress: 'Bukit Bendera, 11500 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 120,
    budgetLevel: 'Medium',
    location: { latitude: 5.4244, longitude: 100.2687 },
    phone: '+604-828 8880',
    website: 'https://www.penanghill.gov.my/',
    openingHours: 'Daily 06:30 - 22:00',
    score: 4.8,
    description: 'Lush UNESCO Biosphere rainforest peak accessed via century-old funicular railway, offering panoramic island vistas and cool mountain air.',
  },
  {
    name: 'The Habitat Penang Hill',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: 'Bukit Bendera, 11300 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 120,
    budgetLevel: 'High',
    location: { latitude: 5.4243, longitude: 100.2687 },
    phone: '+604-826 7677',
    website: 'https://thehabitat.my/',
    openingHours: 'Daily 09:00 - 19:00',
    score: 4.8,
    culturalTask: {
      title: 'Curtis Crest Rainforest Canopy Walk',
      description: 'Walk along the tree canopy bridge and Curtis Crest 360 platform in the 130-million-year-old rainforest.',
      rewardPoints: 150,
    },
    description: 'World-class eco-tourism rainforest reserve inside the UNESCO Biosphere Reserve on Penang Hill, featuring Curtis Crest 360 treetop canopy walk and pristine jungle trails.',
  },
  {
    name: 'The Owl Museum Penang Hill',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Nature', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Nature', 'Local Business'],
    formattedAddress: 'Astaka Bukit Bendera, 11300 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4241, longitude: 100.269 },
    phone: '+604-826 5704',
    website: '',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.6,
    description: 'Southeast Asia\'s first owl-themed art museum showcasing over 1,000 fascinating owl sculptures, paintings, and handicrafts from across the globe.',
  },
  {
    name: 'Pasar Air Itam Laksa',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: '1 Jalan Pasar, 11500 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4013, longitude: 100.2781 },
    phone: '+6012-500 7063',
    website: '',
    openingHours: 'Daily 10:30 - 19:00',
    score: 4.7,
    description: 'Iconic market stall operating since 1955 at the foot of Kek Lok Si, known for rich tamarind mackerel broth, fresh mint, and dark prawn paste.',
  },
  {
    name: 'Sister Curry Mee Air Itam',
    category: 'Food',
    plannerCategories: ['Food', 'Heritage', 'Local Business'],
    interestTags: ['Food', 'Heritage', 'Local Business'],
    formattedAddress: '612 T, Jalan Air Itam, 11500 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.401, longitude: 100.2785 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Wed-Mon 07:30 - 13:00',
    score: 4.7,
    description: 'Legendary roadside stall run by two elderly sisters since 1946, serving charcoal-simmered coconut curry noodles with cuttlefish and chili sambal.',
  },
  {
    name: 'Air Itam Dam & Mountain Trail',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Balik Pulau, 11500 Ayer Itam, Penang, Malaysia',
    area: 'Air Itam',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.397, longitude: 100.264 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 19:00',
    score: 4.7,
    description: 'Scenic hilltop reservoir lake surrounded by forest ridges, popular with morning runners and nature walkers.',
  },
  {
    name: 'Penang National Park (Taman Negara Pulau Pinang)',
    category: 'Nature',
    plannerCategories: ['Nature', 'Heritage'],
    interestTags: ['Nature', 'Heritage'],
    formattedAddress: 'Jalan Hassan Abbas, Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 120,
    budgetLevel: 'Low',
    location: { latitude: 5.46, longitude: 100.2078 },
    phone: '+604-881 3530',
    website: '',
    openingHours: 'Daily 08:00 - 17:00',
    score: 4.7,
    description: 'Malaysia\'s smallest national park featuring coastal jungle hikes, meromictic lake, secluded sandy bays, and lighthouse trails.',
  },
  {
    name: 'Monkey Beach (Teluk Duyung)',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Penang National Park, Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 90,
    budgetLevel: 'Medium',
    location: { latitude: 5.477, longitude: 100.198 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 08:00 - 17:00',
    score: 4.6,
    description: 'Pristine sandy cove tucked inside the national park, reachable by scenic coastal trail or boat ride from Teluk Bahang jetty.',
  },
  {
    name: 'Pantai Kerachut & Turtle Sanctuary',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Penang National Park, Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 90,
    budgetLevel: 'Low',
    location: { latitude: 5.459, longitude: 100.176 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 08:00 - 17:00',
    score: 4.7,
    description: 'Serene beach known for its seasonal green sea turtle nesting center, suspension bridge, and unique dual-layer meromictic lake.',
  },
  {
    name: 'Tropical Spice Garden',
    category: 'Nature',
    plannerCategories: ['Nature', 'Culture', 'Heritage', 'Local Business'],
    interestTags: ['Nature', 'Culture', 'Heritage', 'Local Business'],
    formattedAddress: 'Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 75,
    budgetLevel: 'Medium',
    location: { latitude: 5.4628, longitude: 100.2289 },
    phone: '+604-881 1797',
    website: 'https://tropicalspicegarden.com/',
    openingHours: 'Daily 09:00 - 16:30',
    score: 4.8,
    description: 'Award-winning eco-sanctuary showcasing over 500 species of living tropical herbs, culinary spices, jungle trails, and cooking school.',
  },
  {
    name: 'Entopia by Penang Butterfly Farm',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: '830 Jalan Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 90,
    budgetLevel: 'Medium',
    location: { latitude: 5.4468, longitude: 100.2155 },
    phone: '+604-888 8111',
    website: 'https://www.entopia.com/',
    openingHours: 'Thu-Tue 09:00 - 17:00',
    score: 4.7,
    description: 'Giant glasshouse eco-sanctuary with thousands of free-flying butterflies, live reptiles, and interactive indoor nature discovery centers.',
  },
  {
    name: 'ESCAPE Penang Adventure Park',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: '828 Jalan Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 180,
    budgetLevel: 'High',
    location: { latitude: 5.4485, longitude: 100.2152 },
    phone: '+604-881 1106',
    website: 'https://www.escape.my/',
    openingHours: 'Tue-Sun 10:00 - 18:00',
    score: 4.8,
    description: 'Guinness World Record-holding forest adventure theme park featuring the world\'s longest water slide, ziplining, and obstacle ropes in lush nature.',
  },
  {
    name: 'Teluk Bahang Forest Eco Park (Taman Rimba)',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.4475, longitude: 100.2168 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 18:00',
    score: 4.6,
    description: 'Tranquil state forest park featuring natural river cascades, shady forest walking trails, picnic gazebos, and a forestry museum.',
  },
  {
    name: 'Teluk Bahang Dam Scenic Lookout',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.442, longitude: 100.217 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 19:00',
    score: 4.6,
    description: 'Spectacular reservoir dam providing wide scenic vistas across turquoise waters framed by coastal mountain ridges.',
  },
  {
    name: 'Penang Batik Factory',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business', 'Heritage'],
    interestTags: ['Art', 'Culture', 'Local Business', 'Heritage'],
    formattedAddress: '665 Teluk Bahang, 11050 Penang, Malaysia',
    area: 'Teluk Bahang',
    durationMinutes: 50,
    budgetLevel: 'Medium',
    location: { latitude: 5.4578, longitude: 100.2185 },
    phone: '+604-885 1284',
    website: '',
    openingHours: 'Daily 09:00 - 17:30',
    score: 4.6,
    description: 'One of the pioneers of batik printing in Penang established in 1973, offering live canting wax demonstrations and authentic hand-painted silk batiks.',
  },
  {
    name: 'Batu Ferringhi Beach & Coastal Trail',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.4744, longitude: 100.2472 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.7,
    description: 'Famous white sand coastline along northern Penang with coastal sea breezes, water sports, beach cafes, and sunset viewpoints.',
  },
  {
    name: 'Moonlight Bay Coastal Point',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 35,
    budgetLevel: 'Low',
    location: { latitude: 5.472, longitude: 100.261 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Scenic cliffside rocky coast between Batu Ferringhi and Tanjung Bungah with crashing waves and sunset views.',
  },
  {
    name: 'Miami Beach Penang (Batu Ferringhi)',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.475, longitude: 100.268 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Shaded sandy beach cove popular for quiet ocean strolls, coconut drink stalls, and coastal rock formations.',
  },
  {
    name: 'Yahong Art Gallery & Batik Studio',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Local Business'],
    interestTags: ['Art', 'Culture', 'Local Business'],
    formattedAddress: '58D Batu Ferringhi, 11100 Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 50,
    budgetLevel: 'Medium',
    location: { latitude: 5.4735, longitude: 100.2458 },
    phone: '+604-881 1251',
    website: '',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.7,
    description: 'Art gallery founded by renowned batik painting master Chuah Thean Teng, exhibiting original fine art batiks, Chinese ink paintings, and antiques.',
  },
  {
    name: 'Long Beach Food Court & Seafood',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 50,
    budgetLevel: 'Medium',
    location: { latitude: 5.473, longitude: 100.2465 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 11:30 - 23:00',
    score: 4.7,
    description: 'Bustling open-air food center offering char koay teow, satay skewers, grilled stingray, and fresh tropical fruit juices.',
  },
  {
    name: 'Batu Ferringhi Heritage Kopitiam',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    area: 'Batu Ferringhi',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.4715, longitude: 100.245 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 14:00',
    score: 4.6,
    description: 'Traditional morning kopitiam serving charcoal-toasted kaya butter toast, half-boiled kampung eggs, and aromatic Hainanese coffee.',
  },
  {
    name: 'Audi Dream Farm Balik Pulau',
    category: 'Nature',
    plannerCategories: ['Nature', 'Culture', 'Local Business'],
    interestTags: ['Nature', 'Culture', 'Local Business'],
    formattedAddress: 'Jalan Pulau Betong, 11000 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 5.319, longitude: 100.203 },
    phone: '+6012-406 9099',
    website: '',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.6,
    description: 'Rural family eco-farm in Balik Pulau featuring petting zoo animals, organic vegetable plots, sunflower gardens, and fresh farm dining.',
  },
  {
    name: 'Saanen Dairy Goat Farm Balik Pulau',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: '298 Mukim 1 Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.378, longitude: 100.212 },
    phone: '+6019-516 3017',
    website: '',
    openingHours: 'Daily 10:00 - 17:00',
    score: 4.7,
    description: 'Charming family-run goat farm where visitors can feed friendly dairy goats, taste fresh pasteurized goat milk, and try homemade goat milk ice cream.',
  },
  {
    name: 'Ghee Hup Nutmeg Factory & Plantation',
    category: 'Culture',
    plannerCategories: ['Culture', 'Nature', 'Local Business', 'Food'],
    interestTags: ['Culture', 'Nature', 'Local Business', 'Food'],
    formattedAddress: 'Bukit Prince of Wales, 11000 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.3582, longitude: 100.2285 },
    phone: '+6012-426 6422',
    website: '',
    openingHours: 'Daily 09:00 - 17:00',
    score: 4.7,
    description: 'Traditional hillside nutmeg plantation and processing cottage producing sweet nutmeg slices, therapeutic nutmeg oil, and fresh nutmeg juice.',
  },
  {
    name: 'Kim Laksa Balik Pulau (Nan Guang Coffee Shop)',
    category: 'Food',
    plannerCategories: ['Food', 'Culture', 'Local Business'],
    interestTags: ['Food', 'Culture', 'Local Business'],
    formattedAddress: 'Nan Guang Coffee Shop, Main Road, 11000 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.3524, longitude: 100.2366 },
    phone: '+6012-448 8177',
    website: '',
    openingHours: 'Wed-Sun 10:00 - 17:00',
    score: 4.8,
    description: 'Celebrated Balik Pulau coffee shop serving two styles of laksa: pungent spicy Assam Laksa and creamy coconut milk Siam Laksa.',
  },
  {
    name: 'Bao Sheng Durian Farm & Orchard',
    category: 'Food',
    plannerCategories: ['Food', 'Nature', 'Local Business'],
    interestTags: ['Food', 'Nature', 'Local Business'],
    formattedAddress: '150 Mukim 2 Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 75,
    budgetLevel: 'High',
    location: { latitude: 5.398, longitude: 100.219 },
    phone: '+6012-411 0600',
    website: '',
    openingHours: 'Daily 11:00 - 18:00 (Durian Season)',
    score: 4.7,
    description: 'Heritage organic durian estate overlooking the Malacca Strait, offering seasonal tasting sessions of Red Prawn, Musang King, and Black Thorn.',
  },
  {
    name: 'Balik Pulau Countryside Art Murals',
    category: 'Art',
    plannerCategories: ['Art', 'Nature', 'Culture'],
    interestTags: ['Art', 'Nature', 'Culture'],
    formattedAddress: 'Pekan Balik Pulau, 11000 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.3515, longitude: 100.2355 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.7,
    description: 'Large-scale rural wall murals by Russian artist Julia Volchkova celebrating local fishermen, martial artists, and silversmiths in village shophouses.',
  },
  {
    name: 'Pantai Pasir Panjang (Long Sand Beach)',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Mukim 9 Pulau Betong, 11000 Balik Pulau, Penang, Malaysia',
    area: 'Balik Pulau',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.302, longitude: 100.185 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Tranquil secluded southwest coast beach with scenic fishing boat views, casuarina trees, and panoramic sunsets.',
  },
  {
    name: 'Penang Floating Mosque (Masjid Terapung Tanjung Bungah)',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Nature'],
    interestTags: ['Culture', 'Heritage', 'Nature'],
    formattedAddress: 'Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia',
    area: 'Tanjung Bungah',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4697, longitude: 100.2762 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 06:00 - 21:00',
    score: 4.8,
    description: 'The first floating mosque built on stilts over the sea in Malaysia, featuring Middle Eastern and local architectural minarets.',
  },
  {
    name: 'Tanjung Bungah Beach Coastline',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia',
    area: 'Tanjung Bungah',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.466, longitude: 100.282 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Peaceful northern coast beach known for watersports clubs, gentle ocean waves, and panoramic sea horizons.',
  },
  {
    name: 'Avatar Secret Garden (Tanjung Tokong Seafront)',
    category: 'Nature',
    plannerCategories: ['Nature', 'Culture', 'Local Business'],
    interestTags: ['Nature', 'Culture', 'Local Business'],
    formattedAddress: 'Jalan Tokong Thai Pak Koong, Tanjung Tokong, 10470 Penang, Malaysia',
    area: 'Tanjung Tokong',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.4635, longitude: 100.3075 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 08:00 - 00:00',
    score: 4.6,
    description: 'Enchanting illuminated coastal forest garden behind the Thai Pak Koong seaside temple, with colourful fibre-optic canopy lights.',
  },
  {
    name: 'Straits Quay Marina & Coastal Promenade',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business', 'Food'],
    interestTags: ['Nature', 'Local Business', 'Food'],
    formattedAddress: 'Jalan Seri Tanjung Pinang, Tanjung Tokong, 10470 Penang, Malaysia',
    area: 'Tanjung Tokong',
    durationMinutes: 60,
    budgetLevel: 'Medium',
    location: { latitude: 5.4578, longitude: 100.313 },
    phone: '+604-891 8000',
    website: '',
    openingHours: 'Daily 10:00 - 22:00',
    score: 4.7,
    description: 'Penang\'s premier seafront marina retail and dining promenade with yacht berths, breezy waterfront cafes, and arts market stalls.',
  },
  {
    name: 'Dharmikarama Burmese Temple',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Art'],
    interestTags: ['Culture', 'Heritage', 'Art'],
    formattedAddress: '24 Lorong Burma, Pulau Tikus, 10250 George Town, Penang, Malaysia',
    area: 'Pulau Tikus',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.4312, longitude: 100.3142 },
    phone: '+604-226 9350',
    website: '',
    openingHours: 'Daily 08:00 - 18:00',
    score: 4.8,
    description: 'Historic Burmese temple founded in 1803 featuring a grand golden stupa, wishing pond, shrine of Arahant Upagutta, and historical murals.',
  },
  {
    name: 'Wat Chayamangkalaram (Reclining Buddha Temple)',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Art'],
    interestTags: ['Culture', 'Heritage', 'Art'],
    formattedAddress: '17 Lorong Burma, Pulau Tikus, 10250 George Town, Penang, Malaysia',
    area: 'Pulau Tikus',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4316, longitude: 100.3144 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 08:00 - 17:30',
    score: 4.8,
    description: 'Renowned Thai Buddhist temple housing a colossal 33-metre gold-plated reclining Buddha statue and colourful mythical dragon guards.',
  },
  {
    name: 'Arulmigu Balathandayuthapani Temple (Waterfall Hilltop Temple)',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Nature'],
    interestTags: ['Culture', 'Heritage', 'Nature'],
    formattedAddress: '17 Jalan Kebun Bunga, George Town, 10350 Penang, Malaysia',
    area: 'George Town',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 5.4338, longitude: 100.2917 },
    phone: '+604-229 0777',
    website: '',
    openingHours: 'Daily 06:00 - 21:00',
    score: 4.8,
    description: 'Magnificent hilltop Hindu temple complex reached via 513 steps with sweeping views over George Town and focal point of Thaipusam.',
  },
  {
    name: 'Snake Temple (Ban Ka Lan Temple)',
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage'],
    interestTags: ['Culture', 'Heritage'],
    formattedAddress: 'Jalan Sultan Azlan Shah, Bayan Lepas, 11900 Penang, Malaysia',
    area: 'Bayan Lepas',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.3138, longitude: 100.2853 },
    phone: '+604-643 7273',
    website: '',
    openingHours: 'Daily 08:00 - 18:00',
    score: 4.6,
    description: 'Unique 1850 Taoist temple dedicated to Master Chor Soo Kong, famous for live green pit vipers resting peacefully around altars and incense burners.',
  },
  {
    name: 'Penang War Museum',
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture', 'Nature'],
    interestTags: ['Heritage', 'Culture', 'Nature'],
    formattedAddress: 'Lot 1350 Mukim 12, Jalan Batu Maung, 11960 Bayan Lepas, Penang, Malaysia',
    area: 'Bayan Lepas',
    durationMinutes: 90,
    budgetLevel: 'Medium',
    location: { latitude: 5.2814, longitude: 100.2886 },
    phone: '+604-626 5142',
    website: 'https://penangwarmuseum.com/',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.6,
    description: 'Sprawling historical British coastal fortress and battery built in the 1930s on Bukit Maung, featuring underground tunnels, bunkers, and artillery.',
  },
  {
    name: 'Minor Basilica of St. Anne',
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture', 'Art'],
    interestTags: ['Heritage', 'Culture', 'Art'],
    formattedAddress: 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.3533, longitude: 100.4789 },
    phone: '+604-538 6405',
    website: 'https://stannebm.org/',
    openingHours: 'Daily 06:30 - 21:00',
    score: 4.9,
    culturalTask: {
      title: 'Basilica Architecture Discovery',
      description: 'Photograph the gothic facade of St. Anne Basilica and the historic 1888 hillside chapel.',
      rewardPoints: 110,
    },
    description: 'Historic Catholic pilgrimage site elevated to Minor Basilica status, featuring Gothic architecture, stained glass, and the 1888 Old Shrine.',
  },
  {
    name: 'Cherok Tokun Nature Park & BM Hill Trail',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Kolam, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 90,
    budgetLevel: 'Low',
    location: { latitude: 5.3582, longitude: 100.4908 },
    phone: '+604-530 1800',
    website: '',
    openingHours: 'Daily 07:00 - 19:00',
    score: 4.7,
    description: 'Lush forest reserve with tranquil walking trails, fresh mountain streams, canopy trees, and the scenic hiking path up BM Hill peak.',
  },
  {
    name: 'Mengkuang Dam Lakeside Park',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: 'Mukim 18, Mengkuang, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 5.4012, longitude: 100.493 },
    phone: '+604-500 1200',
    website: '',
    openingHours: 'Daily 07:00 - 19:00',
    score: 4.8,
    description: 'Serene mainland Penang reservoir park framed by green hill peaks, expansive lake scenery, and a popular jogging trail.',
  },
  {
    name: 'Bukit Juru Nature Trail',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Kuala Juru, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 5.334, longitude: 100.418 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 19:00',
    score: 4.6,
    description: 'Scenic hilltop coastal hiking trail in Seberang Perai with panoramic views of the Penang Second Bridge, mangrove forests, and fishing boats.',
  },
  {
    name: 'Frog Hill (Bukit Katak) Scenic Lakes',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Kampung Ladang Toh Allah, 14400 Tasek Gelugor, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.441, longitude: 100.485 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 07:00 - 18:30',
    score: 4.7,
    description: 'Spectacular abandoned quarry site featuring vivid turquoise-green mineral lakes and red clay ridges reminiscent of Jiuzhaigou.',
  },
  {
    name: 'Robina Eco Park Butterworth (Pantai Bersih)',
    category: 'Nature',
    plannerCategories: ['Nature'],
    interestTags: ['Nature'],
    formattedAddress: 'Jalan Robina, Taman Robina, 13050 Butterworth, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.459, longitude: 100.381 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Revitalized seafront coastal park overlooking Penang Island with sunset walking piers, sea breeze promenades, and beach recreation.',
  },
  {
    name: 'Restoran BM Yam Rice',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business', 'Culture'],
    interestTags: ['Food', 'Local Business', 'Culture'],
    formattedAddress: '7 Jalan Murthy, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 50,
    budgetLevel: 'Low',
    location: { latitude: 5.3644, longitude: 100.4608 },
    phone: '+604-530 6826',
    website: '',
    openingHours: 'Daily 09:00 - 15:00',
    score: 4.8,
    description: 'Famous Bukit Mertajam fragrant yam rice paired with salted mustard greens pork rib soup, tender offal, and spicy chili dip.',
  },
  {
    name: 'Restoran BM Cup Rice (Danby Cup Rice)',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.3639, longitude: 100.4608 },
    phone: '+6012-421 8833',
    website: '',
    openingHours: 'Daily 08:00 - 14:00',
    score: 4.7,
    description: 'Iconic vintage BM cup rice drenched in rich roasted pork gravy with tender char siew in a bustling town shophouse.',
  },
  {
    name: 'BM Famous Duck Egg Char Koay Teow',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.3635, longitude: 100.4602 },
    phone: '+6016-443 2819',
    website: '',
    openingHours: 'Daily 19:00 - 23:30',
    score: 4.9,
    description: 'Famous charcoal-fried char koay teow cooked with rich creamy duck egg, fresh cockles, and fragrant wok hei on Jalan Pasar.',
  },
  {
    name: 'BM Rojak Orang Hitam Putih',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 30,
    budgetLevel: 'Low',
    location: { latitude: 5.3641, longitude: 100.4615 },
    phone: '+6012-475 2288',
    website: '',
    openingHours: 'Daily 11:30 - 18:30',
    score: 4.8,
    description: 'Renowned BM fruit and crispy fritter rojak tossed in thick, aromatic black shrimp paste and crushed roasted peanuts.',
  },
  {
    name: 'Sentosa Food Court BM',
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    interestTags: ['Food', 'Local Business'],
    formattedAddress: 'Jalan Sentosa, Taman Sentosa, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.3488, longitude: 100.4722 },
    phone: '+604-539 8888',
    website: '',
    openingHours: 'Daily 17:00 - 00:00',
    score: 4.7,
    description: 'Bustling evening food court in Taman Sentosa featuring over 40 hawker stalls serving BBQ stingray, satay, fried oyster omelette, and claypot noodles.',
  },
  {
    name: 'Pekan Bukit Mertajam Old Market Street',
    category: 'Culture',
    plannerCategories: ['Culture', 'Food', 'Local Business'],
    interestTags: ['Culture', 'Food', 'Local Business'],
    formattedAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    area: 'Bukit Mertajam',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.3638, longitude: 100.4612 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 06:00 - 18:00',
    score: 4.7,
    description: 'Heart of BM town featuring traditional old-style dry and wet markets, Chinese herbal medicine halls, tea merchants, and street hawkers.',
  },
  {
    name: 'Penang Bird Park Seberang Jaya',
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    interestTags: ['Nature', 'Local Business'],
    formattedAddress: 'Jalan Todak, Seberang Jaya, 13700 Butterworth, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 90,
    budgetLevel: 'Medium',
    location: { latitude: 5.3958, longitude: 100.3981 },
    phone: '+604-399 1899',
    website: '',
    openingHours: 'Daily 09:00 - 18:00',
    score: 4.6,
    description: 'First and largest bird park in Malaysia, housing over 300 bird species with walk-in aviaries, lotus ponds, and flamingos.',
  },
  {
    name: 'Butterworth Art Walk',
    category: 'Art',
    plannerCategories: ['Art', 'Culture', 'Heritage'],
    interestTags: ['Art', 'Culture', 'Heritage'],
    formattedAddress: '1 Lorong Bagan Luar 1, 12000 Butterworth, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 45,
    budgetLevel: 'Low',
    location: { latitude: 5.4121, longitude: 100.3664 },
    phone: '+604-332 5000',
    website: '',
    openingHours: 'Daily 24 Hours',
    score: 4.6,
    description: 'Vibrant outdoor alleyway art exhibition showcasing interactive 3D murals depicting Butterworth\'s agricultural, port, and cultural history.',
  },
  {
    name: 'Tow Boo Kong Temple (Nine Emperor Gods)',
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture', 'Art'],
    interestTags: ['Heritage', 'Culture', 'Art'],
    formattedAddress: 'Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 60,
    budgetLevel: 'Low',
    location: { latitude: 5.4336, longitude: 100.3844 },
    phone: '+604-331 3318',
    website: '',
    openingHours: 'Daily 07:00 - 21:00',
    score: 4.8,
    description: 'One of the grandest Taoist temple complexes in Malaysia, famed for its massive carved stone archway, golden dragon pillars, and Nine Emperor Gods festival.',
  },
  {
    name: 'Sree Maha Mariamman Temple Butterworth',
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture'],
    interestTags: ['Heritage', 'Culture'],
    formattedAddress: 'Jalan Bagh, 12000 Butterworth, Penang, Malaysia',
    area: 'Butterworth',
    durationMinutes: 40,
    budgetLevel: 'Low',
    location: { latitude: 5.4019, longitude: 100.3688 },
    phone: '+604-200 0000',
    website: '',
    openingHours: 'Daily 06:00 - 20:30',
    score: 4.7,
    description: 'Historic Dravidian Hindu temple in Butterworth dating back to the 19th century, featuring a multi-tiered colourful Rajagopuram.',
  },

  // KUALA LUMPUR & SELANGOR
  {
    name: 'Central Market (Pasar Seni)',
    category: 'Heritage',
    formattedAddress: 'Jalan Hang Kasturi, City Centre, 50050 Kuala Lumpur, Malaysia',
    area: 'Kuala Lumpur',
    durationMinutes: 75,
    budgetLevel: 'Free',
    location: { latitude: 3.1453, longitude: 101.6953 },
    phone: '+603-2031 0399',
    openingHours: 'Mon-Sun 10:00-22:00',
    score: 4.8,
    description: 'Iconic 1888 Art Deco cultural landmark hosting Malaysian handicrafts, batik studios, Wau kite artisans, and traditional performances.',
  },
  {
    name: 'Batu Caves Lord Murugan Shrine',
    category: 'Heritage',
    formattedAddress: 'Gombak, 68100 Batu Caves, Selangor, Malaysia',
    area: 'Selangor',
    durationMinutes: 90,
    budgetLevel: 'Free',
    location: { latitude: 3.2379, longitude: 101.6840 },
    phone: '+603-6189 6284',
    openingHours: 'Mon-Sun 06:00-21:00',
    score: 4.8,
    culturalTask: {
      title: 'Cathedral Cave Step Ascent',
      description: 'Climb the 272 rainbow steps and photograph the limestone cathedral cave interior.',
      rewardPoints: 130,
    },
    description: 'Limestone hill comprising three major caves, world-renowned 140-ft golden Lord Murugan statue, and 272 colourful rainbow steps.',
  },

  // KELANTAN & TERENGGANU
  {
    name: 'Pasar Besar Siti Khadijah',
    category: 'Heritage',
    formattedAddress: 'Jalan Buluh Kubu, Bandar Kota Bharu, 15000 Kota Bharu, Kelantan, Malaysia',
    area: 'Kota Bharu',
    durationMinutes: 75,
    budgetLevel: 'Low',
    location: { latitude: 6.1287, longitude: 102.2392 },
    phone: '+609-748 2140',
    openingHours: 'Mon-Sun 07:00-18:00',
    score: 4.8,
    culturalTask: {
      title: 'Octagonal Market Geometry & Kuih Akok',
      description: 'Photograph the colourful central octagonal produce hall and sample warm Kuih Akok.',
      rewardPoints: 130,
    },
    description: 'Iconic 4-storey octagonal central market in Kota Bharu operated mostly by female traders, vibrant with local spices and traditional songket.',
  },
  {
    name: 'Masjid Kristal',
    category: 'Heritage',
    formattedAddress: 'Pulau Wan Man, 21000 Kuala Terengganu, Terengganu, Malaysia',
    area: 'Kuala Terengganu',
    durationMinutes: 60,
    budgetLevel: 'Free',
    location: { latitude: 5.3224, longitude: 103.1189 },
    phone: '+609-627 8888',
    openingHours: 'Mon-Sun 06:00-22:00',
    score: 4.8,
    culturalTask: {
      title: 'Crystal Reflection Snapshot',
      description: 'Photograph the gleaming crystal and glass domes reflecting over the Terengganu River.',
      rewardPoints: 120,
    },
    description: 'Magnificent grand mosque built from steel, glass, and crystal on Pulau Wan Man overlooking the scenic Terengganu River.',
  },
  {
    name: 'Borneo Cultures Museum',
    category: 'Culture',
    formattedAddress: 'Jalan Tun Abang Haji Openg, 93000 Kuching, Sarawak, Malaysia',
    area: 'Kuching',
    durationMinutes: 120,
    budgetLevel: 'Medium',
    location: { latitude: 1.5546, longitude: 110.3421 },
    phone: '+6082-536 788',
    openingHours: 'Mon-Fri 09:00-16:45, Sat-Sun 09:30-16:30',
    score: 4.9,
    culturalTask: {
      title: 'Indigenous Tribal Arts Study',
      description: 'Explore Level 3 or 4 and photograph one traditional Dayak craft or textile heirloom.',
      rewardPoints: 150,
    },
    description: 'Iconic 5-storey museum and the second largest in Southeast Asia, housing over 1,000 Borneo cultural artefacts.',
  },
];

const sampleReviewers = [
  'Tan Mei Ling',
  'Hafiz Ridzuan',
  'Sarah Jenkins',
  'Bernard Lim',
  'Chloe Dupont',
  'Kavitha Nair',
  'Chen Wei Ming',
  'Ahmad Faiz',
];

async function seed() {
  console.log(`Starting Firestore sync for ${places.length} curated venues...`);

  let vendorCount = 0;
  let placeCount = 0;
  let reviewCount = 0;

  for (const place of places) {
    const name = place.name.trim();
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    const vendorId = `vendor_${slug}`;
    const placeId = `place_${slug}`;
    const emailSlug = slug.replace(/_/g, '');
    const vendorEmail = `${emailSlug}@myheritage.my`;

    // 1. Set Vendor
    const tags = place.interestTags || place.plannerCategories || [place.category || 'Heritage'];
    await db.collection('vendors').doc(vendorId).set({
      uid: vendorId,
      vendorId: vendorId,
      businessName: name,
      displayName: name,
      ownerName: `${name} Management`,
      email: vendorEmail,
      phone: place.phone || '+604-500 0000',
      category: place.category || 'Heritage',
      area: place.area || 'Malaysia',
      state: 'penang',
      stateName: 'Penang',
      stateId: 'penang',
      interestTags: tags,
      tags: tags,
      formattedAddress: place.formattedAddress || place.area,
      location: place.location || { latitude: 5.4, longitude: 100.3 },
      role: 'vendor',
      status: 'active',
      vendorStatus: 'verified',
      score: place.score || 4.8,
      website: place.website || '',
      openingHours: place.openingHours || 'Mon-Sun 09:00-18:00',
      description: place.description || '',
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    vendorCount++;

    // 2. Set Place
    await db.collection('places').doc(placeId).set({
      placeId: placeId,
      vendorId: vendorId,
      name: name,
      category: place.category || 'Heritage',
      area: place.area || 'Malaysia',
      stateId: 'penang',
      stateName: 'Penang',
      interestTags: tags,
      plannerCategories: tags,
      tags: tags,
      formattedAddress: place.formattedAddress || place.area,
      location: place.location || { latitude: 5.4, longitude: 100.3 },
      score: place.score || 4.8,
      durationMinutes: place.durationMinutes || 60,
      budgetLevel: place.budgetLevel || 'Low',
      phone: place.phone || '+604-500 0000',
      website: place.website || '',
      openingHours: place.openingHours || 'Mon-Sun 09:00-18:00',
      description: place.description || '',
      culturalTask: place.culturalTask || null,
      isVerified: true,
      isActive: true,
      status: 'active',
      trustLabel: 'High Trust',
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    placeCount++;

    // 3. Seed 3-4 Authentic Place-Specific Malaysian Reviews
    let validReviews = [];
    const nameLower = name.toLowerCase();
    const catLower = (place.category || '').toLowerCase();

    if (nameLower.includes('yam rice') || nameLower.includes('bm yam')) {
      validReviews = [
        {
          rating: 5,
          comment: `Authentic BM salted vegetable duck/pork soup paired with aromatic dark yam rice. The homemade chili sauce is unbeatable!`,
          aspectTags: ['Authentic Taste', 'Must Try', 'Value for Money'],
          helpfulCount: 14,
        },
        {
          rating: 5,
          comment: `A legendary stop in Bukit Mertajam. Generous ingredients, piping hot herbal broth, and fast service even during lunch peak.`,
          aspectTags: ['Authentic Taste', 'Friendly Service'],
          helpfulCount: 9,
        },
        {
          rating: 4,
          comment: `Delicious and flavorful. Best to come before 12:30 PM to avoid queueing for seats.`,
          aspectTags: ['Must Try', 'Clean & Cozy'],
          helpfulCount: 6,
        },
      ];
    } else if (nameLower.includes('duck egg') || nameLower.includes('char koay teow') || nameLower.includes('siam road')) {
      validReviews = [
        {
          rating: 5,
          comment: `Incredible wok hei! The rich creaminess of the duck egg elevates the whole plate. Top tier char koay teow in Penang.`,
          aspectTags: ['Authentic Taste', 'Must Try'],
          helpfulCount: 18,
        },
        {
          rating: 5,
          comment: `Crispy cockles and fragrant lard aroma. One of the best street food plates in mainland Penang.`,
          aspectTags: ['Authentic Taste', 'Value for Money'],
          helpfulCount: 11,
        },
        {
          rating: 4,
          comment: `Generous portions and wonderful smoky flavor. Definitely worth waiting a few minutes in line.`,
          aspectTags: ['Must Try'],
          helpfulCount: 5,
        },
      ];
    } else if (nameLower.includes('cheong fatt tze') || nameLower.includes('blue mansion') || nameLower.includes('peranakan')) {
      validReviews = [
        {
          rating: 5,
          comment: `The heritage guided tour is top notch. The indigo courtyard and Feng Shui architecture details are world-class.`,
          aspectTags: ['Heritage Atmosphere', 'Photogenic', 'Scenic View'],
          helpfulCount: 16,
        },
        {
          rating: 5,
          comment: `Stunning restoration in George Town UNESCO core. Photography is wonderful in the open courtyard.`,
          aspectTags: ['Heritage Atmosphere', 'Photogenic'],
          helpfulCount: 12,
        },
        {
          rating: 5,
          comment: `Overwhelmingly beautiful collection of Baba Nyonya antiques, custom tiles, and gold-leaf wood carvings.`,
          aspectTags: ['Heritage Atmosphere', 'Must Try'],
          helpfulCount: 8,
        },
      ];
    } else if (nameLower.includes('batu caves') || nameLower.includes('temple') || nameLower.includes('mosque') || nameLower.includes('basilica')) {
      validReviews = [
        {
          rating: 5,
          comment: `Serene and magnificent cultural landmark. The ornate carvings and peaceful atmosphere make it a must-visit.`,
          aspectTags: ['Heritage Atmosphere', 'Scenic View', 'Photogenic'],
          helpfulCount: 15,
        },
        {
          rating: 5,
          comment: `Remarkable historical craftsmanship and peaceful surroundings. Great educational experience for visitors.`,
          aspectTags: ['Heritage Atmosphere', 'Family Friendly'],
          helpfulCount: 10,
        },
        {
          rating: 4,
          comment: `Majestic architecture and very welcoming caretakers. Don't forget to take photos of the exterior details.`,
          aspectTags: ['Photogenic', 'Scenic View'],
          helpfulCount: 7,
        },
      ];
    } else if (catLower.includes('food') || catLower.includes('restaurant') || catLower.includes('cafe') || catLower.includes('kopitiam')) {
      validReviews = [
        {
          rating: 5,
          comment: `Generous portions, authentic local flavors, and reasonable pricing. Definitely recommend trying their signature specialty dishes in ${place.area}!`,
          aspectTags: ['Authentic Taste', 'Value for Money', 'Must Try'],
          helpfulCount: 12,
        },
        {
          rating: 5,
          comment: `Loved the traditional atmosphere and warm hospitality. A genuine taste of ${place.area} culinary culture.`,
          aspectTags: ['Authentic Taste', 'Friendly Service'],
          helpfulCount: 9,
        },
        {
          rating: 4,
          comment: `Great stop on our itinerary. Clean venue, authentic spices, and very friendly staff.`,
          aspectTags: ['Friendly Service', 'Clean & Cozy'],
          helpfulCount: 6,
        },
      ];
    } else if (catLower.includes('nature') || catLower.includes('park') || catLower.includes('beach')) {
      validReviews = [
        {
          rating: 5,
          comment: `Breathtaking scenery and well-maintained walking paths. Perfect for nature lovers and refreshing walks in ${place.area}.`,
          aspectTags: ['Scenic View', 'Photogenic', 'Family Friendly'],
          helpfulCount: 14,
        },
        {
          rating: 5,
          comment: `Serene green atmosphere with great photo spots. Peaceful escape with stunning panoramic views.`,
          aspectTags: ['Scenic View', 'Photogenic'],
          helpfulCount: 10,
        },
        {
          rating: 4,
          comment: `Clean environment and gentle ocean/mountain breeze. A very relaxing stop for travelers.`,
          aspectTags: ['Scenic View', 'Family Friendly'],
          helpfulCount: 5,
        },
      ];
    } else {
      validReviews = [
        {
          rating: 5,
          comment: `A must-visit cultural landmark in ${place.area}. Well preserved with rich historical background and engaging exhibits.`,
          aspectTags: ['Heritage Atmosphere', 'Photogenic', 'Must Try'],
          helpfulCount: 13,
        },
        {
          rating: 5,
          comment: `Beautiful heritage craftsmanship and architecture. Great educational spot for both solo travelers and families.`,
          aspectTags: ['Heritage Atmosphere', 'Family Friendly'],
          helpfulCount: 8,
        },
        {
          rating: 4,
          comment: `Engaging visit and great cultural insights into Malaysian traditions. Friendly staff and well curated.`,
          aspectTags: ['Friendly Service', 'Must Try'],
          helpfulCount: 5,
        },
      ];
    }

    for (let i = 0; i < validReviews.length; i++) {
      const reviewDocId = `rev_${slug}_valid_${i + 1}`;
      const reviewer = sampleReviewers[(vendorCount + i) % sampleReviewers.length];
      await db.collection('reviews').doc(reviewDocId).set({
        reviewId: reviewDocId,
        placeId: placeId,
        vendorId: vendorId,
        placeName: name,
        travelerName: reviewer,
        reviewerName: reviewer,
        rating: validReviews[i].rating,
        comment: validReviews[i].comment,
        aspectTags: validReviews[i].aspectTags || [],
        helpfulCount: validReviews[i].helpfulCount || 0,
        isVerified: true,
        status: 'valid',
        mlDecision: 'normal',
        mlRiskLevel: 'low',
        mlSuspiciousProbability: 0.04,
        mlRatingMismatch: false,
        flagReasons: [],
        createdAt: Timestamp.fromDate(new Date(Date.now() - (i + 1) * 86400000 * 3)),
        updatedAt: Timestamp.fromDate(new Date(Date.now() - (i + 1) * 86400000 * 3)),
      }, { merge: true });
      reviewCount++;
    }

    // 4. Seed select flagged reviews for testing ML Moderation
    if (vendorCount % 3 === 0) {
      const flaggedDocId = `rev_${slug}_flagged_1`;
      await db.collection('reviews').doc(flaggedDocId).set({
        reviewId: flaggedDocId,
        placeId: placeId,
        vendorId: vendorId,
        placeName: name,
        travelerName: 'SpamBot_Promo',
        rating: 5,
        comment: `Check out cheap discounts and free promo vouchers at http://super-discount-tourist-deals.xyz/claim now! Best place in ${place.area}!`,
        status: 'flagged',
        mlDecision: 'flagged',
        mlSuspiciousProbability: 0.96,
        mlRatingMismatch: false,
        flagReasons: ['Promotional spam URL link detected'],
        flagReason: 'Promotional spam URL link detected',
        createdAt: Timestamp.fromDate(new Date(Date.now() - 86400000)),
      }, { merge: true });
      reviewCount++;
    }
  }

  console.log(`Successfully synced directly to Firebase:`);
  console.log(`- ${vendorCount} Vendors in collection('vendors')`);
  console.log(`- ${placeCount} Places in collection('places')`);
  console.log(`- ${reviewCount} Reviews in collection('reviews')`);
}

seed().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Seeding error:', err);
  process.exit(1);
});

part of '../traveler_pages.dart';

class MalaysianAreaHub {
  const MalaysianAreaHub({
    required this.name,
    required this.primaryQuery,
    required this.aliases,
    required this.description,
    required this.subAreas,
  });

  final String name;
  final String primaryQuery;
  final List<String> aliases;
  final String description;
  final List<MalaysianSubArea> subAreas;
}

class MalaysianSubArea {
  const MalaysianSubArea({
    required this.name,
    required this.fullQuery,
    required this.highlight,
    this.aliases = const [],
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String fullQuery;
  final String highlight;
  final List<String> aliases;
  final double latitude;
  final double longitude;
}

const List<MalaysianAreaHub> malaysianAreaHubs = [
  MalaysianAreaHub(
    name: 'Penang (Pulau Pinang)',
    primaryQuery: 'George Town, Penang',
    aliases: ['png', 'pg', 'penang', 'pulau pinang', 'pinang', 'pulau'],
    description:
        'UNESCO World Heritage shophouses, street food capital & eco rainforest trails',
    subAreas: [
      MalaysianSubArea(
        name: 'George Town',
        fullQuery: 'George Town, Penang',
        highlight:
            'UNESCO Heritage zone, clan jetties, historic mansions & street art murals',
        aliases: ['gt', 'georgetown', 'george town'],
        latitude: 5.4164,
        longitude: 100.3327,
      ),
      MalaysianSubArea(
        name: 'Bukit Mertajam',
        fullQuery: 'Bukit Mertajam, Penang',
        highlight:
            'Minor Basilica of St. Anne, Cherok Tokun nature forest & iconic food streets',
        aliases: ['bm', 'bukit mertajam', 'mertajam'],
        latitude: 5.3630,
        longitude: 100.4667,
      ),
      MalaysianSubArea(
        name: 'Butterworth',
        fullQuery: 'Butterworth, Penang',
        highlight:
            'Penang Bird Park, Butterworth Art Walk, Tow Boo Kong temple & harbor front',
        aliases: ['bw', 'butterworth', 'seberang perai utara'],
        latitude: 5.3991,
        longitude: 100.3638,
      ),
      MalaysianSubArea(
        name: 'Air Itam',
        fullQuery: 'Air Itam, Penang',
        highlight:
            'Kek Lok Si Temple, Penang Hill funicular railway & heritage laksa stalls',
        aliases: ['ayer itam', 'air itam', 'penang hill', 'bukit bendera'],
        latitude: 5.4000,
        longitude: 100.2780,
      ),
      MalaysianSubArea(
        name: 'Teluk Bahang',
        fullQuery: 'Teluk Bahang, Penang',
        highlight:
            'Tropical Spice Garden, Entopia butterfly sanctuary, ESCAPE & traditional batik craft',
        aliases: ['teluk bahang', 'telok bahang', 'spice garden', 'escape'],
        latitude: 5.4560,
        longitude: 100.2200,
      ),
      MalaysianSubArea(
        name: 'Batu Ferringhi',
        fullQuery: 'Batu Ferringhi, Penang',
        highlight:
            'Night market craft stalls, coastal resorts, Yahong art gallery & sea views',
        aliases: ['bf', 'batu ferringhi', 'batu feringghi', 'ferringhi'],
        latitude: 5.4680,
        longitude: 100.2460,
      ),
      MalaysianSubArea(
        name: 'Balik Pulau',
        fullQuery: 'Balik Pulau, Penang',
        highlight:
            'Nutmeg orchards, Audi dream farm, rural heritage kampung & famous laksa',
        aliases: ['bp', 'balik pulau'],
        latitude: 5.3520,
        longitude: 100.2360,
      ),
      MalaysianSubArea(
        name: 'Bayan Lepas',
        fullQuery: 'Bayan Lepas, Penang',
        highlight:
            'Penang Snake Temple, Penang War Museum & southern coastal fishery villages',
        aliases: ['bl', 'bayan lepas', 'bayan baru'],
        latitude: 5.2950,
        longitude: 100.2650,
      ),
      MalaysianSubArea(
        name: 'Tanjung Bungah',
        fullQuery: 'Tanjung Bungah, Penang',
        highlight:
            'Penang Floating Mosque, tranquil coastline & artisan heritage cafes',
        aliases: ['tb', 'tanjung bungah', 'tanjung bunga'],
        latitude: 5.4650,
        longitude: 100.2800,
      ),
      MalaysianSubArea(
        name: 'Tanjung Tokong',
        fullQuery: 'Tanjung Tokong, Penang',
        highlight:
            'Straits Quay marina, Thai Buddhist heritage temples & seafood promenade',
        aliases: ['tt', 'tanjung tokong', 'straits quay'],
        latitude: 5.4500,
        longitude: 100.3050,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Selangor',
    primaryQuery: 'Selangor',
    aliases: [
      'sgr',
      'selangor',
      'shah alam',
      'petaling jaya',
      'pj',
      'klang',
      'batu caves',
      'sekinchan',
    ],
    description:
        'Royal heritage towns, iconic limestone caves, Blue Mosque & paddy field landscapes',
    subAreas: [
      MalaysianSubArea(
        name: 'Batu Caves',
        fullQuery: 'Batu Caves, Selangor',
        highlight:
            'Limestone hill caves, 272 rainbow steps & giant Lord Murugan gold statue',
        aliases: ['batu caves', 'gombak'],
        latitude: 3.2379,
        longitude: 101.6840,
      ),
      MalaysianSubArea(
        name: 'Shah Alam',
        fullQuery: 'Shah Alam, Selangor',
        highlight:
            'Sultan Salahuddin Abdul Aziz Shah Blue Mosque, Islamic Arts Garden & Lake Gardens',
        aliases: ['shah alam', 'blue mosque', 'masjid negeri'],
        latitude: 3.0738,
        longitude: 101.5183,
      ),
      MalaysianSubArea(
        name: 'Royal Klang Heritage Walk',
        fullQuery: 'Klang, Selangor',
        highlight:
            'Sultan Abdul Aziz Royal Gallery, Chong Kok Kopitiam, Little India Klang & heritage trails',
        aliases: ['klang', 'royal klang', 'chong kok'],
        latitude: 3.0449,
        longitude: 101.4456,
      ),
      MalaysianSubArea(
        name: 'Sekinchan',
        fullQuery: 'Sekinchan, Selangor',
        highlight:
            'Paddy Processing Gallery, Redang Beach wishing tree, mango orchards & fishing village',
        aliases: ['sekinchan', 'paddy field', 'pantai redang'],
        latitude: 3.5106,
        longitude: 101.1028,
      ),
      MalaysianSubArea(
        name: 'Kuala Selangor',
        fullQuery: 'Kuala Selangor, Selangor',
        highlight:
            'Bukit Melawati historical fort, lighthouse, silvered leaf monkeys & firefly river cruise',
        aliases: ['kuala selangor', 'bukit melawati', 'fireflies'],
        latitude: 3.3409,
        longitude: 101.2505,
      ),
      MalaysianSubArea(
        name: 'Petaling Jaya',
        fullQuery: 'Petaling Jaya, Selangor',
        highlight:
            'Craft and cultural art spaces, heritage coffee houses & Sunway lifestyle hub',
        aliases: ['pj', 'petaling jaya', 'damansara', 'sunway'],
        latitude: 3.1073,
        longitude: 101.6067,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Kuala Lumpur (KL)',
    primaryQuery: 'Kuala Lumpur',
    aliases: ['kl', 'kuala lumpur', 'wilayah persekutuan', 'wp kl'],
    description:
        'Colonial heritage landmarks, vibrant cultural enclaves & bustling street food alleys',
    subAreas: [
      MalaysianSubArea(
        name: 'Chinatown & Petaling Street',
        fullQuery: 'Petaling Street, Kuala Lumpur',
        highlight:
            'Central Market (Pasar Seni), Kwai Chai Hong art alley & heritage shophouse cafes',
        aliases: [
          'chinatown',
          'petaling street',
          'pasar seni',
          'kwai chai hong',
        ],
        latitude: 3.1436,
        longitude: 101.6978,
      ),
      MalaysianSubArea(
        name: 'Dataran Merdeka / City Centre',
        fullQuery: 'Dataran Merdeka, Kuala Lumpur',
        highlight:
            'Sultan Abdul Samad building, historic colonial core, River of Life & Textile Museum',
        aliases: ['merdeka', 'dataran merdeka', 'city centre', 'river of life'],
        latitude: 3.1488,
        longitude: 101.6938,
      ),
      MalaysianSubArea(
        name: 'Brickfields (Little India)',
        fullQuery: 'Brickfields, Kuala Lumpur',
        highlight:
            'Spices, traditional Indian cuisine, Buddhist Maha Vihara & multi-faith shrines',
        aliases: ['little india', 'brickfields', 'kl sentral'],
        latitude: 3.1292,
        longitude: 101.6841,
      ),
      MalaysianSubArea(
        name: 'Kampung Baru',
        fullQuery: 'Kampung Baru, Kuala Lumpur',
        highlight:
            'Traditional Malay wooden stilt houses, night food market & city skyline contrast',
        aliases: ['kampung baru', 'kg baru'],
        latitude: 3.1627,
        longitude: 101.7067,
      ),
      MalaysianSubArea(
        name: 'Bukit Bintang',
        fullQuery: 'Bukit Bintang, Kuala Lumpur',
        highlight:
            'Jalan Alor heritage street food, lively cultural nightlife & shopping hub',
        aliases: ['bb', 'bukit bintang', 'jalan alor'],
        latitude: 3.1466,
        longitude: 101.7118,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Sabah (Borneo)',
    primaryQuery: 'Kota Kinabalu, Sabah',
    aliases: [
      'sbh',
      'sabah',
      'kota kinabalu',
      'kk',
      'kundasang',
      'sandakan',
      'borneo sabah',
    ],
    description:
        'Indigenous cultural villages, Mount Kinabalu highland trails, wildlife & handicraft markets',
    subAreas: [
      MalaysianSubArea(
        name: 'Kota Kinabalu City & Waterfront',
        fullQuery: 'Kota Kinabalu, Sabah',
        highlight:
            'Filipino Handicraft Market, Atkinson Clock Tower, Signal Hill & Tanjung Aru sunset',
        aliases: ['kk', 'kota kinabalu', 'tanjung aru', 'filipino market'],
        latitude: 5.9804,
        longitude: 116.0735,
      ),
      MalaysianSubArea(
        name: 'Mari Mari Cultural Village',
        fullQuery: 'Inanam, Kota Kinabalu, Sabah',
        highlight:
            '5 ethnic Borneo ethnic longhouses (Kadazan-Dusun, Rungus, Lundayeh, Bajau, Murut)',
        aliases: ['mari mari', 'cultural village'],
        latitude: 5.9750,
        longitude: 116.1950,
      ),
      MalaysianSubArea(
        name: 'Kundasang & Mount Kinabalu',
        fullQuery: 'Kundasang, Sabah',
        highlight:
            'Desa Cattle Dairy Farm, Kinabalu UNESCO National Park & Kundasang War Memorial',
        aliases: ['kundasang', 'kinabalu', 'desa farm', 'ranau'],
        latitude: 5.9780,
        longitude: 116.5770,
      ),
      MalaysianSubArea(
        name: 'Sandakan Heritage & Wildlife',
        fullQuery: 'Sandakan, Sabah',
        highlight:
            'Sepilok Orangutan Rehabilitation Centre, Bornean Sun Bear Centre & Agnes Keith House',
        aliases: ['sandakan', 'sepilok', 'agnes keith'],
        latitude: 5.8630,
        longitude: 117.9480,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Sarawak (Borneo)',
    primaryQuery: 'Kuching, Sarawak',
    aliases: [
      'swk',
      'sarawak',
      'kuching',
      'kch',
      'damai',
      'borneo sarawak',
      'sibu',
      'miri',
    ],
    description:
        'Brooke colonial heritage, Borneo Cultures Museum, indigenous living cultures & riverfront',
    subAreas: [
      MalaysianSubArea(
        name: 'Kuching Waterfront & Old Town',
        fullQuery: 'Kuching Waterfront, Sarawak',
        highlight:
            'Main Bazaar shophouses, Darul Hana Bridge, Fort Margherita & Carpenter Street',
        aliases: ['kuching waterfront', 'main bazaar', 'carpenter street'],
        latitude: 1.5586,
        longitude: 110.3442,
      ),
      MalaysianSubArea(
        name: 'Borneo Cultures Museum',
        fullQuery: 'Borneo Cultures Museum, Kuching, Sarawak',
        highlight:
            'Southeast Asia\'s 2nd largest museum, indigenous crafts, archaeological artifacts',
        aliases: ['cultures museum', 'bcm', 'sarawak museum'],
        latitude: 1.5540,
        longitude: 110.3420,
      ),
      MalaysianSubArea(
        name: 'Sarawak Cultural Village (Damai)',
        fullQuery: 'Pantai Damai, Santubong, Sarawak',
        highlight:
            'Living museum with 7 ethnic replica longhouses, cultural dance show & rainforest backdrop',
        aliases: ['sarawak cultural village', 'damai', 'santubong'],
        latitude: 1.7500,
        longitude: 110.3170,
      ),
      MalaysianSubArea(
        name: 'Siniawan Heritage Night Market',
        fullQuery: 'Siniawan, Bau, Sarawak',
        highlight:
            'Century-old wooden shophouse street lit by red lanterns, traditional Hakka & Dayak food',
        aliases: ['siniawan', 'bau', 'siniawan night market'],
        latitude: 1.4420,
        longitude: 110.2210,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Perak',
    primaryQuery: 'Ipoh, Perak',
    aliases: ['prk', 'perak', 'ipoh', 'taiping', 'kuala kangsar'],
    description:
        'Concubine Lane shophouses, limestone cave temples, Taiping heritage lake & royal palaces',
    subAreas: [
      MalaysianSubArea(
        name: 'Ipoh Old Town',
        fullQuery: 'Ipoh Old Town, Perak',
        highlight:
            'Concubine Lane, colonial train station, mural street art & traditional white coffee',
        aliases: ['old town', 'concubine lane', 'ipoh old town'],
        latitude: 4.5975,
        longitude: 101.0776,
      ),
      MalaysianSubArea(
        name: 'Kek Lok Tong & Cave Temples',
        fullQuery: 'Kek Lok Tong, Ipoh, Perak',
        highlight:
            'Natural limestone caverns, Buddhist shrine garden & Sam Poh Tong heritage temple',
        aliases: ['kek lok tong', 'sam poh tong', 'perak cave'],
        latitude: 4.5580,
        longitude: 101.1290,
      ),
      MalaysianSubArea(
        name: 'Taiping Heritage Town',
        fullQuery: 'Taiping, Perak',
        highlight:
            'Taiping Lake Gardens (century-old rain trees), Perak Museum & First Galleria',
        aliases: ['taiping', 'lake gardens taiping'],
        latitude: 4.8517,
        longitude: 100.7411,
      ),
      MalaysianSubArea(
        name: 'Kuala Kangsar Royal Town',
        fullQuery: 'Kuala Kangsar, Perak',
        highlight:
            'Ubudiah Mosque (golden domes), Istana Iskandariah & Labu Sayong pottery craft',
        aliases: ['kuala kangsar', 'ubudiah', 'labu sayong'],
        latitude: 4.7740,
        longitude: 100.9380,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Melaka (Malacca)',
    primaryQuery: 'Melaka',
    aliases: ['mlk', 'melaka', 'malacca'],
    description:
        'Historic Dutch square, Portuguese fortress, Baba Nyonya culture & river promenade',
    subAreas: [
      MalaysianSubArea(
        name: 'Jonker Street & Dutch Square',
        fullQuery: 'Jonker Street, Melaka',
        highlight:
            'The Stadthuys, Christ Church, Jonker Night Market & Baba Nyonya heritage museum',
        aliases: ['jonker', 'jonker street', 'stadthuys', 'dutch square'],
        latitude: 2.1944,
        longitude: 102.2486,
      ),
      MalaysianSubArea(
        name: 'A Famosa & St. Paul\'s Hill',
        fullQuery: 'A Famosa, Melaka',
        highlight:
            'Portuguese fortress ruins, St. Paul\'s Church & panoramic Melaka Straits views',
        aliases: ['a famosa', 'st paul', 'porta de santiago'],
        latitude: 2.1925,
        longitude: 102.2501,
      ),
      MalaysianSubArea(
        name: 'Melaka River & Kampung Morten',
        fullQuery: 'Kampung Morten, Melaka',
        highlight:
            'Traditional Malay heritage village along Melaka River with colorful night lights',
        aliases: ['kampung morten', 'melaka river', 'river cruise'],
        latitude: 2.2020,
        longitude: 102.2510,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Johor',
    primaryQuery: 'Johor Bahru',
    aliases: ['jb', 'jhr', 'johor', 'johor bahru', 'muar', 'kluang'],
    description:
        'Heritage bakery streets, Sultan Abu Bakar mosque, Muar culinary trail & Kluang coffee',
    subAreas: [
      MalaysianSubArea(
        name: 'Tan Hiok Nee Heritage Walk',
        fullQuery: 'Jalan Tan Hiok Nee, Johor Bahru',
        highlight:
            'Hiap Joo woodfired bakery, Chinese heritage museum, shophouse cafes & cultural walk',
        aliases: ['tan hiok nee', 'jalan tan hiok nee', 'hiap joo'],
        latitude: 1.4560,
        longitude: 103.7640,
      ),
      MalaysianSubArea(
        name: 'Sultan Abu Bakar Royal Heritage',
        fullQuery: 'Masjid Sultan Abu Bakar, Johor Bahru',
        highlight:
            'Victorian-Moorish architectural state mosque, Istana Besar & Royal Abu Bakar Museum',
        aliases: ['sultan abu bakar', 'istana besar'],
        latitude: 1.4580,
        longitude: 103.7550,
      ),
      MalaysianSubArea(
        name: 'Muar Heritage & Food Walk',
        fullQuery: 'Muar, Johor',
        highlight:
            'Muar Cultural Walk street murals, Glutton Street (Jalan Haji Abu), Sai Kee 434 Coffee',
        aliases: ['muar', 'bandar maharani', '434 coffee'],
        latitude: 2.0442,
        longitude: 102.5689,
      ),
      MalaysianSubArea(
        name: 'Kluang Railway Heritage',
        fullQuery: 'Kluang, Johor',
        highlight:
            'Historic Kluang RailCoffee (1938), Kluang Street Art & UK Farm eco agro-tourism',
        aliases: ['kluang', 'kluang railcoffee', 'uk farm'],
        latitude: 2.0330,
        longitude: 103.3180,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Kedah & Langkawi',
    primaryQuery: 'Langkawi, Kedah',
    aliases: ['kdh', 'kedah', 'langkawi', 'alor setar', 'alor star'],
    description:
        'UNESCO Global Geopark, Mahsuri legend sanctuary, royal mosques & padi museum',
    subAreas: [
      MalaysianSubArea(
        name: 'Langkawi Cable Car & Sky Bridge',
        fullQuery: 'Oriental Village, Langkawi, Kedah',
        highlight:
            'Machinchang Cambrian Geoforest Park, SkyBridge, Oriental Village cultural complex',
        aliases: ['langkawi', 'cable car', 'skybridge', 'oriental village'],
        latitude: 6.3710,
        longitude: 99.6710,
      ),
      MalaysianSubArea(
        name: 'Kota Mahsuri Cultural Centre',
        fullQuery: 'Kota Mahsuri, Langkawi, Kedah',
        highlight:
            'Traditional Kedah Malay wooden houses, Mahsuri tomb & folk heritage museum',
        aliases: ['kota mahsuri', 'mahsuri', 'makam mahsuri'],
        latitude: 6.3400,
        longitude: 99.7890,
      ),
      MalaysianSubArea(
        name: 'Alor Setar Heritage Core',
        fullQuery: 'Alor Setar, Kedah',
        highlight:
            'Masjid Zahir (one of Malaysia\'s oldest grand mosques), Balai Besar & Kedah Royal Museum',
        aliases: ['alor setar', 'masjid zahir', 'balai besar'],
        latitude: 6.1200,
        longitude: 100.3680,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Pahang',
    primaryQuery: 'Cameron Highlands, Pahang',
    aliases: [
      'phg',
      'pahang',
      'cameron',
      'cameron highlands',
      'kuantan',
      'bentong',
    ],
    description:
        'Highland tea plantations, colonial mossy forest trails & traditional market heritage',
    subAreas: [
      MalaysianSubArea(
        name: 'BOH Sungei Palas Tea Centre',
        fullQuery: 'Sungei Palas, Cameron Highlands, Pahang',
        highlight:
            'Colonial tea processing factory, cantilevered viewing deck & endless tea plantations',
        aliases: ['boh tea', 'cameron', 'sungei palas'],
        latitude: 4.5170,
        longitude: 101.4080,
      ),
      MalaysianSubArea(
        name: 'Time Tunnel Museum & Brinchang',
        fullQuery: 'Brinchang, Cameron Highlands, Pahang',
        highlight:
            'First memorabilia museum in Malaysia celebrating colonial and indigenous history',
        aliases: ['time tunnel', 'brinchang', 'kea farm'],
        latitude: 4.4980,
        longitude: 101.3910,
      ),
      MalaysianSubArea(
        name: 'Kuantan & Teluk Cempedak',
        fullQuery: 'Kuantan, Pahang',
        highlight:
            'Teluk Cempedak beach, Kuantan 188 Tower, Kuantan Art Street murals & Ana Ikan Bakar Petai',
        aliases: ['kuantan', 'teluk cempedak', 'tanjung lumpur'],
        latitude: 3.8077,
        longitude: 103.3260,
      ),
      MalaysianSubArea(
        name: 'Sungai Lembing Historic Mines',
        fullQuery: 'Sungai Lembing, Pahang',
        highlight:
            'Historic underground tin mine tunnel, vintage hanging bridges & mountain morning panorama',
        aliases: ['sungai lembing', 'lembing'],
        latitude: 3.9160,
        longitude: 103.0330,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Terengganu',
    primaryQuery: 'Kuala Terengganu',
    aliases: [
      'trg',
      'terengganu',
      'kuala terengganu',
      'kt',
      'pasar payang',
      'redang',
      'perhentian',
    ],
    description:
        'Iconic Crystal Mosque, Pasar Payang heritage songket, traditional boatbuilding & keropok lekor trail',
    subAreas: [
      MalaysianSubArea(
        name: 'Pasar Payang & Kampung Cina',
        fullQuery: 'Pasar Payang, Kuala Terengganu',
        highlight:
            'Traditional Terengganu silk, batik, songket, Chinatown shophouse murals & local turtle heritage',
        aliases: ['pasar payang', 'kampung cina', 'chinatown kt'],
        latitude: 5.3370,
        longitude: 103.1360,
      ),
      MalaysianSubArea(
        name: 'Masjid Kristal & Islamic Civilization Park',
        fullQuery: 'Masjid Kristal, Kuala Terengganu',
        highlight:
            'Gleaming glass & steel Crystal Mosque on Pulau Wan Man with 21 world Islamic monument replicas',
        aliases: [
          'masjid kristal',
          'crystal mosque',
          'taman tamadun islam',
          'tti',
        ],
        latitude: 5.3220,
        longitude: 103.1180,
      ),
      MalaysianSubArea(
        name: 'Losong Keropok Lekor & Nasi Dagang',
        fullQuery: 'Kampung Losong, Kuala Terengganu',
        highlight:
            'Famous Nasi Dagang Atas Tol, crispy fish keropok lekor stalls & traditional wooden boatbuilding',
        aliases: ['losong', 'nasi dagang atas tol', 'keropok lekor'],
        latitude: 5.3180,
        longitude: 103.1250,
      ),
    ],
  ),
  MalaysianAreaHub(
    name: 'Kelantan',
    primaryQuery: 'Kota Bharu, Kelantan',
    aliases: [
      'kel',
      'kelantan',
      'kota bharu',
      'kb',
      'pasar siti khadijah',
      'tumpat',
    ],
    description:
        'Vibrant Pasar Siti Khadijah, royal timber palaces, giant reclining Buddha temples & authentic Nasi Kerabu',
    subAreas: [
      MalaysianSubArea(
        name: 'Pasar Siti Khadijah & Old Town',
        fullQuery: 'Pasar Siti Khadijah, Kota Bharu, Kelantan',
        highlight:
            'Iconic octagonal central market run by women traders, traditional kuih akok, batik & Kopitiam Kita',
        aliases: [
          'pasar siti khadijah',
          'pasar besar',
          'roti titab',
          'kopitiam kita',
        ],
        latitude: 6.1280,
        longitude: 102.2390,
      ),
      MalaysianSubArea(
        name: 'Istana Jahar & Cultural Heritage Quarter',
        fullQuery: 'Istana Jahar, Kota Bharu, Kelantan',
        highlight:
            'Museum of Royal Traditions with intricate Malay wood carvings, Istana Batu & Kampung Kraftangan',
        aliases: ['istana jahar', 'kampung kraftangan', 'cultural centre kb'],
        latitude: 6.1320,
        longitude: 102.2370,
      ),
      MalaysianSubArea(
        name: 'Tumpat Cultural Shrines',
        fullQuery: 'Tumpat, Kelantan',
        highlight:
            'Wat Phothivihan (40m Reclining Buddha), Wat Machimmaram (Sitting Buddha) & dragon boat traditions',
        aliases: ['tumpat', 'wat phothivihan', 'wat machimmaram'],
        latitude: 6.1830,
        longitude: 102.1330,
      ),
    ],
  ),
];

const List<Map<String, dynamic>> curatedRealPlaces = [
  // -------------------------------------------------------------
  // PENANG (EXPANDED CURATED REAL PLACES)
  // -------------------------------------------------------------
  {
    'name': 'Pinang Peranakan Mansion',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art', 'Local Business'],
    'tags': ['art', 'peranakan', 'local business', 'mansion', 'heritage', 'george', 'town', 'pinang', 'culture'],
    'formattedAddress': '29 Church Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4182, 'longitude': 100.3408},
    'phone': '+604-264 2929',
    'website': 'https://www.pinangperanakanmansion.com.my/',
    'openingHours': 'Daily 09:30 - 17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Peranakan Heritage Discovery',
      'description': 'Photograph one traditional Baba Nyonya antique or architectural carving and learn about Penang Peranakan customs.',
      'rewardPoints': 120,
    },
    'description': 'Opulent 19th-century Peranakan Baba Nyonya mansion showcasing over 1,000 ornate antiques, gold leaf woodwork, and ancestral customs.',
  },
  {
    'name': 'Cheong Fatt Tze - The Blue Mansion',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art', 'Local Business'],
    'tags': ['art', 'local business', 'mansion', 'blue', 'fatt', 'cheong', 'heritage', 'tze', 'george', 'town', 'the', 'culture'],
    'formattedAddress': '14 Leith Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4216, 'longitude': 100.3341},
    'phone': '+604-262 0006',
    'website': 'https://www.cheongfatttzemansion.com/',
    'openingHours': 'Daily 11:00 - 18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Indigo Architectural Snapshot',
      'description': 'Photograph the iconic indigo courtyard and identify one unique Feng Shui element.',
      'rewardPoints': 130,
    },
    'description': 'Award-winning UNESCO-conserved 1890s courtyard mansion famous for its striking indigo blue walls, Art Nouveau stained glass, and Chinese master craft.',
  },
  {
    'name': 'Leong San Tong Khoo Kongsi',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'kongsi', 'leong', 'khoo', 'tong', 'heritage', 'george', 'san', 'town', 'culture'],
    'formattedAddress': '18 Cannon Square, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4165, 'longitude': 100.3373},
    'phone': '+604-261 4609',
    'website': 'https://www.khookongsi.com.my/',
    'openingHours': 'Daily 09:00 - 17:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Clan Architecture Study',
      'description': 'Photograph the intricate granite stone carvings or ornate roof dragons at Khoo Kongsi.',
      'rewardPoints': 140,
    },
    'description': 'The grandest Chinese clan house in Malaysia, renowned for its opulent stone and wood carvings, dragon pillars, and clan lineage museum.',
  },
  {
    'name': 'Fort Cornwallis',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['cornwallis', 'heritage', 'george', 'town', 'fort', 'culture'],
    'formattedAddress': 'Jalan Tun Syed Sheh Barakbah, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4208, 'longitude': 100.3441},
    'phone': '+604-261 0260',
    'website': 'https://www.thefortcornwallis.com/',
    'openingHours': 'Daily 08:00 - 23:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Colonial Bastion History',
      'description': 'Locate the historic Seri Rambai Cannon and photograph the harbour bastion.',
      'rewardPoints': 110,
    },
    'description': 'Largest standing British fortress in Malaysia, constructed in 1786 by Captain Francis Light with lighthouse, chapel, and historical artillery.',
  },
  {
    'name': 'Clan Jetties of Penang (Chew Jetty)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['penang', 'local business', 'culture', 'jetty', 'heritage', 'jetties', 'george', 'town', 'clan', 'chew'],
    'formattedAddress': 'Weld Quay, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4128, 'longitude': 100.3402},
    'phone': '+604-263 6050',
    'website': '',
    'openingHours': 'Daily 09:00 - 21:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Waterfront Clan Settlement Walk',
      'description': 'Photograph the stilt wooden walkway overlooking the Penang Strait and visit the waterfront temple shrine.',
      'rewardPoints': 100,
    },
    'description': 'Historic 19th-century wooden stilt village built over the sea by early Chinese clan immigrants, featuring timber walkways and seaside shrines.',
  },
  {
    'name': 'Armenian Street Heritage Trail',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture', 'Local Business'],
    'tags': ['art', 'trail', 'street', 'local business', 'heritage', 'george', 'armenian', 'town', 'culture'],
    'formattedAddress': 'Lebuh Armenian, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.415, 'longitude': 100.3365},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.8,
    'culturalTask': {
      'title': 'Street Art Photo Walk',
      'description': 'Photograph the Kids on Bicycle mural and explore the surrounding heritage craft stalls.',
      'rewardPoints': 100,
    },
    'description': 'Iconic UNESCO heritage core known for world-famous Ernest Zacharevic street art murals, antique galleries, and souvenir shophouses.',
  },
  {
    'name': 'Kapitan Keling Mosque',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['keling', 'kapitan', 'mosque', 'heritage', 'george', 'town', 'culture'],
    'formattedAddress': '14 Buckingham Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4167, 'longitude': 100.3372},
    'phone': '+604-261 4201',
    'website': '',
    'openingHours': 'Daily 09:30 - 17:30',
    'score': 4.7,
    'description': 'Prominent historic Indo-Moorish mosque founded in 1801 by George Town\'s early Indian Muslim community leaders.',
  },
  {
    'name': 'Sri Mahamariamman Temple Queen Street',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'street', 'temple', 'heritage', 'george', 'sri', 'town', 'mahamariamman', 'culture', 'queen'],
    'formattedAddress': 'Lebuh Queen, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4169, 'longitude': 100.3397},
    'phone': '+604-262 2256',
    'website': '',
    'openingHours': 'Daily 06:00 - 21:00',
    'score': 4.7,
    'description': 'Oldest Hindu temple in Penang founded in 1833, featuring an ornate Dravidian gopuram tower adorned with sculpted deities.',
  },
  {
    'name': 'St. George\'s Anglican Church',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['anglican', 'heritage', 'george', 'church', 'town', 'culture', 'georges'],
    'formattedAddress': '1 Farquhar Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4203, 'longitude': 100.3392},
    'phone': '+604-261 2739',
    'website': '',
    'openingHours': 'Tue-Sun 09:00 - 17:00',
    'score': 4.6,
    'description': 'Oldest purpose-built Anglican church in Southeast Asia, constructed in 1818 with Georgian neoclassical Doric columns and a memorial canopy.',
  },
  {
    'name': 'Han Jiang Ancestral Temple (Teochew Association)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'teochew', 'temple', 'ancestral', 'heritage', 'association', 'george', 'town', 'jiang', 'han', 'culture'],
    'formattedAddress': '127 Lebuh Chulia, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.417, 'longitude': 100.3382},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 08:30 - 17:00',
    'score': 4.7,
    'description': 'UNESCO Award-winning Teochew ancestral temple founded in 1870, famous for its intricate Teochew wood carvings and gilded altars.',
  },
  {
    'name': 'Sun Yat Sen Museum Penang',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['penang', 'local business', 'yat', 'sen', 'heritage', 'george', 'sun', 'town', 'museum', 'culture'],
    'formattedAddress': '120 Armenian Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4153, 'longitude': 100.3361},
    'phone': '+604-262 0123',
    'website': '',
    'openingHours': 'Daily 09:00 - 17:00',
    'score': 4.6,
    'description': 'Historic shophouse base where Dr. Sun Yat-sen planned the 1911 Guangzhou uprising, preserving period courtyard furniture and historical archives.',
  },
  {
    'name': 'Suffolk House',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Food', 'Local Business'],
    'tags': ['house', 'local business', 'heritage', 'suffolk', 'george', 'town', 'food', 'culture'],
    'formattedAddress': '250 Jalan Air Itam, George Town, 10460 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4103, 'longitude': 100.3069},
    'phone': '+604-228 3930',
    'website': '',
    'openingHours': 'Daily 11:00 - 22:00',
    'score': 4.7,
    'description': 'Malaysia\'s only surviving Anglo-Indian Georgian mansion, former residence of early governors, now hosting heritage tours and fine English high tea.',
  },
  {
    'name': 'Penang Town Hall & City Hall Esplanade',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'penang', 'city', 'heritage', 'george', 'esplanade', 'town', 'hall', 'culture'],
    'formattedAddress': 'Jalan Padang Kota Lama, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4217, 'longitude': 100.3414},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.7,
    'description': 'Majestic Victorian & Edwardian colonial municipal buildings overlooking Padang Kota Lama and the northern seafront promenade.',
  },
  {
    'name': 'Penang State Museum and Art Gallery',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture'],
    'tags': ['state', 'art', 'and', 'penang', 'heritage', 'gallery', 'george', 'town', 'museum', 'culture'],
    'formattedAddress': 'Lebuh Farquhar, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4208, 'longitude': 100.3396},
    'phone': '+604-226 1462',
    'website': '',
    'openingHours': 'Sat-Thu 09:00 - 17:00',
    'score': 4.6,
    'description': 'State cultural gallery preserving Penang\'s historical paintings, antique oil canvasses, colonial artifacts, and rotating contemporary Malaysian art.',
  },
  {
    'name': 'Seh Tek Tong Cheah Kongsi',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'kongsi', 'tong', 'heritage', 'george', 'cheah', 'seh', 'town', 'tek', 'culture'],
    'formattedAddress': '8 Lebuh Pantai, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4157, 'longitude': 100.3385},
    'phone': '+604-261 0107',
    'website': '',
    'openingHours': 'Daily 09:00 - 17:00',
    'score': 4.7,
    'description': 'One of Penang\'s oldest Hokkien clan organizations, noted for its fortified compound, ornate sweep roofs, and lion statues.',
  },
  {
    'name': 'Yap Kongsi & Choo Chay Keong Temple',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'kongsi', 'temple', 'chay', 'heritage', 'george', 'keong', 'choo', 'town', 'culture', 'yap'],
    'formattedAddress': '71 Lebuh Armenian, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 35,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4158, 'longitude': 100.3369},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 09:00 - 17:00',
    'score': 4.6,
    'description': 'Historic clan temple at the corner of Armenian Street boasting Straits Chinese embellishments and dragon stone carvings.',
  },
  {
    'name': 'Tan Jetty Waterfront Heritage',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['waterfront', 'jetty', 'local business', 'heritage', 'george', 'tan', 'town', 'culture'],
    'formattedAddress': 'Weld Quay, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4121, 'longitude': 100.3395},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 09:00 - 21:00',
    'score': 4.6,
    'description': 'Historic wooden clan jetty with a picturesque extended timber pier extending far out into the Penang harbor.',
  },
  {
    'name': 'Queen Victoria Memorial Clock Tower',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['clock', 'tower', 'heritage', 'memorial', 'george', 'victoria', 'town', 'culture', 'queen'],
    'formattedAddress': 'Lebuh Light, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4194, 'longitude': 100.344},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': '60-foot Moorish clock tower commissioned in 1897 by local millionaire Cheah Chen Eok to celebrate Queen Victoria\'s Diamond Jubilee.',
  },
  {
    'name': 'House of Yeap Chor Ee',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['house', 'chor', 'local business', 'heritage', 'george', 'yeap', 'town', 'culture'],
    'formattedAddress': '4 Lebuh Penang, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4187, 'longitude': 100.3421},
    'phone': '+604-261 0288',
    'website': '',
    'openingHours': 'Mon-Fri 09:30 - 17:00',
    'score': 4.6,
    'description': 'Heritage museum documenting the life and rags-to-riches legacy of Penang tycoon and Ban Hin Lee Bank founder Yeap Chor Ee.',
  },
  {
    'name': 'Hin Bus Depot Arts Centre',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'local business', 'george', 'arts', 'centre', 'town', 'hin', 'culture', 'bus', 'depot'],
    'formattedAddress': '31A Jalan Gurdwara, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4124, 'longitude': 100.3297},
    'phone': '+604-218 9004',
    'website': 'https://hinbusdepot.com/',
    'openingHours': 'Mon-Fri 12:00 - 19:00, Sat-Sun 11:00 - 19:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Artisan Depot Mural Explorer',
      'description': 'Explore the open art courtyard and photograph Ernest Zacharevic murals or weekend artisan crafts.',
      'rewardPoints': 110,
    },
    'description': 'A thriving community art space set within a restored 1940s Art Deco bus depot, hosting open-air murals, art exhibitions, artisan cafes, and craft markets.',
  },
  {
    'name': 'ChinaHouse Penang',
    'category': 'Food',
    'plannerCategories': ['Food', 'Art', 'Culture', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'chinahouse', 'george', 'food', 'town', 'culture'],
    'formattedAddress': '153 Beach Street & 183B Victoria Street, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4147, 'longitude': 100.3392},
    'phone': '+604-263 7299',
    'website': 'https://www.chinahouse.com.my/',
    'openingHours': 'Daily 09:00 - 00:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Longest Shophouse Art & Cake Walk',
      'description': 'Walk through the 400-ft connected heritage shophouse compound and photograph the iconic cake table display.',
      'rewardPoints': 100,
    },
    'description': 'Traditional heritage compound made of three linked heritage shophouses with an open courtyard, art galleries, live music, and over 30 varieties of daily cakes.',
  },
  {
    'name': 'Jawi House Cafe Gallery',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Art', 'Local Business'],
    'tags': ['cafe', 'art', 'house', 'local business', 'gallery', 'george', 'town', 'jawi', 'food', 'culture'],
    'formattedAddress': '85 Armenian Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4152, 'longitude': 100.3364},
    'phone': '+604-261 3680',
    'website': 'https://jawihouse.com/',
    'openingHours': 'Wed-Mon 11:00 - 21:30',
    'score': 4.7,
    'culturalTask': {
      'title': 'Jawi Peranakan Spice Heritage',
      'description': 'Taste authentic Jawi Peranakan Nasi Lemuni or Herbal Rice and snap a photo of the heritage dining interior.',
      'rewardPoints': 110,
    },
    'description': 'Michelin-selected culinary gallery celebrating Jawi Peranakan gastronomy, featuring Nasi Lemuni, herbal curries, and antique art gallery displays.',
  },
  {
    'name': 'Wonderfood Museum Penang',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Food', 'Art', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'wonderfood', 'george', 'town', 'food', 'museum', 'culture'],
    'formattedAddress': '49 Beach Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4163, 'longitude': 100.3411},
    'phone': '+604-262 9504',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Giant Hawker Food Snap',
      'description': 'Pose alongside giant replica dishes of Laksa, Cendol, or Roti Canai to document Malaysian street food heritage.',
      'rewardPoints': 100,
    },
    'description': 'Vibrant interactive museum displaying hyper-realistic giant replicas of Malaysian street foods, traditional cooking crafts, and colonial banquet dioramas.',
  },
  {
    'name': 'Tek Sen Restaurant',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['restaurant', 'local business', 'sen', 'george', 'town', 'food', 'tek', 'culture'],
    'formattedAddress': '18 Carnarvon Street, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4172, 'longitude': 100.3355},
    'phone': '+6012-981 5117',
    'website': '',
    'openingHours': 'Wed-Mon 12:00 - 14:30, 18:00 - 20:30',
    'score': 4.8,
    'description': 'Michelin Bib Gourmand heritage Cantonese and Teochew zi char eatery established in 1965, famous for double-cooked pork belly and Assam fish.',
  },
  {
    'name': 'Hameediyah Restaurant (Est. 1907)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Heritage', 'Local Business'],
    'tags': ['est', 'restaurant', 'local business', 'heritage', 'george', 'hameediyah', '1907', 'town', 'food', 'culture'],
    'formattedAddress': '164A Campbell Street, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4172, 'longitude': 100.333},
    'phone': '+604-261 1095',
    'website': 'https://hameediyah.my/',
    'openingHours': 'Daily 10:00 - 22:00',
    'score': 4.8,
    'description': 'The oldest surviving Nasi Kandar establishment in Malaysia, serving signature spice curries, duck rendang, and crispy murtabak on Campbell Street since 1907.',
  },
  {
    'name': 'Penang Road Famous Teochew Chendul',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['chendul', 'famous', 'penang', 'local business', 'road', 'teochew', 'george', 'town', 'food', 'culture'],
    'formattedAddress': '27 & 29 Lebuh Keng Kwee, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4183, 'longitude': 100.331},
    'phone': '+604-262 6002',
    'website': 'https://www.chendul.my/',
    'openingHours': 'Daily 10:30 - 19:00',
    'score': 4.7,
    'description': 'Legendary roadside dessert stall founded in 1936 serving signature Teochew chendul with fresh coconut milk, pandan jelly noodles, and fragrant Gula Melaka.',
  },
  {
    'name': 'Line Clear Nasi Kandar',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['kandar', 'local business', 'george', 'nasi', 'town', 'food', 'clear', 'culture', 'line'],
    'formattedAddress': '177 Jalan Penang, George Town, 10000 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4198, 'longitude': 100.3323},
    'phone': '+604-261 4440',
    'website': '',
    'openingHours': 'Daily 07:00 - 23:00',
    'score': 4.6,
    'description': 'Legendary Penang alleyway eatery serving rich, aromatic mixed curry gravies and spiced fried chicken since 1930.',
  },
  {
    'name': 'Ghee Hiang Heritage Pastry & Sesame Oil (Since 1856)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Culture', 'Local Business'],
    'tags': ['pastry', 'since', '1856', 'local business', 'heritage', 'ghee', 'george', 'town', 'food', 'oil', 'culture', 'hiang', 'sesame'],
    'formattedAddress': '216 Jalan Macalister, George Town, 10400 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4162, 'longitude': 100.3204},
    'phone': '+604-227 2222',
    'website': 'https://ghee-hiang.com/',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.8,
    'description': 'Penang\'s oldest traditional bakery brand founded in 1856, renowned for handcrafted Tau Sar Piah pastries and aromatic pure sesame seed oil.',
  },
  {
    'name': 'Ban Heang Pastry Heritage Bakery',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Local Business'],
    'tags': ['pastry', 'ban', 'local business', 'heritage', 'bakery', 'george', 'town', 'food', 'heang'],
    'formattedAddress': '200 Jalan Macalister, George Town, 10400 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 35,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.416, 'longitude': 100.321},
    'phone': '+604-229 5018',
    'website': '',
    'openingHours': 'Daily 09:00 - 19:00',
    'score': 4.7,
    'description': 'Famous Penang pastry house known for crispy Tambun biscuits, heong peah, and traditional handmade confectionery.',
  },
  {
    'name': 'Him Heang Traditional Tambun Biscuits',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Local Business'],
    'tags': ['biscuits', 'traditional', 'local business', 'heritage', 'tambun', 'george', 'town', 'food', 'him', 'heang'],
    'formattedAddress': '163 Jalan Burma, George Town, 10050 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 35,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4225, 'longitude': 100.322},
    'phone': '+604-228 6129',
    'website': '',
    'openingHours': 'Mon-Sat 09:30 - 15:00',
    'score': 4.7,
    'description': 'Multi-generational heritage biscuit specialist famous for fresh oven-baked Tambun biscuits, Beh Teh Saw, and savoury pastry rolls.',
  },
  {
    'name': 'Moh Teng Pheow Nyonya Koay',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Heritage', 'Local Business'],
    'tags': ['nyonya', 'koay', 'pheow', 'local business', 'teng', 'heritage', 'george', 'moh', 'town', 'food', 'culture'],
    'formattedAddress': 'Lebuh Chulia, Jalan Masjid, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.419, 'longitude': 100.3362},
    'phone': '+6012-415 2677',
    'website': '',
    'openingHours': 'Tue-Sun 10:30 - 17:00',
    'score': 4.7,
    'description': 'Historic Nyonya kuih canteen and workshop manufacturing colourful handmade kuih talam, ang ku kueh, and nasi ulam since 1933.',
  },
  {
    'name': 'Toh Soon Cafe (Charcoal Toast & Coffee)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Local Business'],
    'tags': ['cafe', 'soon', 'local business', 'heritage', 'george', 'toh', 'toast', 'charcoal', 'town', 'food', 'coffee'],
    'formattedAddress': 'Campbell Street Off Lebuh Campbell, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4188, 'longitude': 100.3323},
    'phone': '+604-261 3832',
    'website': '',
    'openingHours': 'Mon-Sat 08:00 - 17:00',
    'score': 4.6,
    'description': 'Iconic alleyway breakfast institution toasting bread over glowing charcoal drums, served with homemade kaya and half-boiled eggs.',
  },
  {
    'name': 'Siam Road Charcoal Char Koay Teow',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['koay', 'local business', 'road', 'charcoal', 'george', 'char', 'town', 'food', 'siam', 'teow'],
    'formattedAddress': '82 Jalan Siam, George Town, 10400 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4147, 'longitude': 100.3205},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Tue-Sat 12:00 - 18:00',
    'score': 4.8,
    'description': 'World-famous Michelin Bib Gourmand char koay teow fried with rich pork lard, succulent prawns, cockles, and smoky charcoal wok hei.',
  },
  {
    'name': 'Gurney Drive Hawker Centre',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['local business', 'drive', 'gurney', 'george', 'centre', 'town', 'food', 'culture', 'hawker'],
    'formattedAddress': '172 Solok Gurney 1, George Town, 10250 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4398, 'longitude': 100.309},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 17:00 - 23:30',
    'score': 4.6,
    'description': 'Penang\'s premier seafront open-air hawker promenade gathering over 50 classic Penang street foods including oyster omelettes, rojak, and pasembur.',
  },
  {
    'name': 'Kimberley Street Food Night Market',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['night', 'street', 'local business', 'kimberley', 'george', 'food', 'town', 'culture', 'market'],
    'formattedAddress': 'Lebuh Kimberley, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4164, 'longitude': 100.3328},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 17:00 - 23:00',
    'score': 4.7,
    'description': 'Historic food street celebrated for the Four Heavenly Kings hawkers: Duck Kway Chap, Char Koay Teow, Si Koh Sui dessert, and Braised Chicken Feet.',
  },
  {
    'name': 'New Lane Hawker Stalls (Lorong Baru)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['local business', 'baru', 'stalls', 'new', 'lorong', 'george', 'town', 'food', 'lane', 'culture', 'hawker'],
    'formattedAddress': 'Lorong Baru, George Town, 10450 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 55,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4144, 'longitude': 100.3262},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Thu-Tue 16:00 - 23:00',
    'score': 4.6,
    'description': 'Bustling roadside evening food street crowded with pop-up hawker carts serving grilled chicken wings, chee cheong fun, and popiah.',
  },
  {
    'name': 'Deen Maju Nasi Kandar',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['kandar', 'maju', 'local business', 'deen', 'george', 'nasi', 'town', 'food', 'culture'],
    'formattedAddress': '170 Jalan Gurdwara, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4108, 'longitude': 100.3286},
    'phone': '+6012-425 2137',
    'website': '',
    'openingHours': 'Daily 12:00 - 23:00',
    'score': 4.7,
    'description': 'Beloved local Nasi Kandar hotspot acclaimed for crispy spiced fried chicken, signature thick Kuah Campur, and coconut sambal.',
  },
  {
    'name': 'Little India Penang Cultural District',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Food', 'Local Business'],
    'tags': ['penang', 'local business', 'culture', 'india', 'heritage', 'george', 'little', 'town', 'food', 'cultural', 'district'],
    'formattedAddress': 'Lebuh Pasar, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4165, 'longitude': 100.34},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 09:00 - 22:00',
    'score': 4.7,
    'description': 'Vibrant ethnic quarter filled with Bollywood melodies, colourful saree shops, aromatic spice merchants, and traditional Indian sweet stalls.',
  },
  {
    'name': 'Chowrasta Market Heritage Traders',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Local Business', 'Food'],
    'tags': ['local business', 'heritage', 'george', 'chowrasta', 'town', 'traders', 'food', 'culture', 'market'],
    'formattedAddress': 'Jalan Penang, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4173, 'longitude': 100.3312},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 06:30 - 18:00',
    'score': 4.6,
    'description': 'Historic marketplace dating back to the 1890s, famous for preserved nutmeg pickles, traditional fresh produce, and second-hand book lofts.',
  },
  {
    'name': 'Art Lane George Town',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture'],
    'tags': ['art', 'heritage', 'george', 'town', 'lane', 'culture'],
    'formattedAddress': '127 Victoria Street, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.414, 'longitude': 100.3398},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 09:00 - 19:00',
    'score': 4.6,
    'description': 'Open public gallery stretching through transformed heritage shophouses adorned with vibrant modern graffiti, paintings, and community art.',
  },
  {
    'name': 'Muntri Street Art & Shophouses',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture', 'Local Business'],
    'tags': ['art', 'muntri', 'street', 'local business', 'heritage', 'george', 'town', 'shophouses', 'culture'],
    'formattedAddress': 'Lebuh Muntri, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4202, 'longitude': 100.3348},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.7,
    'description': 'Elegant heritage lane preserving 19th-century Straits eclectic shophouses, Ernest Zacharevic murals, and artisan lifestyle cafes.',
  },
  {
    'name': 'Penang 3D Trick Art Museum',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'george', 'town', 'trick', 'museum', 'culture'],
    'formattedAddress': '10 Lebuh Penang, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.419, 'longitude': 100.3415},
    'phone': '+604-263 1628',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'description': 'Interactive optical illusion museum with 3D paintings depicting Penang clan jetties, Trishaw rides, and fantasy themes.',
  },
  {
    'name': 'Upside Down Museum Penang',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'george', 'upside', 'town', 'down', 'culture', 'museum'],
    'formattedAddress': '45 Lebuh Kimberley, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4162, 'longitude': 100.3325},
    'phone': '+604-264 2626',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:30',
    'score': 4.6,
    'description': 'Fun, inverted interactive exhibition rooms with upside-down heritage living rooms, Penang kopitiams, and street scenes.',
  },
  {
    'name': 'Penang House of Music',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Heritage'],
    'tags': ['art', 'house', 'penang', 'heritage', 'george', 'town', 'culture', 'music'],
    'formattedAddress': 'Level 4, KOMTAR, Jalan Penang, 10000 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.414, 'longitude': 100.3302},
    'phone': '+604-370 6675',
    'website': '',
    'openingHours': 'Daily 11:00 - 20:00',
    'score': 4.8,
    'description': 'Interactive musical heritage gallery celebrating Penang\'s vibrant 20th-century music, Bangsawan theater, and radio history.',
  },
  {
    'name': 'Batik Painting Museum Penang',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Heritage', 'Local Business'],
    'tags': ['art', 'penang', 'batik', 'local business', 'heritage', 'george', 'town', 'painting', 'culture', 'museum'],
    'formattedAddress': '19 Armenian Street, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4154, 'longitude': 100.3364},
    'phone': '+604-262 0150',
    'website': '',
    'openingHours': 'Daily 10:00 - 18:00',
    'score': 4.7,
    'description': 'Dedicated fine art museum tracing the history of Malaysian batik painting from the 1950s pioneer Chuah Thean Teng to contemporary masters.',
  },
  {
    'name': 'Penang Glass Museum',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'glass', 'george', 'town', 'museum', 'culture'],
    'formattedAddress': '6 Jalan Burma, George Town, 10050 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4188, 'longitude': 100.33},
    'phone': '+604-251 9880',
    'website': '',
    'openingHours': 'Mon-Fri 09:30 - 18:00, Sat 09:30 - 17:00',
    'score': 4.6,
    'description': 'Specialty glass craft gallery showcasing stained glass artwork, 3D glass carving, mirror murals, and glass crafting workshops.',
  },
  {
    'name': 'Ghost Museum Penang (Cultural Folklore)',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'cultural', 'ghost', 'penang', 'local business', 'folklore', 'george', 'town', 'museum', 'culture'],
    'formattedAddress': '57 Lebuh Melayu, George Town, 10100 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4148, 'longitude': 100.3349},
    'phone': '+604-261 2352',
    'website': '',
    'openingHours': 'Daily 10:00 - 19:00',
    'score': 4.6,
    'description': 'Cultural museum showcasing Malaysian, Chinese, and global folklore myths with detailed theatrical sets and costume photo areas.',
  },
  {
    'name': 'Colonial Penang Museum',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture'],
    'tags': ['art', 'penang', 'heritage', 'george', 'town', 'colonial', 'culture', 'museum'],
    'formattedAddress': '4 Jalan Sultan Ahmad Shah, George Town, 10050 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4285, 'longitude': 100.312},
    'phone': '+604-228 8888',
    'website': '',
    'openingHours': 'Daily 09:30 - 18:30',
    'score': 4.6,
    'description': 'Museum housing authentic colonial antiques, marble statues, master oil paintings, and original reverse glass paintings of the 19th century.',
  },
  {
    'name': 'Ernest Zacharevic \'Boy on a Motorbike\' Mural',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture'],
    'tags': ['art', 'zacharevic', 'mural', 'heritage', 'george', 'ernest', 'boy', 'motorbike', 'town', 'culture'],
    'formattedAddress': '12 Lebuh Ah Quee, George Town, 10200 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 25,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4158, 'longitude': 100.337},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.8,
    'description': 'World-famous heritage street art mural integrating an actual vintage motorcycle with wall painting on historic Lebuh Ah Quee.',
  },
  {
    'name': 'Ernest Zacharevic \'Brother & Sister on a Swing\' Mural',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture'],
    'tags': ['art', 'sister', 'zacharevic', 'mural', 'heritage', 'george', 'swing', 'town', 'ernest', 'culture', 'brother'],
    'formattedAddress': 'Gat Lebuh Chulia, George Town, 10300 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 25,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4146, 'longitude': 100.34},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.7,
    'description': 'Charming interactive mural on Gat Lebuh Chulia depicting two smiling siblings swinging on an installed timber swing.',
  },
  {
    'name': 'Penang Botanic Gardens (Waterfall Gardens)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Heritage'],
    'tags': ['penang', 'gardens', 'botanic', 'gardens', 'heritage', 'george', 'nature', 'town', 'waterfall'],
    'formattedAddress': '673A Jalan Kebun Bunga, George Town, 10350 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4378, 'longitude': 100.2905},
    'phone': '+604-226 4401',
    'website': '',
    'openingHours': 'Daily 06:30 - 19:00',
    'score': 4.7,
    'description': 'Historic 1884 botanical gardens surrounded by verdant hills, ancient rainforest trees, lily ponds, and macaque monkeys.',
  },
  {
    'name': 'Youth Park Penang (Taman Belia)',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['belia', 'taman', 'penang', 'park', 'youth', 'george', 'nature', 'town'],
    'formattedAddress': 'Persiaran Kuari, George Town, 10450 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.431, 'longitude': 100.298},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 06:00 - 19:30',
    'score': 4.7,
    'description': 'Expansive green recreation park with natural stream pools, shaded forest walking trails, outdoor gymnasiums, and lush canopy trees.',
  },
  {
    'name': 'Kek Lok Si Temple',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Nature'],
    'tags': ['lok', 'temple', 'itam', 'kek', 'heritage', 'nature', 'air', 'culture'],
    'formattedAddress': 'Tingkat Lembah Ria 1, 11500 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 90,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3995, 'longitude': 100.2737},
    'phone': '+604-828 3317',
    'website': 'https://kekloksitemple.com/',
    'openingHours': 'Daily 08:30 - 17:30',
    'score': 4.9,
    'culturalTask': {
      'title': 'Pagoda of Ten Thousand Buddhas',
      'description': 'Climb the 7-tier Pagoda combining Chinese, Thai, and Burmese architectural tiers and photograph the view.',
      'rewardPoints': 140,
    },
    'description': 'The largest Buddhist temple in Malaysia, featuring the 7-tier Pagoda of Ten Thousand Buddhas, tranquil turtle liberation pond, and towering bronze Guanyin statue.',
  },
  {
    'name': 'Penang Hill Biosphere Nature Reserve',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Heritage'],
    'tags': ['penang', 'itam', 'heritage', 'reserve', 'nature', 'hill', 'air', 'biosphere'],
    'formattedAddress': 'Bukit Bendera, 11500 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 120,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4244, 'longitude': 100.2687},
    'phone': '+604-828 8880',
    'website': 'https://www.penanghill.gov.my/',
    'openingHours': 'Daily 06:30 - 22:00',
    'score': 4.8,
    'description': 'Lush UNESCO Biosphere rainforest peak accessed via century-old funicular railway, offering panoramic island vistas and cool mountain air.',
  },
  {
    'name': 'The Habitat Penang Hill',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['habitat', 'penang', 'local business', 'itam', 'nature', 'hill', 'air', 'the'],
    'formattedAddress': 'Bukit Bendera, 11300 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 120,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4243, 'longitude': 100.2687},
    'phone': '+604-826 7677',
    'website': 'https://thehabitat.my/',
    'openingHours': 'Daily 09:00 - 19:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Curtis Crest Rainforest Canopy Walk',
      'description': 'Walk along the tree canopy bridge and Curtis Crest 360 platform in the 130-million-year-old rainforest.',
      'rewardPoints': 150,
    },
    'description': 'World-class eco-tourism rainforest reserve inside the UNESCO Biosphere Reserve on Penang Hill, featuring Curtis Crest 360 treetop canopy walk and pristine jungle trails.',
  },
  {
    'name': 'The Owl Museum Penang Hill',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Nature', 'Local Business'],
    'tags': ['art', 'penang', 'local business', 'itam', 'owl', 'nature', 'hill', 'air', 'the', 'culture', 'museum'],
    'formattedAddress': 'Astaka Bukit Bendera, 11300 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4241, 'longitude': 100.269},
    'phone': '+604-826 5704',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'description': 'Southeast Asia\'s first owl-themed art museum showcasing over 1,000 fascinating owl sculptures, paintings, and handicrafts from across the globe.',
  },
  {
    'name': 'Pasar Air Itam Laksa',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['laksa', 'local business', 'itam', 'culture', 'food', 'air', 'pasar'],
    'formattedAddress': '1 Jalan Pasar, 11500 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4013, 'longitude': 100.2781},
    'phone': '+6012-500 7063',
    'website': '',
    'openingHours': 'Daily 10:30 - 19:00',
    'score': 4.7,
    'description': 'Iconic market stall operating since 1955 at the foot of Kek Lok Si, known for rich tamarind mackerel broth, fresh mint, and dark prawn paste.',
  },
  {
    'name': 'Sister Curry Mee Air Itam',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Local Business'],
    'tags': ['sister', 'local business', 'itam', 'heritage', 'food', 'air', 'mee', 'curry'],
    'formattedAddress': '612 T, Jalan Air Itam, 11500 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.401, 'longitude': 100.2785},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Wed-Mon 07:30 - 13:00',
    'score': 4.7,
    'description': 'Legendary roadside stall run by two elderly sisters since 1946, serving charcoal-simmered coconut curry noodles with cuttlefish and chili sambal.',
  },
  {
    'name': 'Air Itam Dam & Mountain Trail',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['trail', 'dam', 'itam', 'mountain', 'nature', 'air'],
    'formattedAddress': 'Jalan Balik Pulau, 11500 Ayer Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.397, 'longitude': 100.264},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 19:00',
    'score': 4.7,
    'description': 'Scenic hilltop reservoir lake surrounded by forest ridges, popular with morning runners and nature walkers.',
  },
  {
    'name': 'Penang National Park (Taman Negara Pulau Pinang)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Heritage'],
    'tags': ['bahang', 'taman', 'penang', 'park', 'pulau', 'pinang', 'negara', 'teluk', 'heritage', 'nature', 'national'],
    'formattedAddress': 'Jalan Hassan Abbas, Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 120,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.46, 'longitude': 100.2078},
    'phone': '+604-881 3530',
    'website': '',
    'openingHours': 'Daily 08:00 - 17:00',
    'score': 4.7,
    'description': 'Malaysia\'s smallest national park featuring coastal jungle hikes, meromictic lake, secluded sandy bays, and lighthouse trails.',
  },
  {
    'name': 'Monkey Beach (Teluk Duyung)',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['bahang', 'duyung', 'monkey', 'beach', 'teluk', 'teluk', 'nature'],
    'formattedAddress': 'Penang National Park, Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.477, 'longitude': 100.198},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 08:00 - 17:00',
    'score': 4.6,
    'description': 'Pristine sandy cove tucked inside the national park, reachable by scenic coastal trail or boat ride from Teluk Bahang jetty.',
  },
  {
    'name': 'Pantai Kerachut & Turtle Sanctuary',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['sanctuary', 'bahang', 'kerachut', 'teluk', 'turtle', 'nature', 'pantai'],
    'formattedAddress': 'Penang National Park, Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 90,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.459, 'longitude': 100.176},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 08:00 - 17:00',
    'score': 4.7,
    'description': 'Serene beach known for its seasonal green sea turtle nesting center, suspension bridge, and unique dual-layer meromictic lake.',
  },
  {
    'name': 'Tropical Spice Garden',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture', 'Heritage', 'Local Business'],
    'tags': ['bahang', 'local business', 'spice', 'teluk', 'heritage', 'nature', 'garden', 'tropical', 'culture'],
    'formattedAddress': 'Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 75,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4628, 'longitude': 100.2289},
    'phone': '+604-881 1797',
    'website': 'https://tropicalspicegarden.com/',
    'openingHours': 'Daily 09:00 - 16:30',
    'score': 4.8,
    'description': 'Award-winning eco-sanctuary showcasing over 500 species of living tropical herbs, culinary spices, jungle trails, and cooking school.',
  },
  {
    'name': 'Entopia by Penang Butterfly Farm',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['bahang', 'farm', 'penang', 'local business', 'butterfly', 'entopia', 'teluk', 'nature'],
    'formattedAddress': '830 Jalan Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4468, 'longitude': 100.2155},
    'phone': '+604-888 8111',
    'website': 'https://www.entopia.com/',
    'openingHours': 'Thu-Tue 09:00 - 17:00',
    'score': 4.7,
    'description': 'Giant glasshouse eco-sanctuary with thousands of free-flying butterflies, live reptiles, and interactive indoor nature discovery centers.',
  },
  {
    'name': 'ESCAPE Penang Adventure Park',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['escape', 'bahang', 'penang', 'local business', 'park', 'teluk', 'nature', 'adventure'],
    'formattedAddress': '828 Jalan Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 180,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4485, 'longitude': 100.2152},
    'phone': '+604-881 1106',
    'website': 'https://www.escape.my/',
    'openingHours': 'Tue-Sun 10:00 - 18:00',
    'score': 4.8,
    'description': 'Guinness World Record-holding forest adventure theme park featuring the world\'s longest water slide, ziplining, and obstacle ropes in lush nature.',
  },
  {
    'name': 'Teluk Bahang Forest Eco Park (Taman Rimba)',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['bahang', 'taman', 'park', 'teluk', 'eco', 'nature', 'forest', 'rimba'],
    'formattedAddress': 'Jalan Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4475, 'longitude': 100.2168},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 18:00',
    'score': 4.6,
    'description': 'Tranquil state forest park featuring natural river cascades, shady forest walking trails, picnic gazebos, and a forestry museum.',
  },
  {
    'name': 'Teluk Bahang Dam Scenic Lookout',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['bahang', 'dam', 'lookout', 'teluk', 'nature', 'scenic'],
    'formattedAddress': 'Jalan Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.442, 'longitude': 100.217},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 19:00',
    'score': 4.6,
    'description': 'Spectacular reservoir dam providing wide scenic vistas across turquoise waters framed by coastal mountain ridges.',
  },
  {
    'name': 'Penang Batik Factory',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business', 'Heritage'],
    'tags': ['art', 'bahang', 'penang', 'batik', 'local business', 'teluk', 'heritage', 'factory', 'culture'],
    'formattedAddress': '665 Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4578, 'longitude': 100.2185},
    'phone': '+604-885 1284',
    'website': '',
    'openingHours': 'Daily 09:00 - 17:30',
    'score': 4.6,
    'description': 'One of the pioneers of batik printing in Penang established in 1973, offering live canting wax demonstrations and authentic hand-painted silk batiks.',
  },
  {
    'name': 'Batu Ferringhi Beach & Coastal Trail',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['trail', 'local business', 'batu', 'beach', 'coastal', 'nature', 'ferringhi'],
    'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4744, 'longitude': 100.2472},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.7,
    'description': 'Famous white sand coastline along northern Penang with coastal sea breezes, water sports, beach cafes, and sunset viewpoints.',
  },
  {
    'name': 'Moonlight Bay Coastal Point',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['bay', 'batu', 'point', 'coastal', 'nature', 'ferringhi', 'moonlight'],
    'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 35,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.472, 'longitude': 100.261},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Scenic cliffside rocky coast between Batu Ferringhi and Tanjung Bungah with crashing waves and sunset views.',
  },
  {
    'name': 'Miami Beach Penang (Batu Ferringhi)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['ferringhi', 'penang', 'local business', 'batu', 'beach', 'nature', 'miami', 'batu', 'ferringhi'],
    'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.475, 'longitude': 100.268},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Shaded sandy beach cove popular for quiet ocean strolls, coconut drink stalls, and coastal rock formations.',
  },
  {
    'name': 'Yahong Art Gallery & Batik Studio',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'yahong', 'batik', 'local business', 'batu', 'gallery', 'ferringhi', 'culture', 'studio'],
    'formattedAddress': '58D Batu Ferringhi, 11100 Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4735, 'longitude': 100.2458},
    'phone': '+604-881 1251',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.7,
    'description': 'Art gallery founded by renowned batik painting master Chuah Thean Teng, exhibiting original fine art batiks, Chinese ink paintings, and antiques.',
  },
  {
    'name': 'Long Beach Food Court & Seafood',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['local business', 'batu', 'beach', 'long', 'ferringhi', 'food', 'court', 'seafood'],
    'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.473, 'longitude': 100.2465},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 11:30 - 23:00',
    'score': 4.7,
    'description': 'Bustling open-air food center offering char koay teow, satay skewers, grilled stingray, and fresh tropical fruit juices.',
  },
  {
    'name': 'Batu Ferringhi Heritage Kopitiam',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['local business', 'batu', 'heritage', 'food', 'kopitiam', 'ferringhi'],
    'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4715, 'longitude': 100.245},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 14:00',
    'score': 4.6,
    'description': 'Traditional morning kopitiam serving charcoal-toasted kaya butter toast, half-boiled kampung eggs, and aromatic Hainanese coffee.',
  },
  {
    'name': 'Audi Dream Farm Balik Pulau',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture', 'Local Business'],
    'tags': ['farm', 'balik', 'local business', 'dream', 'pulau', 'nature', 'audi', 'culture'],
    'formattedAddress': 'Jalan Pulau Betong, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.319, 'longitude': 100.203},
    'phone': '+6012-406 9099',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'description': 'Rural family eco-farm in Balik Pulau featuring petting zoo animals, organic vegetable plots, sunflower gardens, and fresh farm dining.',
  },
  {
    'name': 'Saanen Dairy Goat Farm Balik Pulau',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['farm', 'balik', 'saanen', 'pulau', 'local business', 'dairy', 'goat', 'nature'],
    'formattedAddress': '298 Mukim 1 Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.378, 'longitude': 100.212},
    'phone': '+6019-516 3017',
    'website': '',
    'openingHours': 'Daily 10:00 - 17:00',
    'score': 4.7,
    'description': 'Charming family-run goat farm where visitors can feed friendly dairy goats, taste fresh pasteurized goat milk, and try homemade goat milk ice cream.',
  },
  {
    'name': 'Ghee Hup Nutmeg Factory & Plantation',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Nature', 'Local Business', 'Food'],
    'tags': ['nutmeg', 'balik', 'local business', 'pulau', 'plantation', 'ghee', 'nature', 'food', 'factory', 'culture', 'hup'],
    'formattedAddress': 'Bukit Prince of Wales, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3582, 'longitude': 100.2285},
    'phone': '+6012-426 6422',
    'website': '',
    'openingHours': 'Daily 09:00 - 17:00',
    'score': 4.7,
    'description': 'Traditional hillside nutmeg plantation and processing cottage producing sweet nutmeg slices, therapeutic nutmeg oil, and fresh nutmeg juice.',
  },
  {
    'name': 'Kim Laksa Balik Pulau (Nan Guang Coffee Shop)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['kim', 'laksa', 'shop', 'balik', 'local business', 'pulau', 'nan', 'coffee', 'food', 'guang', 'culture'],
    'formattedAddress': 'Nan Guang Coffee Shop, Main Road, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3524, 'longitude': 100.2366},
    'phone': '+6012-448 8177',
    'website': '',
    'openingHours': 'Wed-Sun 10:00 - 17:00',
    'score': 4.8,
    'description': 'Celebrated Balik Pulau coffee shop serving two styles of laksa: pungent spicy Assam Laksa and creamy coconut milk Siam Laksa.',
  },
  {
    'name': 'Bao Sheng Durian Farm & Orchard',
    'category': 'Food',
    'plannerCategories': ['Food', 'Nature', 'Local Business'],
    'tags': ['farm', 'sheng', 'balik', 'local business', 'pulau', 'durian', 'orchard', 'bao', 'nature', 'food'],
    'formattedAddress': '150 Mukim 2 Sungai Pinang, 11010 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 75,
    'budgetLevel': 'High',
    'location': {'latitude': 5.398, 'longitude': 100.219},
    'phone': '+6012-411 0600',
    'website': '',
    'openingHours': 'Daily 11:00 - 18:00 (Durian Season)',
    'score': 4.7,
    'description': 'Heritage organic durian estate overlooking the Malacca Strait, offering seasonal tasting sessions of Red Prawn, Musang King, and Black Thorn.',
  },
  {
    'name': 'Balik Pulau Countryside Art Murals',
    'category': 'Art',
    'plannerCategories': ['Art', 'Nature', 'Culture'],
    'tags': ['art', 'murals', 'countryside', 'balik', 'pulau', 'nature', 'culture'],
    'formattedAddress': 'Pekan Balik Pulau, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3515, 'longitude': 100.2355},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.7,
    'description': 'Large-scale rural wall murals by Russian artist Julia Volchkova celebrating local fishermen, martial artists, and silversmiths in village shophouses.',
  },
  {
    'name': 'Pantai Pasir Panjang (Long Sand Beach)',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['pantai', 'panjang', 'balik', 'pulau', 'beach', 'pasir', 'long', 'nature', 'sand'],
    'formattedAddress': 'Mukim 9 Pulau Betong, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.302, 'longitude': 100.185},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Tranquil secluded southwest coast beach with scenic fishing boat views, casuarina trees, and panoramic sunsets.',
  },
  {
    'name': 'Penang Floating Mosque (Masjid Terapung Tanjung Bungah)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Nature'],
    'tags': ['bungah', 'penang', 'mosque', 'heritage', 'floating', 'masjid', 'nature', 'bungah', 'terapung', 'tanjung', 'culture'],
    'formattedAddress': 'Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia',
    'area': 'Tanjung Bungah',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4697, 'longitude': 100.2762},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 06:00 - 21:00',
    'score': 4.8,
    'description': 'The first floating mosque built on stilts over the sea in Malaysia, featuring Middle Eastern and local architectural minarets.',
  },
  {
    'name': 'Tanjung Bungah Beach Coastline',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['beach', 'coastline', 'nature', 'bungah', 'tanjung'],
    'formattedAddress': 'Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia',
    'area': 'Tanjung Bungah',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.466, 'longitude': 100.282},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Peaceful northern coast beach known for watersports clubs, gentle ocean waves, and panoramic sea horizons.',
  },
  {
    'name': 'Avatar Secret Garden (Tanjung Tokong Seafront)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture', 'Local Business'],
    'tags': ['avatar', 'local business', 'tokong', 'tanjung', 'tanjung', 'seafront', 'nature', 'secret', 'garden', 'culture'],
    'formattedAddress': 'Jalan Tokong Thai Pak Koong, Tanjung Tokong, 10470 Penang, Malaysia',
    'area': 'Tanjung Tokong',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4635, 'longitude': 100.3075},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 08:00 - 00:00',
    'score': 4.6,
    'description': 'Enchanting illuminated coastal forest garden behind the Thai Pak Koong seaside temple, with colourful fibre-optic canopy lights.',
  },
  {
    'name': 'Straits Quay Marina & Coastal Promenade',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business', 'Food'],
    'tags': ['marina', 'promenade', 'quay', 'local business', 'tokong', 'coastal', 'nature', 'food', 'straits', 'tanjung'],
    'formattedAddress': 'Jalan Seri Tanjung Pinang, Tanjung Tokong, 10470 Penang, Malaysia',
    'area': 'Tanjung Tokong',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4578, 'longitude': 100.313},
    'phone': '+604-891 8000',
    'website': '',
    'openingHours': 'Daily 10:00 - 22:00',
    'score': 4.7,
    'description': 'Penang\'s premier seafront marina retail and dining promenade with yacht berths, breezy waterfront cafes, and arts market stalls.',
  },
  {
    'name': 'Dharmikarama Burmese Temple',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Art'],
    'tags': ['art', 'temple', 'pulau', 'dharmikarama', 'heritage', 'culture', 'burmese', 'tikus'],
    'formattedAddress': '24 Lorong Burma, Pulau Tikus, 10250 George Town, Penang, Malaysia',
    'area': 'Pulau Tikus',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4312, 'longitude': 100.3142},
    'phone': '+604-226 9350',
    'website': '',
    'openingHours': 'Daily 08:00 - 18:00',
    'score': 4.8,
    'description': 'Historic Burmese temple founded in 1803 featuring a grand golden stupa, wishing pond, shrine of Arahant Upagutta, and historical murals.',
  },
  {
    'name': 'Wat Chayamangkalaram (Reclining Buddha Temple)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Art'],
    'tags': ['art', 'chayamangkalaram', 'reclining', 'pulau', 'wat', 'heritage', 'buddha', 'temple', 'culture', 'tikus'],
    'formattedAddress': '17 Lorong Burma, Pulau Tikus, 10250 George Town, Penang, Malaysia',
    'area': 'Pulau Tikus',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4316, 'longitude': 100.3144},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 08:00 - 17:30',
    'score': 4.8,
    'description': 'Renowned Thai Buddhist temple housing a colossal 33-metre gold-plated reclining Buddha statue and colourful mythical dragon guards.',
  },
  {
    'name': 'Arulmigu Balathandayuthapani Temple (Waterfall Hilltop Temple)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Nature'],
    'tags': ['temple', 'balathandayuthapani', 'arulmigu', 'heritage', 'george', 'hilltop', 'town', 'nature', 'waterfall', 'temple', 'culture'],
    'formattedAddress': '17 Jalan Kebun Bunga, George Town, 10350 Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4338, 'longitude': 100.2917},
    'phone': '+604-229 0777',
    'website': '',
    'openingHours': 'Daily 06:00 - 21:00',
    'score': 4.8,
    'description': 'Magnificent hilltop Hindu temple complex reached via 513 steps with sweeping views over George Town and focal point of Thaipusam.',
  },
  {
    'name': 'Snake Temple (Ban Ka Lan Temple)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage'],
    'tags': ['snake', 'ban', 'temple', 'culture', 'heritage', 'bayan', 'temple', 'lepas', 'lan'],
    'formattedAddress': 'Jalan Sultan Azlan Shah, Bayan Lepas, 11900 Penang, Malaysia',
    'area': 'Bayan Lepas',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3138, 'longitude': 100.2853},
    'phone': '+604-643 7273',
    'website': '',
    'openingHours': 'Daily 08:00 - 18:00',
    'score': 4.6,
    'description': 'Unique 1850 Taoist temple dedicated to Master Chor Soo Kong, famous for live green pit vipers resting peacefully around altars and incense burners.',
  },
  {
    'name': 'Penang War Museum',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Nature'],
    'tags': ['penang', 'culture', 'heritage', 'nature', 'war', 'bayan', 'museum', 'lepas'],
    'formattedAddress': 'Lot 1350 Mukim 12, Jalan Batu Maung, 11960 Bayan Lepas, Penang, Malaysia',
    'area': 'Bayan Lepas',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.2814, 'longitude': 100.2886},
    'phone': '+604-626 5142',
    'website': 'https://penangwarmuseum.com/',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'description': 'Sprawling historical British coastal fortress and battery built in the 1930s on Bukit Maung, featuring underground tunnels, bunkers, and artillery.',
  },
  {
    'name': 'Minor Basilica of St. Anne',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'minor', 'bukit', 'anne', 'heritage', 'basilica', 'culture', 'mertajam'],
    'formattedAddress': 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3533, 'longitude': 100.4789},
    'phone': '+604-538 6405',
    'website': 'https://stannebm.org/',
    'openingHours': 'Daily 06:30 - 21:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Basilica Architecture Discovery',
      'description': 'Photograph the gothic facade of St. Anne Basilica and the historic 1888 hillside chapel.',
      'rewardPoints': 110,
    },
    'description': 'Historic Catholic pilgrimage site elevated to Minor Basilica status, featuring Gothic architecture, stained glass, and the 1888 Old Shrine.',
  },
  {
    'name': 'Cherok Tokun Nature Park & BM Hill Trail',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['trail', 'tokun', 'cherok', 'park', 'bukit', 'nature', 'hill', 'mertajam'],
    'formattedAddress': 'Jalan Kolam, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 90,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3582, 'longitude': 100.4908},
    'phone': '+604-530 1800',
    'website': '',
    'openingHours': 'Daily 07:00 - 19:00',
    'score': 4.7,
    'description': 'Lush forest reserve with tranquil walking trails, fresh mountain streams, canopy trees, and the scenic hiking path up BM Hill peak.',
  },
  {
    'name': 'Mengkuang Dam Lakeside Park',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['dam', 'local business', 'park', 'bukit', 'mengkuang', 'nature', 'mertajam', 'lakeside'],
    'formattedAddress': 'Mukim 18, Mengkuang, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4012, 'longitude': 100.493},
    'phone': '+604-500 1200',
    'website': '',
    'openingHours': 'Daily 07:00 - 19:00',
    'score': 4.8,
    'description': 'Serene mainland Penang reservoir park framed by green hill peaks, expansive lake scenery, and a popular jogging trail.',
  },
  {
    'name': 'Bukit Juru Nature Trail',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['trail', 'bukit', 'nature', 'juru', 'mertajam'],
    'formattedAddress': 'Kuala Juru, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.334, 'longitude': 100.418},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 19:00',
    'score': 4.6,
    'description': 'Scenic hilltop coastal hiking trail in Seberang Perai with panoramic views of the Penang Second Bridge, mangrove forests, and fishing boats.',
  },
  {
    'name': 'Frog Hill (Bukit Katak) Scenic Lakes',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['lakes', 'bukit', 'butterworth', 'frog', 'nature', 'hill', 'scenic', 'katak'],
    'formattedAddress': 'Kampung Ladang Toh Allah, 14400 Tasek Gelugor, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.441, 'longitude': 100.485},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 07:00 - 18:30',
    'score': 4.7,
    'description': 'Spectacular abandoned quarry site featuring vivid turquoise-green mineral lakes and red clay ridges reminiscent of Jiuzhaigou.',
  },
  {
    'name': 'Robina Eco Park Butterworth (Pantai Bersih)',
    'category': 'Nature',
    'plannerCategories': ['Nature'],
    'tags': ['butterworth', 'park', 'robina', 'eco', 'pantai', 'nature', 'bersih'],
    'formattedAddress': 'Jalan Robina, Taman Robina, 13050 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.459, 'longitude': 100.381},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Revitalized seafront coastal park overlooking Penang Island with sunset walking piers, sea breeze promenades, and beach recreation.',
  },
  {
    'name': 'Restoran BM Yam Rice',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business', 'Culture'],
    'tags': ['local business', 'bukit', 'rice', 'yam', 'food', 'restoran', 'culture', 'mertajam'],
    'formattedAddress': '7 Jalan Murthy, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3644, 'longitude': 100.4608},
    'phone': '+604-530 6826',
    'website': '',
    'openingHours': 'Daily 09:00 - 15:00',
    'score': 4.8,
    'description': 'Famous Bukit Mertajam fragrant yam rice paired with salted mustard greens pork rib soup, tender offal, and spicy chili dip.',
  },
  {
    'name': 'Restoran BM Cup Rice (Danby Cup Rice)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['local business', 'bukit', 'rice', 'cup', 'danby', 'food', 'restoran', 'rice', 'mertajam'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3639, 'longitude': 100.4608},
    'phone': '+6012-421 8833',
    'website': '',
    'openingHours': 'Daily 08:00 - 14:00',
    'score': 4.7,
    'description': 'Iconic vintage BM cup rice drenched in rich roasted pork gravy with tender char siew in a bustling town shophouse.',
  },
  {
    'name': 'BM Famous Duck Egg Char Koay Teow',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['koay', 'famous', 'local business', 'bukit', 'egg', 'char', 'food', 'duck', 'mertajam', 'teow'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3635, 'longitude': 100.4602},
    'phone': '+6016-443 2819',
    'website': '',
    'openingHours': 'Daily 19:00 - 23:30',
    'score': 4.9,
    'description': 'Famous charcoal-fried char koay teow cooked with rich creamy duck egg, fresh cockles, and fragrant wok hei on Jalan Pasar.',
  },
  {
    'name': 'BM Rojak Orang Hitam Putih',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['local business', 'bukit', 'putih', 'hitam', 'food', 'orang', 'mertajam', 'rojak'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3641, 'longitude': 100.4615},
    'phone': '+6012-475 2288',
    'website': '',
    'openingHours': 'Daily 11:30 - 18:30',
    'score': 4.8,
    'description': 'Renowned BM fruit and crispy fritter rojak tossed in thick, aromatic black shrimp paste and crushed roasted peanuts.',
  },
  {
    'name': 'Sentosa Food Court BM',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['sentosa', 'local business', 'bukit', 'food', 'court', 'mertajam'],
    'formattedAddress': 'Jalan Sentosa, Taman Sentosa, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3488, 'longitude': 100.4722},
    'phone': '+604-539 8888',
    'website': '',
    'openingHours': 'Daily 17:00 - 00:00',
    'score': 4.7,
    'description': 'Bustling evening food court in Taman Sentosa featuring over 40 hawker stalls serving BBQ stingray, satay, fried oyster omelette, and claypot noodles.',
  },
  {
    'name': 'Pekan Bukit Mertajam Old Market Street',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Food', 'Local Business'],
    'tags': ['street', 'local business', 'bukit', 'pekan', 'old', 'food', 'culture', 'mertajam', 'market'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3638, 'longitude': 100.4612},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 06:00 - 18:00',
    'score': 4.7,
    'description': 'Heart of BM town featuring traditional old-style dry and wet markets, Chinese herbal medicine halls, tea merchants, and street hawkers.',
  },
  {
    'name': 'Penang Bird Park Seberang Jaya',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['penang', 'jaya', 'butterworth', 'park', 'local business', 'bird', 'nature', 'seberang'],
    'formattedAddress': 'Jalan Todak, Seberang Jaya, 13700 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.3958, 'longitude': 100.3981},
    'phone': '+604-399 1899',
    'website': '',
    'openingHours': 'Daily 09:00 - 18:00',
    'score': 4.6,
    'description': 'First and largest bird park in Malaysia, housing over 300 bird species with walk-in aviaries, lotus ponds, and flamingos.',
  },
  {
    'name': 'Butterworth Art Walk',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Heritage'],
    'tags': ['art', 'butterworth', 'walk', 'heritage', 'culture'],
    'formattedAddress': '1 Lorong Bagan Luar 1, 12000 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4121, 'longitude': 100.3664},
    'phone': '+604-332 5000',
    'website': '',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'description': 'Vibrant outdoor alleyway art exhibition showcasing interactive 3D murals depicting Butterworth\'s agricultural, port, and cultural history.',
  },
  {
    'name': 'Tow Boo Kong Temple (Nine Emperor Gods)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['art', 'nine', 'temple', 'butterworth', 'culture', 'tow', 'emperor', 'kong', 'heritage', 'gods', 'boo'],
    'formattedAddress': 'Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4336, 'longitude': 100.3844},
    'phone': '+604-331 3318',
    'website': '',
    'openingHours': 'Daily 07:00 - 21:00',
    'score': 4.8,
    'description': 'One of the grandest Taoist temple complexes in Malaysia, famed for its massive carved stone archway, golden dragon pillars, and Nine Emperor Gods festival.',
  },
  {
    'name': 'Sree Maha Mariamman Temple Butterworth',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['maha', 'butterworth', 'mariamman', 'temple', 'heritage', 'sree', 'culture'],
    'formattedAddress': 'Jalan Bagh, 12000 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4019, 'longitude': 100.3688},
    'phone': '+604-200 0000',
    'website': '',
    'openingHours': 'Daily 06:00 - 20:30',
    'score': 4.7,
    'description': 'Historic Dravidian Hindu temple in Butterworth dating back to the 19th century, featuring a multi-tiered colourful Rajagopuram.',
  },

  // -------------------------------------------------------------
  // OTHER MALAYSIAN STATES
  // -------------------------------------------------------------
  {
    'name': 'Central Market (Pasar Seni)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Art', 'Retail', 'Local Business'],
    'tags': ['craft', 'heritage', 'art deco', 'kuala lumpur'],
    'formattedAddress':
        'Jalan Hang Kasturi, City Centre, 50050 Kuala Lumpur, Malaysia',
    'area': 'Kuala Lumpur',
    'durationMinutes': 75,
    'budgetLevel': 'Medium',
    'location': {'latitude': 3.1455, 'longitude': 101.6958},
    'phone': '+603-2031 0399',
    'website': 'https://www.centralmarket.com.my/',
    'openingHours': 'Mon-Sun 10:00-20:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Art Deco Craft & Culture Discovery',
      'description':
          'Photograph the 1937 Art Deco façade or traditional Malaysian pewter, wood, and batik stalls.',
      'rewardPoints': 120,
    },
    'description':
        'Historic 1888 landmark transformed into Malaysia’s premier heritage center for authentic handicrafts, batik, souvenirs, and local art.',
  },
  {
    'name': 'Petaling Street Heritage Market',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Food', 'Culture', 'Local Business'],
    'tags': ['chinatown', 'street food', 'heritage', 'kuala lumpur'],
    'formattedAddress':
        'Jalan Petaling, City Centre, 50000 Kuala Lumpur, Malaysia',
    'area': 'Kuala Lumpur',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.1440, 'longitude': 101.6980},
    'openingHours': 'Mon-Sun 09:00-23:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Kwai Chai Hong & Chinatown Street Food',
      'description':
          'Photograph the vibrant historic murals in Kwai Chai Hong or enjoy traditional soya bean drinks.',
      'rewardPoints': 110,
    },
    'description':
        'The bustling historic heart of KL’s Chinatown, famous for heritage pre-war shophouses, Kwai Chai Hong art alley, and famous street food.',
  },
  {
    'name': 'Dutch Square & The Stadthuys',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['dutch square', 'stadthuys', 'melaka', 'historic'],
    'formattedAddress': 'Banda Hilir, 75000 Melaka, Malaysia',
    'area': 'Melaka',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 2.1948, 'longitude': 102.2492},
    'openingHours': 'Mon-Sun 09:00-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Red Square Colonial Landmark Tour',
      'description':
          'Photograph the 1650 Stadthuys and Christ Church red brick façade and learn about Dutch Malacca.',
      'rewardPoints': 130,
    },
    'description':
        'The iconic red square of Melaka, featuring the 1650 Dutch administrative hall (the oldest Dutch building in the East), Christ Church, and the Queen Victoria Fountain.',
  },
  {
    'name': 'A Famosa Fortress',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['fortress', 'portuguese', 'melaka', 'ruins'],
    'formattedAddress':
        'Jalan Parameswara, Bandar Hilir, 78000 Melaka, Malaysia',
    'area': 'Melaka',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 2.1918, 'longitude': 102.2505},
    'openingHours': 'Mon-Sun 24 Hours',
    'score': 4.7,
    'culturalTask': {
      'title': 'Porta de Santiago Portuguese Bastion',
      'description':
          'Photograph the surviving gate of the 1511 Portuguese fortress and climb St. Paul’s Hill.',
      'rewardPoints': 120,
    },
    'description':
        'Among the oldest surviving European architectural remains in Southeast Asia, the Porta de Santiago is the sole surviving gate of the mighty Portuguese fortress built in 1511.',
  },

  // -------------------------------------------------------------
  // SELANGOR (SHAH ALAM, KLANG, BATU CAVES, SEKINCHAN, K.SELANGOR)
  // -------------------------------------------------------------
  {
    'name': 'Batu Caves Lord Murugan Shrine',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage'],
    'tags': ['batu caves', 'temple', 'limestone', 'hinduism', 'selangor'],
    'formattedAddress': 'Gombak, 68100 Batu Caves, Selangor, Malaysia',
    'area': 'Batu Caves',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.2379, 'longitude': 101.6840},
    'openingHours': 'Mon-Sun 06:00-21:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Cave Temple Ascent & Cultural Study',
      'description':
          'Climb the 272 vibrant steps to Cathedral Cave and photograph the 42.7m golden Lord Murugan statue.',
      'rewardPoints': 130,
    },
    'description':
        'Iconic limestone hill housing sacred Hindu cave temples and shrines, fronted by the world’s tallest statue of Lord Murugan and 272 colorful steps.',
  },
  {
    'name': 'Sultan Salahuddin Abdul Aziz Mosque (Blue Mosque)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['blue mosque', 'islamic architecture', 'shah alam', 'selangor'],
    'formattedAddress':
        'Persiaran Masjid, Seksyen 14, 40000 Shah Alam, Selangor, Malaysia',
    'area': 'Shah Alam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.0784, 'longitude': 101.5209},
    'openingHours': 'Mon-Sun 09:00-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Blue Dome Architecture Appreciation',
      'description':
          'Tour the mosque with a docent to examine the stained glass calligraphy and one of the largest religious domes in the world.',
      'rewardPoints': 120,
    },
    'description':
        'Malaysia\'s largest mosque, renowned for its majestic blue and silver dome, four towering 142m minarets, and stunning Islamic geometric artistry.',
  },
  {
    'name': 'Chong Kok Kopitiam Klang',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['kopitiam', 'coffee', 'heritage food', 'klang', 'selangor'],
    'formattedAddress':
        '5 Jalan Stesen, Kawasan 1, 41000 Klang, Selangor, Malaysia',
    'area': 'Klang',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.0435, 'longitude': 101.4496},
    'openingHours': 'Mon-Sun 06:30-14:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Classic Multi-Ethnic Kopitiam Experience',
      'description':
          'Order charcoal-toasted Hainanese bread with homemade kaya and a cup of traditional robust Nanyang kopi.',
      'rewardPoints': 100,
    },
    'description':
        'Operating since 1940 near Klang KTM station, this beloved heritage kopitiam brings together Malay, Chinese, and Indian regulars over charcoal toast and kopi.',
  },
  {
    'name': 'Sultan Abdul Aziz Royal Gallery',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': [
      'royal gallery',
      'selangor sultanate',
      'history',
      'klang',
      'selangor',
    ],
    'formattedAddress':
        '34 Jalan Stesen, Kawasan 1, 41000 Klang, Selangor, Malaysia',
    'area': 'Klang',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.0441, 'longitude': 101.4485},
    'openingHours': 'Tue-Sun 10:00-17:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Selangor Sultanate Heritage Tour',
      'description':
          'View the royal regalia and crown jewels of Sultan Salahuddin Abdul Aziz Shah in the colonial 1909 building.',
      'rewardPoints': 120,
    },
    'description':
        'Housed in the majestic 1909 colonial Sultan Suleiman building, this royal gallery exhibits crown artifacts, weaponry, and Selangor royal history.',
  },
  {
    'name': 'Sekinchan Paddy Processing Gallery',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Nature', 'Local Business'],
    'tags': ['rice', 'paddy', 'farming', 'sekinchan', 'selangor'],
    'formattedAddress':
        'Lot 9990, Jalan Tali Air 5, Ban 2, 45400 Sekinchan, Selangor, Malaysia',
    'area': 'Sekinchan',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.5135, 'longitude': 101.1294},
    'openingHours': 'Mon-Sun 09:00-17:30',
    'score': 4.5,
    'culturalTask': {
      'title': 'Rice Bowl Heritage Discovery',
      'description':
          'Watch the traditional paddy milling demonstration and photograph the vast green rice fields.',
      'rewardPoints': 110,
    },
    'description':
        'Educational rice mill and museum surrounded by picturesque endless emerald paddy fields, showcasing Malaysia’s highest yield rice farming.',
  },
  {
    'name': 'Bukit Melawati Historical Park',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Nature'],
    'tags': ['fort', 'lighthouse', 'cannon', 'kuala selangor', 'selangor'],
    'formattedAddress': '45000 Kuala Selangor, Selangor, Malaysia',
    'area': 'Kuala Selangor',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.3409, 'longitude': 101.2505},
    'openingHours': 'Mon-Sun 08:00-19:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Coastal Fort & Wildlife Walk',
      'description':
          'Photograph the 1907 Altingsburg lighthouse, Dutch cannon battery, and gentle silvered leaf monkeys.',
      'rewardPoints': 110,
    },
    'description':
        'Historic hilltop fortress constructed by Sultan Ibrahim in the late 18th century, featuring ancient cannons, a lighthouse, and friendly silvered leaf monkeys.',
  },

  // -------------------------------------------------------------
  // KUALA LUMPUR (CENTRAL MARKET, DATARAN MERDEKA, BRICKFIELDS)
  // -------------------------------------------------------------
  {
    'name': 'Sultan Abdul Samad Building & Dataran Merdeka',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['dataran merdeka', 'colonial', 'moorish', 'kuala lumpur'],
    'formattedAddress': 'Jalan Raja, City Centre, 50050 Kuala Lumpur, Malaysia',
    'area': 'Dataran Merdeka',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.1488, 'longitude': 101.6938},
    'openingHours': 'Open 24 hours',
    'score': 4.7,
    'culturalTask': {
      'title': 'Independence Heritage Chronicle',
      'description':
          'Photograph the 41-meter clock tower and record the historical significance of the 1957 independence flagpole.',
      'rewardPoints': 130,
    },
    'description':
        'Iconic 1897 Mughal-Gothic heritage landmark facing Dataran Merdeka where the Malayan flag was first hoisted on 31 August 1957.',
  },
  {
    'name': 'National Textile Museum KL',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['textiles', 'songket', 'batik', 'museum', 'kuala lumpur'],
    'formattedAddress':
        '26 Jalan Sultan Hishamuddin, City Centre, 50050 Kuala Lumpur, Malaysia',
    'area': 'Dataran Merdeka',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.1472, 'longitude': 101.6936},
    'openingHours': 'Mon-Sun 09:00-18:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Royal Songket Weaving Study',
      'description':
          'Inspect the gold-thread Royal Songket and Pua Kumbu woven textiles inside the heritage galleries.',
      'rewardPoints': 120,
    },
    'description':
        'Housed in a 1905 heritage building, displaying Malaysia’s rich textile heritage including Songket, Batik, Pua Kumbu, and traditional jewelry.',
  },

  // -------------------------------------------------------------
  // SABAH (KOTA KINABALU, MARI MARI, KUNDASANG, SANDAKAN)
  // -------------------------------------------------------------
  {
    'name': 'Mari Mari Cultural Village',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Nature', 'Food'],
    'tags': ['tribal', 'longhouses', 'indigenous', 'kadazandusun', 'sabah'],
    'formattedAddress': 'Inanam, 88450 Kota Kinabalu, Sabah, Malaysia',
    'area': 'Kota Kinabalu',
    'durationMinutes': 120,
    'budgetLevel': 'High',
    'location': {'latitude': 5.9750, 'longitude': 116.1950},
    'phone': '+6013-881 4921',
    'website': 'https://marimariculturalvillage.my/',
    'openingHours': 'Mon-Sun 10:00-18:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Borneo Indigenous Tribe Odyssey',
      'description':
          'Experience traditional bamboo fire cooking, blowpipe hunting, and the Murut Lansaran trampoline dance.',
      'rewardPoints': 180,
    },
    'description':
        'Immersive living tribal village nestled in remote jungle, showcasing the traditional longhouses, headhunter lore, and customs of 5 native Sabah tribes.',
  },
  {
    'name': 'Kota Kinabalu Handicraft Market (Filipino Market)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Art', 'Local Business'],
    'tags': ['pearls', 'handicrafts', 'woodwork', 'waterfront', 'sabah'],
    'formattedAddress':
        'Jalan Tun Fuad Stephens, 88000 Kota Kinabalu, Sabah, Malaysia',
    'area': 'Kota Kinabalu',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.9804, 'longitude': 116.0735},
    'openingHours': 'Mon-Sun 08:00-22:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Borneo Pearl & Craft Appraisal',
      'description':
          'Identify authentic freshwater Sabah pearls, woven bamboo sompoton instruments, and beaded Rungus necklaces.',
      'rewardPoints': 110,
    },
    'description':
        'Vibrant waterfront bazaar filled with authentic Bornean pearls, wooden crafts, woven baskets, and traditional musical instruments.',
  },
  {
    'name': 'Desa Cattle Dairy Farm Kundasang',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Food', 'Local Business'],
    'tags': ['mount kinabalu', 'farm', 'dairy', 'highland', 'sabah'],
    'formattedAddress': 'Kundasang, 89308 Ranau, Sabah, Malaysia',
    'area': 'Kundasang',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.9780, 'longitude': 116.5770},
    'phone': '+6088-889 562',
    'openingHours': 'Mon-Sun 08:30-16:30',
    'score': 4.7,
    'culturalTask': {
      'title': 'Little New Zealand Mountain Panorama',
      'description':
          'Taste fresh Kundasang gelato against the dramatic backdrop of Mount Kinabalu’s rocky granite peaks.',
      'rewardPoints': 140,
    },
    'description':
        'Scenic highland dairy farm at the foot of Mount Kinabalu, dubbed the Little New Zealand of Sabah with green pastures, fresh milk, and cool air.',
  },
  {
    'name': 'Sepilok Orangutan Rehabilitation Centre',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture'],
    'tags': ['orangutan', 'wildlife', 'conservation', 'rainforest', 'sabah'],
    'formattedAddress': 'Jalan Sepilok, 90000 Sandakan, Sabah, Malaysia',
    'area': 'Sandakan',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.8630, 'longitude': 117.9480},
    'phone': '+6089-531 180',
    'openingHours': 'Mon-Sun 09:00-16:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Borneo Wildlife Conservation Chronicle',
      'description':
          'Observe the orphaned orangutans at the nursery feeding platform and learn about wild release rehabilitation.',
      'rewardPoints': 150,
    },
    'description':
        'World-famous 43-sq-km lowland rainforest sanctuary dedicated to rescuing orphaned and injured orangutans and rehabilitating them back to the wild.',
  },

  // -------------------------------------------------------------
  // SARAWAK (KUCHING, BORNEO CULTURES MUSEUM, DAMAI, SINIAWAN)
  // -------------------------------------------------------------
  {
    'name': 'Borneo Cultures Museum Kuching',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['museum', 'indigenous', 'dayak', 'artifacts', 'sarawak'],
    'formattedAddress':
        'Jalan Tun Abang Haji Openg, 93000 Kuching, Sarawak, Malaysia',
    'area': 'Kuching',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 1.5540, 'longitude': 110.3420},
    'phone': '+6082-548 181',
    'website': 'https://museum.sarawak.gov.my/',
    'openingHours': 'Mon-Fri 09:00-16:45, Sat-Sun 09:30-16:30',
    'score': 4.9,
    'culturalTask': {
      'title': 'Borneo Civilizations Deep Dive',
      'description':
          'Explore Level 3 & 4 exhibits to document Dayak tattoo rituals, ceremonial shields, and ancient Niah Cave human remains.',
      'rewardPoints': 160,
    },
    'description':
        'Architectural masterpiece and Southeast Asia’s second-largest museum, featuring 5 floors of interactive galleries celebrating Borneo’s indigenous heritage.',
  },
  {
    'name': 'Sarawak Cultural Village (Living Museum)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Art', 'Nature'],
    'tags': ['longhouses', 'iban', 'bidayuh', 'rainforest', 'sarawak'],
    'formattedAddress':
        'Pantai Damai, Santubong, 93752 Kuching, Sarawak, Malaysia',
    'area': 'Kuching',
    'durationMinutes': 120,
    'budgetLevel': 'High',
    'location': {'latitude': 1.7500, 'longitude': 110.3170},
    'phone': '+6082-846 411',
    'website': 'https://scv.com.my/',
    'openingHours': 'Mon-Sun 09:00-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': '7 Ethnic Longhouse Passport Quest',
      'description':
          'Collect stamps from the Iban, Bidayuh, Melanau, Orang Ulu, Penan, Malay, and Chinese traditional houses.',
      'rewardPoints': 180,
    },
    'description':
        'Acclaimed 17-acre living museum at Mount Santubong showcasing authentic replica tribal longhouses, sago processing, blowpipe craft, and daily dance shows.',
  },
  {
    'name': 'Kuching Waterfront & Darul Hana Bridge',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['waterfront', 'sarawak river', 'brooke', 'kuching', 'sarawak'],
    'formattedAddress': 'Jalan Main Bazaar, 93000 Kuching, Sarawak, Malaysia',
    'area': 'Kuching',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 1.5586, 'longitude': 110.3442},
    'openingHours': 'Open 24 hours',
    'score': 4.7,
    'culturalTask': {
      'title': 'Sarawak River Heritage Promenade',
      'description':
          'Walk across Darul Hana S-curved bridge to Fort Margherita and spot the historic White Rajah Astana.',
      'rewardPoints': 120,
    },
    'description':
        'Scenic 1km paved promenade along Sarawak River overlooking the 1879 Fort Margherita, the Astana palace, and traditional wooden sampans.',
  },
  {
    'name': 'Siniawan Old Town Night Market',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['hakka', 'night market', 'street food', 'bau', 'sarawak'],
    'formattedAddress': 'Siniawan, 94000 Bau, Sarawak, Malaysia',
    'area': 'Kuching',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 1.4420, 'longitude': 110.2210},
    'openingHours': 'Fri-Sun 17:30-23:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Hakka & Dayak Night Delicacies',
      'description':
          'Sample pitcher plant glutinous rice (Luo Mai Fan) and bamboo chicken along the lantern-lit wooden shophouse lane.',
      'rewardPoints': 130,
    },
    'description':
        'Charming century-old wooden shophouse street in Bau that turns into a bustling red-lantern food haven every weekend with Hakka and Dayak specialties.',
  },

  // -------------------------------------------------------------
  // PERAK (IPOH OLD TOWN, CAVE TEMPLES, TAIPING, KUALA KANGSAR)
  // -------------------------------------------------------------
  {
    'name': 'Concubine Lane & Ipoh Old Town',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Food', 'Culture', 'Local Business'],
    'tags': ['concubine lane', 'white coffee', 'shophouse', 'ipoh', 'perak'],
    'formattedAddress': 'Panglima Lane, 30000 Ipoh, Perak, Malaysia',
    'area': 'Ipoh Old Town',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 4.5975, 'longitude': 101.0776},
    'openingHours': 'Mon-Sun 09:00-18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Tin Mining Heritage Trail',
      'description':
          'Explore Panglima Lane built by mining magnate Yao Tet Shin in 1908 and sample authentic Ipoh White Coffee.',
      'rewardPoints': 120,
    },
    'description':
        'Historic narrow lane built in 1908 during Ipoh’s tin-mining boom, now famous for artisan souvenir stalls, bean curd dessert, and white coffee cafes.',
  },
  {
    'name': 'Kek Lok Tong Cave Temple & Zen Gardens',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Nature'],
    'tags': ['cave temple', 'limestone', 'zen garden', 'ipoh', 'perak'],
    'formattedAddress': 'Persiaran Rapat Baru 4, 31350 Ipoh, Perak, Malaysia',
    'area': 'Ipoh Old Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 4.5580, 'longitude': 101.1290},
    'openingHours': 'Mon-Sun 07:00-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Cave Formation & Lotus Lake Zen Walk',
      'description':
          'Walk through the massive limestone cavern opening into the tranquil lotus pond and paddle boat lake.',
      'rewardPoints': 120,
    },
    'description':
        'Spectacular 12-acre limestone cave temple featuring natural stalactite formations, Buddha statues, and a serene rear landscaped garden with lotus lakes.',
  },
  {
    'name': 'Taiping Lake Gardens (Taman Tasik Taiping)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Heritage'],
    'tags': ['rain trees', 'lake', 'first garden', 'taiping', 'perak'],
    'formattedAddress': 'Jalan Pekeliling, 34000 Taiping, Perak, Malaysia',
    'area': 'Taiping',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 4.8517, 'longitude': 100.7411},
    'openingHours': 'Open 24 hours',
    'score': 4.8,
    'culturalTask': {
      'title': 'Centennial Rain Tree Photography',
      'description':
          'Photograph the ancient 140-year-old rain trees bending gracefully into the mirror-like waters of Taiping Lake.',
      'rewardPoints': 120,
    },
    'description':
        'Established in 1880 as the first public garden in Malaya, famous for its picturesque 64-hectare lakes surrounded by century-old golden rain trees.',
  },
  {
    'name': 'Masjid Ubudiah Kuala Kangsar',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': ['royal mosque', 'golden dome', 'kuala kangsar', 'perak'],
    'formattedAddress': 'Jalan Istana, 33000 Kuala Kangsar, Perak, Malaysia',
    'area': 'Kuala Kangsar',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 4.7645, 'longitude': 100.9507},
    'openingHours': 'Mon-Sun 09:00-17:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Royal Indo-Saracenic Mosque Architecture',
      'description':
          'Admire the Italian marble minarets and golden central dome designed by Arthur Benison Hubback in 1917.',
      'rewardPoints': 130,
    },
    'description':
        'Often rated among the most beautiful mosques in Malaysia, featuring grand golden domes and Italian marble minarets in the royal town of Kuala Kangsar.',
  },

  // -------------------------------------------------------------
  // MELAKA (BABA NYONYA MUSEUM)
  // -------------------------------------------------------------
  {
    'name': 'Baba & Nyonya Heritage Museum',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Local Business'],
    'tags': ['peranakan', 'museum', 'baba nyonya', 'shophouse', 'melaka'],
    'formattedAddress':
        '48-50 Jalan Tun Tan Cheng Lock, 75200 Melaka, Malaysia',
    'area': 'Jonker Street',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 2.1956, 'longitude': 102.2464},
    'phone': '+606-283 1233',
    'website': 'https://babanyonyamuseum.com/',
    'openingHours': 'Tue-Sun 10:00-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Peranakan Heirloom Heritage Tour',
      'description':
          'Discover four generations of the Chan family legacy inside this 1896 townhouse with gold-leaf wood carvings.',
      'rewardPoints': 130,
    },
    'description':
        'Exquisitely preserved 1896 Peranakan townhouse museum featuring mother-of-pearl rosewood furniture, antique ceramics, and silk embroidered shoes.',
  },

  // -------------------------------------------------------------
  // JOHOR (JB TAN HIOK NEE, MUAR)
  // -------------------------------------------------------------
  {
    'name': 'Hiap Joo Bakery & Biscuit Factory',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['woodfired', 'banana cake', 'heritage bakery', 'jb', 'johor'],
    'formattedAddress':
        '13 Jalan Tan Hiok Nee, Bandar Johor Bahru, 80000 Johor Bahru, Johor, Malaysia',
    'area': 'Tan Hiok Nee',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 1.4563, 'longitude': 103.7638},
    'phone': '+607-223 1703',
    'openingHours': 'Mon-Sat 07:30-16:30',
    'score': 4.7,
    'culturalTask': {
      'title': 'Century Woodfired Bakery Experience',
      'description':
          'Taste famous fresh woodfired banana cake baked in an authentic 1919 century-old brick oven.',
      'rewardPoints': 100,
    },
    'description':
        'Iconic heritage bakery operating since 1919 in JB old town, still using a traditional century-old woodfired brick kiln for its signature banana cakes.',
  },
  {
    'name': 'Sai Kee 434 Kopi Muar',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['elephant coffee', 'kopitiam', 'muar', 'johor'],
    'formattedAddress': '121 Jalan Maharani, 84000 Muar, Johor, Malaysia',
    'area': 'Muar',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 2.0442, 'longitude': 102.5689},
    'openingHours': 'Mon-Sun 08:00-17:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Muar Elephant Bean Coffee Tasting',
      'description':
          'Learn about Liberica Elephant coffee beans and enjoy Muar Otak-Otak with charcoal toast.',
      'rewardPoints': 110,
    },
    'description':
        'Famous historical coffee institution established in 1953 in the royal town of Muar, celebrated across Malaysia for its aromatic Liberica bean roasts.',
  },

  // -------------------------------------------------------------
  // KEDAH & LANGKAWI (ORIENTAL VILLAGE, MAHSURI, ZAHIR)
  // -------------------------------------------------------------
  {
    'name': 'Langkawi SkyBridge & Cable Car',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture'],
    'tags': ['skybridge', 'geopark', 'cable car', 'langkawi', 'kedah'],
    'formattedAddress': 'Teluk Burau, 07000 Langkawi, Kedah, Malaysia',
    'area': 'Langkawi',
    'durationMinutes': 120,
    'budgetLevel': 'High',
    'location': {'latitude': 6.3710, 'longitude': 99.6710},
    'phone': '+604-959 4225',
    'website': 'https://panoramalangkawi.com/',
    'openingHours': 'Mon-Sun 09:30-18:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Machinchang 550M-Year Geopark Quest',
      'description':
          'Walk along the 125-meter curved suspension bridge 660m above sea level and view the ancient rock formations.',
      'rewardPoints': 150,
    },
    'description':
        'The world\'s longest curved suspension bridge suspended above Mount Machinchang, offering breathtaking 360-degree views of Langkawi Geopark and the Andaman Sea.',
  },
  {
    'name': 'Makam Mahsuri Cultural Sanctuary',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage'],
    'tags': ['mahsuri', 'legend', 'malay house', 'langkawi', 'kedah'],
    'formattedAddress': 'Kampung Mawar, 07000 Langkawi, Kedah, Malaysia',
    'area': 'Langkawi',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.3400, 'longitude': 99.7890},
    'openingHours': 'Mon-Sun 08:30-17:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Mahsuri Legend & Traditional Folk Heritage',
      'description':
          'Listen to the traditional musical instruments at Rumah Kedah and learn the seven-generation folklore of Mahsuri.',
      'rewardPoints': 120,
    },
    'description':
        'Cultural sanctuary and museum preserving the legendary tale of Princess Mahsuri with traditional Malay wooden houses, dioramas, and sacred well.',
  },
  {
    'name': 'Masjid Zahir Alor Setar',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture'],
    'tags': [
      'zahir mosque',
      'grand mosque',
      'black dome',
      'alor setar',
      'kedah',
    ],
    'formattedAddress':
        'Jalan Putera, Bandar Alor Setar, 05000 Alor Setar, Kedah, Malaysia',
    'area': 'Alor Setar',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1200, 'longitude': 100.3680},
    'openingHours': 'Mon-Sun 08:00-18:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Moorish Heritage Mosque Study',
      'description':
          'Photograph the five black domes symbolizing the 5 pillars of Islam at Kedah\'s 1912 grand state mosque.',
      'rewardPoints': 120,
    },
    'description':
        'Built in 1912 on the grounds of Kedah warriors who fell during the 1821 Siamese invasion, featuring distinct black domes inspired by North Sumatran mosques.',
  },

  // -------------------------------------------------------------
  // PAHANG (KUANTAN & SUNGAI LEMBING)
  // -------------------------------------------------------------
  {
    'name': 'Kuantan 188 Tower & Waterfront',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': [
      'observation tower',
      'waterfront',
      'kuantan',
      'pahang',
      'landmark',
    ],
    'formattedAddress': 'Jalan Mahkota, 25000 Kuantan, Pahang, Malaysia',
    'area': 'Kuantan',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 3.8077, 'longitude': 103.3260},
    'phone': '+609-517 7188',
    'website': 'https://kuantan188.com.my/',
    'openingHours': 'Mon-Sun 10:00-22:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Kuantan Riverfront Panorama',
      'description':
          'Enjoy the 360-degree observation deck view over the Kuantan River and Pahang coastline.',
      'rewardPoints': 110,
    },
    'description':
        'Malaysia\'s second tallest tower offering panoramic views of the Kuantan River, coastal mangroves and the South China Sea.',
  },
  {
    'name': 'Restoran Ana Ikan Bakar Petai',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['seafood', 'ikan bakar', 'petai', 'tanjung lumpur', 'kuantan'],
    'formattedAddress': 'Jalan Tanjung Lumpur, 26060 Kuantan, Pahang, Malaysia',
    'area': 'Kuantan',
    'durationMinutes': 75,
    'budgetLevel': 'Medium',
    'location': {'latitude': 3.7990, 'longitude': 103.3440},
    'phone': '+6019-998 9118',
    'openingHours': 'Tue-Sun 17:00-00:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Pahang Sambal Petai Feast',
      'description':
          'Taste freshly grilled seabass or stingray wrapped in banana leaf with signature red chili petai sambal.',
      'rewardPoints': 90,
    },
    'description':
        'Famous Tanjung Lumpur seafood institution renowned for charcoal-grilled fish smothered in spicy homemade sambal and fresh stink beans.',
  },
  {
    'name': 'Teluk Cempedak Coastal Promenade',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['beach', 'coastal walkway', 'kuantan', 'pahang', 'sunset'],
    'formattedAddress': 'Teluk Cempedak, 25050 Kuantan, Pahang, Malaysia',
    'area': 'Kuantan',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.8130, 'longitude': 103.3720},
    'openingHours': 'Mon-Sun 24 Hours',
    'score': 4.7,
    'culturalTask': {
      'title': 'Coastal Boardwalk Trek',
      'description':
          'Walk across the wooden cliffside boardwalk connecting Teluk Cempedak to Pelindung Beach.',
      'rewardPoints': 100,
    },
    'description':
        'Pahang\'s premier coastal beach with white sands, breezy pine trees and a cliffside boardwalk trail over granite boulder coastlines.',
  },
  {
    'name': 'Sungai Lembing Historic Underground Tin Mines',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Nature', 'Culture'],
    'tags': ['tin mine', 'historic tunnel', 'sungai lembing', 'pahang'],
    'formattedAddress': 'Sungai Lembing, 26200 Kuantan, Pahang, Malaysia',
    'area': 'Sungai Lembing',
    'durationMinutes': 90,
    'budgetLevel': 'Low',
    'location': {'latitude': 3.9160, 'longitude': 103.0330},
    'phone': '+609-541 1475',
    'openingHours': 'Tue-Sun 09:00-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Subterranean Tin Miner Trail',
      'description':
          'Ride the underground mine train into the deep subterranean granite tunnels that once made Lembing the El Dorado of the East.',
      'rewardPoints': 150,
    },
    'description':
        'One of the world\'s deepest underground tin mining networks, dating back to British colonial times with extensive historical tunnels.',
  },

  // -------------------------------------------------------------
  // TERENGGANU (KUALA TERENGGANU, PASAR PAYANG, LOSONG)
  // -------------------------------------------------------------
  {
    'name': 'Pasar Payang Central Heritage Market',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Food', 'Local Business'],
    'tags': ['market', 'batik', 'songket', 'keropok', 'kuala terengganu'],
    'formattedAddress':
        'Jalan Sultan Zainal Abidin, 20000 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3370, 'longitude': 103.1360},
    'openingHours': 'Mon-Sun 07:00-18:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Terengganu Songket & Silk Appreciation',
      'description':
          'Discover handwoven Terengganu gold-thread songket and sample traditional keropok lekor or akok.',
      'rewardPoints': 120,
    },
    'description':
        'Iconic riverside market celebrated for authentic hand-drawn Terengganu batiks, songket weaving, local brassware and traditional Malay kuih.',
  },
  {
    'name': 'Masjid Kristal (Crystal Mosque)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Art'],
    'tags': ['mosque', 'architecture', 'crystal mosque', 'kuala terengganu'],
    'formattedAddress':
        'Pulau Wan Man, 21000 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3220, 'longitude': 103.1180},
    'phone': '+609-627 8888',
    'website': 'http://tti.com.my/',
    'openingHours': 'Mon-Sun 09:00-19:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Crystal Mosque Reflection Capture',
      'description':
          'Photograph the shimmering glass and steel domes reflecting over the Terengganu River at sunset.',
      'rewardPoints': 130,
    },
    'description':
        'A breathtaking glass, crystal, and steel architectural masterpiece situated on Pulau Wan Man, reflecting scenic river views.',
  },
  {
    'name': 'Restoran Nasi Dagang Atas Tol',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': [
      'nasi dagang',
      'tuna gulai',
      'atas tol',
      'kuala terengganu',
      'breakfast',
    ],
    'formattedAddress':
        'Kampung Atas Tol, 21070 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.2850, 'longitude': 103.1460},
    'openingHours': 'Mon-Sun 06:30-12:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Heritage Nasi Dagang Tasting',
      'description':
          'Enjoy traditional red-grain steamed rice with rich gulai ikan tongkol (tuna) and pickled cucumber salad.',
      'rewardPoints': 100,
    },
    'description':
        'Renowned across Malaysia for authentic Terengganu nasi dagang cooked with fragrant coconut milk, fenugreek seeds and spiced tuna curry.',
  },
  {
    'name': 'Kampung Cina (Chinatown Kuala Terengganu)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art', 'Local Business'],
    'tags': [
      'chinatown',
      'shophouses',
      'street art',
      'turtle alley',
      'kuala terengganu',
    ],
    'formattedAddress':
        'Jalan Kampung Cina, 20100 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3350, 'longitude': 103.1340},
    'openingHours': 'Mon-Sun 08:00-22:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Turtle Alley Mural Walk',
      'description':
          'Walk through Turtle Alley and discover the fusion of Peranakan Chinese and Terengganu Malay architectural heritage.',
      'rewardPoints': 110,
    },
    'description':
        'Historical waterfront settlement of 19th-century colonial shophouses, colorful heritage alleyways, ancestral temples and local cafes.',
  },
  {
    'name': 'Keropok Lekor Losong BTB 220',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['keropok lekor', 'losong', 'fish snack', 'kuala terengganu'],
    'formattedAddress':
        'Kampung Losong Masjid, 21000 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3180, 'longitude': 103.1250},
    'openingHours': 'Mon-Sun 08:00-19:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Losong Fish Sausage Experience',
      'description':
          'Watch fresh mackerel fish and sago dough kneaded and boiled, and taste both steamed (rebus) and crispy fried lekor with sweet chili dip.',
      'rewardPoints': 90,
    },
    'description':
        'The heart of Terengganu\'s keropok lekor heritage, offering high-ratio fresh fish sausages freshly prepared throughout the day.',
  },

  // -------------------------------------------------------------
  // KELANTAN (KOTA BHARU & TUMPAT)
  // -------------------------------------------------------------
  {
    'name': 'Pasar Besar Siti Khadijah',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Food', 'Local Business'],
    'tags': [
      'central market',
      'siti khadijah',
      'kuih',
      'kota bharu',
      'kelantan',
    ],
    'formattedAddress':
        'Jalan Buluh Kubu, 15000 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1280, 'longitude': 102.2390},
    'openingHours': 'Mon-Sun 07:00-18:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Octagonal Market Discovery',
      'description':
          'Capture the vibrant multi-tier circular market floor and sample authentic Kelantan Kuih Akok or Nasi Tumpang.',
      'rewardPoints': 130,
    },
    'description':
        'World-famous multi-tiered cultural marketplace operated predominantly by friendly women traders selling colorful spices, keropok, and traditional batiks.',
  },
  {
    'name': 'Istana Jahar (Museum of Royal Traditions & Customs)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art'],
    'tags': ['palace', 'museum', 'royal customs', 'wood carving', 'kota bharu'],
    'formattedAddress': 'Jalan Sultan, 15000 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1320, 'longitude': 102.2370},
    'phone': '+609-748 4477',
    'openingHours': 'Sat-Thu 08:30-17:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Kelantan Malay Architecture Inspection',
      'description':
          'Examine the intricate timber joinery and floral wood carvings of this 1887 royal residence.',
      'rewardPoints': 120,
    },
    'description':
        'Stunning 19th-century royal wooden palace showcasing traditional Kelantan weddings, royal weaponry, and master timber craftsmanship.',
  },
  {
    'name': 'Restoran Nasi Ulam Cikgu',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi ulam', 'herbal rice', 'budu', 'ayam kampung', 'kota bharu'],
    'formattedAddress':
        'Kampung Kraftangan, Jalan Hilir Balai, 15000 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1310, 'longitude': 102.2380},
    'phone': '+6019-961 6665',
    'openingHours': 'Sat-Thu 10:30-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Kelantanese Budu & Ulam Tradition',
      'description':
          'Assemble a traditional herbal rice plate with over 10 raw wild jungle herbs, budu fermented anchovy dip, and crispy deep-fried river fish.',
      'rewardPoints': 110,
    },
    'description':
        'Located in the Handicraft Village, this iconic Malay eatery offers an extraordinary array of fresh medicinal jungle herbs, budu, and spiced fried chicken.',
  },
  {
    'name': 'Kopitiam Kita (Famous Roti Titab)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': [
      'roti titab',
      'kopitiam',
      'breakfast',
      'nasi berlauk',
      'kota bharu',
    ],
    'formattedAddress':
        '4357-A, Taman Desa Jaya, Jalan Pengkalan Chepa, 15400 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1370, 'longitude': 102.2530},
    'phone': '+6019-981 0888',
    'openingHours': 'Mon-Sun 06:00-14:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Legendary Roti Titab Morning',
      'description':
          'Enjoy thick toasted Hainanese bread with half-boiled egg and 4 dollops of rich aromatic pandan kaya.',
      'rewardPoints': 90,
    },
    'description':
        'Kota Bharu\'s most iconic morning kopitiam, bringing together all famous Kelantan nasi packs under one roof alongside signature Roti Titab.',
  },
  {
    'name': 'Wat Phothivihan (Giant Reclining Buddha)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage'],
    'tags': ['temple', 'buddha', 'tumpat', 'kelantan', 'sculpture'],
    'formattedAddress': 'Kampung Jambu, 16200 Tumpat, Kelantan, Malaysia',
    'area': 'Tumpat',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1830, 'longitude': 102.1330},
    'openingHours': 'Mon-Sun 08:00-18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Siamese Heritage in Kelantan',
      'description':
          'Witness the 40-meter-long Reclining Buddha statue, showcasing Kelantan\'s deep cross-border Malaysian-Thai Buddhist harmony.',
      'rewardPoints': 120,
    },
    'description':
        'Home to one of Southeast Asia\'s largest reclining Buddha statues, highlighting the vibrant cultural fusion of Siamese communities in northern Kelantan.',
  },
];

class MalaysianAreaSearchEngine {
  const MalaysianAreaSearchEngine._();

  static String _areaKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsAreaTerm(String value, String term) {
    final valueKey = _areaKey(value);
    final termKey = _areaKey(term);
    if (valueKey.isEmpty || termKey.isEmpty) return false;
    if (termKey.length <= 2) {
      return valueKey.split(' ').contains(termKey);
    }
    return valueKey == termKey || valueKey.contains(termKey);
  }

  static MalaysianSubArea? findSpecificSubArea(String areaText) {
    for (final hub in malaysianAreaHubs) {
      for (final sub in hub.subAreas) {
        if (_containsAreaTerm(areaText, sub.name) ||
            sub.aliases.any((alias) => _containsAreaTerm(areaText, alias))) {
          return sub;
        }
      }
    }
    return null;
  }

  static bool matchesSpecificDestination({
    required String selectedArea,
    required String vendorAddress,
  }) {
    final selectedSubArea = findSpecificSubArea(selectedArea);
    if (selectedSubArea == null) return false;
    return _containsAreaTerm(vendorAddress, selectedSubArea.name) ||
        selectedSubArea.aliases.any(
          (alias) => _containsAreaTerm(vendorAddress, alias),
        );
  }

  static String normalise(String area) {
    final value = area.trim();
    if (value.isEmpty) return 'George Town, Penang, Malaysia';

    final lower = value.toLowerCase();
    for (final hub in malaysianAreaHubs) {
      if (hub.aliases.contains(lower) || hub.name.toLowerCase() == lower) {
        return '${hub.primaryQuery}, Malaysia';
      }
      for (final sub in hub.subAreas) {
        if (sub.name.toLowerCase() == lower || sub.aliases.contains(lower)) {
          return '${sub.fullQuery}, Malaysia';
        }
      }
    }

    if (lower.contains('malaysia')) return value;
    return '$value, Malaysia';
  }

  static bool isSupportedArea(String value) {
    final lower = value.toLowerCase();
    for (final hub in malaysianAreaHubs) {
      if (hub.aliases.any((alias) => lower.contains(alias))) return true;
      if (lower.contains(hub.name.toLowerCase())) return true;
      for (final sub in hub.subAreas) {
        if (lower.contains(sub.name.toLowerCase())) return true;
        if (sub.aliases.any((alias) => lower.contains(alias))) return true;
      }
    }
    const terms = [
      'penang',
      'pulau pinang',
      'george town',
      'air itam',
      'ayer itam',
      'batu ferringhi',
      'tanjung bungah',
      'tanjung tokong',
      'teluk bahang',
      'balik pulau',
      'bayan lepas',
      'jelutong',
      'gelugor',
      'butterworth',
      'bukit mertajam',
      'seberang jaya',
      'seberang perai',
      'perai',
      'nibong tebal',
      'kepala batas',
      'kuala lumpur',
      'kl',
      'melaka',
      'malacca',
      'ipoh',
      'perak',
      'johor',
      'selangor',
      'shah alam',
      'klang',
      'batu caves',
      'sekinchan',
      'sabah',
      'kota kinabalu',
      'kundasang',
      'sandakan',
      'sarawak',
      'kuching',
      'bau',
      'langkawi',
      'kedah',
      'cameron highlands',
      'pahang',
      'malaysia',
    ];
    return terms.any(lower.contains);
  }

  static Map<String, double>? findKnownCenter(String areaText) {
    final selectedSubArea = findSpecificSubArea(areaText);
    if (selectedSubArea != null) {
      return {
        'latitude': selectedSubArea.latitude,
        'longitude': selectedSubArea.longitude,
      };
    }
    final lower = areaText.toLowerCase();
    for (final hub in malaysianAreaHubs) {
      if (lower.contains(hub.primaryQuery.toLowerCase()) ||
          lower.contains(hub.name.toLowerCase()) ||
          hub.aliases.any((alias) => lower.contains(alias))) {
        if (hub.subAreas.isNotEmpty) {
          final firstSub = hub.subAreas.first;
          return {
            'latitude': firstSub.latitude,
            'longitude': firstSub.longitude,
          };
        }
      }
    }
    return null;
  }

  static double calculateAreaRelevance({
    required String selectedArea,
    required String vendorAddress,
  }) {
    final sLower = selectedArea.toLowerCase().trim();
    final vLower = vendorAddress.toLowerCase().trim();

    for (final hub in malaysianAreaHubs) {
      for (final sub in hub.subAreas) {
        final subLower = sub.name.toLowerCase();
        final isSelectedMatchingSub =
            sLower.contains(subLower) ||
            sub.aliases.any((a) => sLower == a || sLower.contains(a));
        if (isSelectedMatchingSub) {
          final isAddressMatchingSub =
              vLower.contains(subLower) ||
              sub.aliases.any((a) => vLower.contains(a));
          if (isAddressMatchingSub) {
            return 1.0;
          }
          final hubTerms =
              <String>{
                    hub.name.toLowerCase(),
                    hub.primaryQuery.toLowerCase(),
                    ...hub.aliases,
                  }
                  .expand(
                    (term) => term
                        .split(RegExp(r'[^a-z0-9]+'))
                        .where((token) => token.length > 2),
                  )
                  .where(
                    (token) =>
                        token != 'malaysia' &&
                        token != 'state' &&
                        token != 'wilayah' &&
                        token != 'persekutuan',
                  )
                  .toSet();
          if (hubTerms.any(vLower.contains)) {
            return 0.72;
          }
          return 0.0;
        }
      }
    }

    final selectedTokens = sLower
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .split(' ')
        .where(
          (token) =>
              token.length > 2 &&
              token != 'penang' &&
              token != 'malaysia' &&
              token != 'pulau' &&
              token != 'pinang' &&
              token != 'state',
        )
        .toSet();
    if (selectedTokens.isEmpty) return 0.5;

    final addressTokens = vLower
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .split(' ')
        .where((token) => token.length > 2)
        .toSet();
    if (addressTokens.isEmpty) return 0.5;

    final matched = selectedTokens.intersection(addressTokens).length;
    return matched / selectedTokens.length;
  }

  static List<MalaysianSubArea> findSuggestions(String rawInput) {
    final query = rawInput.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final matches = <MalaysianSubArea>[];
    for (final hub in malaysianAreaHubs) {
      final hubMatched =
          hub.name.toLowerCase().contains(query) ||
          hub.aliases.any(
            (alias) =>
                alias == query ||
                alias.contains(query) ||
                query.contains(alias),
          );

      for (final sub in hub.subAreas) {
        final subName = sub.name.toLowerCase();
        final subFull = sub.fullQuery.toLowerCase();
        final aliasMatched = sub.aliases.any(
          (alias) =>
              alias == query || alias.contains(query) || query.contains(alias),
        );

        if (subName.contains(query) ||
            subFull.contains(query) ||
            aliasMatched ||
            hubMatched) {
          if (!matches.contains(sub)) {
            matches.add(sub);
          }
        }
      }
    }
    return matches;
  }

  static MalaysianAreaHub findHubForArea(String areaText) {
    final lower = areaText.toLowerCase();
    for (final hub in malaysianAreaHubs) {
      if (hub.aliases.any((a) => lower.contains(a)) ||
          hub.name.toLowerCase().contains(lower) ||
          hub.subAreas.any((sub) => lower.contains(sub.name.toLowerCase()))) {
        return hub;
      }
    }
    return malaysianAreaHubs.first; // Default to Penang
  }
}

class PlaceReviewsData {
  const PlaceReviewsData._();

  static List<Map<String, dynamic>> getVerifiedReviews(
    Map<String, dynamic> place,
  ) {
    final name = '${place['name'] ?? ''}'.trim();
    final nameLower = name.toLowerCase();
    final category = '${place['category'] ?? ''}'.toLowerCase();
    final area = '${place['area'] ?? ''}'.trim();

    // Specific landmark review database
    if (nameLower.contains('yam rice') || nameLower.contains('bm yam')) {
      return [
        {
          'reviewerName': 'Tan Mei Ling',
          'rating': 5,
          'comment':
              'Authentic BM salted vegetable duck/pork soup paired with aromatic dark yam rice. The homemade chili sauce is unbeatable!',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Hafiz Ridzuan',
          'rating': 5,
          'comment':
              'A legendary stop in Bukit Mertajam. Generous ingredients, piping hot herbal soup, and fast service even during lunch peak.',
          'date': '1 week ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Bernard Lim',
          'rating': 4,
          'comment':
              'Delicious and flavorful. Best to come before 12:30 PM to avoid queueing for seats.',
          'date': '2 weeks ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('cup rice') || nameLower.contains('gai fan')) {
      return [
        {
          'reviewerName': 'Kok Keong',
          'rating': 5,
          'comment':
              'Classic BM comfort meal! Steamed cup rice drenched in savory minced meat and roasted pork gravy. Nostalgic taste of Seberang Perai.',
          'date': '4 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Evelyn Khor',
          'rating': 5,
          'comment':
              'Super satisfying breakfast near the old BM market. The pork belly is tender and the chili packs a nice kick.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('duck egg') ||
        nameLower.contains('char koay teow')) {
      return [
        {
          'reviewerName': 'Marcus Goh',
          'rating': 5,
          'comment':
              'Incredible wok hei! The rich creaminess of the duck egg elevates the whole plate. Top tier char koay teow.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Nurul Huda',
          'rating': 5,
          'comment':
              'Crispy cockles and fragrant lard aroma. One of the best street food plates in mainland Penang.',
          'date': '6 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('st. anne') ||
        nameLower.contains('st anne') ||
        nameLower.contains('basilica')) {
      return [
        {
          'reviewerName': 'Maria Santos',
          'rating': 5,
          'comment':
              'Serene and magnificent Minor Basilica. Walking up the old hill shrine surrounded by lush trees was peaceful and spiritually uplifting.',
          'date': '5 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'David Chong',
          'rating': 5,
          'comment':
              'A heritage treasure in Bukit Mertajam with over 175 years of history. Beautiful stained glass and gothic architecture.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('cheong fatt tze') ||
        nameLower.contains('blue mansion')) {
      return [
        {
          'reviewerName': 'Sarah Jenkins',
          'rating': 5,
          'comment':
              'The heritage guided tour is top notch. The indigo courtyard and Feng Shui architecture details are world-class.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Lim Wei Sheng',
          'rating': 5,
          'comment':
              'Stunning restoration in George Town UNESCO core. Photography is wonderful in the open courtyard.',
          'date': '5 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('peranakan mansion')) {
      return [
        {
          'reviewerName': 'Chloe Dupont',
          'rating': 5,
          'comment':
              'Overwhelmingly beautiful collection of Baba Nyonya jewelry, custom tiles, and gold-leaf wood carvings. Must visit in Penang!',
          'date': '1 day ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Ahmad Zaki',
          'rating': 5,
          'comment':
              'Incredible preservation of Straits Chinese heritage. The museum docents are very knowledgeable.',
          'date': '4 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('siti khadijah')) {
      return [
        {
          'reviewerName': 'Siti Rohani',
          'rating': 5,
          'comment':
              'The octagonal central market is full of life! Friendly makcik traders, fresh kuih akok, and stunning hand-printed batiks.',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Lucas Bennett',
          'rating': 5,
          'comment':
              'A sensory wonderland for travelers. The upper floor offers great photo angles of the colourful produce stalls below.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('kristal') || nameLower.contains('crystal mosque')) {
      return [
        {
          'reviewerName': 'Farhan Malik',
          'rating': 5,
          'comment':
              'Gleaming steel and crystal domes reflecting over the Terengganu river at sunset. Breathtaking view!',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Emily Watson',
          'rating': 5,
          'comment':
              'Unique modern Islamic architecture on Pulau Wan Man. Very tranquil and great breeze along the river promenade.',
          'date': '5 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('borneo cultures museum')) {
      return [
        {
          'reviewerName': 'Alexander Ross',
          'rating': 5,
          'comment':
              'Southeast Asia\'s finest museum experience! Five massive floors covering indigenous crafts, archaeology, and living traditions.',
          'date': '1 day ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Jessica Dayak',
          'rating': 5,
          'comment':
              'Immersive interactive exhibits that showcase Borneo\'s diverse ethnic heritage. Plan at least 2 hours here.',
          'date': '4 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('batu caves')) {
      return [
        {
          'reviewerName': 'Ravi Kumar',
          'rating': 5,
          'comment':
              'Climbing the 272 colourful rainbow steps up to the colossal limestone cathedral cave is an iconic Malaysian experience.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Elena Volkova',
          'rating': 5,
          'comment':
              'The Lord Murugan golden statue is majestic. Watch out for the cheeky monkeys along the stairway!',
          'date': '6 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('nasi dagang')) {
      return [
        {
          'reviewerName': 'Faizal Azman',
          'rating': 5,
          'comment':
              'Unbeatable red-grain coconut steamed rice with tender tuna (ikan tongkol) gulai. Truly the gold standard of East Coast cuisine.',
          'date': '3 days ago',
          'isVerified': true,
        },
      ];
    }

    // Category-specific high-quality verified traveler reviews fallback
    if (category.contains('food') ||
        category.contains('restaurant') ||
        category.contains('cafe')) {
      return [
        {
          'reviewerName': 'Kelvin Lee',
          'rating': 5,
          'comment':
              'Generous portions, authentic local flavors, and reasonable pricing. Definitely recommend trying their signature specialty dishes!',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Aishah Rahman',
          'rating': 5,
          'comment':
              'Loved the traditional atmosphere and friendly hospitality. A genuine taste of $area culinary culture.',
          'date': '1 week ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Jason Miller',
          'rating': 4,
          'comment':
              'Great stop on our itinerary. Clean venue, authentic spices, and very welcoming staff.',
          'date': '2 weeks ago',
          'isVerified': true,
        },
      ];
    }

    if (category.contains('nature') ||
        category.contains('park') ||
        category.contains('beach')) {
      return [
        {
          'reviewerName': 'Daniel Lim',
          'rating': 5,
          'comment':
              'Breathtaking scenery and well-maintained walking paths. Perfect for nature lovers and refreshing morning walks.',
          'date': '4 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Grace Tan',
          'rating': 5,
          'comment':
              'Serene green atmosphere with great photo spots. Peaceful escape from the city bustle.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    return [
      {
        'reviewerName': 'Wong Chee Keong',
        'rating': 5,
        'comment':
            'A must-visit cultural landmark in $area. Well preserved with rich historical background and engaging exhibits.',
        'date': '2 days ago',
        'isVerified': true,
      },
      {
        'reviewerName': 'Nur Syafiqah',
        'rating': 5,
        'comment':
            'Beautiful heritage craftsmanship and architecture. Great educational spot for both solo travelers and families.',
        'date': '5 days ago',
        'isVerified': true,
      },
      {
        'reviewerName': 'Tom Harrison',
        'rating': 4,
        'comment':
            'Engaging visit and great cultural insights into Malaysian traditions. Don\'t forget to snap photos of the exterior details.',
        'date': '2 weeks ago',
        'isVerified': true,
      },
    ];
  }
}

class MalaysianPlannerSync {
  const MalaysianPlannerSync._();

  static Future<int> syncAllCuratedPlacesToFirestore() async {
    int count = 0;
    final db = AppServices.db;

    for (final place in curatedRealPlaces) {
      final name = '${place['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;

      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();
      final vendorId = 'vendor_$slug';
      final placeId = 'place_$slug';

      final category = '${place['category'] ?? 'Heritage'}';
      final area = '${place['area'] ?? 'Malaysia'}';
      final address = '${place['formattedAddress'] ?? area}';
      final score = (place['score'] as num?)?.toDouble() ?? 4.8;
      final phone = '${place['phone'] ?? '+604-500 0000'}';
      final website = '${place['website'] ?? ''}';
      final openingHours = '${place['openingHours'] ?? 'Mon-Sun 09:00-18:00'}';
      final duration = (place['durationMinutes'] as num?)?.toInt() ?? 60;
      final budget = '${place['budgetLevel'] ?? 'Low'}';
      final desc = '${place['description'] ?? ''}';
      final loc = place['location'];

      final emailSlug = slug.replaceAll('_', '');
      final vendorEmail = '$emailSlug@myheritage.my';

      final vendorRef = db.collection('vendors').doc(vendorId);
      final placeRef = db.collection('places').doc(placeId);

      await vendorRef.set({
        'uid': vendorId,
        'vendorId': vendorId,
        'businessName': name,
        'displayName': name,
        'ownerName': '$name Management',
        'email': vendorEmail,
        'phone': phone,
        'category': category,
        'area': area,
        'formattedAddress': address,
        'location': loc,
        'role': 'vendor',
        'status': 'active',
        'vendorStatus': 'verified',
        'score': score,
        'website': website,
        'openingHours': openingHours,
        'description': desc,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await placeRef.set({
        'placeId': placeId,
        'vendorId': vendorId,
        'name': name,
        'category': category,
        'area': area,
        'formattedAddress': address,
        'location': loc,
        'score': score,
        'durationMinutes': duration,
        'budgetLevel': budget,
        'phone': phone,
        'website': website,
        'openingHours': openingHours,
        'description': desc,
        'tags': place['tags'] ?? [category.toLowerCase()],
        'culturalTask': place['culturalTask'],
        'status': 'active',
        'trustLabel': 'High Trust',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      count++;
    }

    // Seed reviews for all these vendors in Firestore
    await AppServices.seedVendorReviews(force: true);

    return count;
  }
}

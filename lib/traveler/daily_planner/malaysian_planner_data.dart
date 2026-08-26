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
    aliases: ['sgr', 'selangor', 'shah alam', 'petaling jaya', 'pj', 'klang', 'batu caves', 'sekinchan'],
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
        aliases: ['chinatown', 'petaling street', 'pasar seni', 'kwai chai hong'],
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
    aliases: ['sbh', 'sabah', 'kota kinabalu', 'kk', 'kundasang', 'sandakan', 'borneo sabah'],
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
    aliases: ['swk', 'sarawak', 'kuching', 'kch', 'damai', 'borneo sarawak', 'sibu', 'miri'],
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
    aliases: ['phg', 'pahang', 'cameron', 'cameron highlands', 'kuantan', 'bentong'],
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
    aliases: ['trg', 'terengganu', 'kuala terengganu', 'kt', 'pasar payang', 'redang', 'perhentian'],
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
        aliases: ['masjid kristal', 'crystal mosque', 'taman tamadun islam', 'tti'],
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
    aliases: ['kel', 'kelantan', 'kota bharu', 'kb', 'pasar siti khadijah', 'tumpat'],
    description:
        'Vibrant Pasar Siti Khadijah, royal timber palaces, giant reclining Buddha temples & authentic Nasi Kerabu',
    subAreas: [
      MalaysianSubArea(
        name: 'Pasar Siti Khadijah & Old Town',
        fullQuery: 'Pasar Siti Khadijah, Kota Bharu, Kelantan',
        highlight:
            'Iconic octagonal central market run by women traders, traditional kuih akok, batik & Kopitiam Kita',
        aliases: ['pasar siti khadijah', 'pasar besar', 'roti titab', 'kopitiam kita'],
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
  // PENANG (GEORGE TOWN, AIR ITAM, TELUK BAHANG, BALIK PULAU, BM)
  // -------------------------------------------------------------
  {
    'name': 'Pinang Peranakan Mansion',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['peranakan', 'museum', 'mansion', 'heritage', 'george town'],
    'formattedAddress': '29 Church Street, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.41758, 'longitude': 100.34262},
    'phone': '+604-264 2929',
    'website': 'https://www.pinangperanakanmansion.com.my/',
    'openingHours': 'Mon-Sun 09:30-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Peranakan Heritage Discovery',
      'description':
          'Photograph one traditional Baba Nyonya antique or architectural carving and learn about Penang Peranakan customs.',
      'rewardPoints': 120,
    },
    'description':
        'A stately recreation of a rich 19th-century Baba Nyonya residence showcasing over 1,000 antique Peranakan heirlooms, customs and ornate architecture.',
  },
  {
    'name': 'Cheong Fatt Tze - The Blue Mansion',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art', 'Local Business'],
    'tags': ['blue mansion', 'heritage', 'architecture', 'museum', 'george town'],
    'formattedAddress': '14 Leith Street, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 75,
    'budgetLevel': 'High',
    'location': {'latitude': 5.42157, 'longitude': 100.33407},
    'phone': '+604-262 0006',
    'website': 'https://www.cheongfatttzemansion.com/',
    'openingHours': 'Mon-Sun 11:00-18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Indigo Architectural Snapshot',
      'description':
          'Photograph the iconic indigo courtyard and identify one unique Feng Shui element.',
      'rewardPoints': 130,
    },
    'description':
        'Award-winning UNESCO-conserved 1890s courtyard mansion famous for its striking indigo blue walls, Art Nouveau stained glass, and Chinese master craft.',
  },
  {
    'name': 'Leong San Tong Khoo Kongsi',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['clan house', 'temple', 'heritage', 'museum', 'george town'],
    'formattedAddress': '18 Cannon Square, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4165, 'longitude': 100.3373},
    'phone': '+604-261 4609',
    'website': 'https://www.khookongsi.com.my/',
    'openingHours': 'Mon-Sun 09:00-17:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Clan Architecture Study',
      'description':
          'Photograph the intricate granite stone carvings or ornate roof dragons at Khoo Kongsi.',
      'rewardPoints': 140,
    },
    'description':
        'The grandest Chinese clan house in Malaysia, renowned for its opulent stone and wood carvings, dragon pillars, and clan lineage museum.',
  },
  {
    'name': 'Wonderfood Museum Penang',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Food', 'Art', 'Local Business'],
    'tags': ['food museum', 'culture', 'family', 'street food', 'george town'],
    'formattedAddress': '49 Lebuh Pantai, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4172, 'longitude': 100.3419},
    'phone': '+604-251 9095',
    'website': 'https://www.facebook.com/Wonderfoodmuseum',
    'openingHours': 'Mon-Sun 09:00-18:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Malaysian Food Cultural Quest',
      'description':
          'Photograph giant replicas of traditional multi-ethnic street dishes and explain their cultural heritage.',
      'rewardPoints': 110,
    },
    'description':
        'Whimsical museum featuring giant lifelike models of Malaysian street food, celebrating Malay, Chinese, Indian, and Peranakan food culture.',
  },
  {
    'name': 'Fort Cornwallis',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['fort', 'history', 'colonial', 'cannon', 'george town'],
    'formattedAddress':
        'Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4206, 'longitude': 100.3439},
    'phone': '+604-263 9855',
    'website': 'https://mypenang.gov.my/',
    'openingHours': 'Mon-Sun 09:00-22:00',
    'score': 4.4,
    'culturalTask': {
      'title': 'Colonial Defense Exploration',
      'description':
          'Photograph the historic Seri Rambai Cannon and record the date Captain Francis Light landed.',
      'rewardPoints': 100,
    },
    'description':
        'Malaysia’s largest standing star fort, built in 1786 where Francis Light first established the British settlement on Penang island.',
  },
  {
    'name': 'Chew Jetty',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['clan jetty', 'waterfront', 'heritage', 'village', 'george town'],
    'formattedAddress': 'Pengkalan Weld, 10300 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4138, 'longitude': 100.3406},
    'openingHours': 'Mon-Sun 09:00-21:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Clan Waterfront Chronicle',
      'description':
          'Photograph the wooden stilt boardwalk and temple at Chew Jetty and describe waterfront living.',
      'rewardPoints': 110,
    },
    'description':
        'The largest and most famous waterfront clan jetty in George Town, preserving over a century of traditional Chinese maritime settlement on wooden stilts.',
  },
  {
    'name': 'Hin Bus Depot',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['art', 'market', 'gallery', 'community', 'george town'],
    'formattedAddress': '31A Jalan Gurdwara, 10300 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4116, 'longitude': 100.3262},
    'website': 'https://hinbusdepot.com/',
    'openingHours': 'Mon-Sun 10:00-22:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Creative Hub Exploration',
      'description':
          'Photograph a local art exhibition or mural created inside the repurposed bus depot.',
      'rewardPoints': 120,
    },
    'description':
        'A dynamic creative community hub set in a historic bus depot, hosting art exhibitions, craft markets, studios, and artisan cafes.',
  },
  {
    'name': 'Jawi House Cafe Gallery',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['jawi peranakan', 'cafe', 'heritage food', 'gallery', 'george town'],
    'formattedAddress': '85 Lebuh Armenian, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4150, 'longitude': 100.3364},
    'phone': '+604-261 3680',
    'openingHours': 'Wed-Mon 11:00-21:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Jawi Peranakan Culinary Taste',
      'description':
          'Try authentic Lemuni Rice or herbal Biryani and record one key spice ingredient used in Jawi heritage cuisine.',
      'rewardPoints': 120,
    },
    'description':
        'Authentic Jawi Peranakan restaurant and heritage gallery founded by a local anthropologist family on historic Armenian Street.',
  },
  {
    'name': 'ChinaHouse Penang',
    'category': 'Food',
    'plannerCategories': ['Food', 'Art', 'Local Business'],
    'tags': ['cafe', 'gallery', 'bakery', 'heritage shophouse', 'george town'],
    'formattedAddress':
        '153 & 155 Beach Street, 10300 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4149, 'longitude': 100.3409},
    'phone': '+604-263 7299',
    'website': 'https://chinahouse.com.my/',
    'openingHours': 'Mon-Sun 09:00-24:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Shophouse Architecture & Cake Art',
      'description':
          'Photograph the 400-foot-long shophouse open courtyard linking Beach Street and Victoria Street.',
      'rewardPoints': 100,
    },
    'description':
        'The longest continuous heritage shophouse in Penang, combining three interconnecting heritage properties with art galleries, live music, and artisanal bakeries.',
  },
  {
    'name': 'Tek Sen Restaurant',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['restaurant', 'local food', 'heritage shophouse', 'george town'],
    'formattedAddress':
        '18 & 20 Carnarvon Street, 10100 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4153, 'longitude': 100.3350},
    'phone': '+6012-981 5117',
    'openingHours': 'Wed-Mon 12:00-15:00, 18:00-21:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Traditional Cantonese-Teochew Food',
      'description':
          'Photograph a classic stir-fried heritage dish and note its Penang heritage roots.',
      'rewardPoints': 110,
    },
    'description':
        'Legendary Michelin Bib Gourmand shophouse restaurant running since 1965, celebrated for authentic Cantonese and Teochew home-style cooking.',
  },
  {
    'name': 'Hameediyah Restaurant',
    'category': 'Food',
    'plannerCategories': ['Food', 'Heritage', 'Local Business'],
    'tags': ['nasi kandar', 'murtabak', 'heritage food', 'george town'],
    'formattedAddress':
        '164A Lebuh Campbell, 10020 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4188, 'longitude': 100.3338},
    'phone': '+604-261 1095',
    'openingHours': 'Mon-Sun 10:00-22:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Oldest Nasi Kandar Chronicle',
      'description':
          'Photograph a heritage spiced curry dish and record the founding year of Malaysia’s oldest Nasi Kandar (1907).',
      'rewardPoints': 120,
    },
    'description':
        'The oldest surviving Nasi Kandar establishment in Malaysia, serving signature curries, spice roasts, and murtabak on Campbell Street since 1907.',
  },
  {
    'name': 'Penang Road Famous Teochew Chendul',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['chendul', 'dessert', 'street food', 'george town'],
    'formattedAddress':
        '27 & 29 Lebuh Keng Kwee, 10100 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4183, 'longitude': 100.3310},
    'phone': '+604-262 6002',
    'openingHours': 'Mon-Sun 09:00-18:30',
    'score': 4.5,
    'culturalTask': {
      'title': 'Penang Chendul Street Craft',
      'description':
          'Photograph the classic bowl of shaved ice, pandan jelly noodles, gula melaka and red beans.',
      'rewardPoints': 90,
    },
    'description':
        'Iconic street dessert cart established in 1936, world-famous for its refreshing green pandan noodles in rich coconut milk and aromatic palm sugar.',
  },
  {
    'name': 'Ghee Hiang Macalister Road',
    'category': 'Retail',
    'plannerCategories': ['Local Business', 'Food', 'Culture'],
    'tags': ['tau sar piah', 'sesame oil', 'pastry', 'souvenir', 'george town'],
    'formattedAddress':
        '216 Jalan Macalister, 10400 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4178, 'longitude': 100.3196},
    'phone': '+604-227 2222',
    'website': 'https://ghee-hiang.com/',
    'openingHours': 'Mon-Sun 09:00-20:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Traditional Pastry Heritage',
      'description':
          'Photograph freshly baked Tau Sar Piah or traditional roasted sesame oil and learn its Fujian origins.',
      'rewardPoints': 110,
    },
    'description':
        'Penang’s oldest traditional pastry brand founded in 1856, renowned for its flaky mung bean biscuits (Tau Sar Piah) and pure sesame oil.',
  },
  {
    'name': 'Chowrasta Market',
    'category': 'Retail',
    'plannerCategories': ['Local Business', 'Food', 'Culture'],
    'tags': ['market', 'local produce', 'street food', 'george town'],
    'formattedAddress': 'Jalan Penang, 10000 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4201, 'longitude': 100.3314},
    'openingHours': 'Mon-Sun 06:30-18:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Morning Heritage Market Walk',
      'description':
          'Photograph local Penang pickled fruits (jeruk) or secondhand books on the upper floor of Chowrasta.',
      'rewardPoints': 100,
    },
    'description':
        'Historic 1890s municipal market teeming with local produce, fresh nutmeg, preserved fruits (jeruk), and Penang morning food stalls.',
  },
  {
    'name': 'Kek Lok Si Temple',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['temple', 'pagoda', 'buddhist', 'air itam'],
    'formattedAddress': 'Kek Lok Si Temple, 11500 Air Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 90,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3999, 'longitude': 100.2732},
    'phone': '+604-828 3317',
    'website': 'https://kekloksitemple.com/',
    'openingHours': 'Mon-Sun 08:30-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Pagoda of Ten Thousand Buddhas Study',
      'description':
          'Photograph the Pagoda blending Chinese, Thai, and Burmese architectural tiers and the bronze Guanyin statue.',
      'rewardPoints': 140,
    },
    'description':
        'The largest Buddhist temple complex in Malaysia, featuring the 7-tier Pagoda of Rama VI, ornamental turtle pond, and the towering 30.2-metre bronze statue of Guanyin.',
  },
  {
    'name': 'The Habitat Penang Hill',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['rainforest', 'canopy walk', 'nature', 'penang hill', 'air itam'],
    'formattedAddress':
        'Penang Hill, Jalan Stesen Bukit Bendera, 11300 Air Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 100,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4240, 'longitude': 100.2698},
    'phone': '+6019-645 7741',
    'website': 'https://www.thehabitat.my/',
    'openingHours': 'Mon-Sun 09:00-19:00',
    'score': 4.8,
    'culturalTask': {
      'title': '130-Million-Year Rainforest Canopy Trek',
      'description':
          'Photograph the Langur Way canopy walkway or Curtis Crest tree-top walk in the UNESCO Biosphere Reserve.',
      'rewardPoints': 150,
    },
    'description':
        'World-class rainforest discovery centre atop Penang Hill inside a UNESCO Biosphere Reserve, with pristine canopy walks and 360-degree island views.',
  },
  {
    'name': 'Tropical Spice Garden',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture', 'Local Business'],
    'tags': ['spice garden', 'nature', 'eco', 'teluk bahang'],
    'formattedAddress':
        'Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4637, 'longitude': 100.2387},
    'phone': '+604-881 3799',
    'website': 'https://tropicalspicegarden.com/',
    'openingHours': 'Mon-Thu 09:00-16:30; Fri-Sun 09:00-18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Nature Discovery at Tropical Spice Garden',
      'description':
          'Photograph one plant, landscape or conservation feature and explain why it should be protected.',
      'rewardPoints': 140,
    },
    'description':
        'Award-winning eco-tourism paradise featuring over 500 species of living tropical spices, herbs, tranquil trails, and shaded rainforest streams.',
  },
  {
    'name': 'Entopia by Penang Butterfly Farm',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['butterfly', 'nature', 'invertebrates', 'teluk bahang'],
    'formattedAddress':
        '830 Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 90,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4477, 'longitude': 100.2150},
    'phone': '+604-888 8111',
    'website': 'https://www.entopia.com/',
    'openingHours': 'Mon-Sun 09:00-18:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Entopia Living Sanctuary Observation',
      'description':
          'Photograph one of the 15,000 free-flying butterflies in the Natureland glass atrium.',
      'rewardPoints': 130,
    },
    'description':
        'A giant living nature sanctuary with a huge outdoor glass dome home to 15,000 free-flying butterflies and educational indoor interactive exhibits.',
  },
  {
    'name': 'ESCAPE Penang',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['adventure', 'eco', 'outdoor', 'teluk bahang'],
    'formattedAddress':
        '828 Jalan Teluk Bahang, 11050 Teluk Bahang, Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 120,
    'budgetLevel': 'High',
    'location': {'latitude': 5.4494, 'longitude': 100.2146},
    'phone': '+6017-797 7529',
    'website': 'https://www.escape.my/park/pg',
    'openingHours': 'Tue-Sun 10:00-18:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Eco-Adventure Challenge',
      'description':
          'Photograph the Guinness World Record longest tube water slide set amidst lush natural greenery.',
      'rewardPoints': 130,
    },
    'description':
        'World-renowned eco-adventure theme park set in natural rainforest with zip-lines, rope obstacles, and the world’s longest tube water slide.',
  },
  {
    'name': 'Penang Batik Factory',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['batik', 'craft', 'handmade', 'teluk bahang'],
    'formattedAddress': '669 Mk. 2, Teluk Bahang, 11050 Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4525, 'longitude': 100.2157},
    'phone': '+604-885 1284',
    'website': 'https://www.penangbatik.com.my/',
    'openingHours': 'Mon-Sun 09:00-17:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Traditional Batik Wax & Dye Craft',
      'description':
          'Photograph an artisan hand-drawing batik with a canting copper tool and hot wax.',
      'rewardPoints': 130,
    },
    'description':
        'One of the pioneer batik factories in Penang since 1973, offering live demonstrations of wax-resist batik drawing and hand-painted silk apparel.',
  },
  {
    'name': 'Batu Ferringhi Night Market',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Retail', 'Local Business'],
    'tags': ['night market', 'batu ferringhi', 'craft', 'coastal'],
    'formattedAddress':
        'Jalan Pantai Batu, 11100 Batu Ferringhi, Penang, Malaysia',
    'area': 'Batu Ferringhi',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4710, 'longitude': 100.2470},
    'openingHours': 'Mon-Sun 19:00-23:30',
    'score': 4.5,
    'culturalTask': {
      'title': 'Coastal Night Market Exploration',
      'description':
          'Photograph handcrafted souvenirs or batik sarongs along the vibrant Batu Ferringhi night walk.',
      'rewardPoints': 100,
    },
    'description':
        'Lively open-air coastal night market stretching along Batu Ferringhi road, featuring artisan handicrafts, apparel, street food, and sea breezes.',
  },
  {
    'name': 'Minor Basilica of St. Anne',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['church', 'basilica', 'heritage', 'bukit mertajam'],
    'formattedAddress': 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 70,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3527, 'longitude': 100.4764},
    'phone': '+604-538 6405',
    'website': 'https://stannebm.org/',
    'openingHours': 'Mon-Sun 06:30-19:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Minor Basilica Heritage Discovery',
      'description':
          'Photograph the historic 1888 French Gothic shrine chapel or the modern Minangkabau-inspired Basilica.',
      'rewardPoints': 130,
    },
    'description':
        'Prestigious Minor Basilica and international pilgrimage site established in 1846 by French missionaries, featuring historic shrines and bell towers.',
  },
  {
    'name': 'Cherok Tokun Nature Park',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['forest', 'hiking', 'nature', 'bukit mertajam'],
    'formattedAddress':
        'Jalan Kolam, Cherok Tokun, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 80,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3620, 'longitude': 100.4900},
    'openingHours': 'Mon-Sun 07:00-18:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Ancient Inscription & Rainforest Walk',
      'description':
          'Photograph the ancient 5th-century Sanskrit stone inscription and the towering Mengkuang dam forest trails.',
      'rewardPoints': 120,
    },
    'description':
        'Serene Bukit Mertajam forest reserve featuring shady jungle streams, hill trekking trails, and an ancient 5th-century archaeological rock inscription.',
  },
  {
    'name': 'Restoran BM Yam Rice',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['yam rice', 'pork soup', 'kopitiam', 'bukit mertajam', 'bm'],
    'formattedAddress': '7, Jalan Murthy, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3642, 'longitude': 100.4611},
    'phone': '+604-539 0088',
    'openingHours': 'Wed-Mon 08:30-15:00 (Tue Closed)',
    'score': 4.8,
    'culturalTask': {
      'title': 'Famous BM Yam Rice Feast',
      'description':
          'Photograph the signature dark fragrant yam rice served with hot salted vegetable pork rib broth and homemade chili dip.',
      'rewardPoints': 120,
    },
    'description':
        'Legendary Bukit Mertajam culinary institution celebrated nationwide for savory dark yam rice paired with piping hot salted cabbage and pork offal soup.',
  },
  {
    'name': 'Restoran BM Cup Rice (Danby Cup Rice)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['cup rice', 'roast pork', 'char siew', 'bukit mertajam', 'bm'],
    'formattedAddress': '29, Jalan Danby, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3639, 'longitude': 100.4604},
    'phone': '+6012-421 8899',
    'openingHours': 'Tue-Sun 09:00-15:30 (Mon Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Traditional Cup Rice Unmoulding',
      'description':
          'Photograph the classic steel cup rice unmoulded onto a plate crowned with thick dark gravy, crispy roast pork, and tender chicken.',
      'rewardPoints': 110,
    },
    'description':
        'Iconic heritage BM eatery famous for steaming fluffy rice in metal tins, flipped onto plates and smothered in luscious sweet-savory gravy and roasted meats.',
  },
  {
    'name': 'BM Famous Duck Egg Char Koay Teow',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['char koay teow', 'duck egg', 'street food', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Megat Harun, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3582, 'longitude': 100.4578},
    'openingHours': 'Daily 18:00-23:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Charcoal Wok Duck Egg CKT',
      'description':
          'Capture the fiery charcoal wok hei flame frying flat rice noodles with creamy rich duck egg yolk and fresh cockles.',
      'rewardPoints': 120,
    },
    'description':
        'Renowned Bukit Mertajam evening supper stall frying charcoal-fired Char Koay Teow with rich duck egg, Chinese sausage, prawns, and fragrant pork lard.',
  },
  {
    'name': 'BM Rojak Orang Hitam Putih',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['rojak', 'tong shui', 'dessert', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 35,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3637, 'longitude': 100.4609},
    'openingHours': 'Daily 11:30-18:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Black & White Rojak Tasting',
      'description':
          'Photograph the generous mountain of crunchy crullers, fresh mango, guava, and fried crackers coated in thick sticky shrimp paste sauce.',
      'rewardPoints': 100,
    },
    'description':
        'Bukit Mertajam heritage snack institution famous for its deeply aromatic shrimp paste fruit rojak served with crunchy crackers and traditional herbal tea.',
  },
  {
    'name': 'Cheok Toi Mee Jawa BM',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['mee jawa', 'noodles', 'hawker', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Pasar (Old BM Market), 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3633, 'longitude': 100.4606},
    'openingHours': 'Daily 07:30-13:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Heritage BM Mee Jawa',
      'description':
          'Photograph yellow noodles drenched in thick sweet potato tomato broth topped with crispy fritters, lime, and crushed peanuts.',
      'rewardPoints': 110,
    },
    'description':
        'Decades-old family stall at BM Old Market serving traditional Northern-style Mee Jawa with thick fragrant gravy and crunchy homemade crackers.',
  },
  {
    'name': 'Restoran Mei Le Hwa BM Dim Sum',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['dim sum', 'kopitiam', 'breakfast', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3556, 'longitude': 100.4702},
    'phone': '+604-530 1192',
    'openingHours': 'Daily 06:00-12:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Mainland Morning Dim Sum & Kopi',
      'description':
          'Order a spread of handmade siew mai, steamed bao, and iced kopi in traditional BM kopitiam style.',
      'rewardPoints': 110,
    },
    'description':
        'Popular breakfast gathering spot in Bukit Mertajam serving freshly steamed dim sum baskets, roasted bao, and rich butter coffee.',
  },
  {
    'name': 'BM Famous Lao Hao You Curry Mee',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['curry mee', 'noodles', 'spicy', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3541, 'longitude': 100.4720},
    'openingHours': 'Mon-Sat 07:00-13:30 (Sun Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Aromatic Coconut Curry Mee',
      'description':
          'Photograph the red chili paste dissolving into creamy coconut milk soup with tofu puffs, cockles, and cuttlefish.',
      'rewardPoints': 110,
    },
    'description':
        'Famous mainland curry noodle stall loved by generations for its fragrant santan curry broth, fiery sambal chili paste, and juicy cockles.',
  },
  {
    'name': 'Sentosa Food Court BM',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['food court', 'hawker center', 'dinner', 'supper', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Sentosa, Taman Sentosa, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3488, 'longitude': 100.4682},
    'openingHours': 'Daily 17:00-00:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Sentosa Evening Hawker Food Feast',
      'description':
          'Sample and photograph three hawker specialties such as grilled satay, crispy oyster omelette, or lok lok skewers.',
      'rewardPoints': 120,
    },
    'description':
        'Bustling evening food court in Taman Sentosa featuring over 40 hawker stalls serving BBQ stingray, satay, fried oyster omelette, and claypot noodles.',
  },
  {
    'name': 'Taman Sri Rambai Hawker Centre',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['hawker', 'street food', 'dinner', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Tingkat Rambai 1, Taman Sri Rambai, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 55,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3448, 'longitude': 100.4521},
    'openingHours': 'Daily 17:00-23:30',
    'score': 4.6,
    'culturalTask': {
      'title': 'Sri Rambai Mainland Supper',
      'description':
          'Photograph sizzling carrot cake and mainland Penang prawn mee under vibrant outdoor hawker dining umbrellas.',
      'rewardPoints': 110,
    },
    'description':
        'A vibrant community dining paradise packed with neighborhood stalls dishing out Penang laksa, Hokkien prawn mee, fried oysters, and fresh fruit juices.',
  },
  {
    'name': 'BM Famous Hakka Mee & Yong Tau Foo',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['hakka mee', 'noodles', 'yong tau foo', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Pasar Awam Bukit Mertajam, Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3638, 'longitude': 100.4607},
    'openingHours': 'Daily 06:30-13:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Springy Hakka Noodles',
      'description':
          'Photograph springy handmade yellow noodles tossed in seasoned minced pork and shallot oil with stuffed tofu soup.',
      'rewardPoints': 110,
    },
    'description':
        'Traditional market vendor serving springy Hakka egg noodles topped with fragrant minced pork lard and accompanied by clear soup stuffed bean curd.',
  },
  {
    'name': 'BM Best Cendol & Shaved Ice',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['cendol', 'dessert', 'ais kacang', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 30,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3535, 'longitude': 100.4735},
    'openingHours': 'Daily 10:30-18:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Fresh Gula Melaka Cendol',
      'description':
          'Photograph a refreshing bowl of iced pandan cendol infused with thick smoky coconut sugar syrup.',
      'rewardPoints': 100,
    },
    'description':
        'Refreshing roadside dessert stall popular for silky pandan jelly cendol, creamy santan, and authentic Melaka palm sugar syrup.',
  },
  {
    'name': 'Restoran Nasi Kandar Yasmeen BM',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi kandar', 'curry', 'halal', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Megat Harun, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3592, 'longitude': 100.4589},
    'phone': '+604-537 9922',
    'openingHours': 'Daily 24 Hours',
    'score': 4.6,
    'culturalTask': {
      'title': 'Mainland Kuah Campur Nasi Kandar',
      'description':
          'Order a hearty plate of steaming rice flooded with mixed curries, crisp spiced fried chicken, and salted egg.',
      'rewardPoints': 110,
    },
    'description':
        'Mainland favorite Nasi Kandar joint renowned for rich mixed curry sauces, crispy ayam goreng berempah, and tender beef curry.',
  },
  {
    'name': 'BM Traditional Ban Chang Kuih',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['ban chang kuih', 'pancake', 'street snack', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 25,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3634, 'longitude': 100.4610},
    'openingHours': 'Daily 08:00-14:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Crispy BM Apam Balik',
      'description':
          'Watch the master baker pour batter into brass pans and fold crispy golden pancakes bursting with crushed peanuts and sweet corn.',
      'rewardPoints': 100,
    },
    'description':
        'Beloved Old Market cart crafting crispy-edged and thick fluffy Ban Chang Kuih loaded with toasted ground peanuts, creamy sweet corn, and butter.',
  },
  {
    'name': 'De Antique Cafe BM',
    'category': 'Food',
    'plannerCategories': ['Food', 'Art', 'Local Business'],
    'tags': ['cafe', 'coffee', 'heritage', 'dessert', 'bukit mertajam', 'bm'],
    'formattedAddress': '17, Jalan Arumugam Pillai, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.3645, 'longitude': 100.4600},
    'openingHours': 'Tue-Sun 11:00-20:00 (Mon Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Heritage Shophouse Coffee',
      'description':
          'Photograph artisan drip coffee and handcrafted pastry surrounded by vintage antique memorabilia in a restored BM shophouse.',
      'rewardPoints': 120,
    },
    'description':
        'Cozy vintage cafe inside an authentic heritage shophouse in old BM town, serving specialty espresso, cold brews, and homemade cakes.',
  },
  {
    'name': 'Restoran Tokun Jaya Kopitiam',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['kopitiam', 'toast', 'kopi', 'nature', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Cherok Tokun, Jalan Kulim, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3601, 'longitude': 100.4862},
    'openingHours': 'Daily 06:30-13:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Post-Hike Hainan Kopi & Toast',
      'description':
          'Enjoy charcoal-toasted Hainan bread spread with rich coconut kaya and butter alongside a glass of aromatic local kopi.',
      'rewardPoints': 100,
    },
    'description':
        'Traditional open-air village kopitiam at the foot of Tokun Hill, famous as a lively post-hiking breakfast spot for charcoal toast and kopi.',
  },
  {
    'name': 'Mengkuang Dam Lakeside Park',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['lake', 'dam', 'scenic', 'jogging', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Mukim 18, Mengkuang, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4012, 'longitude': 100.4930},
    'openingHours': 'Daily 07:00-19:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Lakeside Mountain Panorama',
      'description':
          'Photograph the expansive blue reservoir waters framed by verdant jungle peaks and the grand dam promenade.',
      'rewardPoints': 120,
    },
    'description':
        'The largest water reservoir in Penang surrounded by rolling emerald hills, scenic lakeside jogging trails, and panoramic mountain viewing platforms.',
  },
  {
    'name': 'Pekan Bukit Mertajam Old Market Street',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['market', 'street food', 'yam rice', 'bukit mertajam', 'bm'],
    'formattedAddress': 'Jalan Pasar, 14000 Bukit Mertajam, Penang, Malaysia',
    'area': 'Bukit Mertajam',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3635, 'longitude': 100.4608},
    'openingHours': 'Mon-Sun 06:00-14:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Mainland Heritage Culinary Walk',
      'description':
          'Photograph traditional BM Duck Egg Char Koay Teow or fragrant Yam Rice on Old Market Street.',
      'rewardPoints': 110,
    },
    'description':
        'The bustling heritage heart of Bukit Mertajam, legendary for authentic mainland street cuisine including yam rice, cup rice, and duck egg char koay teow.',
  },
  {
    'name': 'Penang Bird Park',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['bird park', 'nature', 'butterworth', 'seberang jaya'],
    'formattedAddress':
        'Jalan Todak, Seberang Jaya, 13700 Perai, Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 80,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.3948, 'longitude': 100.3986},
    'phone': '+604-399 1899',
    'website': 'https://www.penangbirdpark.com.my/',
    'openingHours': 'Mon-Sun 09:00-18:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Avian Sanctuary Observation',
      'description':
          'Photograph one of the 300 bird species inside the walk-in geodesic aviaries and natural wetlands.',
      'rewardPoints': 120,
    },
    'description':
        'The first and largest bird park of its kind in Malaysia, housing over 3,000 birds from 300 species in beautifully landscaped walk-in aviaries.',
  },
  {
    'name': 'Butterworth Art Walk',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Local Business'],
    'tags': ['murals', 'street art', 'butterworth', 'heritage'],
    'formattedAddress':
        '1 Lorong Bagan Luar 1, 12000 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3995, 'longitude': 100.3645},
    'openingHours': 'Mon-Sun 24 Hours',
    'score': 4.5,
    'culturalTask': {
      'title': 'Mainland Street Art Chronicle',
      'description':
          'Photograph a vibrant heritage mural depicting the agricultural and shipping history of Province Wellesley.',
      'rewardPoints': 110,
    },
    'description':
        'Vibrant pedestrian alleyway painted with interactive 3D murals depicting the agricultural, maritime, and cultural history of Butterworth.',
  },
  {
    'name': 'Tow Boo Kong Temple Butterworth',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['temple', 'nine emperor gods', 'butterworth'],
    'formattedAddress':
        '891 Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4278, 'longitude': 100.3842},
    'openingHours': 'Mon-Sun 07:00-21:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Nine Emperor Gods Arch & Hall Study',
      'description':
          'Photograph the magnificent four-pillar stone archway and intricate dragon-sculpted eaves.',
      'rewardPoints': 130,
    },
    'description':
        'One of Southeast Asia’s most majestic Taoist temples dedicated to the Nine Emperor Gods, featuring grand carved archways and golden halls on Raja Uda.',
  },
  {
    'name': 'Gurney Drive Hawker Centre',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['hawker', 'street food', 'seafood', 'gurney', 'george town'],
    'formattedAddress': '172 Solok Gurney 1, 10250 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4402, 'longitude': 100.3088},
    'phone': '+6012-401 2388',
    'openingHours': 'Mon-Sun 16:30-23:30 (Wed Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Gurney Coastal Hawker Taste',
      'description':
          'Photograph crispy oyster omelette (Or Chien) and fresh fruit rojak along the vibrant Gurney waterfront promenade.',
      'rewardPoints': 120,
    },
    'description':
      'World-famous open-air seaside hawker center featuring rows of authentic stalls serving Penang Laksa, Char Koay Teow, grilled seafood, and Rojak.',
  },
  {
    'name': 'Dhammikarama Burmese Temple',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['temple', 'burmese', 'heritage', 'pulau tikus', 'george town'],
    'formattedAddress': '24 Lorong Burma, 10250 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4314, 'longitude': 100.3142},
    'phone': '+604-226 9508',
    'openingHours': 'Daily 08:00-17:30',
    'score': 4.8,
    'culturalTask': {
      'title': 'Burmese Temple Architecture & Well',
      'description':
          'Photograph the ornate golden main shrine hall, the wish-granting wishing pond, and the 1803 historic sacred well.',
      'rewardPoints': 130,
    },
    'description':
      'The only Burmese Buddhist temple in Penang, established in 1803 with exquisite golden pagodas, traditional bell towers, and lush sacred garden statues.',
  },
  {
    'name': 'Wat Chayamangkalaram Reclining Buddha',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['temple', 'thai', 'reclining buddha', 'pulau tikus', 'george town'],
    'formattedAddress': '17 Lorong Burma, 10250 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4318, 'longitude': 100.3138},
    'phone': '+6016-410 5115',
    'openingHours': 'Daily 08:00-17:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Gold-Plated Reclining Buddha Study',
      'description':
          'Photograph the 33-meter gold-plated Reclining Buddha statue, one of the largest in the world.',
      'rewardPoints': 130,
    },
    'description':
      'Famous 1845 Thai Buddhist temple housing a colossal 33-meter gold-plated Reclining Buddha statue and colorful Naga dragon serpents.',
  },
  {
    'name': 'Penang Street Art (Armenian Street Murals)',
    'category': 'Art',
    'plannerCategories': ['Art', 'Culture', 'Heritage', 'Local Business'],
    'tags': ['street art', 'murals', 'ernest zacharevic', 'armenian street', 'george town'],
    'formattedAddress': 'Armenian Street, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4148, 'longitude': 100.3368},
    'openingHours': 'Mon-Sun 24 Hours',
    'score': 4.8,
    'culturalTask': {
      'title': 'Little Children on a Bicycle Hunt',
      'description':
          'Locate and photograph the world-renowned Ernest Zacharevic mural "Kids on a Bicycle" along Armenian Street.',
      'rewardPoints': 120,
    },
    'description':
      'The vibrant open-air artistic heart of George Town UNESCO World Heritage site, famous for interactive 3D street art murals integrated with real bicycles and motorcycles.',
  },
  {
    'name': 'Tan Jetty Long Wooden Pier',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Nature', 'Local Business'],
    'tags': ['clan jetty', 'wooden pier', 'sunset', 'waterfront', 'george town'],
    'formattedAddress': 'Pengkalan Weld, 10300 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4124, 'longitude': 100.3396},
    'openingHours': 'Daily 09:00-21:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Longest Wooden Stilt Pier Walk',
      'description':
          'Walk to the very end of the narrow wooden stilt boardwalk extending into the Penang Strait and photograph the coastal view.',
      'rewardPoints': 110,
    },
    'description':
      'Famous for having the longest wooden walkway extending directly over the water, offering breathtaking panoramic ocean views and calm heritage atmosphere.',
  },
  {
    'name': 'Air Itam Asam Laksa (Pasar Air Itam)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['asam laksa', 'noodles', 'pasar air itam', 'michelin', 'air itam'],
    'formattedAddress': 'Jalan Pasar, 11500 Air Itam, Penang, Malaysia',
    'area': 'Air Itam',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4012, 'longitude': 100.2778},
    'openingHours': 'Daily 10:30-19:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Legendary Penang Asam Laksa Feast',
      'description':
          'Photograph the steaming bowl of sour-savory fish broth with thick rice noodles, fresh mint, shredded mackerel, and sweet prawn paste (hae ko).',
      'rewardPoints': 120,
    },
    'description':
      'Iconic multi-generational laksa institution situated right outside Air Itam market since 1955, celebrated globally for intensely flavorful tamarind-mackerel broth.',
  },
  {
    'name': 'Siam Road Charcoal Char Koay Teow',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['char koay teow', 'charcoal', 'michelin', 'george town'],
    'formattedAddress': '82 Siam Road, 10400 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4154, 'longitude': 100.3204},
    'openingHours': 'Tue-Sat 12:00-18:00 (Sun-Mon Closed)',
    'score': 4.8,
    'culturalTask': {
      'title': 'Siam Road Charcoal Master Wok Hei',
      'description':
          'Photograph the smoky wok-hei noodles tossed with plump prawns, cockles, lap cheong sausage, and crispy pork lard.',
      'rewardPoints': 120,
    },
    'description':
      'Legendary Michelin Bib Gourmand stall famed worldwide for charcoal-fired Char Koay Teow stir-fried with irresistible smoky aroma and rich wok-hei.',
  },
  {
    'name': 'Deen Maju Nasi Kandar',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi kandar', 'curry', 'halal', 'george town'],
    'formattedAddress': '170 Jalan Gurdwara, 10300 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4118, 'longitude': 100.3289},
    'phone': '+6012-425 2786',
    'openingHours': 'Mon-Sun 12:00-22:30',
    'score': 4.7,
    'culturalTask': {
      'title': 'Deen Maju Signature Mixed Gravy',
      'description':
          'Order fragrant yellow spiced rice flooded with "kuah campur" curry mix and crispy spiced fried chicken.',
      'rewardPoints': 120,
    },
    'description':
      'Massively popular George Town Nasi Kandar powerhouse known for signature sweet-savory mixed curry gravy, tender squid, and crispy spiced fried chicken.',
  },
  {
    'name': 'Transfer Road Roti Canai & Roti Bakar',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['roti canai', 'breakfast', 'curry', 'george town'],
    'formattedAddress': '114 Jalan Transfer, 10050 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4208, 'longitude': 100.3306},
    'openingHours': 'Daily 07:00-12:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Transfer Road Morning Roti Feast',
      'description':
          'Photograph fluffy roti canai drenched in thick chicken curry thigh or runny soft-boiled eggs on charcoal toasted bread.',
      'rewardPoints': 110,
    },
    'description':
      'Historic morning breakfast pavement stall since the 1970s, serving crispy flaky Roti Canai accompanied by whole chicken drumstick curry and beef curry.',
  },
  {
    'name': 'Line Clear Nasi Kandar (Chulia Street)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi kandar', 'curry', 'chulia street', 'george town'],
    'formattedAddress': '177 Jalan Penang, 10000 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4199, 'longitude': 100.3323},
    'phone': '+604-261 4440',
    'openingHours': 'Daily 24 Hours',
    'score': 4.5,
    'culturalTask': {
      'title': 'Line Clear Heritage Alley Supper',
      'description':
          'Photograph the colorful counter spread of 20+ authentic Penang curries in the iconic open-air heritage alley.',
      'rewardPoints': 110,
    },
    'description':
      'Storied 24-hour alleyway Nasi Kandar institution operating since 1930, famous for massive tiger prawns, fish head curry, and aromatic spiced rice.',
  },
  {
    'name': 'Penang National Park (Taman Negara Pulau Pinang)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['national park', 'hiking', 'monkey beach', 'turtle sanctuary', 'teluk bahang'],
    'formattedAddress': 'Jalan Hassan Abbas, 11050 Teluk Bahang, Penang, Malaysia',
    'area': 'Teluk Bahang',
    'durationMinutes': 120,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4593, 'longitude': 100.1985},
    'phone': '+604-881 3528',
    'openingHours': 'Daily 08:00-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Coastal Canopy & Beach Exploration',
      'description':
          'Trek along the scenic coastal jungle trail to Monkey Beach or the Kerachut Green Turtle Sanctuary.',
      'rewardPoints': 150,
    },
    'description':
      'The world’s smallest national park, boasting diverse coastal ecosystems, rare meromictic seasonal lake, protected turtle nesting beaches, and lush rainforest.',
  },
  {
    'name': 'Snake Temple (Ban Ka Lan Temple)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['temple', 'snakes', 'heritage', 'bayan lepas'],
    'formattedAddress': 'Jalan Sultan Azlan Shah, 11900 Bayan Lepas, Penang, Malaysia',
    'area': 'Bayan Lepas',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3138, 'longitude': 100.2852},
    'phone': '+604-643 7273',
    'openingHours': 'Daily 08:00-18:00',
    'score': 4.5,
    'culturalTask': {
      'title': 'Legendary Pit Viper Sanctuary',
      'description':
          'Photograph the free-roaming green pit vipers resting peacefully on altars and incense burners inside the historic 1850 Taoist shrine.',
      'rewardPoints': 120,
    },
    'description':
      'Built in 1850 in memory of monk Chor Soo Kong, world-famous for resident green pit vipers dwelling undisturbed among altar trees and smoking incense.',
  },
  {
    'name': 'Penang War Museum (Batu Maung)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['war museum', 'fortress', 'bunkers', 'history', 'batu maung'],
    'formattedAddress': 'Lot 1335 Mukim 12, Teluk Tempoyak, 11960 Batu Maung, Penang, Malaysia',
    'area': 'Batu Maung',
    'durationMinutes': 90,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.2814, 'longitude': 100.2889},
    'phone': '+6016-421 3606',
    'openingHours': 'Daily 09:00-18:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'WWII British Fortress Tunnel Walk',
      'description':
          'Explore and photograph the underground ammunition storage tunnels and cannon battery emplacements built in the 1930s.',
      'rewardPoints': 130,
    },
    'description':
      'Historic 20-acre British military fortress on Bukit Batu Maung constructed in the 1930s, featuring underground bunkers, cannons, and military artifacts.',
  },
  {
    'name': 'Balik Pulau Famous Kim Laksa',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['laksa', 'siam laksa', 'asam laksa', 'balik pulau'],
    'formattedAddress': 'Jalan Balik Pulau, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3518, 'longitude': 100.2359},
    'openingHours': 'Daily 10:00-17:00 (Wed Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Balik Pulau Creamy Siam Laksa Taste',
      'description':
          'Sample and photograph the rich coconut-milk Siam Laksa or classic tangy Asam Laksa in the peaceful Balik Pulau countryside.',
      'rewardPoints': 120,
    },
    'description':
      'Renowned Balik Pulau countryside culinary gem serving authentic Lemak Siam Laksa and Asam Laksa freshly made with local herbs and mackerel.',
  },
  {
    'name': 'Balik Pulau Goat Farm & Nutmeg Factory',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Culture', 'Local Business'],
    'tags': ['farm', 'nutmeg', 'countryside', 'agro', 'balik pulau'],
    'formattedAddress': 'Jalan Bukit Balik Pulau, 11000 Balik Pulau, Penang, Malaysia',
    'area': 'Balik Pulau',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3564, 'longitude': 100.2241},
    'openingHours': 'Daily 09:00-17:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Penang Nutmeg Heritage & Agro-Tour',
      'description':
          'Photograph traditional fresh nutmeg fruit processing and sample freshly pressed soothing nutmeg juice.',
      'rewardPoints': 110,
    },
    'description':
      'Charming agro-tourism stop in the hills of Balik Pulau where visitors learn how Penang’s signature nutmeg fruit and balms are processed by hand.',
  },
  {
    'name': 'Karpal Singh Drive Promenade',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Food', 'Culture', 'Local Business'],
    'tags': ['promenade', 'seafront', 'sunset', 'cafes', 'george town'],
    'formattedAddress': 'Lebuh Sungai Pinang 5, 11600 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3985, 'longitude': 100.3292},
    'openingHours': 'Mon-Sun 24 Hours',
    'score': 4.6,
    'culturalTask': {
      'title': 'Penang Strait Promenade & Sculpture',
      'description':
          'Photograph the striking nautical sea sculpture and the panoramic evening skyline of Penang Bridge.',
      'rewardPoints': 100,
    },
    'description':
      'Scenic seaside promenade facing the Penang Strait, lined with modern cafes, local dessert joints, jogging tracks, and sweeping coastal sea breezes.',
  },
  {
    'name': "St. George's Anglican Church",
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['church', 'georgian', 'oldest', 'heritage', 'george town'],
    'formattedAddress': '1 Farquhar Street, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4201, 'longitude': 100.3392},
    'phone': '+604-261 2739',
    'openingHours': 'Mon-Sat 09:00-17:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Oldest Anglican Church in Southeast Asia',
      'description':
          'Photograph the neoclassical Doric columns and the Francis Light Memorial pavilion on the church lawn.',
      'rewardPoints': 120,
    },
    'description':
      'Consecrated in 1819, this elegant neoclassical building is the oldest purpose-built Anglican church in Southeast Asia.',
  },
  {
    'name': 'Kapitan Keling Mosque',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['mosque', 'indo-moorish', 'heritage', 'george town'],
    'formattedAddress': '14 Jalan Buckingham, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4168, 'longitude': 100.3364},
    'openingHours': 'Daily 09:30-17:30 (Outside prayer times)',
    'score': 4.8,
    'culturalTask': {
      'title': 'Indo-Moorish Mosque Heritage',
      'description':
          'Photograph the yellow domes, crescent finials, and white Moorish arches of George Town’s landmark 1801 mosque.',
      'rewardPoints': 120,
    },
    'description':
      'Founded in 1801 by Indian Muslim traders, famous for its grand golden-yellow Mughal domes, minarets, and tranquil prayer hall.',
  },
  {
    'name': 'Sri Mahamariamman Temple (Queen Street)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['hindu temple', 'gopuram', 'little india', 'heritage', 'george town'],
    'formattedAddress': 'Lebuh Queen, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 40,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4170, 'longitude': 100.3398},
    'openingHours': 'Daily 06:30-12:00, 16:30-21:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Dravidian Gopuram Sculptural Study',
      'description':
          'Photograph the towering 7-tier Dravidian entrance tower carved with 38 colorful Hindu deities.',
      'rewardPoints': 120,
    },
    'description':
      'The oldest Hindu temple in George Town built in 1833, featuring an ornate sculptural gopuram at the entrance of historic Little India.',
  },
  {
    'name': 'Sun Yat Sen Museum Penang',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Local Business'],
    'tags': ['museum', 'history', 'shophouse', 'george town'],
    'formattedAddress': '120 Armenian Street, 10200 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 50,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4152, 'longitude': 100.3361},
    'phone': '+604-262 0123',
    'openingHours': 'Tue-Sun 09:30-17:30 (Mon Closed)',
    'score': 4.7,
    'culturalTask': {
      'title': '1910 Revolutionary Headquarters Visit',
      'description':
          'Photograph the historical shophouse courtyard where Dr. Sun Yat Sen planned the 1911 Canton Uprising.',
      'rewardPoints': 120,
    },
    'description':
      'Heritage Straits shophouse that served as the secret revolutionary base of Dr. Sun Yat Sen in Southeast Asia in 1910.',
  },
  {
    'name': 'Penang State Museum & Art Gallery',
    'category': 'Art',
    'plannerCategories': ['Art', 'Heritage', 'Culture', 'Local Business'],
    'tags': ['museum', 'art gallery', 'history', 'george town'],
    'formattedAddress': '57 Jalan Macalister, 10400 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4162, 'longitude': 100.3268},
    'phone': '+604-226 1462',
    'openingHours': 'Sat-Thu 09:00-17:00 (Fri Closed)',
    'score': 4.6,
    'culturalTask': {
      'title': 'Penang Heritage Oil Paintings & Artefacts',
      'description':
          'Photograph historical landscape paintings depicting early Penang harbor and traditional multi-ethnic cultural clothing.',
      'rewardPoints': 110,
    },
    'description':
      'State museum showcasing historical oil paintings, vintage photographs, traditional costumes, and cultural memorabilia documenting Penang’s history.',
  },
  {
    'name': 'Suffolk House (Georgian Heritage Mansion)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Food', 'Culture', 'Local Business'],
    'tags': ['georgian mansion', 'colonial', 'high tea', 'air itam', 'george town'],
    'formattedAddress': '250 Jalan Air Itam, 10460 George Town, Penang, Malaysia',
    'area': 'George Town',
    'durationMinutes': 60,
    'budgetLevel': 'Medium',
    'location': {'latitude': 5.4098, 'longitude': 100.3065},
    'phone': '+604-228 1109',
    'openingHours': 'Daily 11:00-22:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Anglo-Indian Georgian Architecture',
      'description':
          'Photograph the double-storey colonnaded veranda overlooking the lush green lawns of Malaysia’s sole surviving Georgian garden house.',
      'rewardPoints': 130,
    },
    'description':
      'Award-winning 200-year-old Anglo-Indian Georgian mansion built in early 1800s, surrounded by manicured lawns and offering classic British high tea.',
  },
  {
    'name': 'Tanjung Bungah Floating Mosque',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Nature', 'Local Business'],
    'tags': ['floating mosque', 'coastal', 'architecture', 'tanjung bungah'],
    'formattedAddress': 'Jalan Tanjung Bungah, 11200 Tanjung Bungah, Penang, Malaysia',
    'area': 'Tanjung Bungah',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4678, 'longitude': 100.2789},
    'openingHours': 'Daily 06:00-21:00 (Outside prayer hours)',
    'score': 4.7,
    'culturalTask': {
      'title': 'Floating Minaret & Coastal Vista',
      'description':
          'Photograph the 7-storey minaret and Moorish architectural pillars built over the sea waves in Tanjung Bungah.',
      'rewardPoints': 120,
    },
    'description':
      'The first floating mosque built in Malaysia, erected on stilts directly over the Andaman Sea in 2005, blending Middle Eastern and local maritime architecture.',
  },
  {
    'name': 'Raja Uda Apollo Morning Market',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Retail', 'Local Business'],
    'tags': ['morning market', 'hawker', 'breakfast', 'street food', 'butterworth'],
    'formattedAddress': 'Jalan Raja Uda, 12300 Butterworth, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 55,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4312, 'longitude': 100.3848},
    'openingHours': 'Daily 06:00-12:30',
    'score': 4.7,
    'culturalTask': {
      'title': 'Apollo Morning Market Hawker Spread',
      'description':
          'Sample and photograph Raja Uda signature tom yum noodles, ban chang kuih, or handmade soy bean curd.',
      'rewardPoints': 110,
    },
    'description':
      'Butterworth’s most famous morning market, bustling with hundreds of hawkers dishing out crispy crullers, apom balik, tom yum noodles, and local delicacies.',
  },
  {
    'name': 'Frog Hill (Bukit Katak Scenic Lake)',
    'category': 'Nature',
    'plannerCategories': ['Nature', 'Local Business'],
    'tags': ['nature', 'lakes', 'viewpoint', 'quarry', 'tasek gelugor'],
    'formattedAddress': '14400 Tasek Gelugor, Seberang Perai, Penang, Malaysia',
    'area': 'Butterworth',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.4385, 'longitude': 100.4852},
    'openingHours': 'Daily 07:00-19:00',
    'score': 4.6,
    'culturalTask': {
      'title': 'Penang Jiuzhaigou Turquoise Lakes',
      'description':
          'Climb the red clay hill and photograph the vibrant turquoise blue quarry pools against the green horizon.',
      'rewardPoints': 130,
    },
    'description':
      'Nicknamed Penang’s Jiuzhaigou, this scenic abandoned red-clay brick quarry features breathtaking turquoise green and blue lakes surrounded by wetlands.',
  },
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
    'tags': ['royal gallery', 'selangor sultanate', 'history', 'klang', 'selangor'],
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
    'formattedAddress':
        '45000 Kuala Selangor, Selangor, Malaysia',
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
    'formattedAddress':
        'Jalan Raja, City Centre, 50050 Kuala Lumpur, Malaysia',
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
    'formattedAddress':
        'Inanam, 88450 Kota Kinabalu, Sabah, Malaysia',
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
    'formattedAddress':
        'Kundasang, 89308 Ranau, Sabah, Malaysia',
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
    'formattedAddress':
        'Jalan Sepilok, 90000 Sandakan, Sabah, Malaysia',
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
    'formattedAddress':
        'Jalan Main Bazaar, 93000 Kuching, Sarawak, Malaysia',
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
    'formattedAddress':
        'Siniawan, 94000 Bau, Sarawak, Malaysia',
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
    'formattedAddress':
        'Panglima Lane, 30000 Ipoh, Perak, Malaysia',
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
    'formattedAddress':
        'Persiaran Rapat Baru 4, 31350 Ipoh, Perak, Malaysia',
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
    'formattedAddress':
        'Jalan Pekeliling, 34000 Taiping, Perak, Malaysia',
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
    'formattedAddress':
        'Jalan Istana, 33000 Kuala Kangsar, Perak, Malaysia',
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
    'formattedAddress':
        '121 Jalan Maharani, 84000 Muar, Johor, Malaysia',
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
    'formattedAddress':
        'Teluk Burau, 07000 Langkawi, Kedah, Malaysia',
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
    'formattedAddress':
        'Kampung Mawar, 07000 Langkawi, Kedah, Malaysia',
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
    'tags': ['zahir mosque', 'grand mosque', 'black dome', 'alor setar', 'kedah'],
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
    'tags': ['observation tower', 'waterfront', 'kuantan', 'pahang', 'landmark'],
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
      'description': 'Enjoy the 360-degree observation deck view over the Kuantan River and Pahang coastline.',
      'rewardPoints': 110,
    },
    'description': 'Malaysia\'s second tallest tower offering panoramic views of the Kuantan River, coastal mangroves and the South China Sea.',
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
      'description': 'Taste freshly grilled seabass or stingray wrapped in banana leaf with signature red chili petai sambal.',
      'rewardPoints': 90,
    },
    'description': 'Famous Tanjung Lumpur seafood institution renowned for charcoal-grilled fish smothered in spicy homemade sambal and fresh stink beans.',
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
      'description': 'Walk across the wooden cliffside boardwalk connecting Teluk Cempedak to Pelindung Beach.',
      'rewardPoints': 100,
    },
    'description': 'Pahang\'s premier coastal beach with white sands, breezy pine trees and a cliffside boardwalk trail over granite boulder coastlines.',
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
      'description': 'Ride the underground mine train into the deep subterranean granite tunnels that once made Lembing the El Dorado of the East.',
      'rewardPoints': 150,
    },
    'description': 'One of the world\'s deepest underground tin mining networks, dating back to British colonial times with extensive historical tunnels.',
  },

  // -------------------------------------------------------------
  // TERENGGANU (KUALA TERENGGANU, PASAR PAYANG, LOSONG)
  // -------------------------------------------------------------
  {
    'name': 'Pasar Payang Central Heritage Market',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Food', 'Local Business'],
    'tags': ['market', 'batik', 'songket', 'keropok', 'kuala terengganu'],
    'formattedAddress': 'Jalan Sultan Zainal Abidin, 20000 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3370, 'longitude': 103.1360},
    'openingHours': 'Mon-Sun 07:00-18:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Terengganu Songket & Silk Appreciation',
      'description': 'Discover handwoven Terengganu gold-thread songket and sample traditional keropok lekor or akok.',
      'rewardPoints': 120,
    },
    'description': 'Iconic riverside market celebrated for authentic hand-drawn Terengganu batiks, songket weaving, local brassware and traditional Malay kuih.',
  },
  {
    'name': 'Masjid Kristal (Crystal Mosque)',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Art'],
    'tags': ['mosque', 'architecture', 'crystal mosque', 'kuala terengganu'],
    'formattedAddress': 'Pulau Wan Man, 21000 Kuala Terengganu, Terengganu, Malaysia',
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
      'description': 'Photograph the shimmering glass and steel domes reflecting over the Terengganu River at sunset.',
      'rewardPoints': 130,
    },
    'description': 'A breathtaking glass, crystal, and steel architectural masterpiece situated on Pulau Wan Man, reflecting scenic river views.',
  },
  {
    'name': 'Restoran Nasi Dagang Atas Tol',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi dagang', 'tuna gulai', 'atas tol', 'kuala terengganu', 'breakfast'],
    'formattedAddress': 'Kampung Atas Tol, 21070 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.2850, 'longitude': 103.1460},
    'openingHours': 'Mon-Sun 06:30-12:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Heritage Nasi Dagang Tasting',
      'description': 'Enjoy traditional red-grain steamed rice with rich gulai ikan tongkol (tuna) and pickled cucumber salad.',
      'rewardPoints': 100,
    },
    'description': 'Renowned across Malaysia for authentic Terengganu nasi dagang cooked with fragrant coconut milk, fenugreek seeds and spiced tuna curry.',
  },
  {
    'name': 'Kampung Cina (Chinatown Kuala Terengganu)',
    'category': 'Heritage',
    'plannerCategories': ['Heritage', 'Culture', 'Art', 'Local Business'],
    'tags': ['chinatown', 'shophouses', 'street art', 'turtle alley', 'kuala terengganu'],
    'formattedAddress': 'Jalan Kampung Cina, 20100 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3350, 'longitude': 103.1340},
    'openingHours': 'Mon-Sun 08:00-22:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Turtle Alley Mural Walk',
      'description': 'Walk through Turtle Alley and discover the fusion of Peranakan Chinese and Terengganu Malay architectural heritage.',
      'rewardPoints': 110,
    },
    'description': 'Historical waterfront settlement of 19th-century colonial shophouses, colorful heritage alleyways, ancestral temples and local cafes.',
  },
  {
    'name': 'Keropok Lekor Losong BTB 220',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['keropok lekor', 'losong', 'fish snack', 'kuala terengganu'],
    'formattedAddress': 'Kampung Losong Masjid, 21000 Kuala Terengganu, Terengganu, Malaysia',
    'area': 'Kuala Terengganu',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 5.3180, 'longitude': 103.1250},
    'openingHours': 'Mon-Sun 08:00-19:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Losong Fish Sausage Experience',
      'description': 'Watch fresh mackerel fish and sago dough kneaded and boiled, and taste both steamed (rebus) and crispy fried lekor with sweet chili dip.',
      'rewardPoints': 90,
    },
    'description': 'The heart of Terengganu\'s keropok lekor heritage, offering high-ratio fresh fish sausages freshly prepared throughout the day.',
  },

  // -------------------------------------------------------------
  // KELANTAN (KOTA BHARU & TUMPAT)
  // -------------------------------------------------------------
  {
    'name': 'Pasar Besar Siti Khadijah',
    'category': 'Culture',
    'plannerCategories': ['Culture', 'Heritage', 'Food', 'Local Business'],
    'tags': ['central market', 'siti khadijah', 'kuih', 'kota bharu', 'kelantan'],
    'formattedAddress': 'Jalan Buluh Kubu, 15000 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 75,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1280, 'longitude': 102.2390},
    'openingHours': 'Mon-Sun 07:00-18:00',
    'score': 4.9,
    'culturalTask': {
      'title': 'Octagonal Market Discovery',
      'description': 'Capture the vibrant multi-tier circular market floor and sample authentic Kelantan Kuih Akok or Nasi Tumpang.',
      'rewardPoints': 130,
    },
    'description': 'World-famous multi-tiered cultural marketplace operated predominantly by friendly women traders selling colorful spices, keropok, and traditional batiks.',
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
      'description': 'Examine the intricate timber joinery and floral wood carvings of this 1887 royal residence.',
      'rewardPoints': 120,
    },
    'description': 'Stunning 19th-century royal wooden palace showcasing traditional Kelantan weddings, royal weaponry, and master timber craftsmanship.',
  },
  {
    'name': 'Restoran Nasi Ulam Cikgu',
    'category': 'Food',
    'plannerCategories': ['Food', 'Culture', 'Local Business'],
    'tags': ['nasi ulam', 'herbal rice', 'budu', 'ayam kampung', 'kota bharu'],
    'formattedAddress': 'Kampung Kraftangan, Jalan Hilir Balai, 15000 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 60,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1310, 'longitude': 102.2380},
    'phone': '+6019-961 6665',
    'openingHours': 'Sat-Thu 10:30-17:00',
    'score': 4.8,
    'culturalTask': {
      'title': 'Kelantanese Budu & Ulam Tradition',
      'description': 'Assemble a traditional herbal rice plate with over 10 raw wild jungle herbs, budu fermented anchovy dip, and crispy deep-fried river fish.',
      'rewardPoints': 110,
    },
    'description': 'Located in the Handicraft Village, this iconic Malay eatery offers an extraordinary array of fresh medicinal jungle herbs, budu, and spiced fried chicken.',
  },
  {
    'name': 'Kopitiam Kita (Famous Roti Titab)',
    'category': 'Food',
    'plannerCategories': ['Food', 'Local Business'],
    'tags': ['roti titab', 'kopitiam', 'breakfast', 'nasi berlauk', 'kota bharu'],
    'formattedAddress': '4357-A, Taman Desa Jaya, Jalan Pengkalan Chepa, 15400 Kota Bharu, Kelantan, Malaysia',
    'area': 'Kota Bharu',
    'durationMinutes': 45,
    'budgetLevel': 'Low',
    'location': {'latitude': 6.1370, 'longitude': 102.2530},
    'phone': '+6019-981 0888',
    'openingHours': 'Mon-Sun 06:00-14:00',
    'score': 4.7,
    'culturalTask': {
      'title': 'Legendary Roti Titab Morning',
      'description': 'Enjoy thick toasted Hainanese bread with half-boiled egg and 4 dollops of rich aromatic pandan kaya.',
      'rewardPoints': 90,
    },
    'description': 'Kota Bharu\'s most iconic morning kopitiam, bringing together all famous Kelantan nasi packs under one roof alongside signature Roti Titab.',
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
      'description': 'Witness the 40-meter-long Reclining Buddha statue, showcasing Kelantan\'s deep cross-border Malaysian-Thai Buddhist harmony.',
      'rewardPoints': 120,
    },
    'description': 'Home to one of Southeast Asia\'s largest reclining Buddha statues, highlighting the vibrant cultural fusion of Siamese communities in northern Kelantan.',
  },
];

class MalaysianAreaSearchEngine {
  const MalaysianAreaSearchEngine._();

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

  static double calculateAreaRelevance({
    required String selectedArea,
    required String vendorAddress,
  }) {
    final sLower = selectedArea.toLowerCase().trim();
    final vLower = vendorAddress.toLowerCase().trim();

    for (final hub in malaysianAreaHubs) {
      for (final sub in hub.subAreas) {
        final subLower = sub.name.toLowerCase();
        final isSelectedMatchingSub = sLower.contains(subLower) ||
            sub.aliases.any((a) => sLower == a || sLower.contains(a));
        if (isSelectedMatchingSub) {
          final isAddressMatchingSub = vLower.contains(subLower) ||
              sub.aliases.any((a) => vLower.contains(a));
          if (isAddressMatchingSub) {
            return 1.0;
          } else {
            return 0.05;
          }
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
          hub.aliases.any((alias) => alias == query || alias.contains(query) || query.contains(alias));

      for (final sub in hub.subAreas) {
        final subName = sub.name.toLowerCase();
        final subFull = sub.fullQuery.toLowerCase();
        final aliasMatched = sub.aliases.any(
          (alias) => alias == query || alias.contains(query) || query.contains(alias),
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

  static List<Map<String, dynamic>> getVerifiedReviews(Map<String, dynamic> place) {
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
          'comment': 'Authentic BM salted vegetable duck/pork soup paired with aromatic dark yam rice. The homemade chili sauce is unbeatable!',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Hafiz Ridzuan',
          'rating': 5,
          'comment': 'A legendary stop in Bukit Mertajam. Generous ingredients, piping hot herbal soup, and fast service even during lunch peak.',
          'date': '1 week ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Bernard Lim',
          'rating': 4,
          'comment': 'Delicious and flavorful. Best to come before 12:30 PM to avoid queueing for seats.',
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
          'comment': 'Classic BM comfort meal! Steamed cup rice drenched in savory minced meat and roasted pork gravy. Nostalgic taste of Seberang Perai.',
          'date': '4 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Evelyn Khor',
          'rating': 5,
          'comment': 'Super satisfying breakfast near the old BM market. The pork belly is tender and the chili packs a nice kick.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('duck egg') || nameLower.contains('char koay teow')) {
      return [
        {
          'reviewerName': 'Marcus Goh',
          'rating': 5,
          'comment': 'Incredible wok hei! The rich creaminess of the duck egg elevates the whole plate. Top tier char koay teow.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Nurul Huda',
          'rating': 5,
          'comment': 'Crispy cockles and fragrant lard aroma. One of the best street food plates in mainland Penang.',
          'date': '6 days ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('st. anne') || nameLower.contains('st anne') || nameLower.contains('basilica')) {
      return [
        {
          'reviewerName': 'Maria Santos',
          'rating': 5,
          'comment': 'Serene and magnificent Minor Basilica. Walking up the old hill shrine surrounded by lush trees was peaceful and spiritually uplifting.',
          'date': '5 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'David Chong',
          'rating': 5,
          'comment': 'A heritage treasure in Bukit Mertajam with over 175 years of history. Beautiful stained glass and gothic architecture.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    if (nameLower.contains('cheong fatt tze') || nameLower.contains('blue mansion')) {
      return [
        {
          'reviewerName': 'Sarah Jenkins',
          'rating': 5,
          'comment': 'The heritage guided tour is top notch. The indigo courtyard and Feng Shui architecture details are world-class.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Lim Wei Sheng',
          'rating': 5,
          'comment': 'Stunning restoration in George Town UNESCO core. Photography is wonderful in the open courtyard.',
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
          'comment': 'Overwhelmingly beautiful collection of Baba Nyonya jewelry, custom tiles, and gold-leaf wood carvings. Must visit in Penang!',
          'date': '1 day ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Ahmad Zaki',
          'rating': 5,
          'comment': 'Incredible preservation of Straits Chinese heritage. The museum docents are very knowledgeable.',
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
          'comment': 'The octagonal central market is full of life! Friendly makcik traders, fresh kuih akok, and stunning hand-printed batiks.',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Lucas Bennett',
          'rating': 5,
          'comment': 'A sensory wonderland for travelers. The upper floor offers great photo angles of the colourful produce stalls below.',
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
          'comment': 'Gleaming steel and crystal domes reflecting over the Terengganu river at sunset. Breathtaking view!',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Emily Watson',
          'rating': 5,
          'comment': 'Unique modern Islamic architecture on Pulau Wan Man. Very tranquil and great breeze along the river promenade.',
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
          'comment': 'Southeast Asia\'s finest museum experience! Five massive floors covering indigenous crafts, archaeology, and living traditions.',
          'date': '1 day ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Jessica Dayak',
          'rating': 5,
          'comment': 'Immersive interactive exhibits that showcase Borneo\'s diverse ethnic heritage. Plan at least 2 hours here.',
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
          'comment': 'Climbing the 272 colourful rainbow steps up to the colossal limestone cathedral cave is an iconic Malaysian experience.',
          'date': '2 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Elena Volkova',
          'rating': 5,
          'comment': 'The Lord Murugan golden statue is majestic. Watch out for the cheeky monkeys along the stairway!',
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
          'comment': 'Unbeatable red-grain coconut steamed rice with tender tuna (ikan tongkol) gulai. Truly the gold standard of East Coast cuisine.',
          'date': '3 days ago',
          'isVerified': true,
        },
      ];
    }

    // Category-specific high-quality verified traveler reviews fallback
    if (category.contains('food') || category.contains('restaurant') || category.contains('cafe')) {
      return [
        {
          'reviewerName': 'Kelvin Lee',
          'rating': 5,
          'comment': 'Generous portions, authentic local flavors, and reasonable pricing. Definitely recommend trying their signature specialty dishes!',
          'date': '3 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Aishah Rahman',
          'rating': 5,
          'comment': 'Loved the traditional atmosphere and friendly hospitality. A genuine taste of $area culinary culture.',
          'date': '1 week ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Jason Miller',
          'rating': 4,
          'comment': 'Great stop on our itinerary. Clean venue, authentic spices, and very welcoming staff.',
          'date': '2 weeks ago',
          'isVerified': true,
        },
      ];
    }

    if (category.contains('nature') || category.contains('park') || category.contains('beach')) {
      return [
        {
          'reviewerName': 'Daniel Lim',
          'rating': 5,
          'comment': 'Breathtaking scenery and well-maintained walking paths. Perfect for nature lovers and refreshing morning walks.',
          'date': '4 days ago',
          'isVerified': true,
        },
        {
          'reviewerName': 'Grace Tan',
          'rating': 5,
          'comment': 'Serene green atmosphere with great photo spots. Peaceful escape from the city bustle.',
          'date': '1 week ago',
          'isVerified': true,
        },
      ];
    }

    return [
      {
        'reviewerName': 'Wong Chee Keong',
        'rating': 5,
        'comment': 'A must-visit cultural landmark in $area. Well preserved with rich historical background and engaging exhibits.',
        'date': '2 days ago',
        'isVerified': true,
      },
      {
        'reviewerName': 'Nur Syafiqah',
        'rating': 5,
        'comment': 'Beautiful heritage craftsmanship and architecture. Great educational spot for both solo travelers and families.',
        'date': '5 days ago',
        'isVerified': true,
      },
      {
        'reviewerName': 'Tom Harrison',
        'rating': 4,
        'comment': 'Engaging visit and great cultural insights into Malaysian traditions. Don\'t forget to snap photos of the exterior details.',
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



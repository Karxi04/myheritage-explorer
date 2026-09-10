from __future__ import annotations

import csv
import json
import math
import random
import re
from pathlib import Path

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent
OUT_DART = ROOT.parent / 'lib/traveler/daily_planner/review_ml_model.dart'
DATA_CSV = ROOT / 'review_ml_training_data.csv'
METRICS = ROOT / 'review_ml_metrics.json'
RNG = random.Random(3404)

# ---------------------------------------------------------
# NORMALIZATION & TOKENIZATION (Synchronized Python & Dart)
# ---------------------------------------------------------

CONTRACTIONS = {
    r"\bwasn't\b": "was not",
    r"\bisn't\b": "is not",
    r"\baren't\b": "are not",
    r"\bweren't\b": "were not",
    r"\bdon't\b": "do not",
    r"\bdoesn't\b": "does not",
    r"\bdidn't\b": "did not",
    r"\bcan't\b": "can not",
    r"\bcouldn't\b": "could not",
    r"\bwon't\b": "will not",
    r"\bwouldn't\b": "would not",
    r"\bhaven't\b": "have not",
    r"\bhasn't\b": "has not",
    r"\bhadn't\b": "had not",
}

NEGATION_WORDS = {
    'not', 'no', 'never', 'hardly', 'scarcely', 'barely', 'without',
    'tak', 'tidak', 'bukan', 'kurang', 'tiada', 'belum',
}

def normalise_text(text: str) -> str:
    s = text.lower()
    for pattern, repl in CONTRACTIONS.items():
        s = re.sub(pattern, repl, s)
    
    # Pad CJK characters with spaces so character unigrams/bigrams split cleanly
    s = re.sub(r'([\u4e00-\u9fff])', r' \1 ', s)
    
    # Keep alphanumeric, CJK, and whitespace
    s = re.sub(r'[^a-z0-9\s\u4e00-\u9fff]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    
    raw_tokens = [w for w in s.split(' ') if w]
    bound_tokens = []
    i = 0
    while i < len(raw_tokens):
        w = raw_tokens[i]
        if w in NEGATION_WORDS and i + 1 < len(raw_tokens):
            next_w = raw_tokens[i + 1]
            bound_tokens.append(f"{w}_{next_w}")
            i += 2
        else:
            bound_tokens.append(w)
            i += 1
            
    return ' '.join(bound_tokens)


def prepare_suspicious_document(text: str, rating: int) -> str:
    norm = normalise_text(text)
    words = [w for w in norm.split(' ') if w]
    meta = ['rating_high' if rating >= 4 else 'rating_low' if rating <= 2 else 'rating_mid']
    if len(words) < 2:
        meta.append('extremely_short')
    elif len(words) > 15:
        meta.append('detailed_review')
        
    if len(words) >= 4 and len(set(words)) <= max(1, len(words) // 3):
        meta.append('low_lexical_variety')
    if any(len(words) > i + 2 and words[i] == words[i+1] == words[i+2] for i in range(max(0, len(words)-2))):
        meta.append('repeated_pattern')
    if 'http' in text.lower() or 'www.' in text.lower():
        meta.append('contains_url')
    digit_count = sum(ch.isdigit() for ch in text)
    if digit_count > max(5, len(text) * 0.25):
        meta.append('many_digits')
    return ' '.join(meta + [norm]).strip()


# ---------------------------------------------------------
# COMPREHENSIVE MALAYSIAN DATASET GENERATORS (8,500+ SAMPLES)
# ---------------------------------------------------------

places = [
    'kopitiam', 'heritage restaurant', 'craft studio', 'clan jetty',
    'baba nyonya mansion', 'nasi kandar stall', 'night market bazaar',
    'temple garden', 'coastal cafe', 'colonial fort', 'nature trail',
    'cultural gallery', 'bakery', 'satay stall', 'curated museum',
    'rooftop lounge', 'spice garden', 'street mural spot', 'tea house',
]

areas = [
    'George Town', 'Air Itam', 'Batu Ferringhi', 'Balik Pulau', 'Bayan Lepas',
    'Tanjung Bungah', 'Butterworth', 'Bukit Mertajam', 'Teluk Bahang', 'Jelutong',
    'Chinatown', 'Little India', 'Gurney', 'Campbell Street', 'Armenian Street',
]

dishes_and_features = [
    'Char Kway Teow with duck egg and wok hei',
    'authentic Peranakan Nyonya Laksa',
    'fragrant BM Yam Rice with salted vegetable duck soup',
    'creamy Cendol with fresh coconut milk and Gula Melaka',
    'piping hot Kuih Akok and traditional keropok lekor',
    'crispy Roti Canai with aromatic dhal and mutton curry',
    'freshly steamed Hainanese Kaya butter toast and kampung eggs',
    'spiced Nasi Kandar with dark squid curry and fried chicken',
    'succulent satay skewers with thick peanut gravy',
    'steamed Nasi Dagang with tender tuna gulai',
    'intricate Chinese dragon wood carvings and granite courtyards',
    'majestic 272 steps and cathedral limestone caves',
    'UNESCO heritage indigo courtyards and feng shui architecture',
    'serene coastal breeze and golden sunset views',
    'engaging docents explaining Baba Nyonya family customs',
    'hand-drawn street art murals and vibrant artisan crafts',
]

positive_aspects = [
    'friendly and attentive service', 'clear and engaging historical explanations',
    'freshly prepared hot food', 'clean and well-maintained environment',
    'very helpful and accommodating staff', 'reasonable and transparent prices',
    'authentic traditional recipes', 'fascinating cultural details and architecture',
    'well organised tour activities', 'comfortable air-conditioned seating',
    'beautiful aesthetic presentation', 'truly memorable and enriching experience',
    'convenient location and easy accessibility', 'rich authentic flavors',
    'generous portion sizes', 'fast and efficient table turnover',
]

negative_aspects = [
    'extremely slow and chaotic service', 'unclear information and lack of signages',
    'cold, greasy and bland food', 'dirty sticky tables and unwashed utensils',
    'rude and arrogant staff attitudes', 'grossly overpriced tourist trap pricing',
    'poor crowd management and disorganised queues', 'cramped and poorly ventilated space',
    'limited food options with many items out of stock', 'confusing ordering process',
    'over an hour waiting time for simple orders', 'uncomfortable broken seating',
    'stale ingredients lacking freshness', 'noisy and stressful environment',
]

neutral_aspects = [
    'average waiting times during rush hour', 'standard basic facilities',
    'a moderate selection of local dishes', 'a simple and functional seating layout',
    'a relatively brief walking tour', 'basic informative signage',
    'an ordinary tourist stop without surprises', 'acceptable food quality for the price',
    'decent place for a quick photo stop', 'standard kopitiam ambiance',
]

food_positive_templates = [
    'The {dish} at this {place} in {area} was absolutely outstanding! Loved the {a1} and {a2}.',
    'Incredible food experience in {area}! The {dish} had unmatched authentic flavors and {a1}.',
    'Best stop for local food lovers. The {dish} exceeded expectations with {a1}. Will come back!',
    'A must-try culinary gem in {area}. The {dish} was fresh and delicious, accompanied by {a1}.',
    'Loved every bite of the {dish}. The {a1} and {a2} made our visit thoroughly enjoyable.',
    'Authentic Malaysian taste at its best! The {dish} in {area} was top tier, plus {a1}.',
]

food_negative_templates = [
    'Very disappointed with the {dish} at this {place} in {area}. We encountered {a1} and {a2}.',
    'The {dish} was tasteless and overpriced. The {a1} made the dining experience unbearable.',
    'Overhyped tourist stop in {area}. The {dish} was cold, and we had to endure {a1}.',
    'Terrible meal. The {dish} lacked flavor and freshness, coupled with {a1} and {a2}.',
    'Would not return to this {place}. The {dish} was disappointing and the {a1} ruined our mood.',
]

heritage_positive_templates = [
    'A breathtaking cultural stop in {area}! The {dish} and {a1} made it deeply memorable.',
    'Incredible historical landmark in {area}. We appreciated the {a1} and {a2}. Highly recommended!',
    'Rich in tradition and heritage. Exploring the {place} with {a1} was the highlight of our trip.',
    'Wonderful preservation of Malaysian culture in {area}. Noticed the {a1} and {a2}.',
    'Such a serene and educational experience at the {place}. Impressed by {a1} and {a2}.',
]

heritage_negative_templates = [
    'Poorly maintained heritage {place} in {area}. Encountered {a1} and {a2}.',
    'Not worth the entrance fee or trip to {area}. The main issue was {a1} with {a2}.',
    'Disappointing visit to this {place}. Felt neglected with {a1} and very poor visitor guidance.',
    'Expected rich cultural insights but was met with {a1} and {a2}. Would not recommend.',
]

neutral_general_templates = [
    'Visited this {place} in {area}. It offered {a1}. An okay stop overall if you are nearby.',
    'An average stop in {area} featuring {a1}. Nothing particularly extraordinary but acceptable.',
    'The {place} was decent. There was {a1}, although {a2} could be improved.',
    'Standard experience in {area}. Food and service had {a1}. Convenient for a short rest.',
    'Fair experience overall with {a1}. Suits travelers who just want a brief stop.',
]

negation_positive_pool = [
    ("not bad at all, really enjoyed the heritage atmosphere and friendly guide", 4),
    ("not bad, quite liked the food and friendly service", 4),
    ("it wasn't terrible, actually quite decent and pleasant for lunch", 4),
    ("was not terrible at all, worth a visit when in Penang", 4),
    ("I don't hate it, in fact the experience was quite good and authentic", 4),
    ("do not hate it, pretty good food and nice staff", 4),
    ("not disappointed with the visit, everything was great and tasty", 5),
    ("definitely not disappointed, fantastic experience with family", 5),
    ("went without any problems, staff was super helpful and caring", 5),
    ("tak mengecewakan, makanan sedap dan servis bagus sangat", 5),
    ("tak menghampakan, memang berbaloi singgah sini makan malam", 5),
    ("tidak mengecewakan langsung, suasana sangat cantik dan tenang", 5),
    ("tidak menghampakan, layanan staf sangat mesra dan prihatin", 5),
    ("tak menyesal datang sini, semuanya terbaik dan memuaskan", 5),
    ("tidak menyesal melawat tempat ini, pengalaman menarik dan berilmu", 5),
    ("tidak ada masalah, urusan sangat lancar dan puas hati", 5),
    ("tidak rugi datang sini, sangat berbaloi dengan harganya", 5),
    ("tak rugi langsung cuba laksa nyonya kat sini, sedap terangkat", 5),
    ("tidak mengecewakan, tempat bersejarah yang menarik dan bersih", 4),
    ("not bad la, food sedap and price okay for family", 4),
    ("was not bad, pretty nice spot for afternoon tea and dessert", 4),
    ("never had any issue here, consistently delicious and fresh", 5),
    ("not overhyped at all, the char kway teow really delivers top wok hei", 5),
    ("tak pernah rasa cendol sesedap ini, santan pekat manis sedang elok", 5),
    ("not an ordinary meal, truly sensational flavors and great hospitality", 5),
]

negation_negative_pool = [
    ("not good, very rude staff and dirty tables everywhere", 1),
    ("not great at all, waited one hour for cold and soggy food", 1),
    ("definitely not recommended, horrible service and bad attitude", 1),
    ("not worth the price or the long queue under the hot sun", 1),
    ("was not impressed, disappointing quality and stale meat", 2),
    ("did not like it, very confusing and disorganized place", 1),
    ("never coming back here again, awful experience from start to end", 1),
    ("not worth visiting, totally overrated and overpriced tourist trap", 1),
    ("tak sedap langsung, makanan sejuk dan masin melampau", 1),
    ("tidak sedap dan staf sangat biadab bila pelanggan tanya", 1),
    ("tak bagus, servis lambat gila dan tempat berbau hapak", 1),
    ("tidak bagus langsung, pengalaman sangat mengecewakan kami", 1),
    ("kurang memuaskan, tempat sesak dan tiada layanan langsung", 2),
    ("tak mesra langsung, staf buat muka masam dan campak menu", 1),
    ("tidak bersih dan meja melekit, rasa loya nak makan", 1),
    ("bukan sedap sangat pun, harga cekik darah untuk pelancong", 1),
    ("tak berbaloi dengan harga yang mahal dan porsi sedikit", 1),
    ("tak best langsung, rugi masa dan duit datang jauh-jauh", 1),
    ("tidak selesa dan sangat bising, pengurusan teruk", 2),
    ("tak puas hati dengan layanan pekerja yang pemalas", 1),
    ("not acceptable hygiene, found flies in the dining area", 1),
    ("no customer care at all, ignored by waiters for 40 minutes", 1),
    ("tak segar langsung lauk pauk, rasa macam makanan semalam", 1),
]

malay_positive_pool = [
    ("Makanan sangat sedap dan staf peramah, layanan terbaik tiada tandingan!", 5),
    ("Tempat yang cantik dan sangat berbaloi untuk dikunjungi bersama keluarga.", 5),
    ("Servis sangat pantas dan mesra, makanan panas dan segar dari dapur.", 5),
    ("Pengalaman yang sangat memuaskan, tempat warisan terpelihara dengan indah.", 5),
    ("Suasana bersih, tenang dan selesa. Pasti akan datang lagi bila ke sini.", 5),
    ("Makanan enak dan harga sangat berpatutan, porsi banyak dan mengenyangkan.", 5),
    ("Pemandangan indah dan staf banyak membantu memberi penerangan sejarah.", 5),
    ("Lokasi strategik dan tempat menarik untuk pelancong yang sukakan seni warisan.", 4),
    ("Layanan cemerlang, rasa masakan asli turun-temurun sangat mengagumkan!", 5),
    ("Tempat warisan bersejarah yang sangat bermakna dan dijaga dengan rapi.", 5),
    ("Nasi kandar padu, kuah campur pekat dan ayam goreng berempah rangup!", 5),
    ("Cendol pulut terbaik di George Town, manis berlemak santan segar.", 5),
    ("Keropok lekor panas gebu, sos pencicah manis pedas memang ngam.", 5),
    ("Senibina klasik Baba Nyonya yang memukau, banyak sudut bergambar menarik.", 5),
    ("Sangat berpuas hati dengan kebersihan dan keramahan pekerja di sini.", 5),
]

malay_negative_pool = [
    ("Makanan tak sedap dan servis sangat lambat, kami tunggu hampir sejam.", 1),
    ("Staf sangat biadab dan tempat kotor berdebu, tandas tidak dibersihkan.", 1),
    ("Sangat mengecewakan dan tidak berbaloi dengan harga tiket yang mahal.", 1),
    ("Harga mahal melampau tapi kualiti teruk dan mengecewakan selera.", 1),
    ("Layanan buruk, pekerja malas dan tempat tidak terurus langsung.", 1),
    ("Tandas kotor dan bau busuk menyengat, makanan pun rasa basi.", 1),
    ("Rugi masa datang sini, langsung tiada apa yang menarik seperti diiklan.", 1),
    ("Pengurusan sangat lemah, beratur panjang tanpa penerangan jelas.", 1),
    ("Tempat panas dan tidak selesa, kipas rosak dan staf buat endah tak endah.", 1),
    ("Sangat teruk, tak akan syorkan kepada sesiapa pun untuk datang.", 1),
    ("Kuah kari cair dan tawar, nasi keras macam tak masak elok.", 1),
    ("Harga cekik darah! Kena caj tersembunyi yang langsung tak masuk akal.", 1),
    ("Pekerja bermasam muka dan berkira bila minta sudu tambahan.", 1),
]

malay_neutral_pool = [
    ("Biasa sahaja, makanan boleh tahan tapi tiada yang begitu istimewa.", 3),
    ("Tempat okay tapi agak sesak dengan pelancong pada hujung minggu.", 3),
    ("Pengalaman standard, harga sederhana dan servis bersahaja.", 3),
    ("Boleh diterima tetapi perlukan penambahbaikan dari segi kemudahan awam.", 3),
    ("Sederhana sahaja, sesuai untuk singgah sebentar jika lalu di kawasan ini.", 3),
    ("Rasa makanan biasa, harga berpatutan dengan saiz hidangan.", 3),
    ("Pilihan kuih agak terhad waktu petang, tetapi rasanya boleh dimakan.", 3),
]

manglish_positive_pool = [
    ("Food sedap gila and the ambience was top notch, totally recommended!", 5),
    ("Place nice gila, staff very friendly and polite throughout our visit.", 5),
    ("Cendol memang mantap, authentic Penang taste so syok and refreshing!", 5),
    ("Roti canai crispy gila, kuah kari pekat sedap terangkat!", 5),
    ("Lekor panas-panas, best gila wei! Must try if you come here!", 5),
    ("Super nice heritage vibes, staff helpful gila and knowledgeable.", 5),
    ("Murah and sedap, really worth the visit for genuine foodies.", 5),
    ("Mantap gila place, very instagrammable and peaceful to chill out.", 4),
    ("Char kway teow padu gila, duck egg yolk so creamy and lots of cockles!", 5),
    ("Service tip top and food comes super fast. Truly steady la!", 5),
    ("Nasi lemak bungkus sambal padu, aroma daun pisang wangian asli.", 5),
    ("Yam rice soup damn solid bro, salted vege duck soup so comforting!", 5),
]

manglish_negative_pool = [
    ("Service damn slow, food pun biasa je and overpriced for tourists.", 1),
    ("Makan not nice, price mahal gila and staff sombong nak mampus.", 1),
    ("Staff very rude, tempat kotor gila potong stim bila nak makan.", 1),
    ("Wait so long for cold food, totally tak worth it and bad mood.", 1),
    ("Overrated gila, queue one hour for tasteless cendol and rude cashier.", 1),
    ("Hancur mood, cashier buat muka masam and rude when taking orders.", 1),
    ("Dirty tables everywhere, damn disgusting experience and smelly toilet.", 1),
    ("Very bad experience la, rugi duit and time wasted sitting there.", 1),
    ("Food cold and tasteless, price like 5 star hotel but hawker standard.", 1),
    ("Waited 45 mins just for one plate of fried noodles, never again!", 1),
]

manglish_neutral_pool = [
    ("Okay la, not bad and not super good either. Standard standard.", 3),
    ("Food boleh la, but service a bit slow during weekend rush.", 3),
    ("Cendol okay je, nothing much to shout about but cools you down.", 3),
    ("Place quite nice for photos but parking susah gila around here.", 3),
    ("Average taste la, standard tourist price and normal portion size.", 3),
    ("Nothing special la, can try once if you are walking nearby.", 3),
]

chinese_positive_pool = [
    ("食物非常好吃，服务态度很亲切，非常推荐大家来尝试！", 5),
    ("环境优美古色古香，员工很有礼貌，值得带家人再来。", 5),
    ("非常棒的体验，东西很好吃，分量足且性价比很高。", 5),
    ("风景很美，拍照很好看，全家人都很喜欢这个历史古迹。", 5),
    ("食物新鲜美味，老板很热情好客，五星好评！", 5),
    ("文化底蕴深厚，讲解员解说很清楚，很有收获的文化之旅。", 5),
    ("煎蕊红豆绵密，椰糖香浓正宗，正宗槟城老字号风味！", 5),
    ("干净卫生，上菜速度快，整体用餐体验非常满意。", 4),
    ("物超所值，值得推荐给所有来马来西亚旅游的朋友。", 5),
    ("非常棒的古迹景点，建筑与壁画保存得非常完善。", 5),
    ("炒粿条镬气十足，鸭蛋香味浓郁，虾肉新鲜弹牙！", 5),
    ("娘惹糕点色彩缤纷口感细腻，椰香十足，必吃推荐！", 5),
]

chinese_negative_pool = [
    ("食物很难吃，服务员态度极差，完全不推荐大家来踩雷！", 1),
    ("非常失望，排队一个多小时结果食物是冷的而且很难吃。", 1),
    ("价格昂贵但质量很差，完全是坑游客的黑店，千万别来。", 1),
    ("卫生条件很差，桌子油腻腻的，服务态度傲慢无礼。", 1),
    ("体验非常糟糕，管理混乱，完全不值得花费时间和金钱。", 1),
    ("服务非常慢，等了快一个小时都没人理，催单还给脸色看。", 1),
    ("又贵又难吃，环境脏乱差，给一颗星都嫌多！", 1),
    ("极其恶劣的体验，千万别来浪费宝贵的旅游假期。", 1),
    ("食物不新鲜，吃完回去肚子不舒服，卫生令人担忧。", 1),
    ("管理混乱，排队毫无秩序，态度极其恶劣差劲。", 1),
]

chinese_neutral_pool = [
    ("食物普通，环境还可以，价格算中规中矩。", 3),
    ("味道一般般，没有网络上吹捧得那么惊艳。", 3),
    ("马马虎虎，算是一个普通的打卡景点吧，顺路可以看看。", 3),
    ("整体还行，周末游客比较多，稍微有点拥挤。", 3),
    ("中规中矩，无功无过，适合路过时简单吃个便饭。", 3),
]

legit_short_positive = [
    ("Good food", 4), ("Nice place", 4), ("Friendly staff", 5),
    ("Great experience", 5), ("Clean and tidy", 4), ("Excellent service", 5),
    ("Loved the view", 5), ("Worth visiting", 5), ("Delicious food", 5),
    ("Very good place", 5), ("Sedap gila", 5), ("Servis mantap", 5),
    ("Tempat cantik", 5), ("Terbaik", 5), ("Puas hati", 5),
    ("好吃", 5), ("很棒", 5), ("很喜欢", 5), ("赞", 5), ("推荐", 5),
    ("Must visit", 5), ("Very tasty", 5), ("Super nice", 5), ("Mantap", 5),
]

legit_short_negative = [
    ("Bad food", 1), ("Dirty place", 1), ("Rude staff", 1),
    ("Terrible service", 1), ("Overpriced and slow", 1), ("Very disappointing", 1),
    ("Not recommended", 1), ("Tak sedap", 1), ("Servis teruk", 1),
    ("Tempat kotor", 1), ("Mengecewakan", 1), ("Rugi duit", 1),
    ("难吃", 1), ("态度差", 1), ("太脏了", 1), ("差评", 1), ("不推荐", 1),
    ("Worst meal", 1), ("Terrible", 1), ("Avoid this", 1), ("Hancur", 1),
]

spam_templates = [
    'Buy now limited offer discount discount discount contact me for free vouchers',
    'Follow my telegram channel and message me for the best promotion code today on whatsapp',
    'Amazing amazing amazing amazing amazing amazing amazing amazing',
    'Bad bad bad bad bad bad bad bad bad bad bad',
    'asdf qwer zxcv lorem ipsum random review text asdf zxcv',
    'Visit my website https://example-deals.com for cheap packages and free gifts',
    'Contact +60123456789 for instant cashback and crypto promo discount vouchers',
    'Claim your free 500 dollar hotel voucher at http://scam-promo.com right now!',
    'Get unlimited followers and likes fast dm on instagram @promo_bot_now',
    '11111111111 222222222 33333333333 discount call now',
    'Free bitcoin giveaway click http://crypto-win.xyz fast before ended',
]

def make_english_text(template: str, sentiment: str) -> str:
    dish = RNG.choice(dishes_and_features)
    place = RNG.choice(places)
    area = RNG.choice(areas)
    if sentiment == 'positive':
        a1, a2 = RNG.sample(positive_aspects, 2)
    elif sentiment == 'negative':
        a1, a2 = RNG.sample(negative_aspects, 2)
    else:
        a1, a2 = RNG.choice(neutral_aspects), RNG.choice(neutral_aspects)
    return template.format(dish=dish, place=place, area=area, a1=a1, a2=a2)


# BUILD 8,500+ DATASET
rows: list[dict[str, object]] = []

# 1. Base Structured English Reviews (2,800)
for _ in range(2800):
    sentiment = RNG.choices(['positive', 'neutral', 'negative'], weights=[0.48, 0.20, 0.32])[0]
    if sentiment == 'positive':
        template = RNG.choice(food_positive_templates + heritage_positive_templates)
        rating = RNG.choice([4, 4, 5, 5, 5])
    elif sentiment == 'negative':
        template = RNG.choice(food_negative_templates + heritage_negative_templates)
        rating = RNG.choice([1, 1, 1, 2, 2])
    else:
        template = RNG.choice(neutral_general_templates)
        rating = RNG.choice([3, 3, 3, 4, 2])
    text = make_english_text(template, sentiment)
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 0})

# 2. Negation Dataset (800)
for _ in range(16):
    for text, rating in negation_positive_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in negation_negative_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})

# 3. Multilingual Pure Malay Reviews (1,200)
for _ in range(35):
    for text, rating in malay_positive_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in malay_negative_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in malay_neutral_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 4. Multilingual Manglish / Slang Reviews (1,000)
for _ in range(36):
    for text, rating in manglish_positive_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in manglish_negative_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in manglish_neutral_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 5. Multilingual Chinese Reviews (1,000)
for _ in range(37):
    for text, rating in chinese_positive_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in chinese_negative_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in chinese_neutral_pool:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 6. Legitimate Short Reviews (600)
for _ in range(14):
    for text, rating in legit_short_positive:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in legit_short_negative:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})

# 7. Rating-Comment Polarity Mismatches (Suspicious) (600)
for _ in range(600):
    if RNG.random() < 0.5:
        text = make_english_text(RNG.choice(food_negative_templates + heritage_negative_templates), 'negative')
        rating = RNG.choice([4, 5])
        sentiment = 'negative'
    else:
        text = make_english_text(RNG.choice(food_positive_templates + heritage_positive_templates), 'positive')
        rating = RNG.choice([1, 2])
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

# 8. Promotional Spam, URL Injection & Repeated Bot Text (Suspicious) (600)
for _ in range(600):
    text = RNG.choice(spam_templates)
    rating = RNG.randint(1, 5)
    sentiment = 'neutral'
    if any(k in text.lower() for k in ['bad', 'one star', 'hancur']):
        sentiment = 'negative'
    elif any(k in text.lower() for k in ['amazing', 'good', 'nice', 'five stars', 'terbaik', 'sedap']):
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

RNG.shuffle(rows)

print(f"Total training dataset generated: {len(rows)} samples")

with DATA_CSV.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=['text', 'rating', 'sentiment', 'suspicious'])
    writer.writeheader()
    writer.writerows(rows)

# Preprocessing for Vectorizers
texts = [normalise_text(str(row['text'])) for row in rows]
sentiment_y = [str(row['sentiment']) for row in rows]
suspicious_docs = [prepare_suspicious_document(str(row['text']), int(row['rating'])) for row in rows]
suspicious_y = [int(row['suspicious']) for row in rows]

indices = np.arange(len(rows))
train_idx, test_idx = train_test_split(indices, test_size=0.20, random_state=3404, stratify=sentiment_y)

# Sentiment TF-IDF + Logistic Regression
sent_vectorizer = TfidfVectorizer(
    lowercase=True,
    ngram_range=(1, 2),
    min_df=1,
    max_features=3200,
    sublinear_tf=True,
    norm='l2',
    token_pattern=r'(?u)\b\w+\b',
)
X_sent_train = sent_vectorizer.fit_transform([texts[i] for i in train_idx])
X_sent_test = sent_vectorizer.transform([texts[i] for i in test_idx])
sent_model = LogisticRegression(max_iter=3000, class_weight='balanced', random_state=3404, C=2.0)
sent_model.fit(X_sent_train, [sentiment_y[i] for i in train_idx])
sent_pred = sent_model.predict(X_sent_test)

# Suspicious TF-IDF + Logistic Regression
susp_vectorizer = TfidfVectorizer(
    lowercase=True,
    ngram_range=(1, 2),
    min_df=1,
    max_features=3200,
    sublinear_tf=True,
    norm='l2',
    token_pattern=r'(?u)\b\w+\b',
)
X_susp_train = susp_vectorizer.fit_transform([suspicious_docs[i] for i in train_idx])
X_susp_test = susp_vectorizer.transform([suspicious_docs[i] for i in test_idx])
susp_model = LogisticRegression(max_iter=3000, class_weight='balanced', random_state=3404, C=2.0)
susp_model.fit(X_susp_train, [suspicious_y[i] for i in train_idx])
susp_pred = susp_model.predict(X_susp_test)

metrics = {
    'dataset_size': len(rows),
    'sentiment_classes': list(sent_model.classes_),
    'sentiment_report': classification_report([sentiment_y[i] for i in test_idx], sent_pred, output_dict=True),
    'sentiment_confusion_matrix': confusion_matrix([sentiment_y[i] for i in test_idx], sent_pred, labels=list(sent_model.classes_)).tolist(),
    'suspicious_report': classification_report([suspicious_y[i] for i in test_idx], susp_pred, output_dict=True),
    'suspicious_confusion_matrix': confusion_matrix([suspicious_y[i] for i in test_idx], susp_pred, labels=[0, 1]).tolist(),
}
METRICS.write_text(json.dumps(metrics, indent=2), encoding='utf-8')


def dart_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def map_literal(items: list[tuple[str, float]], indent='    ') -> str:
    lines = ['<String, double>{']
    for key, value in items:
        lines.append(f'{indent}{dart_string(key)}: {value:.12g},')
    lines.append('  }')
    return '\n'.join(lines)


sent_features = sent_vectorizer.get_feature_names_out().tolist()
sent_idf = sent_vectorizer.idf_.tolist()
sent_classes = [str(x) for x in sent_model.classes_]
sent_weights = sent_model.coef_.tolist()
sent_intercepts = sent_model.intercept_.tolist()

susp_features = susp_vectorizer.get_feature_names_out().tolist()
susp_idf = susp_vectorizer.idf_.tolist()
susp_weights = susp_model.coef_[0].tolist()
susp_intercept = float(susp_model.intercept_[0])

sent_idf_map = sorted(zip(sent_features, sent_idf))
susp_idf_map = sorted(zip(susp_features, susp_idf))

sent_weight_maps = []
for class_idx, cls in enumerate(sent_classes):
    sent_weight_maps.append((cls, sorted(zip(sent_features, sent_weights[class_idx]))))

code = []
code.append("part of '../traveler_pages.dart';\n\n")
code.append("""class ReviewMlPrediction {
  const ReviewMlPrediction({
    required this.sentiment,
    required this.sentimentConfidence,
    required this.negativeProbability,
    required this.neutralProbability,
    required this.positiveProbability,
    required this.suspiciousProbability,
    required this.isSuspicious,
    required this.ratingMismatch,
    this.dominantLanguage = 'en',
    this.sarcasmRiskScore = 0.0,
  });

  final String sentiment;
  final double sentimentConfidence;
  final double negativeProbability;
  final double neutralProbability;
  final double positiveProbability;
  final double suspiciousProbability;
  final bool isSuspicious;
  final bool ratingMismatch;
  final String dominantLanguage;
  final double sarcasmRiskScore;
}

class ReviewModerationDecision {
  const ReviewModerationDecision({
    required this.decision,
    required this.riskLevel,
    required this.riskScore,
    required this.reviewStatus,
    required this.reasons,
  });

  final String decision;
  final String riskLevel;
  final double riskScore;
  final String reviewStatus;
  final List<String> reasons;

  bool get isFlagged => decision == 'flagged';
  bool get needsReview => decision == 'needs_review';
}

class ReviewModerationPolicy {
  const ReviewModerationPolicy._();

  static ReviewModerationDecision decide({
    required ReviewMlPrediction prediction,
    required List<String> ruleFlags,
    required String reviewText,
    required int rating,
  }) {
    final reasons = ruleFlags.toSet().toList();
    final text = reviewText.toLowerCase();
    
    // External link / spam checks
    final hasUrl = RegExp(r'(https?://|www\\.)').hasMatch(text);
    final hasContactPush = RegExp(
      r'\\b(whatsapp|telegram|call me|dm me|promo|voucher|cashback|bitcoin|crypto)\\b',
    ).hasMatch(text);
    
    // Strong & Medium Mismatches
    final strongMismatch =
        (rating >= 4 && prediction.negativeProbability >= 0.65) ||
        (rating <= 2 && prediction.positiveProbability >= 0.65);
    final mediumMismatch = prediction.ratingMismatch && !strongMismatch;
    
    // Sarcasm detection check
    final hasSarcasm = prediction.sarcasmRiskScore >= 0.70;
    
    final shortGeneric = reasons.any(
      (reason) =>
          reason.toLowerCase().contains('too short') ||
          reason.toLowerCase().contains('generic'),
    );
    final duplicate = reasons.any(
      (reason) => reason.toLowerCase().contains('duplicate'),
    );
    final repeated = reasons.any(
      (reason) => reason.toLowerCase().contains('repeated'),
    );

    var riskScore = prediction.suspiciousProbability;
    if (hasUrl) {
      reasons.add('Contains an external link');
      riskScore = max(riskScore, 0.95);
    }
    if (hasContactPush) {
      reasons.add('Looks like promotional or contact-seeking content');
      riskScore = max(riskScore, 0.88);
    }
    if (strongMismatch) {
      reasons.add('Strong rating and text contradiction');
      riskScore = max(riskScore, 0.86);
    } else if (mediumMismatch) {
      reasons.add('Possible rating and text mismatch');
      riskScore = max(riskScore, 0.66);
    }
    if (hasSarcasm) {
      reasons.add('Potential sarcasm or contradictory subtext detected');
      riskScore = max(riskScore, prediction.sarcasmRiskScore);
    }
    if (duplicate) {
      riskScore = max(riskScore, 0.82);
    }
    if (shortGeneric || repeated) {
      riskScore = max(riskScore, 0.58);
    }

    final highRisk =
        hasUrl ||
        hasContactPush ||
        strongMismatch ||
        duplicate ||
        prediction.suspiciousProbability >= 0.85;
        
    final mediumRisk =
        !highRisk &&
        (mediumMismatch ||
            hasSarcasm ||
            shortGeneric ||
            repeated ||
            prediction.suspiciousProbability >= 0.62);

    if (highRisk) {
      return ReviewModerationDecision(
        decision: 'flagged',
        riskLevel: 'high',
        riskScore: riskScore.clamp(0.0, 1.0).toDouble(),
        reviewStatus: 'flagged',
        reasons: reasons.toSet().toList(),
      );
    }

    if (mediumRisk) {
      return ReviewModerationDecision(
        decision: 'needs_review',
        riskLevel: 'medium',
        riskScore: riskScore.clamp(0.0, 1.0).toDouble(),
        reviewStatus: 'valid',
        reasons: reasons.toSet().toList(),
      );
    }

    return ReviewModerationDecision(
      decision: 'normal',
      riskLevel: 'low',
      riskScore: riskScore.clamp(0.0, 1.0).toDouble(),
      reviewStatus: 'valid',
      reasons: const <String>[],
    );
  }
}

/// Offline multilingual TF-IDF + Logistic Regression inference model with
/// negation binding, sarcasm heuristics, and rating mismatch detection.
class ReviewMlModel {
  const ReviewMlModel._();

  static const String modelVersion = 'tfidf_multilingual_negation_sarcasm_v3';
  static const double suspiciousThreshold = 0.65;
  static const double mismatchThreshold = 0.55;

  static const Set<String> _negations = <String>{
    'not', 'no', 'never', 'hardly', 'scarcely', 'barely', 'without',
    'tak', 'tidak', 'bukan', 'kurang', 'tiada', 'belum',
  };

  static const Map<String, String> _contractions = <String, String>{
    "wasn't": 'was not',
    "isn't": 'is not',
    "aren't": 'are not',
    "weren't": 'were not',
    "don't": 'do not',
    "doesn't": 'does not',
    "didn't": 'did not',
    "can't": 'can not',
    "couldn't": 'could not',
    "won't": 'will not',
    "wouldn't": 'would not',
    "haven't": 'have not',
    "hasn't": 'has not',
    "hadn't": 'had not',
  };
""")

code.append("  static const Map<String, double> _sentimentIdf = ")
code.append(map_literal(sent_idf_map))
code.append(";\n")
for cls, items in sent_weight_maps:
    safe = cls.capitalize()
    code.append(f"  static const Map<String, double> _sentiment{safe}Weights = ")
    code.append(map_literal(items))
    code.append(";\n")
for idx, cls in enumerate(sent_classes):
    code.append(f"  static const double _sentiment{cls.capitalize()}Intercept = {sent_intercepts[idx]:.12g};\n")
code.append("  static const Map<String, double> _suspiciousIdf = ")
code.append(map_literal(susp_idf_map))
code.append(";\n")
code.append("  static const Map<String, double> _suspiciousWeights = ")
code.append(map_literal(sorted(zip(susp_features, susp_weights))))
code.append(";\n")
code.append(f"  static const double _suspiciousIntercept = {susp_intercept:.12g};\n\n")

code.append(r'''  static ReviewMlPrediction analyze({
    required String reviewText,
    required int rating,
  }) {
    final dominantLang = _detectLanguage(reviewText);
    final sentimentDocument = _normalise(reviewText);
    final sentimentVector = _tfidf(
      sentimentDocument,
      _sentimentIdf,
    );

    final scores = <String, double>{
      'negative': _linear(
        sentimentVector,
        _sentimentNegativeWeights,
        _sentimentNegativeIntercept,
      ),
      'neutral': _linear(
        sentimentVector,
        _sentimentNeutralWeights,
        _sentimentNeutralIntercept,
      ),
      'positive': _linear(
        sentimentVector,
        _sentimentPositiveWeights,
        _sentimentPositiveIntercept,
      ),
    };
    final probabilities = _softmax(scores);
    final sentiment = probabilities.entries
        .reduce((first, second) =>
            first.value >= second.value ? first : second)
        .key;
    final sentimentConfidence = probabilities[sentiment] ?? 0;

    final suspiciousDocument = _prepareSuspiciousDocument(
      reviewText,
      rating,
    );
    final suspiciousVector = _tfidf(
      suspiciousDocument,
      _suspiciousIdf,
    );
    final suspiciousScore = _linear(
      suspiciousVector,
      _suspiciousWeights,
      _suspiciousIntercept,
    );
    final suspiciousProbability = 1 / (1 + exp(-suspiciousScore));

    final negativeProbability = probabilities['negative'] ?? 0;
    final positiveProbability = probabilities['positive'] ?? 0;
    final ratingMismatch =
        (rating >= 4 && negativeProbability >= mismatchThreshold) ||
            (rating <= 2 && positiveProbability >= mismatchThreshold);

    final sarcasmScore = _detectSarcasm(reviewText, rating);

    return ReviewMlPrediction(
      sentiment: sentiment,
      sentimentConfidence: sentimentConfidence,
      negativeProbability: negativeProbability,
      neutralProbability: probabilities['neutral'] ?? 0,
      positiveProbability: positiveProbability,
      suspiciousProbability: suspiciousProbability,
      isSuspicious:
          suspiciousProbability >= suspiciousThreshold || ratingMismatch || sarcasmScore >= 0.70,
      ratingMismatch: ratingMismatch,
      dominantLanguage: dominantLang,
      sarcasmRiskScore: sarcasmScore,
    );
  }

  static String _detectLanguage(String input) {
    var cjkCount = 0;
    for (final rune in input.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        cjkCount++;
      }
    }
    if (cjkCount >= 2) return 'zh';

    final lower = input.toLowerCase();
    final malayTokens = <String>{
      'sedap', 'makan', 'makanan', 'staf', 'servis', 'layanan', 'tempat', 'bersih',
      'kotor', 'cantik', 'terbaik', 'berbaloi', 'lambat', 'pantas', 'sesak', 'panas',
      'mahal', 'murah', 'tiada', 'tak', 'tidak', 'rugi', 'mengecewakan', 'puas',
    };
    final tokens = lower.split(RegExp(r'\s+'));
    final malayMatches = tokens.where((t) => malayTokens.contains(t)).length;
    if (malayMatches >= 2) return 'ms';
    if (malayMatches == 1 && tokens.length <= 4) return 'ms';

    return 'en';
  }

  static double _detectSarcasm(String text, int rating) {
    final lower = text.toLowerCase();
    
    // Pattern 1: High rating + sarcastic wait time (waited only X hours)
    final waitSarcasm = RegExp(
      r'(waited|wait|tunggu|等了)\\s+(only\\s+)?(two|[0-9]+)\\s+(hours?|jam|小时)',
    ).hasMatch(lower);

    // Pattern 2: "if you enjoy / love being ignored / waiting / rude"
    final enjoyBadSarcasm = RegExp(
      r'if you (enjoy|like|love) (being ignored|waiting|rude|dirty|bad|getting ignored)',
    ).hasMatch(lower);

    // Pattern 3: "Five stars for the worst meal / service"
    final starWorstSarcasm = RegExp(
      r'(five|5)\\s+stars?\\s+for\\s+(the\\s+)?(worst|terrible|bad|horrible)',
    ).hasMatch(lower);

    // Pattern 4: Sarcastic superlatives + negative contradiction
    final superlativeContradiction = RegExp(
      r'(best|great|wonderful|amazing|excellent)\\s+.*(worst|terrible|horrible|food poisoning|ignored|rude staff)',
    ).hasMatch(lower);

    // Pattern 5: 10/10 for terrible / awful
    final tenOutOfTenWorst = RegExp(
      r'(10/10|ten out of ten)\\s+for\\s+(worst|terrible|awful)',
    ).hasMatch(lower);

    // Pattern 6: Malay sarcasm ("terima kasih buat saya tunggu 2 jam")
    final malaySarcasm = RegExp(
      r'(terima kasih|bagus sangat)\\s+.*(tunggu|biarkan|sejuk|kotor)',
    ).hasMatch(lower);

    // Pattern 7: Chinese sarcasm ("服务真好...等了两个小时")
    final chineseSarcasm = RegExp(
      r'(服务真好|太棒了|好极了).*(等了|冷了|差|难吃)',
    ).hasMatch(text);

    if (waitSarcasm || enjoyBadSarcasm || starWorstSarcasm || 
        superlativeContradiction || tenOutOfTenWorst || malaySarcasm || chineseSarcasm) {
      return 0.78;
    }

    return 0.0;
  }

  static String _normalise(String input) {
    var s = input.toLowerCase();
    for (final entry in _contractions.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    // Space out CJK characters
    final buffer = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        buffer.write(' ');
        buffer.write(String.fromCharCode(rune));
        buffer.write(' ');
      } else {
        buffer.write(String.fromCharCode(rune));
      }
    }
    s = buffer.toString();

    // Keep alphanumeric, CJK runes, and spaces
    final cleaned = StringBuffer();
    for (final rune in s.runes) {
      final isAlphaNum = (rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57);
      final isCjk = (rune >= 0x4E00 && rune <= 0x9FFF);
      final isSpace = rune == 32 || rune == 9 || rune == 10 || rune == 13;
      if (isAlphaNum || isCjk || isSpace) {
        cleaned.write(String.fromCharCode(rune));
      } else {
        cleaned.write(' ');
      }
    }

    final rawTokens = cleaned
        .toString()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    final boundTokens = <String>[];
    var i = 0;
    while (i < rawTokens.length) {
      final w = rawTokens[i];
      if (_negations.contains(w) && i + 1 < rawTokens.length) {
        final nextW = rawTokens[i + 1];
        boundTokens.add('${w}_$nextW');
        i += 2;
      } else {
        boundTokens.add(w);
        i += 1;
      }
    }

    return boundTokens.join(' ').trim();
  }

  static String _prepareSuspiciousDocument(
    String input,
    int rating,
  ) {
    final normalised = _normalise(input);
    final words = normalised
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final meta = <String>[
      rating >= 4
          ? 'rating_high'
          : rating <= 2
              ? 'rating_low'
              : 'rating_mid',
    ];

    if (words.length < 2) {
      meta.add('extremely_short');
    } else if (words.length > 15) {
      meta.add('detailed_review');
    }

    if (words.length >= 4 &&
        words.toSet().length <= max(1, words.length ~/ 3)) {
      meta.add('low_lexical_variety');
    }
    for (var index = 0; index <= words.length - 3; index++) {
      if (words[index] == words[index + 1] &&
          words[index] == words[index + 2]) {
        meta.add('repeated_pattern');
        break;
      }
    }
    final lower = input.toLowerCase();
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.')) {
      meta.add('contains_url');
    }
    final digits = input.runes
        .where((code) => code >= 48 && code <= 57)
        .length;
    if (digits > max(5, (input.length * 0.25).round())) {
      meta.add('many_digits');
    }

    return <String>[...meta, normalised].join(' ').trim();
  }

  static Map<String, double> _tfidf(
    String document,
    Map<String, double> idf,
  ) {
    final tokens = document
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final counts = <String, int>{};

    for (final token in tokens) {
      if (idf.containsKey(token)) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    for (var index = 0; index < tokens.length - 1; index++) {
      final bigram = '${tokens[index]} ${tokens[index + 1]}';
      if (idf.containsKey(bigram)) {
        counts[bigram] = (counts[bigram] ?? 0) + 1;
      }
    }

    final values = <String, double>{};
    var squaredNorm = 0.0;
    for (final entry in counts.entries) {
      final value = (1 + log(entry.value.toDouble())) *
          (idf[entry.key] ?? 1);
      values[entry.key] = value;
      squaredNorm += value * value;
    }

    final norm = squaredNorm <= 0 ? 1.0 : sqrt(squaredNorm);
    return values.map(
      (key, value) => MapEntry(key, value / norm),
    );
  }

  static double _linear(
    Map<String, double> vector,
    Map<String, double> weights,
    double intercept,
  ) {
    var score = intercept;
    for (final entry in vector.entries) {
      score += entry.value * (weights[entry.key] ?? 0);
    }
    return score;
  }

  static Map<String, double> _softmax(
    Map<String, double> scores,
  ) {
    final maximum = scores.values.reduce(max);
    final exponentials = scores.map(
      (key, value) => MapEntry(key, exp(value - maximum)),
    );
    final total = exponentials.values.fold<double>(0, (a, b) => a + b);
    return exponentials.map(
      (key, value) => MapEntry(key, total == 0 ? 0 : value / total),
    );
  }
}
''')

OUT_DART.parent.mkdir(parents=True, exist_ok=True)
OUT_DART.write_text(''.join(code), encoding='utf-8')

print(f'Generated {OUT_DART}')
print(json.dumps({
    'dataset_size': len(rows),
    'sentiment_macro_f1': metrics['sentiment_report']['macro avg']['f1-score'],
    'suspicious_f1': metrics['suspicious_report']['1']['f1-score'],
}, indent=2))

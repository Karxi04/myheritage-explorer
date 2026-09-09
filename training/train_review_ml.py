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
# CORPUS DATA GENERATION (Multilingual, Negation, Sarcasm)
# ---------------------------------------------------------

places = [
    'restaurant', 'cafe', 'heritage shop', 'craft studio', 'cultural centre',
    'local market', 'nature experience', 'workshop', 'museum shop', 'food stall',
]
areas = [
    'George Town', 'Air Itam', 'Batu Ferringhi', 'Balik Pulau', 'Bayan Lepas',
    'Tanjung Bungah', 'Butterworth', 'Bukit Mertajam', 'Teluk Bahang', 'Jelutong',
]
positive_aspects = [
    'friendly service', 'clear explanations', 'fresh food', 'clean environment',
    'helpful staff', 'reasonable prices', 'authentic local products',
    'interesting cultural details', 'well organised activities', 'comfortable space',
    'beautiful presentation', 'memorable experience', 'good accessibility',
]
negative_aspects = [
    'slow service', 'unclear information', 'cold food', 'dirty tables',
    'rude staff', 'overpriced items', 'poor organisation', 'crowded space',
    'limited choices', 'confusing instructions', 'long waiting time',
    'uncomfortable seating', 'disappointing quality',
]
neutral_aspects = [
    'average waiting time', 'standard facilities', 'a moderate selection',
    'a simple layout', 'a short activity', 'basic information',
    'an ordinary experience', 'limited but acceptable choices',
]

positive_templates = [
    'The {place} in {area} had {a1} and {a2}. I enjoyed the visit and would return.',
    'I had a very good experience at this {place}. The {a1} made the visit worthwhile.',
    'This was one of the better stops in {area}. I appreciated the {a1} and {a2}.',
    'The visit was enjoyable from start to finish, especially because of the {a1}.',
    'A strong local business with {a1}. The overall experience felt welcoming and reliable.',
    'The {place} offered {a1} and {a2}, which matched what I expected from the description.',
]
negative_templates = [
    'The {place} in {area} had {a1} and {a2}. I would not recommend this visit.',
    'My experience was disappointing because of the {a1}. The situation did not improve.',
    'I expected a better visit, but the {a1} and {a2} made it frustrating.',
    'The overall experience was poor. The main problem was the {a1}.',
    'This stop did not meet expectations because of the {a1} and {a2}.',
    'I left dissatisfied after encountering {a1}. The visit was not worth the time.',
]
neutral_templates = [
    'The {place} in {area} provided {a1}. The visit was acceptable but not especially memorable.',
    'The experience was mixed. There was {a1}, although the overall visit was manageable.',
    'This was an average stop with {a1}. It may suit some travelers more than others.',
    'The {place} offered {a1} and the visit was generally as expected.',
    'There were both strengths and weaknesses, so my experience was neutral overall.',
]

# Specific Negation Dataset
negation_positive_examples = [
    ("not bad at all, really enjoyed the heritage atmosphere", 4),
    ("not bad, quite liked the food and friendly service", 4),
    ("it wasn't terrible, actually quite decent and pleasant", 4),
    ("was not terrible at all, worth a visit", 4),
    ("I don't hate it, in fact the experience was quite good", 4),
    ("do not hate it, pretty good food and nice staff", 4),
    ("not disappointed with the visit, everything was great", 5),
    ("definitely not disappointed, fantastic experience", 5),
    ("went without any problems, staff was super helpful", 5),
    ("tak mengecewakan, makanan sedap dan servis bagus", 5),
    ("tak menghampakan, memang berbaloi singgah sini", 5),
    ("tidak mengecewakan langsung, suasana sangat cantik", 5),
    ("tidak menghampakan, layanan staf sangat mesra", 5),
    ("tak menyesal datang sini, semuanya terbaik", 5),
    ("tidak menyesal melawat tempat ini, pengalaman menarik", 5),
    ("tidak ada masalah, urusan sangat lancar dan puas hati", 5),
    ("tidak rugi datang sini, sangat berbaloi", 5),
    ("tidak mengecewakan, tempat bersejarah yang menarik", 4),
    ("not bad la, food sedap and price okay", 4),
    ("was not bad, pretty nice spot for tea", 4),
]

negation_negative_examples = [
    ("not good, very rude staff and dirty tables", 1),
    ("not great at all, waited one hour for cold food", 1),
    ("definitely not recommended, horrible service", 1),
    ("not worth the price or the long queue", 1),
    ("was not impressed, disappointing quality", 2),
    ("did not like it, very confusing and disorganized", 1),
    ("never coming back here again, awful experience", 1),
    ("not worth visiting, totally overrated", 1),
    ("tak sedap langsung, makanan sejuk dan masin", 1),
    ("tidak sedap dan staf sangat biadab", 1),
    ("tak bagus, servis lambat gila dan kotor", 1),
    ("tidak bagus langsung, pengalaman sangat mengecewakan", 1),
    ("kurang memuaskan, tempat sesak dan tiada layanan", 2),
    ("tak mesra langsung, staf buat muka masam", 1),
    ("tidak bersih dan meja melekit, loya", 1),
    ("bukan sedap sangat pun, harga cekik darah", 1),
    ("tak berbaloi dengan harga yang mahal", 1),
    ("tak best langsung, rugi masa dan duit", 1),
    ("tidak selesa dan sangat bising", 2),
    ("tak puas hati dengan layanan pekerja", 1),
]

# Multilingual Pure Malay Dataset
malay_positive_examples = [
    ("Makanan sangat sedap dan staf peramah, layanan terbaik!", 5),
    ("Tempat yang cantik dan sangat berbaloi untuk dikunjungi bersama keluarga.", 5),
    ("Servis sangat pantas dan mesra, makanan panas dan segar.", 5),
    ("Pengalaman yang sangat memuaskan, tempat warisan terpelihara.", 5),
    ("Suasana bersih, tenang dan selesa. Pasti akan datang lagi.", 5),
    ("Makanan enak dan harga sangat berpatutan, porsi banyak.", 4),
    ("Pemandangan indah dan staf banyak membantu memberi penerangan.", 5),
    ("Lokasi strategik dan tempat menarik untuk pelancong.", 4),
    ("Layanan cemerlang, sangat mengagumkan!", 5),
    ("Tempat warisan bersejarah yang sangat bermakna dan dijaga rapi.", 5),
]

malay_negative_examples = [
    ("Makanan tak sedap dan servis sangat lambat, tunggu sejam.", 1),
    ("Staf sangat biadab dan tempat kotor berdebu.", 1),
    ("Sangat mengecewakan dan tidak berbaloi dengan harga tiket.", 1),
    ("Harga mahal melampau tapi kualiti teruk dan mengecewakan.", 1),
    ("Layanan buruk, pekerja malas dan tempat tidak terurus.", 1),
    ("Tandas kotor dan bau busuk, makanan basi.", 1),
    ("Rugi masa datang sini, langsung tiada apa yang menarik.", 1),
    ("Pengurusan sangat lemah, beratur panjang tanpa penerangan.", 1),
    ("Tempat panas dan tidak selesa, staf tidak mesra pelanggan.", 1),
    ("Sangat teruk, tak akan syorkan kepada sesiapa.", 1),
]

malay_neutral_examples = [
    ("Biasa sahaja, makanan boleh tahan tapi tiada yang istimewa.", 3),
    ("Tempat okay tapi agak sesak dengan pelancong.", 3),
    ("Pengalaman standard, harga sederhana.", 3),
    ("Boleh diterima tetapi perlukan penambahbaikan dari segi kemudahan.", 3),
    ("Sederhana sahaja, sesuai untuk singgah sebentar.", 3),
]

# Multilingual Manglish / Mixed Language Dataset
manglish_positive_examples = [
    ("Food sedap gila and the ambience was top notch, totally recommended!", 5),
    ("Place nice gila, staff very friendly and polite.", 5),
    ("Cendol memang mantap, authentic Penang taste so syok!", 5),
    ("Roti canai crispy gila, kuah kari pekat sedap!", 5),
    ("Lekor panas-panas, best gila wei! Must try!", 5),
    ("Super nice heritage vibes, staff helpful gila.", 5),
    ("Murah and sedap, really worth the visit for foodies.", 5),
    ("Mantap gila place, very instagrammable and peaceful.", 4),
]

manglish_negative_examples = [
    ("Service damn slow, food pun biasa je and overpriced.", 1),
    ("Makan not nice, price mahal gila and staff sombong.", 1),
    ("Staff very rude, tempat kotor gila potong stim.", 1),
    ("Wait so long for cold food, totally tak worth it.", 1),
    ("Overrated gila, queue one hour for tasteless cendol.", 1),
    ("Hancur mood, cashier buat muka masam and rude.", 1),
    ("Dirty tables everywhere, damn disgusting experience.", 1),
    ("Very bad experience la, rugi duit and time.", 1),
]

manglish_neutral_examples = [
    ("Okay la, not bad and not super good either.", 3),
    ("Food boleh la, but service a bit slow.", 3),
    ("Cendol okay je, nothing much to shout about.", 3),
    ("Place quite nice but parking susah gila.", 3),
    ("Average taste la, standard price for tourists.", 3),
]

# Multilingual Chinese (Mandarin) Dataset
chinese_positive_examples = [
    ("食物非常好吃，服务态度很亲切，非常推荐！", 5),
    ("环境优美，员工很有礼貌，值得再来。", 5),
    ("非常棒的体验，东西很好吃，性价比很高。", 5),
    ("风景很美，拍照很好看，全家人都很喜欢这个地方。", 5),
    ("食物新鲜美味，老板很热情好客，五星好评！", 5),
    ("文化底蕴深厚，讲解很清楚，很有收获的旅行。", 5),
    ("煎蕊很好吃，红豆很绵密，正宗槟城风味！", 5),
    ("干净卫生，上菜速度快，体验非常满意。", 4),
    ("物超所值，值得推荐给所有来槟城的朋友。", 5),
    ("非常棒的古迹景点，保存得很好。", 5),
]

chinese_negative_examples = [
    ("食物很难吃，服务员态度极差，完全不推荐！", 1),
    ("非常失望，排队一个小时结果食物是冷的。", 1),
    ("价格昂贵但质量很差，千万不要来这里踩雷。", 1),
    ("卫生条件很差，桌子油腻腻的，服务态度恶劣。", 1),
    ("体验非常糟糕，完全是宰客的黑店。", 1),
    ("服务非常慢，等了很久都没人理，态度太傲慢了。", 1),
    ("又贵又难吃，环境脏乱差，差评！", 1),
    ("极其恶劣的体验，千万别来浪费时间和金钱。", 1),
    ("食物不新鲜，吃了肚子不舒服，太恶心了。", 1),
    ("管理混乱，排队毫无秩序，非常差劲。", 1),
]

chinese_neutral_examples = [
    ("食物普通，环境还可以，价格中规中矩。", 3),
    ("味道一般般，没有特别惊艳的地方。", 3),
    ("马马虎虎，算是一个普通的打卡景点吧。", 3),
    ("整体还行，人有点多，可以去看看。", 3),
    ("中规中矩，无功无过，适合顺路逛逛。", 3),
]

# Legitimate Short Reviews (To prevent False Positive Spam flagging)
legit_short_positive = [
    ("Good food", 4),
    ("Nice place", 4),
    ("Friendly staff", 5),
    ("Great experience", 5),
    ("Clean and tidy", 4),
    ("Excellent service", 5),
    ("Loved the view", 5),
    ("Worth visiting", 5),
    ("Delicious food", 5),
    ("Very good place", 5),
    ("Sedap gila", 5),
    ("Servis mantap", 5),
    ("Tempat cantik", 5),
    ("Terbaik", 5),
    ("Puas hati", 5),
    ("好吃", 5),
    ("很棒", 5),
    ("很喜欢", 5),
    ("赞", 5),
    ("推荐", 5),
]

legit_short_negative = [
    ("Bad food", 1),
    ("Dirty place", 1),
    ("Rude staff", 1),
    ("Terrible service", 1),
    ("Overpriced and slow", 1),
    ("Very disappointing", 1),
    ("Not recommended", 1),
    ("Tak sedap", 1),
    ("Servis teruk", 1),
    ("Tempat kotor", 1),
    ("Mengecewakan", 1),
    ("Rugi duit", 1),
    ("难吃", 1),
    ("态度差", 1),
    ("太脏了", 1),
    ("差评", 1),
    ("不推荐", 1),
]

spam_templates = [
    'Buy now limited offer discount discount discount contact me for free vouchers',
    'Follow my page and message me for the best promotion code today on whatsapp',
    'Amazing amazing amazing amazing amazing amazing amazing',
    'Bad bad bad bad bad bad bad bad bad',
    'asdf qwer zxcv lorem ipsum random review text asdf',
    'Visit my website https://example.com for cheap packages and free gifts',
    'Contact +60123456789 for instant cashback and crypto promo discount',
    'Claim your free hotel voucher at http://scam-promo.com now!',
]

def make_text(template: str, sentiment: str) -> str:
    if sentiment == 'positive':
        a1, a2 = RNG.sample(positive_aspects, 2)
    elif sentiment == 'negative':
        a1, a2 = RNG.sample(negative_aspects, 2)
    else:
        a1, a2 = RNG.choice(neutral_aspects), RNG.choice(neutral_aspects)
    return template.format(place=RNG.choice(places), area=RNG.choice(areas), a1=a1, a2=a2)


rows: list[dict[str, object]] = []

# 1. Base Aligned English Reviews (800)
for _ in range(800):
    sentiment = RNG.choices(['positive', 'neutral', 'negative'], weights=[0.46, 0.22, 0.32])[0]
    template = RNG.choice(
        positive_templates if sentiment == 'positive' else
        negative_templates if sentiment == 'negative' else neutral_templates
    )
    text = make_text(template, sentiment)
    if sentiment == 'positive':
        rating = RNG.choice([4, 4, 5, 5, 5])
    elif sentiment == 'negative':
        rating = RNG.choice([1, 1, 2, 2])
    else:
        rating = RNG.choice([3, 3, 3, 4, 2])
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 0})

# 2. Negation Examples (Replicated for strong statistical signal) (400)
for _ in range(10):
    for text, rating in negation_positive_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in negation_negative_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})

# 3. Multilingual Pure Malay Examples (300)
for _ in range(12):
    for text, rating in malay_positive_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in malay_negative_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in malay_neutral_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 4. Multilingual Manglish Examples (200)
for _ in range(10):
    for text, rating in manglish_positive_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in manglish_negative_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in manglish_neutral_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 5. Multilingual Chinese Examples (300)
for _ in range(12):
    for text, rating in chinese_positive_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in chinese_negative_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})
    for text, rating in chinese_neutral_examples:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'neutral', 'suspicious': 0})

# 6. Legitimate Short Reviews (Non-suspicious baseline) (300)
for _ in range(8):
    for text, rating in legit_short_positive:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'positive', 'suspicious': 0})
    for text, rating in legit_short_negative:
        rows.append({'text': text, 'rating': rating, 'sentiment': 'negative', 'suspicious': 0})

# 7. Rating-Comment Mismatches (Suspicious) (350)
for _ in range(350):
    if RNG.random() < 0.5:
        text = make_text(RNG.choice(negative_templates), 'negative')
        rating = RNG.choice([4, 5])
        sentiment = 'negative'
    else:
        text = make_text(RNG.choice(positive_templates), 'positive')
        rating = RNG.choice([1, 2])
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

# 8. Spam, URL, Repeated gibberish (Suspicious) (350)
for _ in range(350):
    text = RNG.choice(spam_templates)
    rating = RNG.randint(1, 5)
    sentiment = 'neutral'
    if any(k in text.lower() for k in ['bad', 'one star', 'hancur']):
        sentiment = 'negative'
    elif any(k in text.lower() for k in ['amazing', 'good', 'nice', 'five stars', 'terbaik']):
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

RNG.shuffle(rows)

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
    max_features=2500,
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
    max_features=2500,
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
    final hasUrl = RegExp(r'(https?://|www\.)').hasMatch(text);
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
      r'(waited|wait|tunggu|等了)\s+(only\s+)?(two|[0-9]+)\s+(hours?|jam|小时)',
    ).hasMatch(lower);

    // Pattern 2: "if you enjoy / love being ignored / waiting / rude"
    final enjoyBadSarcasm = RegExp(
      r'if you (enjoy|like|love) (being ignored|waiting|rude|dirty|bad|getting ignored)',
    ).hasMatch(lower);

    // Pattern 3: "Five stars for the worst meal / service"
    final starWorstSarcasm = RegExp(
      r'(five|5)\s+stars?\s+for\s+(the\s+)?(worst|terrible|bad|horrible)',
    ).hasMatch(lower);

    // Pattern 4: Sarcastic superlatives + negative contradiction
    final superlativeContradiction = RegExp(
      r'(best|great|wonderful|amazing|excellent)\s+.*(worst|terrible|horrible|food poisoning|ignored|rude staff)',
    ).hasMatch(lower);

    // Pattern 5: 10/10 for terrible / awful
    final tenOutOfTenWorst = RegExp(
      r'(10/10|ten out of ten)\s+for\s+(worst|terrible|awful)',
    ).hasMatch(lower);

    // Pattern 6: Malay sarcasm ("terima kasih buat saya tunggu 2 jam")
    final malaySarcasm = RegExp(
      r'(terima kasih|bagus sangat)\s+.*(tunggu|biarkan|sejuk|kotor)',
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


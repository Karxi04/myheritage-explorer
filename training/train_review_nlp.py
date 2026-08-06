from __future__ import annotations
import csv, json, math, random, re
from pathlib import Path
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix, f1_score, precision_score, recall_score, accuracy_score

OUT=Path(__file__).resolve().parent
OUT.mkdir(exist_ok=True)
random.seed(42)

positive_terms=['excellent','amazing','great','love','wonderful','perfect','fantastic','best','enjoyable','friendly','beautiful','helpful','fresh','clean','interesting','comfortable']
negative_terms=['bad','poor','terrible','awful','disappointing','worst','dirty','rude','slow','overpriced','crowded','confusing','unfriendly','stale','noisy']

places=['restaurant','heritage site','museum','street market','cafe','temple','park','gallery','food court','mansion','waterfront','cultural centre']
subjects=['staff','service','food','environment','exhibition','architecture','walking route','information boards','facilities','seating area','entrance process','overall experience']
positive_adj=['excellent','enjoyable','impressive','friendly','clean','well organised','interesting','comfortable','beautiful','helpful','memorable','fresh']
negative_adj=['poor','slow','crowded','dirty','confusing','disappointing','overpriced','noisy','uncomfortable','rude','stale','limited']

rows=[]

def add(text,rating,label,reason):
    rows.append({'text':text,'rating':rating,'label':label,'reason':reason})

# Valid positive/neutral/negative reviews.
for _ in range(260):
    p=random.choice(places); s=random.choice(subjects); a=random.choice(positive_adj); a2=random.choice(positive_adj)
    rating=random.choice([4,4,5,5,5])
    templates=[
        f'The {s} was {a} and the {p} felt {a2}. I would include it in another trip.',
        f'I enjoyed the {p}. The {s} was {a}, and the location was easy to visit.',
        f'A {a} experience with {a2} {s}. The visit matched the information shown in the app.',
        f'The {p} was worth visiting because the {s} was {a}. The overall experience was {a2}.',
    ]
    add(random.choice(templates),rating,0,'valid')
for _ in range(170):
    p=random.choice(places); s=random.choice(subjects); a=random.choice(negative_adj); a2=random.choice(negative_adj)
    rating=random.choice([1,2,2,2,3])
    templates=[
        f'The {s} was {a} and the {p} was {a2}. I would not return during a busy period.',
        f'I did not enjoy the visit because the {s} was {a}. The location also felt {a2}.',
        f'The {p} had potential, but the {s} was {a} and the experience was {a2}.',
        f'The visit was below expectations. The {s} was {a}, although the location was easy to find.',
    ]
    add(random.choice(templates),rating,0,'valid')
for _ in range(120):
    p=random.choice(places); s=random.choice(subjects)
    add(f'The {p} was acceptable overall. The {s} was average, and the visit matched the expected duration.',3,0,'valid')

# Suspicious rating-comment mismatch.
for _ in range(150):
    p=random.choice(places); s=random.choice(subjects); a=random.choice(negative_adj)
    add(f'The {p} was {a}. The {s} was terrible and I would never recommend this place.',random.choice([4,5]),1,'rating_mismatch')
for _ in range(120):
    p=random.choice(places); s=random.choice(subjects); a=random.choice(positive_adj)
    add(f'The {p} was {a}. The {s} was amazing and I loved the entire experience.',random.choice([1,2]),1,'rating_mismatch')

# Suspicious short/generic.
shorts=['Nice','Good','Okay','Bad','Great place','Very good','Not good','Love it','Best','Terrible','Fine','Awesome']
for _ in range(110):
    add(random.choice(shorts),random.randint(1,5),1,'too_short')

# Suspicious repeated patterns.
repeats=['good good good good good','bad bad bad bad bad','nice nice nice nice','great place great place great place','food food food food food','best best best best best']
for _ in range(100):
    add(random.choice(repeats),random.randint(1,5),1,'repeated')

# Promotional / spam.
for _ in range(90):
    code=random.randint(1000,9999)
    text=random.choice([
        f'Visit my website http://cheap-deal{code}.example for discount vouchers and free gifts.',
        f'Contact WhatsApp 01{random.randint(10000000,99999999)} for the best promotion and cheap package.',
        f'Buy now and use promo code SAVE{code}. Click the link for a limited offer.',
        f'Follow my page for guaranteed discounts, free products and special deals.',
    ])
    add(text,random.randint(3,5),1,'spam')

random.shuffle(rows)

csv_path=OUT/'review_training_data.csv'
with csv_path.open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=['text','rating','label','reason'])
    w.writeheader(); w.writerows(rows)

pos=set(positive_terms); neg=set(negative_terms)
def normalize(text):
    return re.sub(r'\s+',' ',re.sub(r'[^a-z0-9\s]',' ',text.lower())).strip()
def repeated(text):
    words=normalize(text).split()
    for i in range(max(0,len(words)-2)):
        if words[i]==words[i+1]==words[i+2]: return True
    freq={}
    for w in words:
        if len(w)>=3: freq[w]=freq.get(w,0)+1
    return any(v>=5 for v in freq.values())
def prepare(text,rating):
    n=normalize(text); words=n.split(); low=text.lower()
    meta=[]
    meta.append('rating_high' if rating>=4 else 'rating_low' if rating<=2 else 'rating_mid')
    if len(text.strip())<12 or len(words)<3: meta.append('very_short')
    elif len(words)<8: meta.append('short_text')
    else: meta.append('normal_length')
    if repeated(text): meta.append('repeated_pattern')
    has_pos=any(t in low for t in positive_terms)
    has_neg=any(t in low for t in negative_terms)
    if has_pos: meta.append('positive_language')
    if has_neg: meta.append('negative_language')
    if (rating>=4 and has_neg) or (rating<=2 and has_pos): meta.append('rating_sentiment_mismatch')
    if 'http://' in low or 'https://' in low or 'www.' in low: meta.append('contains_url')
    if any(t in low for t in ['whatsapp','promo code','buy now','discount','free gift','limited offer','follow my page']): meta.append('promotion_language')
    return ' '.join(meta+[n])

X=[prepare(r['text'],int(r['rating'])) for r in rows]
y=np.array([int(r['label']) for r in rows])

vectorizer=TfidfVectorizer(
    lowercase=False,
    token_pattern=r'(?u)\b[a-z0-9_]{2,}\b',
    ngram_range=(1,2),
    min_df=2,
    max_features=900,
    sublinear_tf=True,
    norm='l2',
)
Xv=vectorizer.fit_transform(X)
X_train,X_test,y_train,y_test=train_test_split(Xv,y,test_size=.25,random_state=42,stratify=y)
model=LogisticRegression(max_iter=2000,class_weight='balanced',random_state=42)
model.fit(X_train,y_train)
probs=model.predict_proba(X_test)[:,1]
threshold=.60
pred=(probs>=threshold).astype(int)
metrics={
    'dataset_rows':len(rows),
    'features':len(vectorizer.vocabulary_),
    'threshold':threshold,
    'accuracy':float(accuracy_score(y_test,pred)),
    'precision':float(precision_score(y_test,pred)),
    'recall':float(recall_score(y_test,pred)),
    'f1':float(f1_score(y_test,pred)),
    'confusion_matrix':confusion_matrix(y_test,pred).tolist(),
    'classification_report':classification_report(y_test,pred,output_dict=True),
}
# Five fold evaluation on fresh model
cv=StratifiedKFold(n_splits=5,shuffle=True,random_state=42)
cv_model=LogisticRegression(max_iter=2000,class_weight='balanced',random_state=42)
metrics['cross_validation_f1']=[float(x) for x in cross_val_score(cv_model,Xv,y,cv=cv,scoring='f1')]
metrics['cross_validation_f1_mean']=float(np.mean(metrics['cross_validation_f1']))

# Train final model on all data.
model.fit(Xv,y)
feature_names=vectorizer.get_feature_names_out().tolist()
coefs=model.coef_[0].tolist(); idfs=vectorizer.idf_.tolist(); intercept=float(model.intercept_[0])

(OUT/'model_metrics.json').write_text(json.dumps(metrics,indent=2),encoding='utf-8')

# Dart literal helpers

def q(s): return json.dumps(s,ensure_ascii=False)
def fmt(x):
    if abs(x)<1e-12: return '0.0'
    return f'{x:.12g}'

model_dart=f"""part of '../traveler_pages.dart';

class ReviewNlpPrediction {{
  const ReviewNlpPrediction({{
    required this.suspiciousProbability,
    required this.isSuspicious,
  }});

  final double suspiciousProbability;
  final bool isSuspicious;
}}

/// Pre-trained TF-IDF + Logistic Regression review classifier.
///
/// Generated by training/train_review_nlp.py. The mobile application performs
/// inference locally, so Firebase Cloud Functions and a paid backend are not
/// required.
class ReviewFlagNlpModel {{
  const ReviewFlagNlpModel._();

  static const String modelVersion = 'tfidf_logreg_v1';
  static const double threshold = {threshold};
  static const double _intercept = {fmt(intercept)};

  static const List<String> _positiveTerms = <String>[
    {', '.join(q(x) for x in positive_terms)},
  ];

  static const List<String> _negativeTerms = <String>[
    {', '.join(q(x) for x in negative_terms)},
  ];

  static const Map<String, double> _idf = <String, double>{{
"""
for name,idf in zip(feature_names,idfs):
    model_dart += f'    {q(name)}: {fmt(idf)},\n'
model_dart += "  };\n\n  static const Map<String, double> _weights = <String, double>{\n"
for name,coef in zip(feature_names,coefs):
    if abs(coef) > 1e-10:
        model_dart += f'    {q(name)}: {fmt(coef)},\n'
model_dart += r"""  };

  static ReviewNlpPrediction predict({
    required String reviewText,
    required int rating,
  }) {
    final document = _prepareDocument(reviewText, rating);
    final tokens = document
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    final counts = <String, int>{};
    for (final token in tokens) {
      if (_idf.containsKey(token)) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    for (var index = 0; index < tokens.length - 1; index++) {
      final bigram = '${tokens[index]} ${tokens[index + 1]}';
      if (_idf.containsKey(bigram)) {
        counts[bigram] = (counts[bigram] ?? 0) + 1;
      }
    }

    final values = <String, double>{};
    var squaredNorm = 0.0;
    for (final entry in counts.entries) {
      final tf = 1.0 + log(entry.value.toDouble());
      final value = tf * (_idf[entry.key] ?? 1.0);
      values[entry.key] = value;
      squaredNorm += value * value;
    }

    final norm = squaredNorm <= 0 ? 1.0 : sqrt(squaredNorm);
    var score = _intercept;
    for (final entry in values.entries) {
      score += (entry.value / norm) * (_weights[entry.key] ?? 0.0);
    }

    final probability = 1.0 / (1.0 + exp(-score));
    return ReviewNlpPrediction(
      suspiciousProbability: probability,
      isSuspicious: probability >= threshold,
    );
  }

  static String _prepareDocument(String reviewText, int rating) {
    final normalised = reviewText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = normalised
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final lower = reviewText.toLowerCase();
    final meta = <String>[
      rating >= 4 ? 'rating_high' : rating <= 2 ? 'rating_low' : 'rating_mid',
    ];

    if (reviewText.trim().length < 12 || words.length < 3) {
      meta.add('very_short');
    } else if (words.length < 8) {
      meta.add('short_text');
    } else {
      meta.add('normal_length');
    }

    if (_hasRepeatedPattern(words)) meta.add('repeated_pattern');

    final hasPositive = _positiveTerms.any(lower.contains);
    final hasNegative = _negativeTerms.any(lower.contains);
    if (hasPositive) meta.add('positive_language');
    if (hasNegative) meta.add('negative_language');
    if ((rating >= 4 && hasNegative) || (rating <= 2 && hasPositive)) {
      meta.add('rating_sentiment_mismatch');
    }

    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.')) {
      meta.add('contains_url');
    }
    if (<String>[
      'whatsapp',
      'promo code',
      'buy now',
      'discount',
      'free gift',
      'limited offer',
      'follow my page',
    ].any(lower.contains)) {
      meta.add('promotion_language');
    }

    return <String>[...meta, normalised].join(' ').trim();
  }

  static bool _hasRepeatedPattern(List<String> words) {
    for (var index = 0; index <= words.length - 3; index++) {
      if (words[index] == words[index + 1] &&
          words[index] == words[index + 2]) {
        return true;
      }
    }
    final counts = <String, int>{};
    for (final word in words) {
      if (word.length < 3) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    return counts.values.any((count) => count >= 5);
  }
}
"""
model_target = OUT.parent / 'lib' / 'traveler' / 'daily_planner' / 'review_flag_model.dart'
model_target.parent.mkdir(parents=True, exist_ok=True)
model_target.write_text(model_dart, encoding='utf-8')

# training script source self-contained (copy this file itself)
print(json.dumps(metrics,indent=2))
print('training outputs:', OUT)
print('Dart model:', model_target)

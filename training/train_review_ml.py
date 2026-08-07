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
spam_templates = [
    'Buy now limited offer discount discount discount contact me for free vouchers',
    'Follow my page and message me for the best promotion code today',
    'Amazing amazing amazing amazing amazing',
    'Bad bad bad bad bad',
    'asdf qwer zxcv lorem ipsum random review text',
    'Visit my website https://example.com for cheap packages and free gifts',
    'Good', 'Nice', 'Ok', 'Five stars', 'One star',
]


def make_text(template: str, sentiment: str) -> str:
    if sentiment == 'positive':
        a1, a2 = RNG.sample(positive_aspects, 2)
    elif sentiment == 'negative':
        a1, a2 = RNG.sample(negative_aspects, 2)
    else:
        a1, a2 = RNG.choice(neutral_aspects), RNG.choice(neutral_aspects)
    return template.format(place=RNG.choice(places), area=RNG.choice(areas), a1=a1, a2=a2)


def prepare_suspicious_document(text: str, rating: int) -> str:
    norm = re.sub(r'[^a-z0-9\s]', ' ', text.lower())
    norm = re.sub(r'\s+', ' ', norm).strip()
    words = [w for w in norm.split(' ') if w]
    meta = ['rating_high' if rating >= 4 else 'rating_low' if rating <= 2 else 'rating_mid']
    if len(words) < 3:
        meta.append('very_short')
    elif len(words) < 8:
        meta.append('short_text')
    else:
        meta.append('normal_length')
    if len(set(words)) <= max(1, len(words) // 3):
        meta.append('low_lexical_variety')
    if any(words[i] == words[i+1] == words[i+2] for i in range(max(0, len(words)-2))):
        meta.append('repeated_pattern')
    if 'http' in text.lower() or 'www.' in text.lower():
        meta.append('contains_url')
    digit_count = sum(ch.isdigit() for ch in text)
    if digit_count > max(4, len(text) * 0.20):
        meta.append('many_digits')
    return ' '.join(meta + [norm]).strip()


rows: list[dict[str, object]] = []

# Normal aligned reviews.
for _ in range(850):
    sentiment = RNG.choices(['positive', 'neutral', 'negative'], weights=[0.48, 0.20, 0.32])[0]
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

# More diverse aligned paraphrases.
for _ in range(450):
    sentiment = RNG.choice(['positive', 'negative', 'neutral'])
    if sentiment == 'positive':
        aspect = RNG.choice(positive_aspects)
        text = f'I visited a {RNG.choice(places)} near {RNG.choice(areas)}. {aspect.capitalize()} made the experience pleasant for our group.'
        rating = RNG.choice([4, 5])
    elif sentiment == 'negative':
        aspect = RNG.choice(negative_aspects)
        text = f'Our group visited this {RNG.choice(places)}, but {aspect} affected the whole experience and we left unhappy.'
        rating = RNG.choice([1, 2])
    else:
        aspect = RNG.choice(neutral_aspects)
        text = f'The visit included {aspect}. It was neither especially good nor especially poor.'
        rating = 3
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 0})

# Rating/sentiment mismatches: grammatically valid but suspicious.
for _ in range(420):
    if RNG.random() < 0.5:
        text = make_text(RNG.choice(negative_templates), 'negative')
        rating = RNG.choice([4, 5])
        sentiment = 'negative'
    else:
        text = make_text(RNG.choice(positive_templates), 'positive')
        rating = RNG.choice([1, 2])
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

# Spam, repetition, low-content, promotion and gibberish.
for _ in range(360):
    text = RNG.choice(spam_templates)
    rating = RNG.randint(1, 5)
    sentiment = 'neutral'
    if any(k in text.lower() for k in ['bad', 'one star']):
        sentiment = 'negative'
    elif any(k in text.lower() for k in ['amazing', 'good', 'nice', 'five stars']):
        sentiment = 'positive'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

# Copied/generic reviews with many repeated patterns.
for _ in range(220):
    place = RNG.choice(places)
    text = RNG.choice([
        f'This {place} is the best best best best best place ever',
        f'The {place} was okay okay okay okay okay',
        f'Excellent service excellent service excellent service at this {place}',
        f'Worst experience worst experience worst experience at this {place}',
    ])
    rating = RNG.randint(1, 5)
    sentiment = 'positive' if 'best' in text.lower() or 'excellent' in text.lower() else 'negative' if 'worst' in text.lower() else 'neutral'
    rows.append({'text': text, 'rating': rating, 'sentiment': sentiment, 'suspicious': 1})

RNG.shuffle(rows)

with DATA_CSV.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=['text', 'rating', 'sentiment', 'suspicious'])
    writer.writeheader()
    writer.writerows(rows)

texts = [str(row['text']) for row in rows]
sentiment_y = [str(row['sentiment']) for row in rows]
suspicious_docs = [prepare_suspicious_document(str(row['text']), int(row['rating'])) for row in rows]
suspicious_y = [int(row['suspicious']) for row in rows]

indices = np.arange(len(rows))
train_idx, test_idx = train_test_split(indices, test_size=0.23, random_state=3404, stratify=suspicious_y)

sent_vectorizer = TfidfVectorizer(
    lowercase=True,
    ngram_range=(1, 2),
    min_df=2,
    max_features=1100,
    sublinear_tf=True,
    norm='l2',
)
X_sent_train = sent_vectorizer.fit_transform([texts[i] for i in train_idx])
X_sent_test = sent_vectorizer.transform([texts[i] for i in test_idx])
sent_model = LogisticRegression(max_iter=2500, class_weight='balanced', random_state=3404)
sent_model.fit(X_sent_train, [sentiment_y[i] for i in train_idx])
sent_pred = sent_model.predict(X_sent_test)

susp_vectorizer = TfidfVectorizer(
    lowercase=True,
    ngram_range=(1, 2),
    min_df=2,
    max_features=1300,
    sublinear_tf=True,
    norm='l2',
)
X_susp_train = susp_vectorizer.fit_transform([suspicious_docs[i] for i in train_idx])
X_susp_test = susp_vectorizer.transform([suspicious_docs[i] for i in test_idx])
susp_model = LogisticRegression(max_iter=2500, class_weight='balanced', random_state=3404)
susp_model.fit(X_susp_train, [suspicious_y[i] for i in train_idx])
susp_pred = susp_model.predict(X_susp_test)

metrics = {
    'dataset_size': len(rows),
    'sentiment_classes': list(sent_model.classes_),
    'sentiment_report': classification_report([sentiment_y[i] for i in test_idx], sent_pred, output_dict=True),
    'sentiment_confusion_matrix': confusion_matrix([sentiment_y[i] for i in test_idx], sent_pred, labels=list(sent_model.classes_)).tolist(),
    'suspicious_report': classification_report([suspicious_y[i] for i in test_idx], susp_pred, output_dict=True),
    'suspicious_confusion_matrix': confusion_matrix([suspicious_y[i] for i in test_idx], susp_pred, labels=[0,1]).tolist(),
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
code.append("part of '../traveler_pages.dart';\n")
code.append("class ReviewMlPrediction {\n")
code.append("  const ReviewMlPrediction({required this.sentiment, required this.sentimentConfidence, required this.negativeProbability, required this.neutralProbability, required this.positiveProbability, required this.suspiciousProbability, required this.isSuspicious, required this.ratingMismatch});\n")
code.append("  final String sentiment;\n  final double sentimentConfidence;\n  final double negativeProbability;\n  final double neutralProbability;\n  final double positiveProbability;\n  final double suspiciousProbability;\n  final bool isSuspicious;\n  final bool ratingMismatch;\n}\n\n")
code.append("/// Offline TF-IDF + Logistic Regression inference generated by\n/// training/train_review_ml.py. No fixed positive/negative keyword list is\n/// used to decide rating/comment mismatch; the sentiment model predicts the\n/// review meaning and that probability is compared with the star rating.\n")
code.append("class ReviewMlModel {\n  const ReviewMlModel._();\n")
code.append("  static const String modelVersion = 'tfidf_sentiment_suspicious_v2';\n")
code.append("  static const double suspiciousThreshold = 0.62;\n  static const double mismatchThreshold = 0.56;\n")
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

    return ReviewMlPrediction(
      sentiment: sentiment,
      sentimentConfidence: sentimentConfidence,
      negativeProbability: negativeProbability,
      neutralProbability: probabilities['neutral'] ?? 0,
      positiveProbability: positiveProbability,
      suspiciousProbability: suspiciousProbability,
      isSuspicious:
          suspiciousProbability >= suspiciousThreshold || ratingMismatch,
      ratingMismatch: ratingMismatch,
    );
  }

  static String _normalise(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

    if (words.length < 3) {
      meta.add('very_short');
    } else if (words.length < 8) {
      meta.add('short_text');
    } else {
      meta.add('normal_length');
    }

    if (words.isNotEmpty &&
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
    if (digits > max(4, (input.length * 0.20).round())) {
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

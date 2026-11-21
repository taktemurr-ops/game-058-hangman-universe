import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'word_kit.dart';

/// Hangman: guess the hidden word letter by letter before the lives run out.
class HangPuzzle {
  final List<Entry> words;
  final int lives;
  final bool showCategory;
  const HangPuzzle(this.words, this.lives, this.showCategory);
}

class HangLevel {
  final Dual<HangPuzzle> p;
  final int timeLimit;
  const HangLevel(this.p, this.timeLimit);
}

HangPuzzle makeHang(WordLang lang, SeededRandom r, int difficulty, bool mystery) {
  final n = (1 + difficulty ~/ 4).clamp(1, 3);
  final lives = (8 - difficulty ~/ 3).clamp(5, 8);
  final minLen = 3 + difficulty ~/ 3;
  final pool = [for (final e in lang.bank) if (e.word.replaceAll(' ', '').length >= minLen) e];
  r.shuffle(pool);
  return HangPuzzle(pool.take(n).toList(), lives, !mystery);
}

HangLevel generateHang(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final m = spec.has('mystery');
  final en = makeHang(WordLang.of(false), SeededRandom(r.nextUint32()), spec.difficulty, m);
  final tr = makeHang(WordLang.of(true), SeededRandom(r.nextUint32()), spec.difficulty, m);
  return HangLevel(Dual(en, tr), spec.has('timer') ? 60 + en.words.length * 40 : 0);
}

String? checkHang(HangPuzzle p, WordLang lang) {
  if (p.words.isEmpty) return 'no words';
  if (p.words.map((e) => e.word).toSet().length != p.words.length) return 'duplicate';
  for (final e in p.words) {
    for (final c in e.word.split('')) {
      if (c != ' ' && !lang.alphabet.contains(c)) return 'bad letter $c';
    }
    // A perfect player needs one guess per distinct letter: always winnable.
  }
  if (p.lives < 5) return 'too few lives';
  return null;
}

class HangGame {
  final HangPuzzle p;
  int index = 0;
  final Set<String> guessed = {};
  int lives;
  int misses = 0;
  int moves = 0;
  int solved = 0;
  HangGame(this.p) : lives = p.lives;

  Entry get current => p.words[index];
  bool get won => solved >= p.words.length;
  bool get lost => lives <= 0 && !won;

  bool revealed(String c) => c == ' ' || guessed.contains(c);
  bool get wordDone => current.word.split('').every(revealed);
  String get mask => current.word.split('').map((c) => revealed(c) ? c : '_').join();

  /// Returns true for a hit.
  bool guess(String c) {
    if (won || lost || guessed.contains(c)) return true;
    moves++;
    guessed.add(c);
    final hit = current.word.contains(c);
    if (!hit) {
      lives--;
      misses++;
    }
    if (wordDone) _next();
    return hit;
  }

  void _next() {
    solved++;
    if (solved < p.words.length) {
      index++;
      guessed.clear();
    }
  }

  /// Reveals a hidden letter of the current word.
  String? hint() {
    if (won) return null;
    for (final c in current.word.split('')) {
      if (!revealed(c)) {
        guessed.add(c);
        if (wordDone) _next();
        return c;
      }
    }
    return null;
  }

  void addLives(int n) => lives += n;

  String serialize() => [index, solved, guessed.join(','), lives, misses, moves].join('|');

  factory HangGame.restore(HangPuzzle p, String s) {
    final g = HangGame(p);
    final parts = s.split('|');
    if (parts.length < 6) return g;
    g.index = (int.tryParse(parts[0]) ?? 0).clamp(0, p.words.length - 1);
    g.solved = int.tryParse(parts[1]) ?? 0;
    g.guessed.addAll(splitList(parts[2]));
    g.lives = int.tryParse(parts[3]) ?? p.lives;
    g.misses = int.tryParse(parts[4]) ?? 0;
    g.moves = int.tryParse(parts[5]) ?? 0;
    return g;
  }
}

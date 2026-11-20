import 'package:flutter_test/flutter_test.dart';
import 'package:game_058_hangman_universe/core/level_plan.dart';
import 'package:game_058_hangman_universe/game/hangman_engine.dart';
import 'package:game_058_hangman_universe/game/rules.dart';
import 'package:game_058_hangman_universe/game/word_kit.dart';

void main() {
  final rules = HangmanRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('levels are valid in both languages and harder levels have more words', () {
    for (final n in [1, 33, 500, 8000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      for (final tr in [false, true]) {
        expect(checkHang(l.p.of(tr), WordLang.of(tr)), isNull, reason: 'level $n');
      }
    }
    expect(rules.build(planner.spec(4999)).puzzle.p.en.words.length,
        greaterThanOrEqualTo(rules.build(planner.spec(1)).puzzle.p.en.words.length));
  });

  test('a perfect guesser always wins without losing a life', () {
    for (final n in [1, 77, 2000]) {
      final p = rules.build(planner.spec(n)).puzzle.p.tr;
      final g = HangGame(p);
      var guard = 0;
      while (!g.won && guard++ < 200) {
        final c = g.current.word.split('').firstWhere((c) => !g.revealed(c));
        expect(g.guess(c), isTrue);
      }
      expect(g.won, isTrue);
      expect(g.misses, 0);
    }
  });

  test('misses cost lives, continue adds lives, hint and resume', () {
    final p = rules.build(planner.spec(2)).puzzle.p.en;
    final g = HangGame(p);
    final wrong = WordLang.of(false).alphabet.split('').firstWhere((c) => !p.words.first.word.contains(c));
    expect(g.guess(wrong), isFalse);
    expect(g.lives, p.lives - 1);
    g.addLives(2);
    expect(g.lives, p.lives + 1);
    expect(g.hint(), isNotNull);
    expect(HangGame.restore(p, g.serialize()).serialize(), g.serialize());
  });
}

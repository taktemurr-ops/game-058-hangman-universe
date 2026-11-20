import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'hangman_engine.dart';
import 'word_kit.dart';

class HangmanRules extends GameRules<HangLevel> {
  @override
  String get gameId => 'game-058-hangman-universe';

  @override
  List<String> get optionalMechanics => const ['mystery', 'timer'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('words_guessed', 'Bilinen kelime', 'Words guessed', scale: 100),
        GameStat('flawless_words', 'Hatasız bölüm', 'Flawless levels', scale: 5),
        GameStat('letters_guessed', 'Tahmin edilen harf', 'Letters guessed', scale: 500),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'words_guessed', [10, 25, 50]),
        MissionTemplate('m2', 'flawless_words', [1, 3, 5], coinReward: 80),
      ];

  @override
  HangLevel generate(LevelSpec spec) => generateHang(spec);

  @override
  Validation validate(HangLevel l, LevelSpec spec) {
    final e = checkHang(l.p.en, WordLang.of(false)) ?? checkHang(l.p.tr, WordLang.of(true));
    return e == null ? Validation.ok(l.p.en.words.length) : Validation.fail(e);
  }
}

GameRules createRules() => HangmanRules();

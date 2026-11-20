import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';
import 'hangman_engine.dart';
import 'rules.dart';
import 'word_kit.dart';
import 'word_ui.dart';

class HangmanView extends StatefulWidget {
  final PlayContext ctx;
  const HangmanView({super.key, required this.ctx});

  @override
  State<HangmanView> createState() => _HangmanViewState();
}

class _HangmanViewState extends State<HangmanView> with RoundClock {
  late HangLevel level;
  late HangGame game;
  int _hints = 0;
  int _solved = 0;
  int _words = 0;
  bool _clue = false;
  bool _ended = false;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<HangLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? HangGame.restore(level.p.of(_tr), snap) : HangGame(level.p.of(_tr));
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    startClock(
        initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
        limit: ctx.spec.mode == GameModeId.timeAttack ? 120 : level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() =>
      ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _solved});

  void _guess(String c) {
    if (_ended) return;
    final before = game.solved;
    final hit = game.guess(c);
    ctx.sfx(hit ? Sfx.place : Sfx.error);
    if (game.solved > before) {
      _words++;
      _clue = false;
    }
    setState(() {});
    _persist();
    _after();
  }

  void _after() {
    if (game.won) {
      if (_chain) {
        _solved++;
        ctx.sfx(Sfx.combo);
        final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _solved]));
        setState(() {
          level = HangmanRules().build(next).puzzle;
          game = HangGame(level.p.of(_tr));
        });
        _persist();
        return;
      }
      _end(true);
    } else if (game.lost) {
      _offerContinue();
    }
  }

  Future<void> _offerContinue() async {
    if (ctx.spec.mode == GameModeId.zen) {
      setState(() => game.addLives(3));
      return;
    }
    clockPaused = true;
    final again = await ctx.requestContinue();
    clockPaused = false;
    if (!mounted) return;
    if (again) {
      setState(() => game.addLives(2));
    } else {
      _end(false);
    }
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.misses <= 1 && _hints == 0 ? 3 : (game.misses <= 3 ? 2 : 1);
    if (_chain) stars = _solved >= 4 ? 3 : (_solved >= 2 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _solved * 800 : (won ? (2000 + game.lives * 300 - seconds).clamp(100, 9000) : 0),
      stars: won ? stars : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      gameStats: {
        'words_guessed': _words,
        'flawless_words': won && game.misses == 0 ? 1 : 0,
        'letters_guessed': game.moves,
      },
    ));
  }

  Future<void> _hint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    final before = game.solved;
    setState(() => game.hint());
    if (game.solved > before) _words++;
    _persist();
    _after();
  }

  Future<void> _showClue() async {
    if (_clue || !await ctx.requestBooster()) return;
    setState(() => _clue = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = WordLang.of(_tr);
    final e = game.current;
    final misses = game.guessed.where((c) => !e.word.contains(c)).toSet();
    final hits = game.guessed.where((c) => e.word.contains(c)).toSet();
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.favorite, '${game.lives}'),
          (Icons.format_list_numbered, '${math.min(game.solved + 1, game.p.words.length)}/${game.p.words.length}'),
          if (_chain) (Icons.emoji_events, '$_solved'),
        ]),
        if (game.p.showCategory)
          Text(lang.catName(e.cat), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.primary)),
        if (_clue) Padding(padding: const EdgeInsets.all(6), child: Text(e.clue, textAlign: TextAlign.center)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CustomPaint(
              painter: _GallowsPainter(game.p.lives + (game.lives > game.p.lives ? game.lives - game.p.lives : 0), game.misses, cs.onSurface),
              size: Size.infinite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(alignment: WrapAlignment.center, children: [
            for (final c in game.mask.split(''))
              c == ' '
                  ? const SizedBox(width: 18)
                  : LetterTile(c == '_' ? '' : c,
                      size: 34, color: c == '_' ? cs.surfaceContainerHighest : cs.primaryContainer),
          ]),
        ),
        WordKeyboard(alphabet: lang.alphabet, onKey: _guess, hits: hits, misses: misses),
        BoosterBar(buttons: [
          BoosterButton(Icons.menu_book, tx(ctx, 'Clue', 'İpucu cümlesi'), _clue ? null : _showClue),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}

class _GallowsPainter extends CustomPainter {
  final int lives;
  final int misses;
  final Color color;
  _GallowsPainter(this.lives, this.misses, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset at(double x, double y) => o + Offset(x * s, y * s);
    // gallows
    canvas.drawLine(at(0.15, 0.95), at(0.6, 0.95), p);
    canvas.drawLine(at(0.3, 0.95), at(0.3, 0.08), p);
    canvas.drawLine(at(0.3, 0.08), at(0.65, 0.08), p);
    canvas.drawLine(at(0.65, 0.08), at(0.65, 0.2), p);
    // 6 body parts spread over the available lives
    final parts = lives <= 0 ? 6 : (misses * 6 / lives).ceil().clamp(0, 6);
    final body = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (parts > 0) canvas.drawCircle(at(0.65, 0.28), s * 0.08, body);
    if (parts > 1) canvas.drawLine(at(0.65, 0.36), at(0.65, 0.62), body);
    if (parts > 2) canvas.drawLine(at(0.65, 0.42), at(0.55, 0.52), body);
    if (parts > 3) canvas.drawLine(at(0.65, 0.42), at(0.75, 0.52), body);
    if (parts > 4) canvas.drawLine(at(0.65, 0.62), at(0.57, 0.78), body);
    if (parts > 5) canvas.drawLine(at(0.65, 0.62), at(0.73, 0.78), body);
  }

  @override
  bool shouldRepaint(covariant _GallowsPainter old) => old.misses != misses || old.lives != lives;
}

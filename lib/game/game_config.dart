import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'hangman_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-058-hangman-universe',
  title: const ['Adam Asmaca Evreni', 'Hangman Universe', 'Galgenmännchen', 'Ahorcado Universo', 'Le Pendu Univers'],
  tagline: const ['Harfleri tahmin et, gizli kelimeyi aç!', 'Guess letters and reveal the hidden word!', 'Rate die Buchstaben!', '¡Adivina las letras!', 'Devinez les lettres !'],
  seedColor: const Color(0xFF6A4C93),
  icon: Icons.spellcheck,
  rules: HangmanRules(),
  buildPlay: (ctx) => HangmanView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.keyboard, ['Harf seç: varsa kelimede açılır.', 'Pick a letter; it is revealed if it is in the word.', 'Buchstabe wählen.', 'Elige una letra.', 'Choisissez une lettre.']),
    TutorialStep(Icons.favorite, ['Yanlış harf can götürür.', 'Wrong letters cost lives.', 'Falsche Buchstaben kosten Leben.', 'Las letras erróneas restan vidas.', 'Les erreurs coûtent des vies.']),
    TutorialStep(Icons.menu_book, ['Takılırsan ipucu cümlesini aç.', 'Stuck? Open the clue sentence.', 'Hinweissatz öffnen.', 'Abre la frase pista.', 'Ouvrez la phrase indice.']),
  ],
);

import 'dart:ui';

/// Spielfeld Farben
class FieldColors {
  static const tomato = Color.fromARGB(255, 255, 99, 71);
  static const springgreen = Color.fromARGB(255, 0, 255, 127);
  static const skyblue = Color.fromARGB(255, 135, 206, 235);
  static const darkSkyblue = Color.fromARGB(255, 109, 160, 180);
  static const backgroundblue = Color.fromARGB(240, 169, 216, 255);
  static const fieldbackground = Color.fromARGB(50, 128, 128, 128);
}

/// Tisch Farben
class TableColors {
  static const blue = Color.fromARGB(255, 28, 67, 151);
  static const green = Color.fromARGB(255, 98, 160, 93);
  static const purple = Color.fromARGB(255, 192, 47, 185);
  static const orange = Color.fromARGB(255, 222, 97, 14);
  static const gold = Color.fromARGB(255, 208, 157, 28);
  static const turquoise = Color.fromARGB(255, 32, 218, 209);

  static get(int i) =>
      <Color>[blue, green, purple, orange, gold, turquoise][i % 6];
}

/// Baumphase Farben
class TreeColors {
  static const cornsilk = Color.fromARGB(255, 255, 248, 220);
  static const rebeccapurple = Color.fromARGB(255, 102, 51, 153);
  static const royalblue = Color.fromARGB(255, 65, 105, 225);
  static const yellowgreen = Color.fromARGB(255, 154, 205, 50);
  static const hotpink = Color.fromARGB(255, 255, 105, 180);
}

/// Gruppenphase Übersicht Farben
class GroupPhaseColors {
  static const steelblue = Color.fromARGB(255, 70, 130, 180);
  static const grouppurple = Color.fromARGB(240, 180, 70, 130);
  static const cupred = Color.fromARGB(255, 213, 35, 70);
}

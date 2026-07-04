# AeroGo Python Engine -- Reference Implementation Only

This package (`engine/board.py`, `engine/game.py`, `engine/rules.py`,
`engine/sgf.py`) implements Go rules (legal moves, captures, suicide,
simple ko, pass, undo/redo, SGF I/O) in Python. It is used only by the
standalone Tkinter app at the project root (`app.py`).

**It is not used by the Flutter app and is not shared code.**

## Source of truth

The Flutter app -- AeroGo's primary target per the top-level README -- has
its own, independent Go engine written in Dart:
`lib/game/go_engine.dart` (`GoGame`, `BoardPoint`, `Stone`, `GameSnapshot`,
plus the heuristic AI in `GoAiPlayer`).

**`lib/game/go_engine.dart` is the source of truth for AeroGo's rules.**
This Python package is a frozen reference implementation kept only for the
Tkinter prototype. The two implementations are written in different
languages and do not share code, so a bug fix or rules change made in one
will not automatically apply to the other.

Practical consequences:

- If you find a rules bug (captures, suicide, ko, scoring, etc.), fix it in
  `lib/game/go_engine.dart` first. Only port the fix here if you also need
  to keep `app.py` correct.
- Do not assume behavioral parity between the two engines. They were
  developed independently and have already diverged in small ways (for
  example, exact ko-rule handling and API shape differ between
  `engine/rules.py` and the Dart `GoGame`).
- New rules or AI features should be designed against
  `lib/game/go_engine.dart`. Treat `engine/` as legacy unless you are
  specifically working on the Tkinter reference app.

See the top-level `README.MD` for how `app.py` and the Flutter app relate.

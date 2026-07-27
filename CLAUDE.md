# Working on Pipwise

Pipwise is a Farkle-and-elements dice game for Android, built in Godot 4.7. The
README explains the game; this file is how to work on it.

## Run it

```
godot --headless --script res://tests/run_tests.gd       # the engine suite
godot --headless res://tools/playthrough_probe.tscn      # every level, through its buttons
godot --headless --script res://tools/balance_probe.gd   # the difficulty curve
godot --headless --script res://tools/generate_campaign.gd
```

The first two run in CI. Note which are scenes and which are scripts: anything
that instantiates a level has to be a scene, because the levels reach `GameState`
on ready and the autoloads only exist when a scene is run.

The main scene is `scenes/opening/opening.tscn`. Target is **720x1280 portrait**,
renderer `gl_compatibility`.

## The rules that hold the project together

**The engine layer has no `Node` in it.** Everything under `scripts/` is either a
`Resource` (authored in the editor) or a `RefCounted` (runtime state). Views
subscribe to engine signals and render; they never drive the rules. This is what
lets `tools/balance_probe.gd` play four hundred levels a second without drawing a
frame, and it is the single most valuable property the codebase has. Do not break
it for convenience.

**All randomness goes through `RngService`.** One seeded instance per game. A
fixed seed reproduces a whole run exactly, which is what makes the tests and the
probe meaningful. Never call `randi()` or `Array.shuffle()` in engine code. The
one deliberate exception is `DieView._show_random_face`, which is visual noise
during a roll animation and must *not* consume the seeded stream — it says so.

**Every engine change needs a test.** `tests/suites/` and a hand-rolled harness in
`tests/test_case.gd`, small enough to read in one sitting.

**Every UI change needs the playthrough probe.** The suite calls the engine
directly, so it can never see a board where the rules are fine and every button
happens to be disabled — the player stuck looking at dice they cannot act on.
`tools/playthrough_probe.tscn` presses the real buttons and is the only thing
that catches that.

**Level scenes are generated, never hand-edited.** `tools/generate_campaign.gd`
writes `resources/campaign.tres`, the ten `level_N.tscn` files, and the scene list
inside `game_ui.tscn`. Hand-maintaining ten identical scenes invites exactly one
of them to be wrong.

**Difficulty numbers are measured, not guessed.** `Campaign.TARGETS` came from
`tools/balance_probe.gd`. Rerun it after touching a target, a turn count, a bag,
or anything in the scoring table — all of them move the whole curve. The bot
adapts its own aggression to the target, so converging takes two or three passes.

## Comment style

Comments explain *why*, not *what*. The reader can see what the code does; what
they cannot see is the alternative that was rejected and the reason. Match the
density of what is already there — `scripts/rules/objective.gd` and
`scripts/game/farkle_game.gd` are the standard. A class comment should say what
the class is for and what it deliberately is not.

## Where things are

| Path | Contents |
| --- | --- |
| `scripts/dice/` | Die, DieType, DieFace, the pool, the elements |
| `scripts/rules/` | Scoring, objectives, rulesets, boss modifiers |
| `scripts/game/` | `FarkleGame` (the turn loop) and `GameContext` (the scoreboard) |
| `scripts/campaign/` | The ten-level curve and endless mode |
| `scenes/game_scene/` | The board, the dice views, the HUD |
| `scenes/menus/`, `scenes/windows/` | Menus, options, pause, guide, tutorial |
| `tools/` | Generators, the balance probe, the screenshot harness. Not shipped |
| `addons/maaacks_game_template/` | Upstream template — menus, scene loader, save layer |

## The seams

These exist so that new content is data rather than code. Use them.

- **`Objective`** — what a level asks for. Two questions, asked at different
  moments: `is_met()` after every bank, `is_failed()` when a turn ends.
- **`LevelModifier`** — a boss twist. `filter_scorable()` runs *before* the scorer
  sees the dice, not after; filtering afterwards can hand the player three dice of
  a broken straight that look takeable and score nothing.
- **`BagDefinition`** — what dice the player brings. The seam a shop sells into.
- **`Ruleset`** — everything else about a level. An authored
  `resources/rulesets/level_N.tres` overrides level N with no code change.
- **`ElementRules`** — what the elements do, built per roll from the dice on the
  table. Element effects live here, never in the scorer.

## What is deliberately not built

The MVP is dice only. `docs/DESIGN.md` holds the full specification and a
**Deviations** section recording every place the build knowingly differs from it,
and why. Read that section before changing a scoring rule — several of the
numbers look wrong and are not.

Not built yet, in rough priority order: cards and spells (spec §3), the shop and
currencies (§6), per-die levelling (§1.4), dice evolution and D8+ (§1.2), mega
combos (§2.3), drop tables (§5.3).

Two known constraints worth keeping in mind:

- **Single dice score only on 1 and 5**, not on every face as §1.2's base column
  says. If every face scores, no roll can fail, so no Farkle can happen, so
  pushing is free and the game has no core. This is load-bearing and pinned by
  `test_farkle_scorer.gd`.
- **The rainbow bag is the weakest in the game**, not the strongest, because one
  die per element reaches no trio and repeats nothing. It becomes the build the
  design document imagines only once the mega combos exist.

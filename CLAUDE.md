# Working on Pipwise

Pipwise is a Farkle-and-elements dice game for Android, built in Godot 4.7. The
README explains the game; this file is how to work on it.

## Run it

```
godot --headless --script res://tests/run_tests.gd       # the engine suite
godot --headless res://tools/playthrough_probe.tscn      # every level, through its buttons
godot --headless res://tools/run_probe.tscn              # losing, and getting out of it
godot --headless --script res://tools/balance_probe.gd   # the difficulty curve
godot --headless --script res://tools/generate_campaign.gd
godot --headless --script res://tools/generate_sfx.gd    # the sound effects
```

The first three run in CI. Note which are scenes and which are scripts: anything
that instantiates a level has to be a scene, because the levels reach `GameState`
on ready and the autoloads only exist when a scene is run.

The main scene is `scenes/opening/opening.tscn`. Target is **540x960 portrait**, renderer `gl_compatibility`.

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

**A run is not a level.** `RunState` is thrown away when a run ends; the dice
collection lives in `GameState` and is not. That split is the whole of the
rogue-lite, and one field in the wrong resource loses it — a test in
`test_run_state.gd` walks `RunState`'s properties to make sure no dice ever end
up there.

**Every run starts at level 1.** There is no checkpoint and there must not be
one: an attempt that resumes where it died risked nothing, and the game stops
having a loop. `RunState.create()` takes no starting level on purpose, and a test
asserts that signature — that is exactly the seam resuming crept in through the
first time. The dice are what make attempt two shorter than attempt one.

**Levels lend what the player lacks.** `Campaign.TARGETS` were measured against
exact bags, so `DiceCollection.apply_floor()` raises whatever is equipped to the
level's elements at level start — not just on the loadout screen, because a
loadout is chosen at a boss (`Campaign.offers_a_loadout()`) and carried while the
references escalate behind it. Plain dice are never a requirement; they are the
padding a reference bag is filled out with.

**A loss must always leave a way out.** `LevelManager._on_level_lost()` builds
and connects the loss window *before* it records anything. It was the other way
round once, and a single bad line in the bookkeeping was enough to leave a player
on a dead board with no window. Nothing after the window may be load-bearing for
escaping the level, and `tools/run_probe.tscn` is what pins that.

**Every UI change needs the playthrough probe.** The suite calls the engine
directly, so it can never see a board where the rules are fine and every button
happens to be disabled — the player stuck looking at dice they cannot act on.
`tools/playthrough_probe.tscn` presses the real buttons and is the only thing
that catches that.

**What can be taken and what is worth taking are two questions.**
`FarkleScorer.scorable_dice()` answers the first and drives tappability and
Farkle detection; `best_selection()` answers the second, searches subsets, and
drives only the Take button. Merge them again and a die the player is allowed to
tap goes grey — the exact dead board the playthrough probe exists for.

A subset wins for two unrelated reasons, and both are easy to forget. §2.3's
Chaos Mode and Universal Overload are conditions a *further* die can break. And
an element bonus is a percentage of a die's share of its own `ScorePart`, so
adding a plain 5 to a pair of Ice 5s leaves the base at 500 and takes a third of
each Ice die's bonus with it. The second predates the mega combos: the scorer
carried a comment asserting it could not happen, and handed out the worse take on
every Ice level. Both are pinned in `test_farkle_scorer.gd`.

**Level scenes are generated, never hand-edited.** `tools/generate_campaign.gd`
writes `resources/campaign.tres`, the ten `level_N.tscn` files, and the scene list
inside `game_ui.tscn`. Hand-maintaining ten identical scenes invites exactly one
of them to be wrong.

**Sizes are in design pixels against a 540-wide viewport.** Stretch is
`canvas_items` with aspect `expand`, so 540 scales to the device width and the
height grows to whatever the screen is. On a 1440-wide phone that is 2.67x, which
makes 1 design px about 0.76dp — so a 74px button lands near 56dp, comfortably
over the 48dp Android asks of a tap target. It was 720 wide until a real device
showed the buttons coming out at 32dp. If you shrink a control, do that maths
first.

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
| `scripts/rules/` | Scoring, objectives, rulesets, boss modifiers, mega combos |
| `scripts/cards/` | The cards, the hand and the deck |
| `scripts/game/` | `FarkleGame` (the turn loop) and `GameContext` (the scoreboard) |
| `scripts/campaign/` | The curve, endless, the dice collection and the run |
| `scenes/game_scene/` | The board, the dice views, the HUD |
| `scenes/menus/`, `scenes/windows/` | Menus, options, pause, guide, tutorial |
| `scenes/game_scene/effects/` | Shake, flash, particles and the sounds |
| `tools/` | Generators, the probes, the screenshot harness. Not shipped |
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
  table. Element effects live here, never in the scorer. **Cards reach the scorer
  through this and nowhere else** — a card that changes what an element pays is
  folded in beside the element, so `FarkleScorer` never learns cards exist.
- **`Card`** — one thing energy can buy. A `Resource` with virtual hooks that all
  do nothing by default, exactly like `LevelModifier`, so a new card is a new
  subclass and never a new branch in the turn loop. `CardLibrary` is the
  catalogue; the hand is ids in `RunState`, the way the loadout already is.

## What is deliberately not built

The MVP is dice only. `docs/DESIGN.md` holds the full specification and a
**Deviations** section recording every place the build knowingly differs from it,
and why. Read that section before changing a scoring rule — several of the
numbers look wrong and are not.

Not built yet, in rough priority order: the rest of the cards (§3.4-3.6 —
artifacts, spells and relics), the shop and currencies (§6), per-die levelling
(§1.4), dice evolution and D8+ (§1.2), drop tables (§5.3).

**Before adding a card, read deviation 8 of `docs/DESIGN.md`.** Seven of §3's
cards do nothing in this build — they are written against rerolls that cost
something, a currency, and a death that takes items, none of which exist here.
Two more duplicate a rule the dice already have. Transcribing the list is how you
ship dead cards.

Two known constraints worth keeping in mind:

- **Single dice score only on 1 and 5**, not on every face as §1.2's base column
  says. If every face scores, no roll can fail, so no Farkle can happen, so
  pushing is free and the game has no core. This is load-bearing and pinned by
  `test_farkle_scorer.gd`.
- **The rainbow bag is feast-or-famine, not strong.** One die per element reaches
  no trio and repeats nothing, so Elemental Master is the only rule that pays it
  — and that needs all six dice to score at once, which is about one roll in
  twenty. The campaign deals every element somewhere so the build is *available*,
  but never deals the bag itself, because a measured target cannot sit on a bag
  that pays nothing four turns in five.

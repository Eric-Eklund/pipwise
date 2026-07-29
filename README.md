# Pipwise: Dice & Elements

A Farkle-inspired dice game for Android, built in Godot 4.7.

## The game

Every die has two dimensions — the value it rolls, and the element it carries.
The first decides what scores. The second decides how much.

### A turn

Roll six dice. Set aside whatever scores. Then choose.

```
ROLL  ──▶ nothing scores?  ──▶ FARKLE: the turn's points are gone
      └─▶ something does   ──▶ set dice aside
                               ├─▶ all six set aside → HOT DICE: all six back, points kept
                               ├─▶ [Roll again] roll what is left, points still at risk
                               └─▶ [Bank]       points become safe, next turn
```

Every die you set aside is one fewer to roll with, and fewer dice means a worse
chance the next roll scores anything at all. That is the whole tension: banking
2000 is worth more than losing 5000, and you never quite know which one you are
about to do.

### What scores

| | |
| --- | --- |
| A single 1 | 100 |
| A single 5 | 50 |
| Three 1s | 1000 |
| Three of anything else | face value × 100 |
| Each die past the third | doubles the set |
| A straight, 1 to 6 | 1500 |
| Three pairs | 1500 |

A lone 2, 3, 4 or 6 is worth nothing. That is what makes a Farkle possible, and a
Farkle is the only thing standing between the player and infinite points.

### Elements

Six of them. Each does something on its own, and something stronger once three
are on the table.

| | | Three or more |
| --- | --- | --- |
| 🔥 Fire | Scored 6s pay +50% | Triples of 6 pay +200 more |
| ❄️ Ice | Dice in a matched set pay +100% | **Pairs score as triples** |
| ⚡ Lightning | Scored 4s, 5s and 6s pay double | They pay triple instead |
| 🌿 Nature | An even pip total returns a die to the table, rolled again | Two come back |
| ☠️ Shadow | Halves the Farkle penalty | A Farkle *pays* you |
| 💎 Crystal | Scored 1s pay triple | 1s pay quadruple, and a straight pays +1000 |

On top of that, scoring several dice of the same element together multiplies the
whole selection — ×1.5 for two, up to ×10 for all six. So the question stops
being "what scores" and becomes "what scores *together*".

Ice is the one that changes the shape of the game rather than the size of the
number. Three Ice dice make bare pairs score, which means fewer Farkles and more
points at once — it is the difference between a cautious turn and a long one.

### Mega combos

Three combos read the *shape* of what you take rather than how much of it.

| | | |
| --- | --- | --- |
| 🌟 Elemental Master | All six elements, scored together | ×5, replacing the ladder |
| ☄️ Universal Overload | All six, and every one of them a 6 | ×5 and a flat +5000 |
| 🔮 Chaos Mode | Every element you take, taken at least twice | Element bonuses double |

The last one is why the turn has a decision in it. "Take everything that scores"
used to be correct almost always, so the choice was never really a choice. Chaos
breaks on a single stray die: take two Crystal, three Fire and one lone Lightning
and it is worth 4500 — leave the Lightning on the table and the same roll pays
6500. And the die you *don't* take is one more die to roll with next.

There is a quieter version of the same trap without any combo at all. An element
bonus is a percentage of what its die contributes to the set it is in, and three
Ice dice make a bare pair pay the same 500 as a triple — so throwing a plain 5 in
with two Ice 5s adds nothing to the total and takes a third of each Ice die's
bonus away with it.

So the Take button offers the best selection rather than every scoring die, and
says **Take best** when those differ. You can still take everything. It is just
no longer free.

### Cards

Every turn your dice are worth energy — the pips they are showing, added up —
and energy buys cards. You hold five, draw two more for every level you clear,
and they go when the run does.

| | | |
| --- | --- | --- |
| 🔒 Lock All | Sets aside every die worth taking, and banks their points into the turn | 2⚡ |
| 🎲 Extra Die | Rolls one more die onto the table for the rest of the turn | 3⚡ |
| ✨ Score Boost | Matched sets pay +50% until you roll again | 4⚡ |
| 🔁 Value Converter | Turns a die that scores nothing into a 1 or a 5 | 4⚡ |
| ↕ Value Shift | Moves one die a single pip, up or down | 5⚡ |
| 🎯 Forced Reroll | Roll again with nothing set aside — but you cannot bank until you do | 5⚡ |
| 🛡 Farkle Shield | The next Farkle costs you nothing | 6⚡ |

The budget is taken once, at the top of the turn, and does not move afterwards —
a wallet that shrank when you rolled badly would be a wallet you could not plan
against.

Value Shift and Value Converter ask for a die. Tap the card and the row turns
into a prompt: the dice that card can use light up, everything else goes dark,
and the three buttons wait. Tapping a die spends the card; **Cancel** costs
nothing, because a targeted card is not paid for until it has its die.
**Hold a card down** to see what it does, how long it lasts, and why it will not
go.

Two of them are worth reading twice. Farkle Shield does not hand the roll back —
a dead board is still a dead board. What it buys is keeping the points you had
already earned, which is the difference between a push you can afford and one you
cannot. Forced Reroll is the opposite trade: it buys the one thing Farkle never
gives away, a roll you did not have to commit anything for, and charges for it by
taking the bank away until you have made it.

None of this is required. The level targets were measured against a player
holding no cards at all, so the hand is upside and never a tax.

### Your dice

You own a collection. It starts as six plain dice, and clearing a level grants
the dice that level showed you — permanently, across every future run. Before a
run, and before each boss, you choose which six to take.

A level lends you whatever you lack, so you can never equip yourself into a
level you cannot clear. What owning dice buys you is not raw power but
combinations: three of an element is where its trio switches on, and that is the
number the loadout screen puts under your thumb.

### Runs

A run is an attempt at the campaign, and it always starts at level 1. Lose a
level and the run is over — but the dice stay yours. That is the whole loop: die,
keep the dice, get further.

Starting over is not the punishment it sounds like, because you do not start over
*equal*. The levels you cleared last time paid you their dice, and the early
campaign goes fast when you can walk into level 4 with three Ice. Resuming from
the last boss was tried first and made a loss a non-event — if the attempt picks
up where it died, nothing was ever risked.

### Levels

Ten of them, teaching one thing at a time. Levels 1 and 2 are plain dice, so you
learn what a Farkle costs before an element ever softens one. Elements arrive
from level 3; a trio is first possible on level 4. Levels 8 and 9 give you two
trios at once and ask which one this roll is for — and they are also where a
mega combo first fires, because three of one element and three of another is
exactly the shape Chaos Mode wants.

All six elements are dealt somewhere across the ten, so a player who clears level
9 owns at least one of each and the level 10 boss is the first place a rainbow
loadout can be equipped. Shadow rides on level 6 because 6 is where the Farkle
penalty starts, and Nature on 7 beside Ice because both are about squeezing more
takes out of a turn.

| | | |
| --- | --- | --- |
| 5 | **Ember Warden** | Nothing banks below 500. You have to push. |
| 10 | **Fire Lord** | Only Fire dice score. Everything else is dead weight. |

Clearing level 10 runs into **endless mode**, where the target climbs and the
turns shrink until one round outruns you. How long you last is the score.

The targets are measured rather than guessed — see [Balance](#balance) below.

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/` | Game logic. Headless and testable — no scenes, no textures |
| `scripts/cards/` | The cards, the hand and the deck |
| `scenes/game_scene/` | The board, the dice views, the HUD |
| `scenes/menus/`, `scenes/windows/` | Main menu, options, pause, guide, tutorial |
| `resources/` | The campaign, skins and themes |
| `tools/` | Development scripts. Not shipped |
| `tests/` | The engine test suite and its runner |
| `assets/sfx/` | Sound effects, generated by `tools/generate_sfx.gd` |
| `docs/DESIGN.md` | The full design specification, and where the build differs |
| `addons/maaacks_game_template/` | Upstream template — menus, scene loader, save layer |

### Architecture

The rule engine is deliberately headless: `Resource` for anything authored in the
editor, `RefCounted` for runtime state, and **no `Node` in the engine layer**. The
view layer subscribes to engine signals and renders — it never drives the rules.
A whole level can be played to a win or a loss inside a test without rendering a
frame, which is also what lets the balance probe play thousands of them.

The seams that keep it open:

- `FarkleScorer` — stateless and static. Given dice and element rules, it returns
  what a selection is worth. It answers "what *can* be taken" and "what is *worth*
  taking" with two separate functions, because since the mega combos those are
  two different questions and the first one is what greys a die out.
- `ElementRules` — what the elements do, rebuilt per roll from the dice on the
  table. The scorer asks; it never decides.
- `MegaCombo` — the three §2.3 shapes, as pure data and one predicate. Where a
  fourth would go, and the reason a selection can now be worth less for being
  bigger.
- `Card` — one thing energy can buy, with hooks that all do nothing by default.
  A new card is a subclass, never a new branch in the turn loop, and cards reach
  the scorer only through `ElementRules`. Its `Duration` is what makes "one
  round" mean something on a board where a turn is many rolls.
- `Objective` — what a level asks for. Two questions now rather than one, because
  a level is many turns: `is_met()` after a bank, `is_failed()` when turns run out.
- `LevelModifier` — a boss twist, configured into the level rather than consulted
  per roll, which is why the scorer does not know bosses exist.
- `DiceCollection` — what the player owns, and the loan that keeps a measured
  target reachable whatever they equipped.
- `RunState` — one attempt. Discarded on a loss; the collection is not.
- `BagDefinition` — a set of dice. The seam a shop would sell into.
- `Ruleset` — everything else. Dropping `resources/rulesets/level_N.tres` in
  overrides level N and needs no code.

All randomness goes through a single seeded `RngService`, so rolls are
reproducible.

## Running

Open the project in Godot 4.7 and press play. The main scene is
`scenes/opening/opening.tscn`. Target resolution is **540x960 portrait** and the
renderer is `gl_compatibility`.

### Tests

```
godot --headless --script res://tests/run_tests.gd
```

The harness is hand-rolled and lives in `tests/test_case.gd` — small enough to
read in one sitting.

```
godot --headless res://tools/playthrough_probe.tscn
```

Plays every level scene through its own Take, Roll and Bank buttons and fails if
any run deadlocks or never reaches a verdict. The suite above never draws a
frame, so it cannot see a board where the rules are fine and every button happens
to be disabled; this can.

```
godot --headless res://tools/run_probe.tscn
```

Loses every level on purpose — both by running out of turns and by pressing on
through a Farkle — and fails unless the player is left a window, a working button
and their dice. It drives the real `LevelManager`, which the probe above never
reaches, and that gap is how a crash in the loss handler once shipped and left
the board frozen with nothing to press.

All three run on every push via `.github/workflows/tests.yml`.

### Balance

```
godot --headless --script res://tools/balance_probe.gd
```

Plays every level four hundred times with a deliberately mediocre bot — it takes
the best selection and banks on a fixed threshold, never reading the board and
never valuing a die left behind — and reports the clear rate. Nine of the ten
campaign levels currently measure between 50% and 55% for that bot, with level 1
deliberately looser at 62%, which should put a human comfortably above the design
document's 60% target.

This is where `Campaign.TARGETS` came from. Rerun it after changing a target, a
turn count, a bag, or anything in the scoring table; all of them move the whole
curve, and the bot pushes harder when the target is higher, so it takes two or
three passes to converge.

### Tools

```
godot --headless --script res://tools/generate_campaign.gd
```

Regenerates the campaign resource, the ten level scenes and the scene list. The
level scenes are four identical lines with a different number, and
hand-maintaining them invites exactly one to be wrong.

```
godot --headless --script res://tools/generate_sfx.gd
```

Synthesises the six sound effects into `assets/sfx/`. They are sine partials
under an envelope — which is all a UI blip has ever been — written as a tool so
they stay ordinary assets, replaceable one at a time by anything better with no
code change.

```
godot res://tools/screenshot_harness.tscn -- \
    --scene=res://scenes/game_scene/levels/level_8.tscn --seed=11 --take=1 \
    --out=user://shot.png
```

Renders a scene to a PNG, optionally with a seeded roll and dice already taken,
so the board can be checked without a device.

## Android

`export_presets.cfg` is tracked rather than ignored — it is the build config, and
an untracked one means rebuilding it from memory on every machine. Building an APK
additionally needs the Godot export templates and an Android SDK, and
`package/unique_name` is still `com.example.pipwise`.

## Design

[`docs/DESIGN.md`](docs/DESIGN.md) holds the full specification — elements, cards,
progression, economy, the lot — and a **Deviations** section recording every place
this build knowingly differs from it. The MVP is dice only; cards, the shop,
per-die levelling and dice evolution are specified but not built.

## Credits and license

Pipwise is built on [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template)
(MIT). See [ATTRIBUTION.md](ATTRIBUTION.md) for the full list of sourced work and
[LICENSE.txt](LICENSE.txt) for the license.

The in-game credits screen is generated from `ATTRIBUTION.md` at build time — edit
that file, not the credits scene.

Template documentation lives in
[`addons/maaacks_game_template/docs/`](/addons/maaacks_game_template/docs/).

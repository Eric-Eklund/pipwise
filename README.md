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
| 🌿 Nature | An even pip total returns a die to the table | Two come back |
| ☠️ Shadow | Halves the Farkle penalty | A Farkle *pays* you |
| 💎 Crystal | Scored 1s pay triple | 1s pay quadruple, and a straight pays +1000 |

On top of that, scoring several dice of the same element together multiplies the
whole selection — ×1.5 for two, up to ×10 for all six. So the question stops
being "what scores" and becomes "what scores *together*".

Ice is the one that changes the shape of the game rather than the size of the
number. Three Ice dice make bare pairs score, which means fewer Farkles and more
points at once — it is the difference between a cautious turn and a long one.

### Levels

Ten of them, teaching one thing at a time. Levels 1 and 2 are plain dice, so you
learn what a Farkle costs before an element ever softens one. Elements arrive
from level 3; a trio is first possible on level 4. Level 8 gives you two trios at
once and asks which one this roll is for.

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
| `scenes/game_scene/` | The board, the dice views, the HUD |
| `scenes/menus/`, `scenes/windows/` | Main menu, options, pause, guide, tutorial |
| `resources/` | The campaign, skins and themes |
| `tools/` | Development scripts. Not shipped |
| `tests/` | The engine test suite and its runner |
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
  what a selection is worth and whether anything scores at all.
- `ElementRules` — what the elements do, rebuilt per roll from the dice on the
  table. The scorer asks; it never decides.
- `Objective` — what a level asks for. Two questions now rather than one, because
  a level is many turns: `is_met()` after a bank, `is_failed()` when turns run out.
- `LevelModifier` — a boss twist, configured into the level rather than consulted
  per roll, which is why the scorer does not know bosses exist.
- `BagDefinition` — what dice the player owns. The seam a shop would sell into.
- `Ruleset` — everything else. Dropping `resources/rulesets/level_N.tres` in
  overrides level N and needs no code.

All randomness goes through a single seeded `RngService`, so rolls are
reproducible.

## Running

Open the project in Godot 4.7 and press play. The main scene is
`scenes/opening/opening.tscn`. Target resolution is **720x1280 portrait** and the
renderer is `gl_compatibility`.

### Tests

```
godot --headless --script res://tests/run_tests.gd
```

The harness is hand-rolled and lives in `tests/test_case.gd` — small enough to
read in one sitting. It runs on every push via `.github/workflows/tests.yml`.

### Balance

```
godot --headless --script res://tools/balance_probe.gd
```

Plays every level four hundred times with a deliberately mediocre bot — it takes
everything that scores and banks on a fixed threshold, never reading the board —
and reports the clear rate. The ten campaign levels currently measure between 45%
and 67% for that bot, which should put a human comfortably above the design
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

# Pipwise

A card-and-dice game for Android, built in Godot 4.7.

## The game

One level is one hand, and it should take about fifteen seconds.

- **Draw five cards** from a standard 52-card deck and **roll six dice**.
- **The dice are white energy.** Their pips add up to a budget: 6 to 36, 21 on
  an average roll. Swapping a card costs 3. Locking a die so a reroll leaves it
  alone costs 4.
- **Reroll up to three times.** Free, but everything you did not lock changes,
  and a worse roll takes energy back that you have not spent yet. That is the
  whole risk.
- **Save the hand** and it scores:

  ```
  (sum of card values + sum of dice pips) x poker hand multiplier
  ```

  Aces are 14, face cards 11-13. A pair doubles, a straight is x5, a straight
  flush is x10. The dice count twice on purpose — the pips you spend as energy
  still ride into the score, so swapping a card costs tempo rather than points.

Clear the target and the level is won. Miss it and it is lost. There is no
second hand.

### Levels

Thirty of them, with a boss every fifth:

| | | |
| --- | --- | --- |
| 5 | **Frost King** | One die is frozen — it cannot be locked or rerolled. |
| 10 | **The Gambler** | Lock at least two dice before you may save. |
| 15 | **Mirror Master** | Pairs score as nothing. Straights and flushes pay 50% more. |
| 20 | **Short Deck** | Four cards only, so no straight and no flush. |
| 25 | **Wild Card** | Suits and runs count for nothing. Match ranks instead. |

Difficulty does not come from an ever-rising target. The player's scoring power
is fixed — there are no upgrades yet — so the spread of what a hand is worth on
level 30 is the same as on level 1, and past about 155 points a target stops
being hard and becomes impossible. Instead the campaign takes things away:
rerolls at 13 and 23, a die at 27, and from 21 a number is no longer enough —
the hand has to *be* something.

Clearing level 30 runs into **endless mode**, where the target keeps climbing
until it outruns you. How long you last is the score.

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/` | Game logic. Headless and testable — no scenes, no textures. |
| `scenes/game_scene/` | The game shell, levels, and the card/dice view layer. |
| `scenes/menus/`, `scenes/windows/` | Main menu, options, pause, result windows. |
| `resources/` | The campaign, the boss rulesets, skins and themes. |
| `tools/` | Development scripts. Not shipped — see below. |
| `tests/` | The engine test suite and its runner. |
| `addons/maaacks_game_template/` | Upstream template — menus, scene loader, save layer. |

### Architecture

The rule engine is deliberately headless: `Resource` for anything authored in
the editor, `RefCounted` for runtime state, and **no `Node` in the engine
layer**. The view layer subscribes to engine signals and renders — it never
drives the rules. A whole level can be played to a win or a loss inside a test
without rendering a frame.

The seams that keep it open:

- `HandEvaluator` / `Objective` — scoring and win conditions are swappable
  resources, so a level changes the rules without changing code.
- `LevelModifier` — a boss twist. Modifiers configure the `GameContext` once at
  level start rather than being asked per hand, which is why the evaluator does
  not know bosses exist.
- `Campaign` — computes an ordinary level from a curve and hands over an
  authored `.tres` when one exists. Dropping `resources/rulesets/level_N.tres`
  in overrides level N and needs no code.
- `DeckDefinition` / `BagDefinition` — what the player owns. The seam a shop
  would sell into.

All randomness goes through a single seeded `RngService`, so shuffles and rolls
are reproducible. The deck is built before the dice, on purpose and pinned by a
test: swapping those two lines would change every seeded outcome in the game.

## Running

Open the project in Godot 4.7 and press play. The main scene is
`scenes/opening/opening.tscn`. Target resolution is **720x1280 portrait** and
the renderer is `gl_compatibility`.

### Tests

```
godot --headless --script res://tests/run_tests.gd
```

The harness is hand-rolled and lives in `tests/test_case.gd` — small enough to
read in one sitting. It runs on every push via `.github/workflows/tests.yml`.

### Tools

```
godot --headless --script res://tools/balance_probe.gd
```

Plays every level hundreds of times with a deliberately weak bot and reports
the clear rate. The level targets were set from what it measured, not guessed,
so rerun it after changing a multiplier, a cost, or the number of dice — all
three move the whole curve.

```
godot --headless --script res://tools/generate_campaign.gd
godot --headless --script res://tools/generate_boss_rulesets.gd
```

Regenerate the level scenes, the campaign resource and the boss rulesets. The
thirty level scenes are four identical lines with a different number, and
hand-maintaining them invites exactly one to be wrong.

```
godot res://tools/screenshot_harness.tscn -- \
    --scene=res://scenes/game_scene/levels/level_5.tscn --out=user://shot.png
```

Renders a scene to a PNG, optionally with cards marked and dice locked, so the
UI can be checked without a device.

## Android

`export_presets.cfg` is tracked rather than ignored — it is the build config,
and an untracked one means rebuilding it from memory on every machine. Building
an APK additionally needs the Godot export templates and an Android SDK, and
`package/unique_name` is still `com.example.pipwise`.

## Credits and license

Pipwise is built on [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template)
(MIT). See [ATTRIBUTION.md](ATTRIBUTION.md) for the full list of sourced work
and [LICENSE.txt](LICENSE.txt) for the license.

The in-game credits screen is generated from `ATTRIBUTION.md` at build time —
edit that file, not the credits scene.

Template documentation lives in
[`addons/maaacks_game_template/docs/`](/addons/maaacks_game_template/docs/).

# Pipwise

A card-and-dice game for Android, built in Godot 4.7.

## The game

You draw cards from a deck and dice from a bag, then play combinations to reach
a score target before your plays run out.

- **Cards score.** You draw a hand of 5 from a standard 52-card deck, play a
  combination against the level's target, and the cards you used are replaced
  with fresh draws.
- **Dice are currency, not points.** You draw 2 dice from a bag of 6. Each die
  face is an *action* — redraw cards, lock a card, draw an extra, boost a
  multiplier. Spending a die spends the action.
- **Levels are challenges.** Each level is a `Ruleset` resource: which deck,
  which bag, how big a hand, how many plays, and what score to beat.

The deck and bag are fixed for now. The data model is built so deck- and
bag-building can be added later without touching the engine.

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/` | Game logic. Headless and testable — no scenes, no textures. |
| `scenes/game_scene/` | The game shell, levels, and the card/dice view layer. |
| `scenes/menus/`, `scenes/windows/` | Main menu, options, pause, result windows. |
| `resources/` | Themes, decks, bags, and per-level rulesets. |
| `addons/maaacks_game_template/` | Upstream template — menus, scene loader, save layer. |

### Architecture

The rule engine is deliberately headless: `Resource` for anything authored in
the editor, `RefCounted` for runtime state, and **no `Node` in the engine
layer**. The view layer subscribes to engine signals and renders — it never
drives the rules.

Two seams keep the design open:

- `DieAction` — a die face is an action. New effects are a new subclass plus a
  `.tres`; the engine only knows the base class.
- `HandEvaluator` / `Objective` — scoring and win conditions are swappable
  resources, so a level can change the rules without changing code.

All randomness goes through a single seeded `RngService`, which makes shuffles
and rolls reproducible in tests.

## Running

Open the project in Godot 4.7 and press play. The main scene is
`scenes/opening/opening.tscn`.

Target resolution is **720x1280 portrait**. The renderer is `gl_compatibility`
for mobile compatibility.

## Credits and license

Pipwise is built on [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template)
(MIT). See [ATTRIBUTION.md](ATTRIBUTION.md) for the full list of sourced work
and [LICENSE.txt](LICENSE.txt) for the license.

The in-game credits screen is generated from `ATTRIBUTION.md` at build time —
edit that file, not the credits scene.

Template documentation lives in
[`addons/maaacks_game_template/docs/`](/addons/maaacks_game_template/docs/).

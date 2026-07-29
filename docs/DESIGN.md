# Pipwise: Dice & Elements — design specification

A Farkle-inspired dice game with a fantasy theme. Every die carries two
dimensions — a value and an element — and the player builds rogue-lite
strategies on top of them through card support and progression.

- **Platform:** Android (Godot)
- **Genre:** Farkle core + rogue-lite + fantasy
- **Core cycle:** roll → score → element combos → cast spells → push your luck
- **Session length:** 2-5 minutes per run, endless levels

> Transcribed from the authored design document. Tables have been reflowed for
> readability; no numbers were changed. Where the build deviates from this
> document, the deviation is recorded in [Deviations](#deviations-and-open-questions)
> at the bottom rather than silently applied here.

---

## 1. Dice

### 1.1 Two dimensions per die

Every die has three attributes:

| Attribute | Description | Values |
| --- | --- | --- |
| Value | The faces | 1-6, expandable |
| Element | Six of them | 🔥 Fire, ❄️ Ice, ⚡ Lightning, 🌿 Nature, ☠️ Shadow, 💎 Crystal |
| Level | The die's strength | Lv1 … Lv10+ |

### 1.2 Values and base points

| Value | Base | Triple | Quad | Pent | Sext |
| --- | --- | --- | --- | --- | --- |
| 1 | 100p | 1000p | 2000p | 4000p | 8000p |
| 2 | 20p | 200p | 400p | 800p | 1600p |
| 3 | 30p | 300p | 600p | 1200p | 2400p |
| 4 | 40p | 400p | 800p | 1600p | 3200p |
| 5 | 50p | 500p | 1000p | 2000p | 4000p |
| 6 | 60p | 600p | 1200p | 2400p | 4800p |

Expansion at high levels (75+): D8 adds 7 and 8 at 70p/80p, D10 adds 9 and 10 at
90p/100p, D12 adds 11 and 12 at 110p/120p. Evolving a die costs Essence and Gems
and requires selling duplicate dice. The result is a higher ceiling at the cost
of a higher Farkle rate.

### 1.3 Elements

| Element | Base bonus | Per level |
| --- | --- | --- |
| 🔥 Fire | 6s +50% | +5% |
| ❄️ Ice | Pairs +100% | +10% |
| ⚡ Lightning | 4-6 score double | +10% |
| 🌿 Nature | Even total restores one die | +1 die |
| ☠️ Shadow | Farkle penalty halved | -10% |
| 💎 Crystal | All 1s tripled | +100p |

### 1.4 Die levels

Each die levels independently, from Lv1 to Lv10.

| Level | Effect | Example on a Fire die |
| --- | --- | --- |
| 1 | Base | 6 = 60p + 30p bonus |
| 3 | +10% bonus | 6 = 60p + 33p bonus |
| 5 | Unlocks an ability | +1 reroll when you score a 6 |
| 7 | +20% bonus | 6 = 60p + 48p bonus |
| 10 | Ultimate | 6 = 100p, ×2 bonus |

Upgrade costs run from 500 coins + 10 Essence at Lv2 to 5000 coins + 100 Essence
at Lv10.

### 1.5 Starting sets and drops

| Levels | Starting dice | Drops |
| --- | --- | --- |
| 1-10 | 6× Basic (Lv1) | 1 Fire/Ice die (Lv1) per boss |
| 11-30 | 4× Basic + 2× Element | 1 element die (Lv2-3) per 3 levels |
| 31-50 | 2× Basic + 4× Element | 1 element die (Lv4-5) + 1 artifact |
| 51-75 | 6× Element | 1 element die (Lv6-8) + 1 spell |
| 76-100 | Mixed | 1 premium die (Lv9-10) + 1 relic |
| 100+ | Everything unlocked | Any die, any relic |

---

## 2. Element combos

### 2.1 Simple combos

Counting dice of the same element, among the dice that scored:

| Count | Multiplier | Example: Fire 6s |
| --- | --- | --- |
| 2 | ×1.5 | (60 + 30) × 1.5 = 135p |
| 3 | ×2.5 | (60 + 45) × 2.5 = 262p |
| 4 | ×4 | (60 + 60) × 4 = 480p |
| 5 | ×6 | (60 + 75) × 6 = 810p |
| 6 | ×10 | (60 + 90) × 10 = 1500p |

Formula: `(base points + element bonus) × combo multiplier`

### 2.2 Element trios (3 or more of the same element)

**🔥 Fire trio** — 6s score 100p instead of 60p; triples of 6 gain +200p.
Lv5+: 6s double. Lv10: 6s triple, and +1 reroll.

**❄️ Ice trio** — pairs count as triples when scoring; Farkle chance drops 50%.
Lv5+: pairs gain another +100%. Lv10: triples gain +50%, stacking.

**⚡ Lightning trio** — 4s through 6s score double; 1s become 6s for the round.
Lv5+: 4-6 triple. Lv10: a 6 is guaranteed on the first roll.

**🌿 Nature trio** — rerolls cost no energy, and you get one free reroll per
round. Lv5: an even total restores two dice. Lv10: two free rerolls per round.

**☠️ Shadow trio** — a Farkle pays +50p instead of costing 100p; 1s score 150p.
Lv5: a Farkle pays +100p. Lv10: +200p and an extra reroll.

**💎 Crystal trio** — 1s triple, to 300p; a 1-6 straight pays +1000p.
Lv5: 1s quadruple. Lv10: 1s quintuple and the straight pays +2000p.

### 2.3 Mega combos

**🌟 Elemental Master** (one of each element) — every die is wild for the round
and may act as any element. ×5 on everything, ×7 at Lv10+.

**☄️ Universal Overload** (a 6 in every element) — automatic straight bonus and
+5000p, guaranteeing the round. Lv10+: 8000p and a ×3 combo.

**🔮 Chaos Mode** (3+ different elements, at least 2 of each) — every element
combo fires at once, ×2 on all element bonuses, ×3 at Lv10.

---

## 3. Cards

### 3.1 Card types

| Type | Rarity | Count | Use |
| --- | --- | --- | --- |
| Scrolls | Common | 4-6 | Base spells, one round |
| Potions | Uncommon | 6 (one per element) | Element boosts, one round |
| Artifacts | Rare | 6 (one per element) | Permanent for the run |
| Spells | Epic | 6 (one per element) | Game-changing, one round, expensive |
| Relics | Legendary | 4 | Run-defining, once per run |

### 3.2 Scrolls (common)

| Card | Effect | Energy | Max per round |
| --- | --- | --- | --- |
| Extra Die | +1 die this round | 3 | 2 |
| Reroll Token | +1 free reroll | 2 | 3 |
| Coin Boost | +50% coins from the run | 4 | 1 |
| Shield | Farkle immunity this round | 5 | 1 |
| Draw 2 | Draw 2 extra cards | 3 | 2 |
| Discard Swap | Swap 3 cards free | 4 | 1 |

### 3.3 Potions (uncommon, element-specific)

| Card | Effect | Energy |
| --- | --- | --- |
| Fire Brew | 🔥 Fire dice ×2 this round | 5 |
| Frost Shield | ❄️ Ice dice +100% pair bonus | 6 |
| Storm Call | ⚡ Lightning dice guaranteed 4-6 | 7 |
| Earth Restore | 🌿 Nature dice restore 2 dice | 5 |
| Shadow Veil | ☠️ Shadow dice +100% Farkle points | 6 |
| Crystal Focus | 💎 Crystal dice triple all 1s | 8 |

### 3.4 Artifacts (rare, permanent for the run)

| Card | Effect | Energy |
| --- | --- | --- |
| Fire Crown | 🔥 Fire triples +200p | 8 |
| Ice Scepter | ❄️ Ice pairs count as triples | 10 |
| Thunder Orb | ⚡ Lightning 6s always double | 12 |
| Forest Charm | 🌿 Nature rerolls always free | 10 |
| Void Mask | ☠️ Shadow dice ignore Farkle | 15 |
| Diamond Ring | 💎 Crystal 1s always 300p | 20 |

### 3.5 Spells (epic)

| Card | Effect | Energy |
| --- | --- | --- |
| Meteor Storm | Every die becomes a 6 | 15 |
| Frozen World | Every die becomes Ice | 18 |
| Lightning Field | Every die becomes 4-6 | 20 |
| Nature's Blessing | Reroll everything, keep the score so far | 25 |
| Shadow Realm | Farkle is positive this round | 22 |
| Crystal Shatter | 1s triple, +1000p | 30 |

### 3.6 Relics (legendary, once per run)

| Card | Effect | Energy |
| --- | --- | --- |
| Dragon Heart | Every die wild | 40 |
| Phoenix Feather | Death costs half your items, not all | 50 |
| Elemental Crown | Element combos ×2 permanently | 60 |
| Time Diamond | Reroll and keep every die | 75 |

### 3.7 Drawing

Run start draws 5 cards: 60% common, 25% uncommon, 10% rare, 4% epic, 1%
legendary. Between levels, draw 2. A boss win draws 3 with a rarity guarantee.
The shop sells specific cards for coins, gems and souls.

---

## 4. Round flow

```
STAGE START
  Draw 6 dice (value + element + level)
  Draw 5 cards
  Energy = sum of the dice symbols
  Goal: reach the target score
        ↓
STEP 1 — SCORE DICE
  Pick which dice to score
  Unscored dice must be rerolled
  Score every die → EXTRA DIE
        ↓
STEP 2 — CHECK ELEMENT COMBOS
  Count dice per element
  Apply combo multipliers
  Add element-specific bonuses
        ↓
STEP 3 — PLAY CARDS
  Cast spells, potions, artifacts
  Paid for with energy
  Artifacts persist
        ↓
STEP 4 — REROLL THE REST
  Unscored dice are rerolled
  Max 3 rerolls per round
  A roll can fail (Farkle)
        ↓
STEP 5 — PUSH YOUR LUCK
  [Continue] reroll and risk a Farkle
  [Bank it]  secure the score, next round
  Push limits: 80%, 65%, 50% (3 max)
        ↓
STEP 6 — RESULT
  Total vs. goal
  Win: coins, gems, drops
  Loss: souls, possibly items
```

---

## 5. Progression

### 5.1 Level bands

| Levels | Title | Unlocks | Target |
| --- | --- | --- | --- |
| 1-10 | Novice | Fire/Ice dice, scrolls | 500-1000p |
| 11-25 | Apprentice | Lightning/Nature, potions | 1500-2500p |
| 26-50 | Expert | Shadow/Crystal, artifacts | 3000-6000p |
| 51-75 | Master | All elements, spells | 7000-12000p |
| 76-100 | Legend | Relics, D8/D10 dice | 15000-25000p |
| 100+ | Champion | Endless mode, any die | Any |

### 5.2 Bosses

| Boss | Level | Target | Rule change | Reward |
| --- | --- | --- | --- | --- |
| Fire Lord | 25 | 2500p | Only Fire dice score | 🔥 Fire die (Lv3) + Fire Brew |
| Ice Queen | 50 | 5000p | All 1s become 6s | ❄️ Ice die (Lv5) + Frost Shield |
| Storm Caller | 75 | 10000p | Only Lightning dice score | ⚡ Lightning die (Lv7) + Storm Call |
| Elemental King | 100 | 25000p | All elements ×2 | Any relic + any die (Lv10) |

### 5.3 Drop table

| Levels | Common | Uncommon | Rare | Epic | Legendary |
| --- | --- | --- | --- | --- | --- |
| 1-10 | 80% | 15% | 5% | — | — |
| 11-25 | 60% | 25% | 10% | 5% | — |
| 26-50 | 50% | 30% | 15% | 5% | — |
| 51-75 | 40% | 35% | 20% | 5% | — |
| 76-100 | 30% | 35% | 25% | 8% | 2% |
| 100+ | 25% | 30% | 30% | 10% | 5% |

---

## 6. Economy

| Currency | Spent on | Earned from |
| --- | --- | --- |
| Coins | Scrolls, potions, die upgrades | Run score |
| Gems | Artifacts, spells | Boss wins |
| Essence | Die evolution (D6 → D8 → D10) | Selling duplicate dice |
| Souls | Relics, Phoenix Feather | Deaths (1 per death) |

The shop between runs — the Elemental Market — sells element dice at 500 coins,
scrolls at 100 coins, potions at 300 coins, artifacts at 50 gems, spells at 100
gems, relics at 5 souls and an evolution step at 500 coins.

Evolution: Basic (D6) → Enhanced (D8) at 500 coins + 10 Essence + Lv5 →
Master (D10) at 1000 coins + 25 Essence + Lv10 → Grand (D12) at 2500 coins +
50 Essence + Lv15.

---

## 7. Example builds

**Fire Specialist (aggressive)** — 4× Fire (Lv7-10) + 2 basic, with Fire Brew,
Meteor Storm, Fire Crown and Dragon Heart. Push hard. 5000-10000p per round.
Extreme single-round ceiling; hungry for energy and specific cards.

**Elemental Balanced (consistent)** — one die of each element (Lv5-8), with
Elemental Crown, Nature's Blessing and Storm Call. The Elemental Master combo is
always live: ×5, or ×10 with the crown. 2500-5000p per round. Low variance,
lower ceiling.

**Shadow Risk Taker (high risk)** — 6× Shadow (Lv8-10), with Void Mask, Shadow
Veil and Phoenix Feather. Void Mask makes a Farkle *positive*, so push with no
consequence and farm souls. 1000-8000p, wildly variable.

---

## 8. Visual design

| Element | Colour | Particles | Animation |
| --- | --- | --- | --- |
| 🔥 Fire | `#FF4500` | Embers, sparks | Glow pulses on a 6 |
| ❄️ Ice | `#00FFFF` | Snowflakes | Frosted glass |
| ⚡ Lightning | `#FFD700` | Electric arcs | Crackles on 4-6 |
| 🌿 Nature | `#32CD32` | Leaves | Soft sway |
| ☠️ Shadow | `#4B0082` | Dark mist | Swirling void |
| 💎 Crystal | `#C0C0C0` | Shimmer | Sparkles on a 1 |

Combo feedback: a light screen shake, dice glowing in the element colour, gold
text naming the combo ("FIRE TRIO! +500p"), and a particle burst. A *ding* for a
base score, a *whoosh* for a combo, a *boom* for a mega combo. The score number
animates upward and the progress bar fills in the element colour.

---

## 9. Balance parameters

| Parameter | Value |
| --- | --- |
| Starting dice | 6 |
| Starting cards | 5 |
| Max rerolls | 3 per round |
| Energy cost (swap) | 3-8 by card type |
| Push chances | 80% / 65% / 50%, 3 max |
| Farkle penalty | -100p, scaling with level |
| Target score (Lv1) | 500p |
| Legendary drop rate | 2% at Lv100 |

---

## 10. Post-MVP expansions

Daily challenges and achievements first, then co-op and an arena mode, then
custom dice and a season pass. After level 150, D16 and D20 dice with two new
elements (⭐ Cosmic, 🌙 Void), eight-element combos and a ten-straight bonus.
Cosmetic die skins sold for coins and gems or dropped from events.

---

## 11. Success metrics

| Metric | Target |
| --- | --- |
| Round time | 2-5 min |
| Win rate | 60% |
| Daily active | 25% |
| Day-7 retention | 40% |
| Average session | 15 min |
| Boss win rate | 50% |

---

## Deviations and open questions

Places where the build knowingly differs from the specification above, and why.
Each is a decision that can be reversed — none of them are accidents.

### 1. Single dice score only on 1 and 5 — **resolved, deliberate**

§1.2's *Base* column gives every face a score: a lone 2 is 20p, a lone 3 is 30p,
and so on. Taken literally that means **every die always scores**, so a roll can
never fail, so a Farkle can never happen — and with no bust risk, "Continue" is
strictly better than "Bank it" every single time. The push-your-luck core of
§4 step 5 disappears entirely.

The build therefore uses classic Farkle singles:

```
1 = 100p        5 = 50p        2, 3, 4, 6 = nothing on their own
```

Everything else in §1.2 is kept **verbatim**, because the triple/quad/pent/sext
columns already *are* classic Farkle — three 1s at 1000p, three N at N×100, and
each extra die doubling the triple. Only the *Base* column changes.

Note that this makes Fire ("6s +50%") a triples-and-combos element rather than a
singles element, which reads as an improvement: it gives Fire a distinct shape
instead of a flat bonus on every roll.

### 2. Rerolls are limited by the bust, not by a counter — **provisional**

§4 step 4 says "max 3 rerolls per round", and §4 step 5 gives push limits of
80%/65%/50% for at most 3 pushes. In Farkle these are the same decision counted
twice, and a hard cap makes it a non-decision: with a guaranteed-safe first and
second roll, the only real choice is the third.

The MVP lets the player roll as long as they keep setting dice aside, with the
Farkle as the only limiter — the standard Farkle rule — and budgets the *level*
by capping turns instead. Worth revisiting once the loop has been played: if
turns feel too long, the cap comes back.

### 3. Two element rules are reinterpreted, four are transcribed

§1.2's base column and §1.3's element rules were written against each other. Once
single dice stop scoring on every face, two of the six elements no longer have
anything to attach to, so they were re-aimed at the nearest thing that keeps their
identity. The other four are the document's own wording.

| Element | Built as | Against the document |
| --- | --- | --- |
| 🔥 Fire | Scored 6s pay +50% | exact |
| ❄️ Ice | Dice in a matched set pay +100% | **reinterpreted** — "pairs +100%" has nothing to multiply, since a bare pair scores nothing |
| ⚡ Lightning | Scored 4-6 pay double | exact |
| 🌿 Nature | An even pip total returns a die | exact, but see below on *which* sum |
| ☠️ Shadow | Halves the Farkle penalty | exact |
| 💎 Crystal | Scored 1s pay triple | exact |

The trios are the same story. Fire, Ice, Shadow and Crystal use the document's
own lines. Lightning's trio repeated its own base rule word for word, so it
escalates to tripling instead — the Lv5 line. Nature's trio was written about
reroll costs, which this game does not have, so it takes the Lv5 line too.

**Where a trio is counted** is a rule the document does not state: on the dice
**in play**, all of them, set aside or not. §2.1's combo multiplier is counted on
the dice that actually **scored**. The split is deliberate — a trio changes what
is *possible* (Ice makes pairs score at all), so the player has to see it before
choosing, while a combo rewards what they chose and can only be known after.

### 4. Nature reads pips, not points

§1.3 says "jämn summa" — even sum — without saying of what. Read as the point
total it is not a condition at all: every entry in the scoring table is a multiple
of fifty and every combo multiplier keeps it that way, so the total is even almost
always, and Nature would quietly mean "a free die, every single turn".

The build reads the **pips on the scored dice**. That is a real coin flip, it is
the number the player is looking at, and it matches the word *sum* better than a
multiplied, bonused, rounded score does.

### 5. The rainbow bag is feast-or-famine, not strong — **resolved**

This entry used to read "the rainbow bag is the weakest in the game", and it was
true: §7's "Elemental Balanced" build — one die of each element — reaches no trio
and repeats no element, so **no** trio rule fired and §2.1's combo ladder never
left ×1. It was strictly worse than six plain dice plus any three matching ones.

§2.3's Elemental Master now exists and pays it ×5. But that combo needs all six
dice to score in one selection, which means a straight, three pairs or a
six-of-a-kind — roughly **one fresh six-die roll in twenty**. So the bag is not
strong in the way §7 imagines; it is high-variance, worth a great deal on the
rolls that land and nothing at all on the rest.

The campaign still does not deal it, and the test still pins that — but for a
new reason. A level's target is measured against its bag, and a bag that pays
nothing four turns in five is not something a measured target can sit on top of.
It is a build the player may *choose* at a boss, having seen what it does.

### 6. MVP scope

The first playable slice is dice only: the turn loop, six elements, the §2.1
combo ladder and the §2.2 trios at their level-1 tier, roughly ten levels and
endless mode.

Cards arrived after the dice: §3's Scrolls and Potions are built, which is §4's
step 3 and the last thing missing from the shape of a turn. Artifacts, Spells and
Relics are not — see deviation 8 for which of them can be transcribed and which
need rules that do not exist yet.

Not built yet, in rough priority order: the rest of the cards (§3.4-3.6), the
shop and currencies (§6), per-die levelling (§1.4), dice evolution and D8+
(§1.2), and the drop tables (§5.3). The engine seams they will attach to exist —
see `CLAUDE.md` — but none of it is balanced or worth balancing until the core
loop is known to be fun.

The campaign is ten levels rather than a hundred, so the bosses are compressed:
the Ember Warden on 5 and the Fire Lord on 10, rather than the Fire Lord on 25.
The other three bosses in §5.2 are unbuilt.

### 7. The mega combos are reinterpreted, and one of them is why

§2.3 is built, and it is the first thing in the game that makes taking *fewer*
dice correct. That was the point of building it.

Before it, `FarkleScorer` carried a comment claiming that taking every scoring
die was always at least as good as taking less — no entry in the scoring table
pays less for more dice, and §2.1's ladder counts the leading element, which
another die can only raise. So the first decision of a Farkle turn had one right
answer and the turn collapsed to "take all, then push or bank".

Two of the three mega combos are conditions a *further* die can break, which is
what reopens it. Building them also turned up that the comment was **already
false**: an element bonus is a percentage of a die's share of its own scoring
part, and an Ice trio makes a bare pair pay the same flat 500 as a triple — so
adding a plain 5 to two Ice 5s leaves the base alone and dilutes each Ice die's
share of it by a third. The scorer had been handing out the worse take on every
Ice level, with nothing looking for it. `best_selection()` now searches subsets
and both cases are pinned.

Four departures from the text:

| §2.3 says | Built as | Why |
| --- | --- | --- |
| Master makes every die *wild*, able to act as any element | Master is the ×5 and nothing else | There is no wild mechanic in the engine, and adding one would reach into `Die`, `ElementRules` and the scorer at once |
| Chaos needs **3+** distinct elements, 2 of each | **2+** distinct elements, 2 of each | See below |
| Chaos: "all element combos fire at once, ×2 on element bonuses" | ×2 on the element-bonus portion only | "All combos fire at once" has no referent in a build where element effects are per-die percentages rather than togglable combos. Multiplying the base as well would make Chaos strictly dominate §2.1's ladder instead of competing with it |
| Overload grants an automatic straight bonus | Dropped | The six 6s that fire it are already a six-of-a-kind worth 4800; a 1500 straight bonus is unreachable underneath that |

**Chaos at two elements rather than three** is the load-bearing one. With a
six-die pool, "3+ distinct elements with at least 2 of each" can only ever be
satisfied by exactly 2+2+2 — which uses the whole table, so no larger selection
can break it, so it would create no decision at all. It would also fire on no bag
the campaign ships. At two it fires on levels 8 and 9, and one stray die of a
third element is enough to break it. That difference is the whole feature.

**Master replaces §2.1's ladder rather than stacking on it**, as a floor under
the multiplier rather than an override. Six dice of one element already pay ×10
and a rainbow hand should sit below that — a mono bag is harder to assemble. The
floor form also guarantees a mega combo can never make a selection worth *less*
than the same selection without it, which matters because the best-selection
search has no way to decline one.

**Overload's +5000 is paid outside the multiplier.** Inside it, on the only hand
that can fire it, it would be +25000 and the number would stop meaning anything.

### 8. Seven cards do nothing in this build, and are not built

§3 lists 28 cards. Ten are built — the Scrolls and the Potions, §4's missing
step 3 — and the rest wait. But seven of them cannot simply be transcribed later,
because they are written against rules this build does not have. Recorded here so
the next slice does not ship them dead.

| Card | Decision | Why |
| --- | --- | --- |
| Extra Die | **Reworked** | "+1 die this round" is a seventh die, and the pool is fixed at what the bag holds — growing it would reach into the tray, the energy budget and hot dice at once. Built as **Second Wind**: a die you set aside comes back *rolled again*. Restoring it unrolled handed it back on the face that scored, so the card was worth one die's points twice over rather than a gamble. Its id is still `extra_die`, because that is what a saved hand stores |
| Reroll Token, Forest Charm | **Dropped** | Rerolls are unlimited and free here (deviation 2). "+1 free reroll" is +1 of something you already have infinitely |
| Coin Boost | **Dropped** | There is no currency (§6 unbuilt) |
| Ice Scepter | Deferred | "Ice pairs count as triples" *is* the Ice trio, exactly. Needs a different effect before it can be an artifact |
| Crystal Focus | **Reworked** | "Triples all 1s" is already Crystal's base rule. Built as "doubles Crystal's bonus" |
| Shadow Veil | **Reworked** | "+100% Farkle points" doubles zero — a Farkle costs points here, it does not pay them, unless three Shadow dice are out. Built as "a Farkle pays you this turn", which is the trio's effect bought for one turn |
| Phoenix Feather | Deferred | "Death costs half your items" — death costs no items. The dice collection is permanent |
| Dragon Heart | Deferred | Needs the wild mechanic deliberately not built for Elemental Master (deviation 7) |

The trap worth naming: a uniform potion — "double your element's bonus" — reads
like it would cover all six neatly, and it is dead for two of them. **Nature and
Shadow pay no points at all**; Nature returns dice and Shadow softens a bust.
Four potions are the uniform kind and two are their own effects, which is why
`ElementBoostCard` covers Fire, Ice, Lightning and Crystal and no more.

**A potion is refused on a board without its element.** This reverses an earlier
decision, recorded here because the earlier one was deliberate and argued: a
potion for an element you did not bring is a bad draw, and Discard Swap is the
answer to a hand of them. That is still true. What it missed is §5's schedule.
The campaign deals **no elements at all until level 3**, and each element arrives
once — Lightning on 6, Nature on 7 — so at most two of the six potions can pay on
any level, and none can on the two levels where a new player first meets the
hand. Every one of them was drawn bright, buyable, and worth nothing, and the
first thing a player did with the card row was spend a quarter of a turn's energy
on a card that did not move a single number. `can_play()` now answers false when
the element is not in play, which costs the player nothing: the card sits in hand
until the level it was drawn for.

`ShadowVeilCard` is deliberately **not** guarded this way. It carries
`Element.SHADOW` for its name and its colour and nothing else — it grants the
trio's effect outright rather than multiplying a die's share, so it pays on a
board with no Shadow die anywhere.

Holding a card down opens `CardDetailWindow`, which is where the refusal is
explained. That window is the only place the game says *why* a card will not go,
so it answers for a greyed out card as readily as a bright one — which is why
`CardView` times its hold off `_gui_input` rather than `button_down`: a disabled
Button emits no button signals at all.

**A card's "one round" is one turn**, not one level. §4's stage flow reads as a
level, but its steps are a single push-your-luck sequence, which is a turn here.

**Energy is a per-turn budget, taken once.** §4 sets it at "stage start". Read
live it moves under the player mid-turn — spend nine, push into a worse roll, and
the budget that paid for it drops below what was already spent. A number you
cannot plan against is not a currency.

**Card targets are measured card-free.** `tools/balance_probe.gd`'s bot is dealt
no hand at all, so the campaign's clear rates describe a player who never plays
one. That is deliberate and worth keeping: it means no level can ever *require* a
card, and everything the hand does is upside.

### 9. Die levels are fixed at 1

§1.3's per-level element scaling and §1.4's per-die upgrades are not in the MVP,
so every element effect fires at its level-1 tier. `Die.level` exists and is
carried through scoring, so the scaling is a change to the element rules rather
than to the data model.

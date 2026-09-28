# 迟归 / Late Return

A 2D side-view pixel-art post-apocalyptic survival demo made with **Godot 4.3** (GDScript, GL Compatibility renderer).

> 从“醒来”到“回来”。 A brother wakes up in an abandoned convenience store, scavenges water and food, sneaks through a street that no longer belongs to people, and makes it back to the classroom where his sister is waiting.

## Running

Open the folder with Godot 4.3+ and press Play, or run:

```bash
godot --path .
```

The main scene is `scenes/ui/main_menu.tscn`. The game renders at 480×270 and scales to the window by integer steps.

## Controls

| Key | Action |
|---|---|
| A / D | Move |
| Space | Jump · in a hide spot: knock to lure zombies · in a long story scene: hold to skip |
| Shift | Run (loud) |
| Caps Lock | Toggle quiet walk (静步) |
| F | Interact / search / pick up / hide / leave (every searchable can always be checked) |
| Tab | Backpack |
| H | Flashlight |
| 1 / 2 / 3 | Select hand slot 1 / 2 / 3 (pressing the selected one again = empty hands) |
| G | (camp, next to the sister, after an outing) End the day |
| Mouse | Aim |
| Left mouse | Use the held item: shoot, swing, throw · in a hide spot with a zombie in reach: knife takedown |
| Right mouse (hold) | Hold breath |
| Esc | Pause |
| F3 | Debug overlay (debug builds only: FPS, player state, presence, noise, zombie states, vision cones, last seen/heard positions) |

All bindings live in the project InputMap.

## Demo flow

Main menu → abandoned convenience store (wake-up, flashlight, loot water ×4 / food ×4 with guaranteed loot, cash register, exit lock) → **Street Checkpoint** → abandoned street (patrolling zombies, vision/hearing/presence, grass, hide spots, breath holding, alert roar chain reaction, chase, death, GAME OVER, restart at the checkpoint) → loading → school camp (the sister, overhead dialogue ending) → the first handwritten diary page → Demo 2 (below).

## Demo 2: the days after (半自由生存探索)

After the camp ending the first **diary page (9月28日)** appears, then the task
**寻找能够治疗哮喘病的药**, and day two begins. From now on each day is:

学校营地 (Hub: shared food/water, sister, storage) → door **[F] 外出** → hand-marked
**region map** (附近的便利店 playable; Wargame 中心 / 市中心医院 / 地铁站 shown with
their cost but "后面的区域以后再来探索吧......") → pay food/water on departure → **region**
(the street between the school and the store; an **expedition checkpoint** is taken
here) → enter at least one **location** (the store, and with the key its back
**warehouse**) → the gate home opens → food/water are handed to the camp
("获得物资") → talk to the sister **[F]** or end the day **[G]** → templated
handwritten **diary** of what was really brought home → new day (date +1 on the
real calendar, pistol ammo back to 10, everything else persists).

New systems: camp resources & costs, expedition checkpoint (no double cost, no
duplication), persistent world loot (searched containers stay empty, a few refill,
the warehouse key may appear), warehouse door (locked: rattling makes noise),
work uniform (clothing slot, +5 backpack slots, cannot be taken off while the
bag would overflow), empty bottle throwable (pixel arc preview, real flight,
BOTTLE noise at the impact point, zombies sprint to it but never prefer it over a
player they see), longer widening zombie searches after seeing someone hide,
green environmental language on every hide spot, sister small-talk pool.

## Hand equipment & backpack

Three **hand slots** (keys 1 / 2 / 3) form a quick bar — not three held items.
Any item whose `ItemData` says it is hand equipment (`equippable`,
`usable_in_hand`, `equipment_category` = pistol / melee / throwable /
tool) fits any of the three; money, food, water, keys and quest items never
do. The default loadout is 1 pistol, 2 knife, 3 empty. Only the selected
slot's item is active: it runs its `HandBehavior` (`scripts/hand/`:
pistol aim/fire and knife swing = `weapon_behavior.gd`, bottle throw-aim =
`throw_behavior.gd`); switching always puts the old item away first. A new
kind of hand item is a new `.tres` (+ a behaviour script) — the Player does
not change.

The backpack screen (Tab) is sorted by **drag & drop**: backpack ↔ backpack
(move / merge stacks / swap), backpack ↔ hand and gear slots, slot ↔ slot.
While dragging, a target shows a green (fits), red (does not fit) or
neutral (backpack cell) frame; a refused drop leaves the item where it
was. All of it is `GameState.move_item()` on the real data, so scene
changes, checkpoints, saves and new days keep every item in place.

## Lighting & foreground

Pixel-art sprites stay Nearest; light, glows and the nearest foreground are
allowed to be soft. Every map layers several lights (cold ambient, warm
local sources, sky wash, flashlight) and has a near-camera Foreground plus
a blurred ForegroundBlur layer that fades while it covers the player,
zombies or anything interactable. Gameplay exposure (lamp pools vs.
shadows) is placed by hand and kept separate from the rendered light. See
`docs/rendering_layers.md` for the layer / z_index convention.

## Hide spots as tactical nodes

Inside a hide spot (green language: weeds, vines, moss, a green rag) the
player can: wait; pick the bottle slot and **throw** (normal arc, same
bottle rules, stays hidden); press **Space** to knock (`hide_lure` noise
from the spot) and draw a zombie over; and when a living zombie is within
reach and a knife sits in **any** hand slot, **left mouse** performs a
takedown — quick camera zoom, lean out, one blow, back in hiding, the
previously active slot restored. Only the nearest zombie is targeted; the
rest of the world keeps running and may see or hear it.

## Settings

设置 (main menu and pause menu, same data, saved to `user://settings.cfg`):
**屏幕** — 显示模式 (全屏 / 无边框窗口 / 窗口) and 分辨率 (16:9 sizes the
monitor can show; used in windowed mode, too-large sizes shrink to fit). A
display change applies at once and reverts after 15 s unless kept.
**声音** — 主音量 / 音乐 / 音效 (0-100, perceptual dB curve, live). Buses:
Master ← Music ← Ambience; Master ← SFX ← World, UI, Voice.
The game always renders at 480×270 and is integer-scaled, so every output
resolution shows the same part of the world.

## Saving

One autosave slot (`user://savegame.dat`, managed by the `SaveSystem` autoload).
The game saves itself at safe points only, and a small "进度已保存" note shows
in the bottom-right corner:

* the **Street Checkpoint** (day 1),
* every time the **camp hub** is reached (start of a day, coming home — after
  the supplies were handed over),
* the **expedition checkpoint** on entering a region.

The main menu then offers **继续游戏** (with the date and place of the save).
Continuing a save made during an outing resumes at the expedition start, like
restarting after death: the cost is not paid twice and nothing is duplicated.
**新游戏** asks before overwriting an existing save. Test scripts use their own
temporary save file and never touch the real one.

## Project layout

```
scenes/      player, enemies, maps, interactables, props, items, ui, effects
scripts/
  actors/      player.gd, zombie.gd, sister.gd  (thin coordinators)
  components/  movement, health, breath, stealth, flashlight, weapon,
               interaction, vision, hearing, ground_nav, patrol, attack
  ai/          state_machine.gd, zombie_state.gd, states/*.gd (13 states)
  systems/     GameState, AudioManager, NoiseSystem, SceneManager, SaveSystem (autoloads),
               inventory, loot_director, dialogue_player, game_camera
  interactables/, levels/, ui/, effects/, data/ (Resource classes)
resources/   items, weapons, loot_tables, containers, enemies, dialogue, tilesets
art/         generated pixel art (see docs/art_asset_requirements.md)
audio/       generated sound effects and ambience loops
tools/
  art/       pixel-art generators (palette, character rig, environments, UI)
  audio/     procedural sound generator
  builders/  Python scene builders for the maps and prop scenes
  tests/     automated tests (see below)
docs/        art_asset_requirements.md, rendering_layers.md, design notes
```

Data is resource driven: new items, weapons, loot tables, containers, zombie archetypes or dialogue are new `.tres` files; no gameplay code changes needed.

## Tests

Tests are Godot `SceneTree` scripts. Run them with a display (Xvfb is fine) to also save screenshots:

```bash
godot --path . -s res://tools/tests/test_store.gd      -- /tmp/shots   # store loot loop
godot --path . -s res://tools/tests/test_street.gd     -- /tmp/shots   # AI, stealth, death, checkpoint
godot --path . -s res://tools/tests/test_full_flow.gd  -- /tmp/shots   # menu → first diary
godot --path . -s res://tools/tests/test_day_loop.gd   -- /tmp/shots   # Demo 2 day loop
godot --path . -s res://tools/tests/test_save.gd       -- /tmp/shots   # autosave / continue
godot --path . -s res://tools/tests/test_hand_equipment.gd -- /tmp/shots   # hand slots, drag & drop
godot --path . -s res://tools/tests/test_visual_layers.gd  -- /tmp/shots   # lighting, foreground
godot --path . -s res://tools/tests/test_round_hide.gd     -- /tmp/shots   # searchables, corpses, traversal, skip, hide gameplay
godot --path . -s res://tools/tests/test_settings.gd       -- /tmp/shots   # settings (run on a >= 2560x1440 screen)
godot --path . -s res://tools/tests/shoot_scenes.gd    -- /tmp/shots   # screenshots of every map (no checks)
```

Each prints `PASS/FAIL` lines and `RESULT: OK` on success.

## Credits

* Font: [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font) by TakWolf, SIL Open Font License 1.1 (`fonts/OFL.txt`).
* Diary handwriting: [LXGW WenKai 霞鹜文楷](https://github.com/lxgw/LxgwWenKai), SIL OFL 1.1 (`fonts/OFL-LXGW-WenKai.txt`), subset to the characters the game uses by `tools/fonts/build_hand_font.py`.
* All art and audio are generated by the scripts in `tools/`.

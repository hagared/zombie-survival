# Zombie Survival (Roblox)

An endless-wave zombie-survival arena for Roblox, built entirely from code —
no external rigs, meshes, animations or models required. The map (ground,
buildings, mountains, roads, spawn pads), every zombie, every weapon, the
entire UI, and all animations are generated procedurally at runtime.

## Features

- **Endless waves** of zombies with scaling health & damage every wave.
- **5 zombie tiers** that unlock at waves 1 / 5 / 10 / 15 / 20:
  Walker, Runner, Brute, Spitter (ranged), Hellhound.
- **4 weapons** — every player starts with a Pistol; the rest are bought in
  the shop:
  - Pistol — 1 ray
  - Shotgun — **2 rays** (twin barrels)
  - Auto Rifle — high fire rate, single ray
  - Minigun — **3 rays** (rotating barrel cluster)
- **3 placeable defenses** whose price **multiplies on every purchase**:
  - Turret — auto-targets and fires
  - Barbed Wire — slows and damages over time
  - Mine — proximity AoE explosion
- **Procedural arena**: grass ground, paved plaza, road ring, a couple
  rings of randomly-rotated buildings, four signature towers, and a
  perimeter of jagged mountains.
- **Procedural animations** driven by `RunService.Heartbeat` / `RenderStepped`:
  zombie walk/limb sway, weapon recoil, minigun barrel spin, money tween,
  shop open/close, button hover.
- **Smooth tween-based GUIs** built entirely with `Instance.new` (HUD
  with money / wave / zombie counter / health, weapon chips, announcement
  toast, shop modal with tabs).

## Controls

| Input            | Action                              |
| ---------------- | ----------------------------------- |
| `WASD` / `Space` | Move / jump                         |
| `LMB`            | Fire (hold for automatic weapons)   |
| `1` `2` `3` `4`  | Switch to owned weapon              |
| `B`              | Open / close shop                   |
| `LMB` in shop    | Confirm purchase                    |
| `LMB` after buy  | Place purchased defense in world    |
| `Q` / `Esc`      | Cancel a pending defense placement  |

## Project structure

This is a [Rojo](https://rojo.space) project so the files map straight into
a Roblox place:

```
default.project.json
src/
├── shared/        → ReplicatedStorage.Shared
│   ├── Config.lua
│   └── Remotes.lua
├── server/        → ServerScriptService.Server
│   ├── init.server.lua
│   ├── MapGenerator.lua
│   ├── ZombieFactory.lua
│   ├── ZombieAI.lua
│   ├── PlayerData.lua
│   ├── WeaponServer.lua
│   ├── ShopServer.lua
│   ├── DefenseManager.lua
│   └── WaveManager.lua
└── client/        → StarterPlayer.StarterPlayerScripts.Client
    ├── init.client.lua
    ├── HudGui.lua
    ├── ShopGui.lua
    ├── WeaponClient.lua
    ├── WeaponModels.lua
    └── Effects.lua
```

## Running it in Studio

### Option 1 — Rojo (recommended)

```bash
# install rojo if you haven't: https://rojo.space/docs/v7/getting-started/installation/
rojo build default.project.json -o ZombieSurvival.rbxlx
# then open ZombieSurvival.rbxlx in Roblox Studio and press Play.
```

You can also `rojo serve` and use the Rojo Studio plugin for live sync while
iterating on the source.

### Option 2 — Manual copy

If you don't want to install Rojo, just paste each `.lua` file into the
matching Studio location (the path comments above the snippets correspond to
the folders in the project tree).

## Tuning

Almost every game number lives in `src/shared/Config.lua`:
weapon stats, zombie tier health/damage/reward, wave growth multipliers,
defense base price and `PriceMul`, intermission length, etc. Tweak there
without touching the gameplay code.

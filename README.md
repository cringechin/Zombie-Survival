# Zombie Survival

Rojo-powered Roblox project for an arena wave survival game inspired by *Survive Zombie Arena*: big zombie waves, co-op survival, guns, and wave leaderboards.

## Setup

This repo uses Rokit to pin Roblox tooling. If tools are not installed yet, run:

```powershell
rokit install
wally install
```

1. Open Roblox Studio.
2. Install the Rojo Studio plugin if you have not already.
3. Run:

```powershell
rojo serve
```

4. In Studio, connect the Rojo plugin to the local server.

## Build

```powershell
rojo build -o ZombieSurvival.rbxlx
```

## Project Layout

- `src/ReplicatedStorage/Shared/Config`: shared game tuning.
- `src/ReplicatedStorage/Shared/Network`: ByteNet packet definitions.
- `src/ServerScriptService/Data`: server-only data schema modules.
- `src/ServerScriptService/Services`: server gameplay and persistence services.
- `src/StarterPlayer/StarterPlayerScripts/UI`: React UI components.
- `Packages`: shared Wally packages synced into `ReplicatedStorage.Packages`.
- `ServerPackages`: server-only Wally packages synced into `ServerScriptService.ServerPackages`.

## Packages

- `ByteNet`: structured networking packets for client/server messages.
- `React`: component model for client UI.
- `ReactRoblox`: Roblox renderer for React.
- `ProfileStore`: server-only profile persistence with session locking.

Player data is stored through `PlayerDataService` using the schema in `PlayerDataSchema`. The current template tracks total kills, best wave, coins, equipped weapon, and owned weapons.

## NPCs

- Base class: `src/ServerScriptService/Classes/NPC/NPC.lua`
- Subclasses: `src/ServerScriptService/Subclasses/NPCs`
- Shared subclass registry: `src/ReplicatedStorage/Shared/NPC/NPCRegistry.lua`

`BasicZombie` uses this asset path:

```text
ReplicatedStorage.Assets.Zombies.BasicZombie.Zombie
```

Tune `Damage`, `WalkSpeed`, `AttackRange`, `AttackCooldown`, and `SpecialAttacks` in `NPCRegistry`. If the model at that path is empty, the NPC class uses a simple fallback model so waves can still run during development.

## Disaster Weapons

Disaster weapons are regular Roblox tools backed by server-authoritative casts.

- Shared tuning: `src/ReplicatedStorage/Shared/Weapons/DisasterWeaponConfig.lua`
- Network packet: `src/ReplicatedStorage/Shared/Network/Packets.lua`
- Server casts: `src/ServerScriptService/Services/DisasterWeaponService.lua`
- Tool scripts: `src/StarterPack`

The first weapon is `Lightning`, which strikes the clicked world position and deals `30` damage to zombies inside its impact radius.

## Studio Setup Notes

Add parts under `Workspace.ZombieSpawns` to control where zombies spawn. If no spawn parts exist, zombies spawn around a simple default ring.

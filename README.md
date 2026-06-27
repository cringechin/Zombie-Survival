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
3. Run the place you want to sync:

```powershell
rojo serve lobby
rojo serve gameplay
```

4. In Studio, connect the Rojo plugin to the local server for that place.

`lobby` serves on port `34873`, and `gameplay` serves on port `34872`, so both Rojo servers can be left running at the same time. After publishing the gameplay place, set `GameplayPlaceId` in `lobby/src/ReplicatedStorage/LobbyConfig.lua` so the lobby can teleport players into it.

## Build

```powershell
rojo build gameplay -o ZombieSurvival.rbxlx
rojo build lobby -o ZombieSurvivalLobby.rbxlx
```

## Project Layout

- `gameplay/src/ReplicatedStorage/Shared/Config`: shared game tuning.
- `gameplay/src/ReplicatedStorage/Shared/Network`: ByteNet packet definitions.
- `gameplay/src/ServerScriptService/Data`: server-only data schema modules.
- `gameplay/src/ServerScriptService/Services`: server gameplay and persistence services.
- `gameplay/src/StarterPlayer/StarterPlayerScripts/UI`: React UI components.
- `lobby/src`: lightweight lobby place that counts down and teleports players to gameplay.
- `gameplay/default.project.json`: Rojo project for the gameplay place.
- `lobby/default.project.json`: Rojo project for the lobby place.
- `shared/ServerRuntime`: shared server bootstrap utilities used by both places.
- `Packages`: shared Wally packages synced into `ReplicatedStorage.Packages`.
- `ServerPackages`: server-only Wally packages synced into `ServerScriptService.ServerPackages`.

Server startup is service-driven. Each place has a single `Bootstrap.server.lua` that runs `Runtime.ServiceLoader`; service modules under `ServerScriptService.Services` are discovered automatically when they expose `start()`. Use an `Order` field on a service when startup order matters.

## Lobby Queues

The lobby place expects queue rooms under `Workspace.Queues`. Each queue room should include `InQueue`, `Model`, and `Refs`; `Refs` should include `CamPos`, `Enter`, `EnterPos`, `ExitPos`, and `UI.BillboardGui` with `Players` and `Time` labels. Add more queue rooms as siblings under `Workspace.Queues`; the lobby service registers each room separately.

Queue networking uses ByteNet packets in `lobby/src/ReplicatedStorage/Shared/Network/Packets.lua`, not RemoteEvents. Set the published gameplay place id in `lobby/src/ReplicatedStorage/LobbyConfig.lua`.

Each queue can override lobby defaults with attributes or ValueBase objects under a `Settings` folder. Supported keys are `GameplayPlaceId`, `MaximumPlayers`, `MinimumPlayers`, `CreationTime`, `CountdownTime`, `CountdownScalePerPlayer`, `FullQueueSpeedMultiplier`, and `InstantTeleportWhenFull`.

## Packages

- `ByteNet`: structured networking packets for client/server messages.
- `React`: component model for client UI.
- `ReactRoblox`: Roblox renderer for React.
- `ProfileStore`: server-only profile persistence with session locking.

Player data is stored through `PlayerDataService` using the schema in `PlayerDataSchema`. The current template tracks total kills, best wave, coins, equipped weapon, and owned weapons.

## NPCs

- Base class: `gameplay/src/ServerScriptService/Classes/NPC/NPC.lua`
- Subclasses: `gameplay/src/ServerScriptService/Subclasses/NPCs`
- Shared subclass registry: `gameplay/src/ReplicatedStorage/Shared/NPC/NPCRegistry.lua`

`BasicZombie` uses this asset path:

```text
ReplicatedStorage.Assets.Zombies.BasicZombie.Zombie
```

Tune `Damage`, `WalkSpeed`, `AttackRange`, `AttackCooldown`, and `SpecialAttacks` in `NPCRegistry`. If the model at that path is empty, the NPC class uses a simple fallback model so waves can still run during development.

## Disaster Weapons

Disaster weapons are regular Roblox tools backed by server-authoritative casts.

- Shared tuning: `gameplay/src/ReplicatedStorage/Shared/Weapons/DisasterWeaponConfig.lua`
- Network packet: `gameplay/src/ReplicatedStorage/Shared/Network/Packets.lua`
- Server casts: `gameplay/src/ServerScriptService/Services/DisasterWeaponService.lua`
- Tool scripts: `gameplay/src/StarterPack`

The first weapon is `Lightning`, which strikes the clicked world position and deals `30` damage to zombies inside its impact radius.

## Studio Setup Notes

Add parts under `Workspace.ZombieSpawns` to control where zombies spawn. If no spawn parts exist, zombies spawn around a simple default ring.

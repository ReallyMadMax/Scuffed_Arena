# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scuffed Arena is a multiplayer arena game built with Godot 4.5. The project uses GDScript for gameplay logic and implements peer-to-peer multiplayer networking using WebRTC with WebSocket signaling.

## Project Structure

- **Root directory**: `/mnt/Extra/GODOT/Scuffed_Arena/`
- **Godot project**: `scuffed_arena/` subdirectory
- **Main project file**: `scuffed_arena/project.godot`
- **Signaling server**: `SignalingServer/` - Standalone C# WebSocket server

### Key Directories

- `scuffed_arena/scripts/` - All GDScript files
  - `scripts/network/` - Client and server networking logic (WebRTC + signaling)
  - `scripts/gui/menus/` - Menu UI scripts
- `scuffed_arena/scenes/` - Scene files (.tscn)
  - `scenes/gui/menus/` - Menu scenes
- `SignalingServer/` - C# signaling server (no port forwarding needed!)
  - `Program.cs` - Main server implementation
  - `README.md` - Setup and deployment guide

## Architecture

### Autoload Singletons

Three autoload singletons manage global state (defined in project.godot):

1. **GameManager** (`scripts/game_manager.gd`) - Stores player data in `Players` dictionary
2. **Client** (`scripts/network/client.gd`) - Handles client-side networking, WebRTC peer connections, lobby operations, and connection diagnostics
3. **Server** (`scripts/network/server.gd`) - WebSocket signaling server for matchmaking and WebRTC signaling

### Networking Architecture

The game uses a WebRTC-based peer-to-peer networking approach:

#### Signaling Servers (Choose One)

**Option 1: C# Signaling Server** (RECOMMENDED - No port forwarding needed!)
- Located in `SignalingServer/` directory
- **AUTO-STARTS** when host clicks "Host Game" (no manual setup for local/LAN!)
- For internet play: expose via ngrok/localhost.run after auto-start
- Or deploy to free VPS (Railway, fly.io) for 24/7 availability
- Managed by `Server.start_signaling_server()` and `Server.stop_signaling_server()`
- See `SignalingServer/README.md` for full setup instructions

**Option 2: GDScript Signaling Server** (Legacy - Requires port forwarding)
- `Server` autoload (`scripts/network/server.gd`)
- Runs inside Godot, requires host to port forward
- Original implementation, still functional

#### Connection Flow

1. **WebSocket Signaling**: Handles initial connection, lobby creation/joining, and WebRTC signaling (OFFER/ANSWER/CANDIDATE messages)
   - Client supports both IP:Port (`192.168.1.1:6000`) and full URLs (`wss://domain.com`)
   - See `client.gd:connectToServer()` for URL parsing logic

2. **WebRTC P2P**: After signaling, clients establish direct peer-to-peer connections using WebRTC
   - NAT traversal handled automatically through:
     - **STUN servers** (Google's public STUN) for discovering public IP/port mappings
     - **TURN relay servers** (openrelay.metered.ca on multiple ports) as fallback
   - Game host does NOT need to port forward (only the signaling server does)

Message types are defined in both `client.gd` and `server.gd` via the `Message` enum.

**Important**: The game traffic flows peer-to-peer via WebRTC, NOT through the signaling server. Only the initial handshake goes through the signaling server.

### Player System

Players inherit from an abstract base class:

- **player_class** (`scripts/Player_parent.gd`) - Abstract base class with common properties (speed, health, cooldowns), animation handling, and RPC methods for damage
- **Concrete implementations**:
  - `scripts/player.gd` - Basic player character with WASD movement
  - `scripts/skelly.gd` - Ranged mage with projectile shooting
  - `scripts/ghost.gd` - Enemy AI that chases and attacks the player

Player spawning happens in `scripts/main.gd`, which reads from `GameManager.Players` and instantiates player scenes with multiplayer authority set based on player ID.

### Multiplayer Synchronization

- Each player node's name is set to their multiplayer ID (as string)
- `MultiplayerSynchronizer` node manages authority per player
- Only the authoritative client processes input for their character
- Camera is removed from non-owned player instances
- RPCs use `@rpc("any_peer", "call_local")` for synchronized actions

### Ability System

The `Ability` class (`scripts/ability.gd`) provides a resource-based ability system with cooldown tracking, range, and damage properties. Players preload this script to create custom abilities.

## Running the Project

### Opening in Godot Editor

```bash
# If godot is in PATH
godot --path /mnt/Extra/GODOT/Scuffed_Arena/scuffed_arena

# Or use the full path to your Godot 4.5 executable
/path/to/godot4.5 --path /mnt/Extra/GODOT/Scuffed_Arena/scuffed_arena
```

### Running the Game

From the Godot editor, press F5 or click the Play button. The game starts with the main scene defined in `project.godot` (uid://k0b7d88pg0p1).

## Input Mappings

Defined in `project.godot` under `[input]`:

- **Movement**: WASD keys (also supports gamepad analog stick)
- **Attack**: F key

## Common Development Patterns

### Creating a New Player Character

1. Create a new script extending `player_class`
2. Implement `_init()` to set character-specific properties (speed, etc.)
3. Override `_ready()` to set multiplayer authority: `$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())`
4. Check authority in `_process()` before handling input: `if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id(): return`
5. Call `update_animation_parameters()` after movement

### Adding RPC Methods

Use the pattern: `@rpc("any_peer", "call_local")` for synchronized gameplay actions that should execute on all clients.

### Working with Lobby System

The `Lobby` class (`scripts/lobby.gd`) manages player lists and host tracking. Server maintains one lobby instance, referenced by `LOBBY_ID`. Clients receive player data via `Message.JOIN_LOBBY`.

## Important Notes

- The project includes both C# support (`Scuffed_Arena.csproj`) and GDScript, but only GDScript is currently used
- External IP is fetched from `https://ipv4.icanhazip.com` for **display purposes only** (so host knows what IP to share)
- WebRTC uses Google STUN servers and openrelay.metered.ca (ports 80, 443, 3478, and TLS) as TURN fallback
- **NAT Traversal**: All handled by WebRTC ICE. No manual hole punching is performed.
- When debugging multiplayer, check `Client.client_id` is assigned before creating/joining lobbies
- The game clears all non-autoload nodes when transitioning to the main scene (see `client.gd:start_game()`)
- Connection diagnostics are logged with `[WebRTC]` prefix - monitor console for detailed connection states
- For production use, consider a paid TURN service for better reliability (free TURN servers can be rate-limited or unreliable)

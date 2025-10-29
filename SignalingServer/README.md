# Scuffed Arena Signaling Server

A lightweight WebSocket signaling server for Scuffed Arena multiplayer that enables **hosting games without port forwarding**.

## How It Works

This server only handles **initial connection setup** (signaling). Once players connect, all game traffic flows **peer-to-peer via WebRTC** (no data goes through this server after connection).

**Key Benefit**: The game host doesn't need to port forward! Only this tiny signaling server needs to be publicly accessible.

## 🚀 AUTO-START (Recommended for Local Play)

**The signaling server now starts AUTOMATICALLY when you click "Host Game"!**

### For Local/LAN Play:
1. Click "Host Game" in Scuffed Arena
2. The signaling server starts automatically
3. Friends on your local network can connect using your local IP

**That's it!** No manual server setup needed for local/LAN games.

### For Internet Play (Friends Outside Your Network):

**Auto-Start + ngrok Workflow:**
1. Click "Host Game" (server starts automatically in background)
2. Open terminal and run: `ngrok http 6000`
3. Copy the ngrok URL (e.g., `https://abc123.ngrok-free.app`)
4. In the game, enter: `wss://abc123.ngrok-free.app` in the IP field
5. Share that URL with friends - they enter it in "Connect" menu

The server runs in the background until you close the game!

## Quick Start (Manual Setup for Internet Play)

### Option 1: Local Server + ngrok (Recommended)

1. **Start the signaling server** (from the `SignalingServer` directory):
   ```bash
   cd SignalingServer
   dotnet run
   ```

2. **Expose it publicly with ngrok** (in a new terminal):
   ```bash
   ngrok http 6000
   ```

3. **Copy the ngrok URL** (looks like `wss://xxxx-xxx-xxx-xxx.ngrok-free.app`)
   - ngrok will display a "Forwarding" URL like: `https://abc123.ngrok-free.app`
   - Convert to WebSocket: `wss://abc123.ngrok-free.app`

4. **Share the URL** with your friends

5. **In the game**:
   - **Host**: Enter the ngrok URL (e.g., `wss://abc123.ngrok-free.app`) in the IP field
   - **Friends**: Enter the same ngrok URL

### Option 2: Local Server + localhost.run (Free, no account)

1. **Start the signaling server**:
   ```bash
   cd SignalingServer
   dotnet run
   ```

2. **Expose it with localhost.run** (in a new terminal):
   ```bash
   ssh -R 80:localhost:6000 nokey@localhost.run
   ```

3. **Copy the URL** provided by localhost.run (e.g., `https://xxxx.lhr.life`)
   - Convert to WebSocket: `wss://xxxx.lhr.life`

4. **Share with friends** and use in-game

### Option 3: Deploy to a Free VPS (24/7 availability)

Deploy to Railway, fly.io, or DigitalOcean:

**Railway** (easiest):
```bash
# Install Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# Deploy
railway login
railway init
railway up
```

Railway will give you a public URL that works 24/7.

## Game Setup

### For the Host:

1. Run the signaling server (locally or on VPS)
2. Expose it via ngrok/localhost.run (if local)
3. In Scuffed Arena:
   - Click "Host Game"
   - Enter the WebSocket URL in the IP field:
     - ngrok: `wss://abc123.ngrok-free.app`
     - localhost.run: `wss://xxxx.lhr.life`
     - VPS: `wss://yourdomain.com`
     - Local testing: `ws://localhost` or `ws://192.168.x.x`
   - Click "Host Game"

### For Friends Joining:

1. Get the WebSocket URL from the host
2. In Scuffed Arena:
   - Click "Connect"
   - Enter the WebSocket URL in the IP field
   - Click "Connect"

## Important Notes

### WebSocket URLs
- **Secure** (ngrok/VPS with HTTPS): `wss://domain.com`
- **Local/unsecured**: `ws://ip-address`
- The game automatically detects if you're entering a full URL or just an IP

### Port Forwarding
- **NOT NEEDED** for game hosts!
- Only this lightweight signaling server needs internet access
- All game traffic is P2P via WebRTC

### NAT Traversal
- WebRTC handles all NAT traversal automatically
- Uses STUN servers (Google's public STUN)
- Falls back to TURN relay if direct connection fails
- Works behind most consumer routers without configuration

## Troubleshooting

### "Connection Failed"
- Check that the signaling server is running
- Verify the WebSocket URL is correct (`wss://` for HTTPS, `ws://` for local)
- If using ngrok, make sure you're using the current session URL (they change on restart)

### ngrok Warning Page
- ngrok free tier shows a warning page on first visit
- This doesn't affect WebSocket connections
- Or upgrade to ngrok paid tier to remove warnings

### localhost.run Expired
- localhost.run sessions expire after inactivity
- Just restart the ssh tunnel to get a new URL

## Advanced Configuration

### Custom Port
```bash
dotnet run 8080  # Use port 8080 instead of 6000
```

Then update ngrok:
```bash
ngrok http 8080
```

### Production Deployment

For 24/7 hosting, consider:
- **Railway**: Automatic HTTPS, free tier available
- **fly.io**: Global CDN, free tier available
- **DigitalOcean**: $4/month VPS

## Architecture

```
Player 1 (Host)           Signaling Server          Player 2 (Friend)
     |                          |                          |
     |------- WebSocket ------->|<------ WebSocket ---------|
     |     (Initial setup)      |      (Initial setup)      |
     |                          |                           |
     |<======================= WebRTC P2P ==================>|
              (All game traffic - no server needed!)
```

1. **Signaling Server**: Coordinates initial connection (lightweight, always online)
2. **WebRTC P2P**: Direct connection between players for game traffic (no port forwarding!)

## Why This Solution?

**Before**: Host needed to port forward their router (complicated, security risk)

**Now**:
- Run tiny signaling server locally
- Expose via ngrok/localhost.run (no port forwarding)
- Or deploy to free VPS once for 24/7 availability
- Game traffic is still P2P (low latency, no server costs)

**Result**: Anyone can host games without router configuration!

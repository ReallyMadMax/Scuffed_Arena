# How to Host a Game (No Port Forwarding Required!)

This guide explains how to host multiplayer games in Scuffed Arena without needing to configure your router.

## 🎮 Quick Start

### Local/LAN Games (Easiest)

**Playing with friends on the same network:**

1. **Host**: Click "Host Game" in Scuffed Arena
   - Signaling server starts automatically!
   - Leave the IP field empty or use your local IP

2. **Friends**: Click "Connect"
   - Enter the host's local IP (e.g., `192.168.1.100`)

**That's it!** The signaling server runs automatically in the background.

---

### Internet Games (Friends Anywhere)

**Playing with friends over the internet:**

#### Step 1: Start the Game as Host
1. Click "Host Game" in Scuffed Arena
2. The signaling server starts automatically in the background

#### Step 2: Expose the Server (Choose One)

**Option A: Using ngrok** (requires free account at ngrok.com)
```bash
# In a terminal
ngrok http 6000
```
- Copy the URL: `https://abc123.ngrok-free.app`
- Convert to WebSocket: `wss://abc123.ngrok-free.app`

**Option B: Using localhost.run** (no account needed!)
```bash
# In a terminal
ssh -R 80:localhost:6000 nokey@localhost.run
```
- Copy the URL provided: `https://xxxx.lhr.life`
- Convert to WebSocket: `wss://xxxx.lhr.life`

#### Step 3: Connect in Game
1. In Scuffed Arena, enter the WebSocket URL in the IP field
2. Share the URL with friends
3. Friends enter the same URL in "Connect" menu

---

## 📋 Complete Workflow Examples

### Example 1: LAN Party / Same WiFi
```
Host:
1. Click "Host Game"
2. Tell friends your local IP (shown in menu)

Friends:
1. Click "Connect"
2. Enter host's IP: 192.168.1.100
```

### Example 2: Internet with ngrok
```
Host:
1. Click "Host Game" (server auto-starts)
2. Run: ngrok http 6000
3. Get URL: wss://abc123.ngrok-free.app
4. Enter that URL in game IP field
5. Share with friends

Friends:
1. Click "Connect"
2. Enter: wss://abc123.ngrok-free.app
```

### Example 3: Internet with localhost.run
```
Host:
1. Click "Host Game" (server auto-starts)
2. Run: ssh -R 80:localhost:6000 nokey@localhost.run
3. Get URL: wss://xxxx.lhr.life
4. Enter that URL in game IP field
5. Share with friends

Friends:
1. Click "Connect"
2. Enter: wss://xxxx.lhr.life
```

---

## 🔧 Technical Details

### What Happens Automatically

When you click "Host Game":
1. ✅ C# signaling server starts (port 6000)
2. ✅ Server builds automatically if needed
3. ✅ Server runs in background
4. ✅ Server stops when you quit the game

### What's Manual (Only for Internet Play)

- Running ngrok/localhost.run to expose the server
- Entering the public URL in the game

### Requirements

- **.NET SDK** (for auto-starting the signaling server)
  - Check: `dotnet --version`
  - Install: https://dotnet.microsoft.com/download

- **ngrok** (optional, for internet play)
  - Free account: https://ngrok.com

- **SSH** (for localhost.run, usually pre-installed on Linux/Mac)

---

## 🐛 Troubleshooting

### "Failed to start signaling server"
- Make sure .NET SDK is installed: `dotnet --version`
- Check that `SignalingServer/` folder exists in project directory

### "Connection failed"
- **LAN**: Make sure you're on the same network
- **Internet**: Check that ngrok/localhost.run is running and URL is correct
- URL format: `wss://` for HTTPS, `ws://` for local

### ngrok shows warning page
- This is normal for free tier, doesn't affect WebSocket connections
- Or upgrade to paid ngrok to remove warnings

### localhost.run session expired
- Sessions expire after inactivity
- Just restart the SSH tunnel to get a new URL

---

## 🚀 Advanced: Deploy for 24/7 Availability

Instead of running ngrok/localhost.run every time, deploy the signaling server once:

### Option 1: Railway (Recommended)
```bash
# Install Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# Deploy from SignalingServer directory
cd SignalingServer
railway login
railway init
railway up
```

Railway gives you a permanent URL that works 24/7 (free tier available).

### Option 2: fly.io
```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Deploy
cd SignalingServer
fly launch
fly deploy
```

### Option 3: Any VPS ($4-5/month)
- DigitalOcean, Linode, Vultr, etc.
- Run: `dotnet run` on the server
- Get permanent public URL

---

## 🎯 Summary

**Local Play**: Just click "Host Game" - everything is automatic!

**Internet Play**: Click "Host Game" + run ngrok/localhost.run + share URL

**No port forwarding needed!** The signaling server handles initial connections, then game traffic flows P2P.

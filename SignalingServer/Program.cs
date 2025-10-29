using System.Collections.Concurrent;
using System.Text.Json;
using Fleck;

namespace SignalingServer;

class Program
{
    // Message types (must match GDScript enum)
    enum Message
    {
        ID = 0,
        JOIN = 1,
        USER_CONNECTED = 2,
        USER_DISCONNECTED = 3,
        CREATE_LOBBY = 4,
        JOIN_LOBBY = 5,
        CANDIDATE = 10,
        OFFER = 11,
        ANSWER = 12,
        CHECK_IN = 13
    }

    class Player
    {
        public required string Name { get; set; }
        public required int Id { get; set; }
        public required int Index { get; set; }
    }

    class Lobby
    {
        public int HostId { get; set; }
        public Dictionary<int, Player> Players { get; set; } = new();

        public Lobby(int hostId)
        {
            HostId = hostId;
        }

        public Player AddPlayer(int id, string playerName)
        {
            var player = new Player
            {
                Name = playerName,
                Id = id,
                Index = Players.Count
            };
            Players[id] = player;
            return player;
        }

        public void RemovePlayer(int id)
        {
            Players.Remove(id);
        }
    }

    static readonly ConcurrentDictionary<int, IWebSocketConnection> _connections = new();
    static Lobby? _lobby;
    static int _nextClientId = 1;
    static readonly string LOBBY_ID = "BAHAHAHAHA";

    static void Main(string[] args)
    {
        // Allow custom port via command line arg
        int port = args.Length > 0 && int.TryParse(args[0], out var p) ? p : 6000;

        FleckLog.Level = LogLevel.Info;
        var server = new WebSocketServer($"ws://0.0.0.0:{port}");

        Console.WriteLine("=================================================");
        Console.WriteLine($"Scuffed Arena Signaling Server");
        Console.WriteLine($"Listening on port {port}");
        Console.WriteLine("=================================================");
        Console.WriteLine();
        Console.WriteLine("To expose this server publicly without port forwarding:");
        Console.WriteLine($"  ngrok http {port}");
        Console.WriteLine("  OR");
        Console.WriteLine($"  ssh -R 80:localhost:{port} nokey@localhost.run");
        Console.WriteLine();
        Console.WriteLine("Then share the public URL with your friends!");
        Console.WriteLine("=================================================");
        Console.WriteLine();

        server.Start(socket =>
        {
            socket.OnOpen = () => OnClientConnected(socket);
            socket.OnClose = () => OnClientDisconnected(socket);
            socket.OnMessage = message => OnMessage(socket, message);
        });

        Console.WriteLine("Press Enter to stop the server...");
        Console.ReadLine();
    }

    static void OnClientConnected(IWebSocketConnection socket)
    {
        int clientId = Interlocked.Increment(ref _nextClientId);
        _connections[clientId] = socket;

        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Client connected: {clientId} ({socket.ConnectionInfo.ClientIpAddress})");

        // Send ID message to client
        var idMessage = new Dictionary<string, object>
        {
            ["id"] = clientId,
            ["message"] = (int)Message.ID
        };

        SendToClient(clientId, idMessage);
    }

    static void OnClientDisconnected(IWebSocketConnection socket)
    {
        var clientId = _connections.FirstOrDefault(x => x.Value == socket).Key;
        if (clientId != 0)
        {
            _connections.TryRemove(clientId, out _);
            _lobby?.RemovePlayer(clientId);
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Client disconnected: {clientId}");
        }
    }

    static void OnMessage(IWebSocketConnection socket, string messageJson)
    {
        try
        {
            var data = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(messageJson);
            if (data == null) return;

            var messageType = (Message)data["message"].GetInt32();

            switch (messageType)
            {
                case Message.CREATE_LOBBY:
                    HandleCreateLobby(socket, data);
                    break;

                case Message.JOIN_LOBBY:
                    HandleJoinLobby(socket, data);
                    break;

                case Message.OFFER:
                case Message.ANSWER:
                case Message.CANDIDATE:
                    HandleWebRTCSignaling(data);
                    break;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ERROR] Failed to process message: {ex.Message}");
        }
    }

    static void HandleCreateLobby(IWebSocketConnection socket, Dictionary<string, JsonElement> data)
    {
        var clientId = _connections.FirstOrDefault(x => x.Value == socket).Key;
        if (clientId == 0) return;

        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Client {clientId} creating lobby...");

        _lobby = new Lobby(clientId);

        // Modify the data to add lobby_id
        var userData = data.ToDictionary(
            kvp => kvp.Key,
            kvp => kvp.Value
        );
        userData["lobby_id"] = JsonSerializer.SerializeToElement(LOBBY_ID);

        HandleJoinLobby(socket, userData);
    }

    static void HandleJoinLobby(IWebSocketConnection socket, Dictionary<string, JsonElement> data)
    {
        var clientId = _connections.FirstOrDefault(x => x.Value == socket).Key;
        if (clientId == 0 || _lobby == null) return;

        var playerName = data.ContainsKey("name") ? data["name"].GetString() ?? "Player" : "Player";

        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Client {clientId} ({playerName}) joining lobby...");

        // Notify existing players about the new connection
        foreach (var existingPlayerId in _lobby.Players.Keys.ToList())
        {
            SendConnectionPacket(clientId, existingPlayerId, null);
            SendConnectionPacket(existingPlayerId, clientId, null);

            var lobbyInfo = new Dictionary<string, object>
            {
                ["message"] = (int)Message.JOIN_LOBBY,
                ["players"] = _lobby.Players,
                ["lobby_id"] = LOBBY_ID
            };
            SendToClient(existingPlayerId, lobbyInfo);
        }

        // Add the new player
        _lobby.AddPlayer(clientId, playerName);

        // Send connection packet to the new player with lobby info
        SendConnectionPacket(clientId, clientId, _lobby);

        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Lobby now has {_lobby.Players.Count} player(s)");
    }

    static void SendConnectionPacket(int senderId, int receiverId, Lobby? newLobby)
    {
        var data = new Dictionary<string, object>
        {
            ["message"] = (int)Message.USER_CONNECTED,
            ["sender_id"] = senderId
        };

        if (newLobby != null)
        {
            data["host"] = newLobby.HostId;
            data["player"] = newLobby.Players[senderId];
        }

        SendToClient(receiverId, data);
    }

    static void HandleWebRTCSignaling(Dictionary<string, JsonElement> data)
    {
        // Forward WebRTC signaling messages (OFFER/ANSWER/CANDIDATE) to the target peer
        if (!data.ContainsKey("peer")) return;

        var targetPeerId = data["peer"].GetInt32();

        var messageType = (Message)data["message"].GetInt32();
        var msgName = messageType == Message.CANDIDATE ? "ICE candidate" :
                     messageType == Message.OFFER ? "OFFER" : "ANSWER";

        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Forwarding {msgName} to peer {targetPeerId}");

        SendToClient(targetPeerId, data);
    }

    static void SendToClient(int clientId, object data)
    {
        if (_connections.TryGetValue(clientId, out var socket))
        {
            var json = JsonSerializer.Serialize(data);
            socket.Send(json);
        }
    }
}

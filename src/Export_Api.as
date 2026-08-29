#if DEPENDENCY_EDITOR

namespace MapTogether {
    const uint DefaultWaitTimeoutMs = 30000;
    const uint DefaultChatLimit = 50;

    Json::Value@ GetStatus() {
        UpdateSessionFlags();
        auto o = Json::Object();
        o["ok"] = true;
        o["inMainMenu"] = IsInMainMenu;
        o["inEditor"] = IsInEditor;
        o["inSubEditor"] = IsInSubEditor;
        o["isTestingOrValidating"] = IsTestingOrValidating;
        o["isLoading"] = IsLoading;
        o["windowOpen"] = g_WindowOpen;
        o["connecting"] = IS_CONNECTING;
        o["stage"] = StageName(g_ConnectionStage);
        o["server"] = ServerKey(m_CurrServer);
        o["serverName"] = ServerToName(m_CurrServer);
        o["lastRoomId"] = m_RoomId;
        o["dropPendingUpdates"] = g_DropMsgsTemp;
        o["clubItemsDisabled"] = EditorPatches::DisableClubItems_IsApplied;
        o["skipClubFavUpdate"] = EditorPatches::SkipClubFavItemUpdate_IsApplied;
        o["renderPlayers"] = S_RenderPlayersNvg;
        o["statusHud"] = S_RenderStatusHUD;
        o["camLocked"] = g_CamLockedToPlayer !is null;
        if (g_CamLockedToPlayer !is null) {
            o["camLockedTo"] = g_CamLockedToPlayer.name;
        }

        if (g_MTConn is null) {
            o["connected"] = false;
            o["hasConnection"] = false;
            o["hasErrored"] = false;
            o["isShutdown"] = false;
            o["playerCount"] = 0;
            o["pendingUpdates"] = 0;
            return o;
        }

        o["hasConnection"] = true;
        o["connected"] = g_MTConn.IsConnected;
        o["isConnecting"] = g_MTConn.IsConnecting;
        o["isShutdown"] = g_MTConn.IsShutdown;
        o["hasErrored"] = g_MTConn.hasErrored;
        o["error"] = g_MTConn.error;
        o["roomId"] = g_MTConn.roomId;
        o["roomIdWithServer"] = g_MTConn.RoomIdWithServer();
        o["password"] = g_MTConn.roomPassword;
        o["remote"] = g_MTConn.remote_domain;
        o["actionRateLimit"] = int(g_MTConn.actionRateLimit);
        o["actionLimitHz"] = g_MTConn.ActionLimitHz;
        o["playerLimit"] = int(g_MTConn.playerLimit);
        o["itemMaxSize"] = int(g_MTConn.itemMaxSize);
        o["rulesFlags"] = int(g_MTConn.rulesFlags);
        o["isPuzzle"] = g_MTConn.isPuzzle;
        o["isAdmin"] = g_MTConn.HasLocalAdmin();
        o["localSkinUrl"] = g_MTConn.localSkinUrl;
        o["playerCount"] = int(g_MTConn.playersInRoom.Length);
        o["playersEver"] = int(g_MTConn.playersEver.Length);
        o["serverPlayerCount"] = int(g_MTConn.nbPlayersOnServer);
        o["pendingUpdates"] = int(g_MTConn.pendingUpdates.Length);
        o["msgsRead"] = int(g_MTConn.msgsRead);
        o["totalBlocksPlaced"] = int(g_MTConn.totalBlocksPlaced);
        o["totalBlocksRemoved"] = int(g_MTConn.totalBlocksRemoved);
        o["totalItemsPlaced"] = int(g_MTConn.totalItemsPlaced);
        o["totalItemsRemoved"] = int(g_MTConn.totalItemsRemoved);
        o["mapBase"] = MapBaseKey(g_MTConn.mapBaseName);
        o["mapMood"] = MapMoodKey(g_MTConn.mapBaseMood);
        o["mapEnv"] = MapEnvKey(g_MTConn.mapBaseEnv);
        o["car"] = MapCarKey(MapCar(g_MTConn.baseCar));
        o["mapSize"] = Nat3ToJson(g_MTConn.mapSize);
        return o;
    }

    Json::Value@ SetServer(Json::Value &in opts) {
        string err;
        MTServers server;
        if (!ParseServer(JsonStr(opts, "server"), server, err)) return Fail(err);
        m_CurrServer = server;
        return GetStatus();
    }

    Json::Value@ CreateRoom(Json::Value &in opts) {
        UpdateSessionFlags();
        string err = ApplyCreateOpts(opts);
        if (err.Length > 0) return Fail(err);
        if (!IsInMainMenu) return Fail("must be in the main menu to create a new map and room");
        if (Busy()) return Fail("a Map Together connection is already active");
        g_MenuState = MenuState::RoomConnectingOrRunning;
        ConnectToMapTogether_FreshMap();
        return Started("create");
    }

    Json::Value@ InviteCurrentMap(Json::Value &in opts) {
        UpdateSessionFlags();
        string err = ApplyInviteOpts(opts);
        if (err.Length > 0) return Fail(err);
        if (!IsInEditor) return Fail("must be in the map editor to invite the current map");
        if (Busy()) return Fail("a Map Together connection is already active");
        g_MenuState = MenuState::RoomConnectingOrRunning;
        if (JsonBool(opts, "puzzle", false)) {
            InviteToMapTogetherRoom_ExistingMap_Puzzle();
        } else {
            InviteToMapTogetherRoom_ExistingMap();
        }
        return Started("invite");
    }

    Json::Value@ JoinRoom(Json::Value &in opts) {
        UpdateSessionFlags();
        string err = ApplyJoinOpts(opts);
        if (err.Length > 0) return Fail(err);
        bool useCurrentMap = JsonBool(opts, "useCurrentMap", false) || JsonBool(opts, "puzzle", false);
        if (useCurrentMap && !IsInEditor) return Fail("useCurrentMap/puzzle join requires the current map to be open in the editor");
        if (!useCurrentMap && !IsInMainMenu) return Fail("must be in the main menu to join and open the room map");
        if (Busy()) return Fail("a Map Together connection is already active");
        g_MenuState = MenuState::RoomConnectingOrRunning;
        if (JsonBool(opts, "puzzle", false)) {
            JoinMapTogetherRoom_Puzzle();
        } else {
            JoinMapTogetherRoom();
        }
        return Started("join");
    }

    Json::Value@ Disconnect(Json::Value &in opts) {
        if (g_MTConn !is null) {
            g_MTConn.Close();
            @g_MTConn = null;
        }
        IS_CONNECTING = false;
        g_ConnectionStage = ConnectionStage::None;
        g_MenuState = MenuState::None;
        UnlockEditorCamera();
        return GetStatus();
    }

    Json::Value@ WaitUntilReady(Json::Value &in opts) {
        uint timeoutMs = JsonUint(opts, "timeoutMs", DefaultWaitTimeoutMs);
        uint started = Time::Now;
        while (true) {
            if (g_MTConn is null && !IS_CONNECTING) {
                return Fail("no Map Together connection in progress");
            }
            if (g_MTConn !is null && g_MTConn.hasErrored) {
                return Fail(g_MTConn.error.Length > 0 ? g_MTConn.error : "connection errored");
            }
            if (g_MTConn !is null && g_MTConn.IsShutdown) {
                return Fail(g_MTConn.error.Length > 0 ? g_MTConn.error : "connection shut down");
            }
            if (g_MTConn !is null && g_MTConn.IsConnected && g_ConnectionStage == ConnectionStage::Done) {
                auto r = GetStatus();
                r["ready"] = true;
                return r;
            }
            if (Time::Now - started >= timeoutMs) {
                auto r = Fail("timed out waiting for Map Together to become ready");
                r["status"] = GetStatus();
                return r;
            }
            yield();
        }
        return Fail("wait loop exited unexpectedly");
    }

    Json::Value@ WaitUntilIdle(Json::Value &in opts) {
        uint timeoutMs = JsonUint(opts, "timeoutMs", DefaultWaitTimeoutMs);
        uint started = Time::Now;
        while (true) {
            if (g_MTConn is null) return Fail("not connected");
            if (g_MTConn.hasErrored) return Fail(g_MTConn.error);
            if (g_MTConn.IsConnected && g_ConnectionStage == ConnectionStage::Done && g_MTConn.pendingUpdates.Length == 0) {
                auto r = GetStatus();
                r["idle"] = true;
                return r;
            }
            if (Time::Now - started >= timeoutMs) {
                auto r = Fail("timed out waiting for pending updates to drain");
                r["status"] = GetStatus();
                return r;
            }
            yield();
        }
        return Fail("wait loop exited unexpectedly");
    }

    Json::Value@ GetPlayers(Json::Value &in opts) {
        if (g_MTConn is null) return Fail("not connected");
        bool includeLeft = JsonBool(opts, "includeLeft", false);
        auto players = Json::Array();
        auto src = includeLeft ? g_MTConn.playersEver : g_MTConn.playersInRoom;
        for (uint i = 0; i < src.Length; i++) {
            players.Add(PlayerToJson(src[i]));
        }
        auto o = Json::Object();
        o["ok"] = true;
        o["players"] = players;
        o["count"] = int(src.Length);
        return o;
    }

    Json::Value@ SendChat(Json::Value &in opts) {
        if (g_MTConn is null || !g_MTConn.IsConnected) return Fail("not connected");
        string msg = JsonStr(opts, "message");
        if (msg.Length == 0) msg = JsonStr(opts, "text");
        if (msg.Length == 0) return Fail("message is required");
        string tyErr;
        ChatMsgTy ty;
        if (!ParseChatType(JsonStr(opts, "type", "room"), ty, tyErr)) return Fail(tyErr);
        g_MTConn.SendChatMessage(ty, msg);
        auto o = Json::Object();
        o["ok"] = true;
        o["sent"] = true;
        o["type"] = ChatTypeName(ty);
        o["length"] = int(msg.Length);
        return o;
    }

    Json::Value@ GetChat(Json::Value &in opts) {
        if (g_MTConn is null) return Fail("not connected");
        uint limit = JsonUint(opts, "limit", DefaultChatLimit);
        auto msgs = g_MTConn.serverChat.messages;
        uint start = 0;
        if (limit > 0 && msgs.Length > limit) start = msgs.Length - limit;
        auto arr = Json::Array();
        for (uint i = start; i < msgs.Length; i++) {
            arr.Add(ChatToJson(msgs[i]));
        }
        auto o = Json::Object();
        o["ok"] = true;
        o["messages"] = arr;
        o["count"] = int(arr.Length);
        o["total"] = int(msgs.Length);
        return o;
    }

    Json::Value@ FocusPlayer(Json::Value &in opts) {
        if (g_MTConn is null) return Fail("not connected");
        auto p = FindPlayer(JsonStr(opts, "name"), JsonStr(opts, "id"));
        if (p is null) return Fail("player not found");
        bool lockCam = JsonBool(opts, "lock", false);
        p.FocusEditorCamera(lockCam);
        auto o = Json::Object();
        o["ok"] = true;
        o["focused"] = p.name;
        o["locked"] = lockCam;
        return o;
    }

    Json::Value@ UnlockCamera(Json::Value &in opts) {
        UnlockEditorCamera();
        auto o = Json::Object();
        o["ok"] = true;
        o["unlocked"] = true;
        return o;
    }

    Json::Value@ SetActionLimit(Json::Value &in opts) {
        if (g_MTConn is null || !g_MTConn.IsConnected) return Fail("not connected");
        if (!g_MTConn.HasLocalAdmin()) return Fail("local player is not a room admin");
        uint limit = JsonUint(opts, "msBetween", 0);
        if (opts.HasKey("hz")) {
            float hz = JsonFloat(opts, "hz", 0.0);
            limit = uint(Math::Round(HzToActionLimit(hz)));
        }
        g_MTConn.WriteSetActionLimit(limit);
        auto o = GetStatus();
        o["requestedLimit"] = int(limit);
        return o;
    }

    Json::Value@ SetDropPendingUpdates(Json::Value &in opts) {
        bool drop = JsonBool(opts, "drop", true);
        bool was = g_DropMsgsTemp;
        g_DropMsgsTemp = drop;
        if (drop && !was) startnew(OnEnabled_DropMsgsTemp);
        auto o = Json::Object();
        o["ok"] = true;
        o["dropPendingUpdates"] = g_DropMsgsTemp;
        return o;
    }

    Json::Value@ ClearPurpleBoxes(Json::Value &in opts) {
        OnClick_ClearPurpleBoxes();
        auto o = Json::Object();
        o["ok"] = true;
        o["cleared"] = true;
        return o;
    }

    Json::Value@ SetWindowOpen(Json::Value &in opts) {
        g_WindowOpen = JsonBool(opts, "open", true);
        return GetStatus();
    }

    Json::Value@ SetClubItemPatches(Json::Value &in opts) {
        bool disable = JsonBool(opts, "disableClubItems", false);
        bool skip = JsonBool(opts, "skipClubFavUpdate", false);
        m_DisableClubItems_Patch = disable;
        m_EnableClubItemsSkip = skip && !disable;
        if (disable) {
            EditorPatches::DisableClubItems_IsApplied = true;
        } else if (skip) {
            EditorPatches::SkipClubFavItemUpdate_IsApplied = true;
        } else {
            EditorPatches::UnapplyAny();
        }
        return GetStatus();
    }

    Json::Value@ SetUiFlags(Json::Value &in opts) {
        if (opts.HasKey("renderPlayers")) S_RenderPlayersNvg = JsonBool(opts, "renderPlayers", S_RenderPlayersNvg);
        if (opts.HasKey("statusHud")) S_RenderStatusHUD = JsonBool(opts, "statusHud", S_RenderStatusHUD);
        if (opts.HasKey("drawOwnLabels")) S_DrawOwnLabels = JsonBool(opts, "drawOwnLabels", S_DrawOwnLabels);
        if (opts.HasKey("statusEventsOnScreen")) S_StatusEventsOnScreen = JsonBool(opts, "statusEventsOnScreen", S_StatusEventsOnScreen);
        return GetStatus();
    }

    Json::Value@ GetRecentRooms(Json::Value &in opts) {
        if (RecentRooms is null) LoadRecentRooms();
        auto arr = Json::Array();
        if (RecentRooms !is null && RecentRooms.GetType() == Json::Type::Array) {
            for (uint i = 0; i < RecentRooms.Length; i++) {
                arr.Add(RecentRooms[i]);
            }
        }
        auto o = Json::Object();
        o["ok"] = true;
        o["rooms"] = arr;
        o["count"] = int(arr.Length);
        return o;
    }

    Json::Value@ CheckDesync(Json::Value &in opts) {
        UpdateSessionFlags();
        if (!IsInEditor) return Fail("must be in the map editor");
        if (g_MTConn is null) return Fail("not connected");
        bool fix = JsonBool(opts, "fix", false);
        Editor::CheckForDesyncObjects(false);
        if (fix) {
            _mWasYoloModeEnabled = S_YoloMode;
            S_YoloMode = false;
            if (Editor::desyncLastExtra !is null) {
                g_MTConn.pendingUpdates.InsertLast(MTDeleteUpdate(Editor::desyncLastExtra));
            }
            if (Editor::desyncLastMissing !is null) {
                g_MTConn.pendingUpdates.InsertLast(MTPlaceUpdate(Editor::desyncLastMissing.PopulateMacroblock(Editor::MakeMacroblockSpec())));
            }
            startnew(CheckDesyncAgainSoon);
        }
        auto o = Json::Object();
        o["ok"] = true;
        o["fix"] = fix;
        o["extra"] = Editor::desyncLastExtra is null ? -1 : int(Editor::desyncLastExtra.Length);
        o["missing"] = Editor::desyncLastMissing is null ? -1 : int(Editor::desyncLastMissing.Length);
        return o;
    }

    Json::Value@ UndoUpdate(Json::Value &in opts) {
        if (g_MTConn is null || !g_MTConn.IsConnected) return Fail("not connected");
        if (!g_MTConn.HasLocalAdmin()) return Fail("local player is not a room admin");
        auto @log = g_MTConn.updateLog;
        if (log.Length == 0) return Fail("no undoable updates");
        int idx = opts.HasKey("index") ? int(opts["index"]) : int(log.Length) - 1;
        if (idx < 0) idx = int(log.Length) + idx;
        if (idx < 0 || uint(idx) >= log.Length) return Fail("update index out of range");
        auto upd = log[uint(idx)];
        if (upd is null) return Fail("update is null");
        g_MTConn.WriteUpdate(upd.Invese());
        auto o = Json::Object();
        o["ok"] = true;
        o["index"] = idx;
        o["summary"] = upd.SummaryText;
        return o;
    }

    Json::Value@ ListServers(Json::Value &in opts) {
        auto arr = Json::Array();
        AddServer(arr, MTServers::Au);
        AddServer(arr, MTServers::De);
        AddServer(arr, MTServers::Us);
        AddServer(arr, MTServers::Dev);
        auto o = Json::Object();
        o["ok"] = true;
        o["servers"] = arr;
        o["current"] = ServerKey(m_CurrServer);
        return o;
    }

    bool ParseServer(const string &in raw, MTServers &out server, string &out err) {
        string s = raw.ToLower();
        if (s.Length == 0 || s == "de" || s == "germany") {
            server = MTServers::De;
            err = "";
            return true;
        }
        if (s == "au" || s == "australia") {
            server = MTServers::Au;
            err = "";
            return true;
        }
        if (s == "us" || s == "united states" || s == "usa") {
            server = MTServers::Us;
            err = "";
            return true;
        }
        if (s == "dev" || s == "development") {
            server = MTServers::Dev;
            err = "";
            return true;
        }
        err = "unknown server: " + raw + " (use Au, De, Us, Dev)";
        return false;
    }

    bool ParseMood(const string &in raw, MapMood &out mood, string &out err) {
        string s = raw.ToLower();
        if (s.Length == 0 || s == "day") { mood = MapMood::Day; err = ""; return true; }
        if (s == "night") { mood = MapMood::Night; err = ""; return true; }
        if (s == "sunset") { mood = MapMood::Sunset; err = ""; return true; }
        if (s == "sunrise") { mood = MapMood::Sunrise; err = ""; return true; }
        err = "unknown mood: " + raw;
        return false;
    }

    bool ParseBase(const string &in raw, MapBase &out base, string &out err) {
        string s = raw.ToLower();
        s = s.Replace(" ", "");
        if (s.Length == 0 || s == "stadium155" || s == "155") { base = MapBase::Stadium155; err = ""; return true; }
        if (s == "nostadium") { base = MapBase::NoStadium; err = ""; return true; }
        if (s == "stadiumold" || s == "old") { base = MapBase::StadiumOld; err = ""; return true; }
        err = "unknown base: " + raw;
        return false;
    }

    bool ParseEnv(const string &in raw, MapEnv &out env, string &out err) {
        string s = raw.ToLower();
        s = s.Replace(" ", "");
        if (s.Length == 0 || s == "stadium") { env = MapEnv::Stadium; err = ""; return true; }
        if (s == "redisland") { env = MapEnv::RedIsland; err = ""; return true; }
        if (s == "greencoast") { env = MapEnv::GreenCoast; err = ""; return true; }
        if (s == "bluebay") { env = MapEnv::BlueBay; err = ""; return true; }
        if (s == "whiteshore") { env = MapEnv::WhiteShore; err = ""; return true; }
        err = "unknown environment: " + raw;
        return false;
    }

    bool ParseCar(const string &in raw, MapCar &out car, string &out err) {
        string s = raw.ToLower();
        s = s.Replace(" ", "");
        if (s.Length == 0 || s == "carsport" || s == "stadium" || s == "default") { car = MapCar::CarSport; err = ""; return true; }
        if (s == "carsnow" || s == "snow") { car = MapCar::CarSnow; err = ""; return true; }
        if (s == "carrally" || s == "rally") { car = MapCar::CarRally; err = ""; return true; }
        if (s == "cardesert" || s == "desert") { car = MapCar::CarDesert; err = ""; return true; }
        err = "unknown car: " + raw;
        return false;
    }

    string ApplyCreateOpts(Json::Value &in opts) {
        string err = ApplySharedRoomOpts(opts);
        if (err.Length > 0) return err;
        if (!ParseMood(JsonStr(opts, "mood"), m_Mood, err)) return err;
        if (!ParseBase(JsonStr(opts, "base"), m_Base, err)) return err;
        if (!ParseEnv(JsonStr(opts, "env"), m_Env, err)) return err;
        if (!ParseCar(JsonStr(opts, "car"), m_Car, err)) return err;
        if (opts.HasKey("env")) {
            // same per-env default the UI env combo applies: custom
            // environments are natively 64x64, Stadium is 48x48. Explicit
            // size opts below still win.
            m_Size.x = m_Env == MapEnv::Stadium ? 48 : 64;
            m_Size.z = m_Size.x;
        }
        ApplySizeOpts(opts);
        return "";
    }

    string ApplyInviteOpts(Json::Value &in opts) {
        return ApplySharedRoomOpts(opts);
    }

    string ApplyJoinOpts(Json::Value &in opts) {
        string err;
        if (opts.HasKey("server") && !ParseServer(JsonStr(opts, "server"), m_CurrServer, err)) return err;
        string roomId = NormalizeRoomId(JsonStr(opts, "roomId"));
        if (roomId.Length == 0) return "roomId is required";
        if (RoomIdHasServerPrefix(roomId)) {
            m_CurrServer = ServerFromRoomId(roomId);
        }
        string roomIdNoServer = GetRoomIdNoServer(roomId);
        if (roomIdNoServer.Length != 6) return "roomId must be 6 characters (or include a server prefix)";
        m_RoomId = roomId;
        m_Password = JsonStr(opts, "password");
        ApplyPatchOpts(opts);
        return "";
    }

    string ApplySharedRoomOpts(Json::Value &in opts) {
        string err;
        if (opts.HasKey("server") && !ParseServer(JsonStr(opts, "server"), m_CurrServer, err)) return err;
        if (opts.HasKey("password")) m_Password = JsonStr(opts, "password");
        if (opts.HasKey("playerLimit")) {
            m_PlayerLimit = uint16(Math::Clamp(int(JsonUint(opts, "playerLimit", 8)), 2, 0xFFFF));
        }
        if (opts.HasKey("actionLimitMs")) m_newRoomActionLimit = JsonUint(opts, "actionLimitMs", 0);
        if (opts.HasKey("allowCustomItems")) m_AllowCustomItems = JsonBool(opts, "allowCustomItems", false);
        if (opts.HasKey("allowSweeps")) m_AllowSweeps = JsonBool(opts, "allowSweeps", false);
        if (opts.HasKey("allowSelectionCut")) m_AllowSelectionCut = JsonBool(opts, "allowSelectionCut", false);
        ApplyPatchOpts(opts);
        return "";
    }

    void ApplyPatchOpts(Json::Value &in opts) {
        if (opts.HasKey("disableClubItems")) m_DisableClubItems_Patch = JsonBool(opts, "disableClubItems", false);
        if (opts.HasKey("skipClubFavUpdate")) m_EnableClubItemsSkip = JsonBool(opts, "skipClubFavUpdate", true);
    }

    void ApplySizeOpts(Json::Value &in opts) {
        if (opts.HasKey("size") && opts["size"].GetType() == Json::Type::Array && opts["size"].Length >= 3) {
            m_Size.x = ClampDim(uint(int(opts["size"][0])));
            m_Size.y = ClampDim(uint(int(opts["size"][1])));
            m_Size.z = ClampDim(uint(int(opts["size"][2])));
        } else {
            if (opts.HasKey("sizeX") || opts.HasKey("x")) m_Size.x = ClampDim(JsonUint(opts, opts.HasKey("sizeX") ? "sizeX" : "x", m_Size.x));
            if (opts.HasKey("sizeY") || opts.HasKey("y")) m_Size.y = ClampDim(JsonUint(opts, opts.HasKey("sizeY") ? "sizeY" : "y", m_Size.y));
            if (opts.HasKey("sizeZ") || opts.HasKey("z")) m_Size.z = ClampDim(JsonUint(opts, opts.HasKey("sizeZ") ? "sizeZ" : "z", m_Size.z));
        }
        m_SizeX = m_Size.x;
        m_SizeY = m_Size.y;
        m_SizeZ = m_Size.z;
    }

    uint ClampDim(uint v) {
        if (v < 8) return 8;
        if (v > 255) return 255;
        return v;
    }

    bool ParseChatType(const string &in raw, ChatMsgTy &out ty, string &out err) {
        string s = raw.ToLower();
        if (s.Length == 0 || s == "room") { ty = ChatMsgTy::Room; err = ""; return true; }
        if (s == "server") { ty = ChatMsgTy::Server; err = ""; return true; }
        if (s == "team") { ty = ChatMsgTy::Team; err = ""; return true; }
        if (s == "whisper") { ty = ChatMsgTy::Whisper; err = ""; return true; }
        err = "unknown chat type: " + raw;
        return false;
    }

    string JsonStr(Json::Value@ o, const string &in key, const string &in def = "") {
        if (o is null || o.GetType() != Json::Type::Object || !o.HasKey(key)) return def;
        if (o[key].GetType() != Json::Type::String) return def;
        return string(o[key]);
    }

    bool JsonBool(Json::Value@ o, const string &in key, bool def) {
        if (o is null || o.GetType() != Json::Type::Object || !o.HasKey(key)) return def;
        if (o[key].GetType() != Json::Type::Boolean) return def;
        return bool(o[key]);
    }

    uint JsonUint(Json::Value@ o, const string &in key, uint def) {
        if (o is null || o.GetType() != Json::Type::Object || !o.HasKey(key)) return def;
        auto t = o[key].GetType();
        if (t == Json::Type::Number) return uint(int(o[key]));
        return def;
    }

    float JsonFloat(Json::Value@ o, const string &in key, float def) {
        if (o is null || o.GetType() != Json::Type::Object || !o.HasKey(key)) return def;
        if (o[key].GetType() != Json::Type::Number) return def;
        return float(o[key]);
    }

    Json::Value@ Fail(const string &in error) {
        auto o = Json::Object();
        o["ok"] = false;
        o["error"] = error;
        return o;
    }

    Json::Value@ Started(const string &in action) {
        auto o = GetStatus();
        o["ok"] = true;
        o["started"] = true;
        o["action"] = action;
        return o;
    }

    bool Busy() {
        return g_MTConn !is null && !g_MTConn.hasErrored && !g_MTConn.IsShutdown;
    }

    string StageName(ConnectionStage stage) {
        switch (stage) {
            case ConnectionStage::None: return "none";
            case ConnectionStage::GettingAuthToken: return "auth";
            case ConnectionStage::ConnectingToServer: return "connecting";
            case ConnectionStage::Joining: return "joining";
            case ConnectionStage::Creating: return "creating";
            case ConnectionStage::OpeningEditor: return "openingEditor";
            case ConnectionStage::Done: return "done";
        }
        return "unknown";
    }

    string ServerKey(MTServers server) {
        switch (server) {
            case MTServers::Au: return "Au";
            case MTServers::De: return "De";
            case MTServers::Us: return "Us";
            case MTServers::Dev: return "Dev";
        }
        return "De";
    }

    string MapMoodKey(MapMood mood) {
        switch (mood) {
            case MapMood::Night: return "night";
            case MapMood::Sunset: return "sunset";
            case MapMood::Sunrise: return "sunrise";
        }
        return "day";
    }

    string MapBaseKey(MapBase base) {
        switch (base) {
            case MapBase::NoStadium: return "nostadium";
            case MapBase::StadiumOld: return "stadiumold";
        }
        return "stadium155";
    }

    string MapEnvKey(MapEnv env) {
        switch (env) {
            case MapEnv::RedIsland: return "redisland";
            case MapEnv::GreenCoast: return "greencoast";
            case MapEnv::BlueBay: return "bluebay";
            case MapEnv::WhiteShore: return "whiteshore";
        }
        return "stadium";
    }

    string MapCarKey(MapCar car) {
        switch (car) {
            case MapCar::CarSnow: return "carsnow";
            case MapCar::CarRally: return "carrally";
            case MapCar::CarDesert: return "cardesert";
        }
        return "carsport";
    }

    string ChatTypeName(ChatMsgTy ty) {
        switch (ty) {
            case ChatMsgTy::Server: return "server";
            case ChatMsgTy::Team: return "team";
            case ChatMsgTy::Whisper: return "whisper";
        }
        return "room";
    }

    Json::Value Nat3ToJson(const nat3 &in v) {
        auto a = Json::Array();
        a.Add(int(v.x));
        a.Add(int(v.y));
        a.Add(int(v.z));
        return a;
    }

    Json::Value@ PlayerToJson(PlayerInRoom@ p) {
        auto o = Json::Object();
        if (p is null) return o;
        o["name"] = p.name;
        o["id"] = p.id;
        o["inRoom"] = p.isInRoom;
        o["admin"] = p.isAdmin;
        o["mod"] = p.isMod;
        o["local"] = p.isLocal;
        o["title"] = p.customTitle;
        o["lastUpdate"] = p.lastUpdate == PlayerUpdateTy::Cursor ? "cursor" : "vehicle";
        o["testing"] = p.isTesting;
        o["skinUrl"] = p.skinUrl;
        o["blocksPlaced"] = int(p.blocksPlaced);
        o["blocksRemoved"] = int(p.blocksRemoved);
        o["itemsPlaced"] = int(p.itemsPlaced);
        o["itemsRemoved"] = int(p.itemsRemoved);
        o["skinsChanged"] = int(p.skinsChanged);
        return o;
    }

    Json::Value@ ChatToJson(ChatMessage@ msg) {
        auto o = Json::Object();
        if (msg is null) return o;
        o["type"] = ChatTypeName(msg.msgTy);
        o["message"] = msg.message;
        o["timestamp"] = int(msg.timestamp);
        if (msg.player !is null) {
            o["player"] = msg.player.name;
            o["playerId"] = msg.player.id;
        }
        return o;
    }

    PlayerInRoom@ FindPlayer(const string &in name, const string &in id) {
        if (g_MTConn is null) return null;
        string nameL = name.ToLower();
        for (uint i = 0; i < g_MTConn.playersEver.Length; i++) {
            auto p = g_MTConn.playersEver[i];
            if (p is null) continue;
            if (id.Length > 0 && p.id == id) return p;
            if (nameL.Length > 0 && p.name.ToLower() == nameL) return p;
        }
        return null;
    }

    void AddServer(Json::Value@ arr, MTServers server) {
        auto o = Json::Object();
        o["id"] = ServerKey(server);
        o["name"] = ServerToName(server);
        o["endpoint"] = ServerToEndpoint(server);
        arr.Add(o);
    }
}

#else

namespace MapTogether {
    Json::Value@ GetStatus() { return FailNoEditor(); }
    Json::Value@ SetServer(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ CreateRoom(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ InviteCurrentMap(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ JoinRoom(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ Disconnect(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ WaitUntilReady(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ WaitUntilIdle(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ GetPlayers(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SendChat(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ GetChat(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ FocusPlayer(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ UnlockCamera(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SetActionLimit(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SetDropPendingUpdates(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ ClearPurpleBoxes(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SetWindowOpen(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SetClubItemPatches(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ SetUiFlags(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ GetRecentRooms(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ CheckDesync(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ UndoUpdate(Json::Value &in opts) { return FailNoEditor(); }
    Json::Value@ ListServers(Json::Value &in opts) { return FailNoEditor(); }

    Json::Value@ FailNoEditor() {
        auto o = Json::Object();
        o["ok"] = false;
        o["error"] = "Editor++ is required";
        return o;
    }
}

#endif

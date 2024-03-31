const uint meta_bytes = 46;

// const uint8 MAP_MOOD_DAY = 0;
// const uint8 MAP_MOOD_NIGHT = 1;
// const uint8 MAP_MOOD_SUNSET = 2;
// const uint8 MAP_MOOD_SUNRISE = 3;
const uint8 MAP_BASE_NOSTADIUM  = 0b00100000;
const uint8 MAP_BASE_STADIUM    = 0b01000000;
const uint8 MAP_BASE_STADIUM155 = 0b10000000;

uint32 COUNT_MESSAGES_READ = 0;

enum ConnectionStage {
    None, GettingAuthToken, ConnectingToServer, Joining, Creating, OpeningEditor, Done
}

ConnectionStage g_ConnectionStage = ConnectionStage::None;

class MapTogetherConnection {
    protected Net::Socket@ socket;
    string op_token;
    bool hasErrored = false;
    string error;

    MTServers server;
    string remote_domain;
    string roomId;
    string roomPassword;
    uint actionRateLimit;
    nat3 mapSize;
    uint8 mapBase;
    uint8 baseCar;
    uint8 rulesFlags;
    uint itemMaxSize;
    uint16 playerLimit;
    MapBase mapBaseName;
    MapMood mapBaseMood;

    PlayerInRoom@[] playersInRoom;
    uint[] playersInRoomIds;
    PlayerInRoom@[] playersEver;
    uint[] playersEverIds;
    PlayerInRoom@[] admins;
    PlayerInRoom@[] mods;
    dictionary names;
    Editor::MacroblockSpec@ firstMB;
    bool logAllUpdates = false;
    MTUpdateUndoable@[] updateLog;
    MTSetSkinUpdate@[] setSkinLog;

    uint totalBlocksPlaced;
    uint totalBlocksRemoved;
    uint totalItemsPlaced;
    uint totalItemsRemoved;

    StatusMsgUI@ statusMsgs = StatusMsgUI();
    ServerChat@ serverChat = ServerChat();

    // create a room
    MapTogetherConnection(const string &in password, bool expectEditorImmediately,
        uint roomMsBetweenActions = 0,
        nat3 _mapSize = nat3(80, 255, 80), uint8 _mapBase = 128, uint8 _baseCar = 0,
        uint8 _rulesFlags = 0, uint _itemMaxSize = 0, uint16 _roomPlayerLimit = 0xFFFF
    ) {
        g_ConnectionStage = ConnectionStage::None;
        server = m_CurrServer;
        remote_domain = ServerToEndpoint(m_CurrServer);
        log_info("Creating new room on server: " + remote_domain);
        IS_CONNECTING = true;
        InitSock();
        log_info('Connected to server');
        if (socket is null) {
            log_warn("socket is null");
            return;
        }
        g_ConnectionStage = ConnectionStage::Creating;
        // 1 = create
        log_trace('writing room request type');
        socket.Write(uint8(1));
        roomPassword = password;
        log_trace('writing room pw');
        WriteLPString(socket, roomPassword);
        log_trace('writing room action limit: ' + roomMsBetweenActions);
        socket.Write(roomMsBetweenActions);
        log_trace('writing room map size: ' + _mapSize.ToString());
        socket.Write(uint8(_mapSize.x));
        socket.Write(uint8(_mapSize.y));
        socket.Write(uint8(_mapSize.z));
        log_trace('writing room map base: ' + _mapBase);
        socket.Write(uint8(_mapBase));
        log_trace('writing room base car: ' + _baseCar);
        socket.Write(uint8(_baseCar));
        log_trace('writing room rules flags: ' + _rulesFlags);
        socket.Write(uint8(_rulesFlags));
        log_trace('writing room item max size: ' + _itemMaxSize);
        socket.Write(_itemMaxSize);
        log_trace('writing player limit (room size): ' + _roomPlayerLimit);
        socket.Write(_roomPlayerLimit);


        log_info('Sent create room request');
        ExpectOKResp();
        log_info('Got okay response');
        ExpectRoomDetails();
        log_info('Got room details');

        if (socket is null) {
            log_warn("socket is null");
            return;
        }

        g_ConnectionStage = ConnectionStage::OpeningEditor;
        this.expectEditorImmediately = expectEditorImmediately;
        startnew(CoroutineFunc(this.Connected_WaitingForEditor));
    }

    // join a room
    MapTogetherConnection(const string &in roomId, const string &in password = "") {
        remote_domain = ServerToEndpoint(m_CurrServer);
        log_info("Joining room on server: " + remote_domain);
        IS_CONNECTING = true;
        InitSock();
        g_ConnectionStage = ConnectionStage::Joining;
        if (socket is null) {
            log_warn("socket is null");
            return;
        }
        // 2 = join
        log_trace('writing room request type');
        socket.Write(uint8(2));
        WriteLPString(socket, roomId);
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        ExpectOKResp();
        log_info("Got okay response");
        ExpectRoomDetails();
        log_info("Got room details");

        if (socket is null) {
            log_warn("socket is null");
            return;
        }

        g_ConnectionStage = ConnectionStage::OpeningEditor;
        expectEditorImmediately = false;
        startnew(CoroutineFunc(this.Connected_WaitingForEditor));
    }

    bool expectEditorImmediately;
    void Connected_WaitingForEditor() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (expectEditorImmediately) {
            if (editor is null) {
                NotifyError("Expected to be in editor already.");
                while ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null) yield();
                while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
            }
            this.SendMapAsMacroblock();
        } else {
            if (editor is null) Notify("Waiting to enter editor...");
            while ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null) yield();
            while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        }

        startnew(Editor::EditorFeedGen_Loop);
        startnew(CoroutineFunc(this.ReadUpdatesLoop));
        IS_CONNECTING = false;
        g_ConnectionStage = ConnectionStage::Done;
    }

    bool get_IsConnected() {
        return socket !is null && !hasErrored && roomId.Length == 6;
    }
    bool get_IsConnecting() {
        return socket !is null && !hasErrored && roomId.Length == 0;
    }
    bool get_IsShutdown() {
        return socket is null || hasErrored;
    }
    float get_ActionLimitHz() {
        return ActionLimitToHz(actionRateLimit);
    }
    const string LookupName(const string &in id) {
        if (names.Exists(id)) {
            return string(names[id]);
        }
        return id;
    }

    void ExpectRoomDetails() {
        if (!ExpectOKResp()) {
            log_warn('ExpectRoomDetails: not ok. Msg: ' + error);
            return;
        }
        log_trace('Expecting room details, avail: ' + socket.Available());
        log_trace('socket can read: ' + socket.CanRead());
        while (!socket.CanRead() && socket.Available() < 2) yield();
        log_trace('Got enough bytes to read len. avail: ' + socket.Available());
        roomId = ReadLPString(socket);
        log_trace("Read room id: " + roomId);
        if (roomId.Length != 6) {
            CloseWithErr("Invalid room id from server: " + roomId);
            return;
        }
        m_RoomId = roomId;
        actionRateLimit = socket.ReadUint32();
        log_info("Read action rate limit: " + actionRateLimit);
        mapSize.x = socket.ReadUint8();
        mapSize.y = socket.ReadUint8();
        mapSize.z = socket.ReadUint8();
        log_info("Read map size: " + mapSize.ToString());
        mapBase = socket.ReadUint8();
        log_info("Read map base: " + mapBase);
        mapBaseName = EncodedMapBaseToName(mapBase);
        mapBaseMood = EncodedMapBaseToMood(mapBase);
        baseCar = socket.ReadUint8();
        log_info("Read base car: " + baseCar);
        rulesFlags = socket.ReadUint8();
        log_info("Read rules flags: " + rulesFlags);
        itemMaxSize = socket.ReadUint32();
        log_info("Read item max size: " + itemMaxSize);
        playerLimit = socket.ReadUint16();
        log_info("Read player limit: " + playerLimit);
    }

    bool ExpectOKResp() {
        log_trace('Expecting OK response');
        while (!socket.CanRead() && socket.Available() < 3) yield();
        log_trace('Got enough bytes to read, avail: ' + socket.Available());
        auto resp = socket.ReadRaw(3);
        log_trace('Read bytes OK_/ERR, avail: ' + socket.Available());
        if (resp == "OK_") return true;
        log_trace("Not OK_, got: " + resp);
        if (resp != "ERR") {
            CloseWithErr("Unexpected response from server: " + resp);
        } else {
            auto msg = ReadLPString(socket);
            CloseWithErr("Error from Server: " + msg);
        }
        return false;
    }

    protected void InitSock() {
        g_ConnectionStage = ConnectionStage::GettingAuthToken;
        string op_token = GetAuthToken();
        g_ConnectionStage = ConnectionStage::ConnectingToServer;
        // log_trace('token: ' + op_token);
        @this.socket = Net::Socket();
        uint startTime = Time::Now;
        auto timeoutAt = Time::Now + 7500;
        log_info('Connecting to: ' + remote_domain + ':19796');
        if (!socket.Connect(remote_domain, 19796)) {
            CloseWithErr("Failed to connect to MapTogether server");
            return;
        }
        while (Time::Now < timeoutAt && !socket.CanWrite() && !socket.CanRead()) {
            yield();
        }
        if (Time::Now >= timeoutAt) {
            CloseWithErr("Failed to connect to MapTogether server: timeout");
            return;
        } else {
            log_warn("Connected in " + (Time::Now - startTime) + " ms");
        }
        log_info('Connected to: ' + remote_domain + ':19796');
        if (!socket.Write(uint16(op_token.Length))) {
            CloseWithErr("Failed to write auth token length");
            return;
        }
        if (!socket.WriteRaw(op_token)) {
            CloseWithErr("Failed to write auth token");
            return;
        }
        log_info('Sent auth to server');
        // send version details
        socket.Write(uint8(0xFF));
        socket.Write(uint8(0x04));
        socket.Write(uint8(0x80));
    }

    protected void CloseWithErr(const string &in err) {
        NotifyError(err);
        if (socket is null) return;
        hasErrored = true;
        error = err;
        socket.Close();
        @socket = null;
    }

    void Close() {
        if (socket is null) return;
        // todo: tell leaving
        socket.Close();
        @socket = null;
    }

    protected int ignorePlace = 0;
    protected int ignorePlaceSkins = 0;

    void SendMapAsMacroblock() {
        auto mapMb = Editor::GetMapAsMacroblock();
        if (mapMb.macroblock.Blocks.Length == 0 && mapMb.macroblock.Items.Length == 0) {
            // nothing to send, so don't
            return;
        }
        ignorePlace++;
        ignorePlaceSkins += mapMb.setSkins.Length;
        this.WritePlaced(mapMb.macroblock);
        this.WriteSetSkins(mapMb.setSkins);
    }

    void WriteUpdate(MTUpdateUndoable@ update) {
        if (socket is null) return;
        if (update is null) return;
        auto place = cast<MTPlaceUpdate>(update);
        if (place !is null) {
            WritePlaced(place.mb);
            return;
        }
        auto del = cast<MTDeleteUpdate>(update);
        if (del !is null) {
            WriteDeleted(del.mb);
            return;
        }
        auto skin = cast<MTSetSkinUpdate>(update);
        if (skin !is null) {
            WriteSetSkins({skin.skin});
            return;
        }
    }

    void WriteSetSkins(const Editor::SetSkinSpec@[]@ skins) {
        if (socket is null) return;
        if (skins is null) return;
        if (skins.Length == 0) return;
        MemoryBuffer@ buf;
        auto nbSkins = skins.Length;
        for (uint i = 0; i < nbSkins; i++) {
            @buf = MemoryBuffer();
            skins[i].WriteToNetworkBuffer(buf);
            buf.Seek(0);
            socket.Write(uint8(MTUpdateTy::SetSkin));
            socket.Write(uint32(buf.GetSize()));
            socket.Write(buf, buf.GetSize());
        }
    }

    void WritePlaced(Editor::MacroblockSpec@ mb) {
        if (socket is null) return;
        socket.Write(uint8(MTUpdateTy::Place));
        auto buf = MemoryBuffer();
        mb.WriteToNetworkBuffer(buf);
        // if (mb.blocks.Length > 0) {
        //     log_trace('Writing placed: mb.blocks[0].mobilVariant: ' + mb.blocks[0].mobilVariant);
        // }
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    void WriteDeleted(Editor::MacroblockSpec@ mb) {
        if (socket is null) return;
        socket.Write(uint8(MTUpdateTy::Delete));
        auto buf = MemoryBuffer();
        mb.WriteToNetworkBuffer(buf);
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    void WriteVehiclePos(const VehiclePos@ pos) {
        if (socket is null) return;
        socket.Write(uint8(MTUpdateTy::VehiclePos));
        auto buf = MemoryBuffer();
        pos.WriteToNetworkBuffer(buf);
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    void WritePlayerCamCursor(const PlayerCamCursor@ cursor) {
        if (socket is null) return;
        socket.Write(uint8(MTUpdateTy::PlayerCamCursor));
        auto buf = MemoryBuffer();
        cursor.WriteToNetworkBuffer(buf);
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    void WriteSetActionLimit(uint limit) {
        if (socket is null) return;
        if (!HasLocalAdmin()) return;
        socket.Write(uint8(MTUpdateTy::Admin_SetActionLimit));
        socket.Write(uint32(4));
        socket.Write(uint32(limit));
    }

    void SendChatMessage(ChatMsgTy msgTy, const string &in msg) {
        if (socket is null) return;
        socket.Write(uint8(MTUpdateTy::ChatMsg));
        socket.Write(uint32(msg.Length + 3));
        socket.Write(uint8(msgTy));
        WriteLPString(socket, msg);
    }

    // not used
    bool PauseAutoRead = false;
    MTUpdate@[] pendingUpdates;
    uint msgsRead = 0;

    void ReadUpdatesLoop() {
        MTUpdate@ next;
        while (IsConnecting) yield();
        while (IsConnected) {
            // while (PauseAutoRead) yield();
            @next = ReadMTUpdateMsg();
            COUNT_MESSAGES_READ++;
            if (COUNT_MESSAGES_READ % 100 == 0) {
                log_info("[Cumulative] Have read " + COUNT_MESSAGES_READ + " messages");
            }
            if (next !is null) {
                if (ignorePlace > 0 && next.ty == MTUpdateTy::Place) {
                    ignorePlace--;
                } else if (ignorePlaceSkins > 0 && next.ty == MTUpdateTy::SetSkin) {
                    ignorePlaceSkins--;
                } else if (next.ty == MTUpdateTy::PlayerJoin
                    || next.ty == MTUpdateTy::PlayerLeave
                    || next.ty == MTUpdateTy::PlayerCamCursor
                    || next.ty == MTUpdateTy::VehiclePos
                    || next.ty == MTUpdateTy::Admin_SetActionLimit
                    || next.ty == MTUpdateTy::ChatMsg
                ) {
                    next.Apply(null);
                } else if (next.ty == MTUpdateTy::SetSkin) {
                    auto skin = cast<MTSetSkinUpdate>(next);
                    setSkinLog.InsertLast(skin);
                    pendingUpdates.InsertLast(next);
                } else {
                    pendingUpdates.InsertLast(next);
                }
                if (logAllUpdates && next.isUndoable) {
                    updateLog.InsertLast(cast<MTUpdateUndoable>(next));
                }
                msgsRead++;
                RecordUserStats(next);
            } else {
                if (socket is null) {
                    log_trace('socket is null, breaking read updates loop');
                    return;
                } else {
                    log_warn("got null message in update loop");
                }
                yield();
            }


            // // pendingUpdates
            // if (updates !is null) {
            //     for (uint i = 0; i < updates.Length; i++) {
            //         pendingUpdates.InsertLast(updates[i]);
            //     }
            // }
            // yield();
        }
    }

    void RecordUserStats(MTUpdate@ update) {
        if (update is null) return;

        auto place = cast<MTPlaceUpdate>(update);
        auto del = cast<MTDeleteUpdate>(update);
        if (place !is null) {
            totalBlocksPlaced += place.mb.blocks.Length;
            totalItemsPlaced += place.mb.items.Length;
        } else if (del !is null) {
            totalBlocksRemoved += del.mb.blocks.Length;
            totalItemsRemoved += del.mb.items.Length;
        }

        auto p = FindPlayerInRoom(update.meta.playerMwId);
        if (p is null) {
            @p = FindPlayerEver(update.meta.playerMwId);
            if (p !is null && update.ty != MTUpdateTy::PlayerLeave) {
                AddPlayer(p);
            }
        }
        if (p is null) return;
        p.UpdateStats(update);
    }

    PlayerInRoom@ FindAdmin(const MwId &in playerId) {
        for (uint i = 0; i < admins.Length; i++) {
            if (admins[i].playerMwId.Value == playerId.Value) {
                return admins[i];
            }
        }
        return null;
    }

    PlayerInRoom@ FindPlayerEver(const MwId &in playerId) {
        for (uint i = 0; i < playersEver.Length; i++) {
            if (playersEverIds[i] == playerId.Value) {
                return playersEver[i];
            }
        }
        return null;
    }

    PlayerInRoom@ FindPlayerInRoom(const MwId &in playerId) {
        for (uint i = 0; i < playersInRoom.Length; i++) {
            if (playersInRoomIds[i] == playerId.Value) {
                return playersInRoom[i];
            }
        }
        return null;
    }

    // protected MTUpdate@[]@ ReadUpdates(uint max) {
    //     if (socket is null) return null;
    //     if (socket.Available() < 1) return {};
    //     MTUpdate@[] updates;
    //     uint start = Time::Now;
    //     MTUpdate@ next = ReadMTUpdateMsg(socket);
    //     uint count = 0;
    //     while (next !is null && count < max) {
    //         log_trace('read update: ' + count);
    //         if (ignorePlace > 0 && next.ty == MTUpdateTy::Place) {
    //             ignorePlace--;
    //         } else if (ignorePlaceSkins > 0 && next.ty == MTUpdateTy::SetSkin) {
    //             ignorePlaceSkins--;
    //         } else if (next.ty == MTUpdateTy::PlayerJoin) {
    //             next.Apply(null);
    //         } else if (next.ty == MTUpdateTy::PlayerLeave) {
    //             next.Apply(null);
    //         } else if (next.ty == MTUpdateTy::PlayerCamCursor) {
    //             next.Apply(null);
    //         } else if (next.ty == MTUpdateTy::VehiclePos) {
    //             next.Apply(null);
    //         } else if (next.ty == MTUpdateTy::SetSkin) {
    //             // do nothing => drop set skin messages
    //         } else {
    //             updates.InsertLast(next);
    //         }
    //         @next = ReadMTUpdateMsg(socket);
    //         count++;
    //         if (Time::Now - start > 2) {
    //             log_trace('breaking read loop due to yield');
    //             break;
    //         }
    //     }
    //     log_trace('finished reading: ' + updates.Length);
    //     log_trace('remaining bytes: ' + socket.Available());
    //     return updates;
    // }

    void AddPlayer(PlayerInRoom@ player) {
        if (playersEver.Length == 0) {
            playersEver.InsertLast(player);
            playersEverIds.InsertLast(player.playerMwId.Value);
            playersInRoom.InsertLast(player);
            playersInRoomIds.InsertLast(player.playerMwId.Value);
            names[player.id] = player.name;
            player.isInRoom = true;
            AddAdmin(player);
            statusMsgs.AddGameEvent(MTEventPlayerAdminJoined(player));
            return;
        }
        auto p = FindPlayerInRoom(player.playerMwId);
        if (p !is null) {
            log_warn("Player already in room, but was added again: " + player.name);
            return;
        }
        @p = FindPlayerEver(player.playerMwId);
        if (p is null) {
            playersEver.InsertLast(player);
            playersEverIds.InsertLast(player.playerMwId.Value);
            playersInRoom.InsertLast(player);
            playersInRoomIds.InsertLast(player.playerMwId.Value);
            names[player.id] = player.name;
            if (player.isXertroV) {
                AddAdmin(player);
            }
        } else {
            playersInRoom.InsertLast(p);
            playersInRoomIds.InsertLast(p.playerMwId.Value);
            p.isInRoom = true;
        }
        statusMsgs.AddGameEvent(MTEventPlayerJoined(player));
    }

    bool HasLocalAdmin() {
        for (uint i = 0; i < admins.Length; i++) {
            if (admins[i].isLocal) return true;
        }
        return false;
    }

    void AddAdmin(PlayerInRoom@ player) {
        admins.InsertLast(player);
        player.isAdmin = true;
        if (player.isLocal) {
            UndoRestrictionPatches();
            NotifyWarning("You are now an admin in this room. Restriction patches (no sweeping blocks, etc) have been disabled.");
            logAllUpdates = true;
        }
    }

    void AddMod(PlayerInRoom@ player) {
        mods.InsertLast(player);
        player.isMod = true;
        if (player.isLocal) {
            UndoRestrictionPatches();
            NotifyWarning("You are now a mod in this room. Restriction patches (no sweeping blocks, etc) have been disabled.");
        }
    }

    void RemoveMod(PlayerInRoom@ player) {
        for (uint i = 0; i < mods.Length; i++) {
            if (mods[i].id == player.id) {
                mods.RemoveAt(i);
                player.isMod = false;
                if (player.isLocal) {
                    NotifyWarning("You are no longer a mod in this room. Restriction patches (no sweeping blocks, etc) have been re-enabled.");
                    if (rulesFlags & RulesFlags::AllowSweeps == 0) {
                        Patch_DisableSweeps.Apply();
                    }
                    if (rulesFlags & RulesFlags::AllowSelectionCut == 0) {
                        Patch_DisableCutSelection.Apply();
                    }
                }
            }
        }
    }

    void RemovePlayer(const string &in playerId) {
        for (uint i = 0; i < playersInRoom.Length; i++) {
            if (playersInRoom[i].id == playerId) {
                statusMsgs.AddGameEvent(MTEventPlayerLeft(playersInRoom[i]));
                playersInRoom[i].isInRoom = false;
                playersInRoom.RemoveAt(i);
                playersInRoomIds.RemoveAt(i);
            }
        }
    }

    void UpdatePlayerCamCursor(PlayerCamCursor@ cursor) {
        PlayerInRoom@ player = FindPlayerEver(cursor.meta.playerMwId.Value);
        if (player is null) {
            warn("unexpected: player not found: " + cursor.meta.playerId);
            return;
        }
        player.lastUpdate = PlayerUpdateTy::Cursor;
        player.lastCamCursor.UpdateFrom(cursor);
    }

    void UpdatePlayerVehiclePos(VehiclePos@ pos) {
        PlayerInRoom@ player;
        for (uint i = 0; i < playersInRoom.Length; i++) {
            @player = playersInRoom[i];
            if (player.id == pos.meta.playerId) {
                player.lastUpdate = PlayerUpdateTy::Vehicle;
                player.lastVehiclePos.UpdateFrom(pos);
                return;
            }
        }
    }

    void RenderPlayersNvg() {
        if (!S_RenderPlayersNvg) return;
        PlayerInRoom@ p;
        for (uint i = 0; i < playersInRoom.Length; i++) {
            @p = playersInRoom[i];
            if (p.isLocal && !S_DrawOwnLabels) continue;
            if (p.lastUpdate == PlayerUpdateTy::Cursor) {
                p.lastCamCursor.RenderNvg(p.name);
            } else if (p.lastUpdate == PlayerUpdateTy::Vehicle) {
                p.lastVehiclePos.RenderNvg(p.name);
            }
        }
    }

    void RenderStatusHUD() {
        if (!S_RenderStatusHUD) return;
        RenderMessagesUpdateStatus();
    }

    MsgMeta@ tmpMeta = MsgMeta("asdf", 123);

    MTUpdate@ ReadMTUpdateMsg() {
        // while (!socket.CanRead()) {
        //     yield_why("ReadMTUpdateMsg_SocRead");
        // }
        // auto UpdateHeader = ReadUpdateMsgHeader();
        // while (socket.Available() < UpdateHeader.PayloadLen || !socket.CanRead()) {
        //     yield_why("ReadMTUpdateMsg_DL_Payload");
        // }

        // min size: 17 (u8 + 0u32 + 0u32 + u64)
        while (socket !is null && socket.Available() < 16) {
            yield_why("ReadMTUpdateMsg_LT17BytesAvail");
        }
        if (socket is null) return null;
        auto start_avail = socket.Available();
        auto ty = MTUpdateTy(socket.ReadUint8());
        auto len = socket.ReadUint32();
        log_trace("Reading update type: " + tostring(ty) + " | " + len + " B");
        if (len > 10000000) {
            NotifyError("Netcode issue detected: msg of len > 10MB. Please reload the plugin. Open a fresh map, and rejoin the room.");
            throw('ReadMTUpdateMsg: bad msg length! > 10MB');
        }
        while (socket.Available() < int(len + meta_bytes)) {
            log_trace("Waiting for more bytes to read update: " + len + "; available: " + socket.Available() + "; start_avail: " + start_avail + "; ty: " + ty);
            yield_why("ReadMTUpdateMsg_WaitForLengthBytes");
        }
        uint start = Time::Now;

        // benchmark socket.Available
        // 0.20 ms with no loop
        // 0.45 ms / 1000 with nothing
        // for (uint i = 0; i < 1000; i++) {
        //     x = socket.Available(); // 2ms / 1000
        //     x = GetNbLogMsgs(); // 0.65ms / 1000
        // }


        // auto avail = socket.Available();
        // log_trace("!!!! Read update ("+tostring(ty)+") len: " + Text::Format("0x%08x", len) + "; available: " + socket.Available());
        // if (socket.Available() < int(len)) {
        //     NotifyWarning("Not enough available bytes to read!!! Expected: " + len + "; Available: " + socket.Available());
        // }
        MTUpdate@ update;
        if (len > 0) {
            // while (socket.Available() < int(len + meta_bytes)) {
            //     log_trace("(if len > 0) Waiting for more bytes to read update: " + (len + meta_bytes) + "; available: " + socket.Available());
            //     yield_why("ReadMTUpdateMsg_WaitForBytes_2_ExpectNoYield");
            // }
            // log_trace("Reading socket into buf, len: " + len + "; available: " + socket.Available());
            auto buf = ReadBufFromSocket(socket, len);
            // if (buf.GetSize() != len) {
            //     log_warn("ReadMTUpdateMsg1: Read wrong number of bytes: Expected: " + len + "; Read: " + int32(buf.GetSize()));
            // }
            // log_trace("Buf to update now");
            @update = BufToMTUpdate(ty, buf);
            // log_trace("Got update");
        }
        // if (avail - socket.Available() > int(len)) {
        //     log_warn("ReadMTUpdateMsg2: Read wrong number of bytes: Expected: " + len + "; before - after available: " + (avail - socket.Available()));
        // }
        // log_trace("reading msg tail (46 bytes); avail: " + socket.Available());
        // log_trace('remaining before meta: ' + socket.Available());
        // log_trace('reading 8 bytes: ' + Text::FormatPointer(socket.ReadInt64()));
        // socket.ReadRaw(meta_bytes);
        // auto @meta = tmpMeta;
        // log_trace('remaining after meta: ' + socket.Available());
        // log_trace('meta.playerId: ' + meta.playerId);
        // log_trace('meta.timestamp: ' + Text::FormatPointer(meta.timestamp));
        if (update is null) {
            socket.ReadRaw(meta_bytes);
            log_warn("Failed to read update from server");
            return null;
        }
        auto @meta = ReadMsgTail(socket);
        @update.meta = meta;
        if (update.ty != ty) {
            log_warn("Mismatched update type: " + tostring(update.ty) + " != " + tostring(ty));
        }
        // auto end = Time::Now;
        // log_trace("Read update of len "+len+" in " + (end - start) + " ms");
        return update;
    }

    void RenderMessagesUpdateStatus() {
        auto nbPending = pendingUpdates.Length;
        vec4 textCol = cWhite;
        vec4 strokeCol = cBlack;
        if (nbPending == 0) {
            textCol = cWhite25;
            strokeCol = cBlack25;
        }
        vec2 textPos = g_screen - vec2(0.02, 0.98) * g_screen.y;
        nvg::Reset();
        nvg::BeginPath();
        nvg::FontSize(playerLabelBaseHeight * 2.0);
        nvg::FontFace(f_Nvg_Montserrat);
        nvg::TextAlign(nvg::Align::Right | nvg::Align::Top);
        DrawTextWithShadow(textPos, tostring(nbPending) + " Pending Actions", textCol, playerLabelBaseHeight * 0.2, strokeCol);
        nvg::ClosePath();
        // if (UI::Begin("nvg debug player status")) {
        //     UI::Text("Pending Updates: " + nbPending);
        //     UI::Text("Text pos: " + textPos.ToString());
        //     UI::Text("Text col: " + textCol.ToString());
        //     UI::Text("fs: " + playerLabelBaseHeight * 2.0);
        // }
        // UI::End();
    }
}

// must match server; u8
enum MTUpdateTy {
    Unknown = 0,
    Place = 1,
    Delete = 2,
    // should never be recieved
    Resync = 3,
    SetSkin = 4,
    SetWaypoint = 5,
    SetMapName = 6,
    PlayerJoin = 7,
    PlayerLeave = 8,
    Admin_PromoteMod = 9,
    Admin_DemoteMod = 10,
    Admin_KickPlayer = 11,
    Admin_BanPlayer = 12,
    Admin_ChangeAdmin = 13,
    PlayerCamCursor = 14,
    VehiclePos = 15,
    Admin_SetActionLimit = 16,
    Admin_SetVariable = 17,
    Admin_SetRoomPlayerLimit = 18,
    Admin_AlertStatusToAll = 19,
    ChatMsg = 20,
    // not numbered yet
    // put new commands above this
    XXX_LAST
}


// class MTHeader {
//     uint32 PayloadLen;
//     MTUpdateTy ty;
//     MTHeader(uint32 PayloadLen, MTUpdateTy ty) {
//         this.PayloadLen = PayloadLen;
//         this.ty = ty;
//     }
//     void WriteToSocket(Net::Socket@ soc) {
//         Socket_WriteSTART(soc);
//         soc.Write(PayloadLen);
//         soc.Write((PayloadLen & 0xFFFFFF) | (uint(ty) << 24));
//     }
// }

// void Socket_WriteSTART(Net::Socket@ soc) {
//     soc.WriteRaw("START***");
// }

// void Socket_WriteEND(Net::Socket@ soc) {
//     soc.WriteRaw("****ENDS");
// }



PlayerCamCursor@ tmpPlayerCamCursor = PlayerCamCursor();
VehiclePos@ tmpVehiclePos = VehiclePos();

MTUpdate@ BufToMTUpdate(MTUpdateTy ty, MemoryBuffer@ buf) {
    switch (ty) {
        case MTUpdateTy::Place:
            return PlaceUpdateFromBuf(buf);
        case MTUpdateTy::Delete:
            return DeleteUpdateFromBuf(buf);
        // case MTUpdateTy::Resync:
        //     return ResyncUpdateFromBuf(buf);
        case MTUpdateTy::SetSkin:
            return SetSkinUpdateFromBuf(buf);
        case MTUpdateTy::SetWaypoint:
            //return SetWaypointUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: SetWaypointUpdateFromBuf");
            return null;
        case MTUpdateTy::SetMapName:
            //return SetMapNameUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: SetMapNameUpdateFromBuf");
            return null;
        case MTUpdateTy::PlayerJoin:
            return PlayerJoinUpdate(buf);
        case MTUpdateTy::PlayerLeave:
            return PlayerLeaveUpdate(buf);
            // return null;
        case MTUpdateTy::Admin_PromoteMod:
            //return PromoteModUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: PromoteModUpdateFromBuf");
            return null;
        case MTUpdateTy::Admin_DemoteMod:
            //return DemoteModUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: DemoteModUpdateFromBuf");
            return null;
        case MTUpdateTy::Admin_KickPlayer:
            //return KickPlayerUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: KickPlayerUpdateFromBuf");
            return null;
        case MTUpdateTy::Admin_BanPlayer:
            //return BanPlayerUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: BanPlayerUpdateFromBuf");
            return null;
        case MTUpdateTy::Admin_ChangeAdmin:
            //return ChangeAdminUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: ChangeAdminUpdateFromBuf");
            return null;
        case MTUpdateTy::PlayerCamCursor:
            return tmpPlayerCamCursor.ReadFromBuf(buf);
        case MTUpdateTy::VehiclePos:
            return tmpVehiclePos.ReadFromBuf(buf);
        case MTUpdateTy::Admin_SetActionLimit:
            return SetActionLimitUpdate(buf);
        case MTUpdateTy::ChatMsg:
            return ChatUpdate(buf);
    }
    return null;
}

MTUpdate@ PlaceUpdateFromBuf(MemoryBuffer@ buf) {
    auto mt = Editor::MacroblockSpecFromBuf(buf);
    @lastRxPlaceMb = mt;
    if (g_MTConn !is null && g_MTConn.firstMB is null) {
        @g_MTConn.firstMB = mt;
    }
    return MTPlaceUpdate(mt);
}

MTUpdate@ DeleteUpdateFromBuf(MemoryBuffer@ buf) {
    auto mt = Editor::MacroblockSpecFromBuf(buf);
    @lastRxDeleteMb = mt;
    return MTDeleteUpdate(mt);
}

MTUpdate@ SetSkinUpdateFromBuf(MemoryBuffer@ buf) {
    return MTSetSkinUpdate(Editor::SetSkinSpecFromBuf(buf));
}

MemoryBuffer@ g_TmpMemBufForSockRead = MemoryBuffer(0);

MemoryBuffer@ ReadBufFromSocket(Net::Socket@ socket, uint32 len) {
    if (len > 10000000) throw('bad msg length! > 10MB');
    if (g_TmpMemBufForSockRead.GetSize() < len) {
        g_TmpMemBufForSockRead.Resize(len);
    }
    auto @buf = g_TmpMemBufForSockRead;
    buf.Seek(0);
    // auto buf = MemoryBuffer(len);
    uint count = 0;
    // uint len8Bytes = len - (len % 8);
    while (count + 8 < len) {
        buf.Write(socket.ReadUint64());
        count += 8;
    }
    while (count < len) {
        buf.Write(socket.ReadUint8());
        count += 1;
    }
    // if (buf.GetSize() != len || !buf.AtEnd()) {
    //     NotifyWarning("ReadBufFromSocket: Read wrong number of bytes: Expected: " + len + "; Read: " + buf.GetSize());
    // }
    buf.Seek(0);
    return buf;
}

MsgMeta@ ReadMsgTail(Net::Socket@ socket) {
    auto playerId = ReadLPString(socket);
    auto timestamp = socket.ReadUint64();
    return MsgMeta(playerId, timestamp);
    // return null;
}



class MsgMeta {
    MwId playerMwId;
    string playerId;
    string playerName;
    uint64 timestamp;

    MsgMeta(const string &in playerId, uint64 timestamp) {
        this.playerId = playerId;
        playerMwId.SetName(playerId);
        this.timestamp = timestamp;
        if (g_MTConn !is null) playerName = g_MTConn.LookupName(playerId);
        MTUpdateCount_Meta_Created++;
    }

    ~MsgMeta() {
        MTUpdateCount_Meta_Destroyed++;
    }

    PlayerInRoom@ GetPlayer() {
        return g_MTConn.FindPlayerInRoom(playerMwId);
    }
}

const string ReadLPString(Net::Socket@ socket) {
    auto len = socket.ReadUint16();
    // 0x5245 = 21061
    if (len > 0x5245) throw("LP String too long!");
    if (len == 0x5245) {
        // these are b"ER" as a LE u16, this is our limit so we can catch ERR msgs.
        auto x = socket.ReadUint8();
        if (x == 0x52 /* R */) {
            auto str_len = socket.ReadUint16();
            NotifyError("Server Error!: " + socket.ReadRaw(str_len));
        } else {
            return "\x52" + socket.ReadRaw(len - 1);
        }
    }
    // log_trace("Reading LPString: len = " + len);
    return socket.ReadRaw(len);
    // log_trace("Read LPString: len = " + resp.Length);
}

void WriteLPString(Net::Socket@ socket, const string &in str) {
    socket.Write(uint16(str.Length));
    socket.WriteRaw(str);
}

string ReadLPStringFromBuffer(MemoryBuffer@ buf) {
    uint16 len = buf.ReadUInt16();
    return buf.ReadString(len);
}

void WriteLPStringToBuffer(MemoryBuffer@ buf, const string &in str) {
    if (str.Length > 0xFFFF) {
        throw("String too long");
    }
    buf.Write(uint16(str.Length));
    buf.Write(str);
}

void WriteVec3ToBuffer(MemoryBuffer@ buf, vec3 v) {
    buf.Write(v.x);
    buf.Write(v.y);
    buf.Write(v.z);
}

vec3 ReadVec3FromBuffer(MemoryBuffer@ buf) {
    auto x = buf.ReadFloat();
    auto y = buf.ReadFloat();
    auto z = buf.ReadFloat();
    return vec3(x, y, z);
}

void WriteNat3ToBuffer(MemoryBuffer@ buf, nat3 v) {
    buf.Write(v.x);
    buf.Write(v.y);
    buf.Write(v.z);
}

nat3 ReadNat3FromBuffer(MemoryBuffer@ buf) {
    auto x = buf.ReadUInt32();
    auto y = buf.ReadUInt32();
    auto z = buf.ReadUInt32();
    return nat3(x, y, z);
}

enum PlayerUpdateTy {
    Cursor, Vehicle
}

class PlayerInRoom {
    string name;
    string id;
    MwId playerMwId;
    uint64 joinTime;
    bool isMod;
    bool isAdmin;
    bool isLocal;
    bool isInRoom;
    uint[] actionCounts;
    uint blocksPlaced = 0;
    uint blocksRemoved = 0;
    uint itemsPlaced = 0;
    uint itemsRemoved = 0;
    uint skinsChanged = 0;
    // bool gameDead = false;
    string customTitle;
    string nameAndTitle;

    PlayerUpdateTy lastUpdate = PlayerUpdateTy::Cursor;
    PlayerCamCursor lastCamCursor = PlayerCamCursor();
    VehiclePos lastVehiclePos = VehiclePos();

    PlayerInRoom(const string &in name, const string &in id, uint64 joinTime) {
        this.name = name;
        this.id = id;
        playerMwId.SetName(id);
        this.joinTime = joinTime;
        this.isMod = false;
        this.isAdmin = false;
        isInRoom = true;
        isLocal = name == GetApp().LocalPlayerInfo.Name;
        // need at least 16
        actionCounts = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        CheckForCustomTitle();
    }

    void UpdateStats(MTUpdate@ update) {
        if (update is null) return;
        if (uint(update.ty) > 255) {
            NotifyWarning("Bad action type: " + uint(update.ty));
            return;
        }
        while (uint(update.ty) >= actionCounts.Length) {
            actionCounts.InsertLast(0);
        }
        actionCounts[uint(update.ty)]++;
        if (update.ty == MTUpdateTy::Place) {
            auto place = cast<MTPlaceUpdate>(update);
            blocksPlaced += place.mb.Blocks.Length;
            itemsPlaced += place.mb.Items.Length;
        } else if (update.ty == MTUpdateTy::Delete) {
            auto del = cast<MTDeleteUpdate>(update);
            blocksRemoved += del.mb.Blocks.Length;
            itemsRemoved += del.mb.Items.Length;
        } else if (update.ty == MTUpdateTy::SetSkin) {
            skinsChanged++;
        }
    }

    bool get_isXertroV() {
        return playerMwId.Value == MwId_Value_XertroV;
    }
    bool get_isVille() {
        return playerMwId.Value == MwId_Value_Ville;
    }
    bool get_isSkiFreak() {
        return playerMwId.Value == MwId_Value_SkiFreak;
    }
    bool get_isTrunckley() {
        return playerMwId.Value == MwId_Value_Trunckley;
    }
    bool get_isArEyeses() {
        return playerMwId.Value == MwId_Value_ArEyeses;
    }
    bool get_isArDotDotDot() {
        return playerMwId.Value == MwId_Value_ArDotDotDot;
    }
    bool get_isHylis() {
        return playerMwId.Value == MwId_Value_Hylis;
    }
    bool get_isTona() {
        return playerMwId.Value == MwId_Value_Tona;
    }
    bool get_isEyebo() {
        return playerMwId.Value == MwId_Value_Eyebo;
    }
    bool get_isSpike() {
        return playerMwId.Value == MwId_Value_Spike;
    }
    bool get_isKora() {
        return playerMwId.Value == MwId_Value_Kora;
    }
    bool get_isLakanta() {
        return playerMwId.Value == MwId_Value_Lakanta;
    }

    void CheckForCustomTitle() {
        if (isXertroV) {
            customTitle = "Boss Admin";
        } else if (isVille) {
            customTitle = "Grandmapper";
        } else if (isSkiFreak) {
            customTitle = "Philosomapper";
        } else if (isTrunckley) {
            customTitle = "No-Mountains";
        } else if (isArEyeses || isArDotDotDot) {
            customTitle = "Troll Kacky Mapper";
        } else if (isKora) {
            customTitle = "Cutmaster";
        } else if (isSpike) {
            customTitle = "Friendly Mapper";
        } else if (isLakanta) {
            customTitle = "Mad Bastard";
        } else if (isEyebo) {
            customTitle = "KEKLator";
        } else {
            customTitle = "Mapper";
        }
        if (customTitle.Length > 0) {
            nameAndTitle = customTitle + " " + name;
        } else {
            nameAndTitle = name;
        }
    }

    void FocusEditorCamera(bool lockCam = false) {
        if (lastUpdate == PlayerUpdateTy::Cursor) {
            auto camPos = vec3(lastCamCursor.cam_matrix.tx, lastCamCursor.cam_matrix.ty, lastCamCursor.cam_matrix.tz);
            auto targetPos = lastCamCursor.target;
            float targetDist = (targetPos - camPos).Length();
            mat4 translation = mat4::Translate(camPos);
            mat4 camMat = mat4(lastCamCursor.cam_matrix);
            auto camRot = mat4::Inverse(mat4::Inverse(translation) * camMat);
            auto pyr = PitchYawRollFromRotationMatrix(camRot);
            Editor::SetCamAnimationGoTo(vec2(pyr.y, pyr.x), targetPos, targetDist);
            // log_trace('set editor cam anim');
        } else {
            // vec3 camPos = editor.OrbitalCameraControl.Pos;
            auto vMat = lastVehiclePos.mat;
            vec3 vPos = vec3(vMat.tx, vMat.ty, vMat.tz);
            float dist = 90.0;
            // how is this an unbound function?
            auto lookDir = Editor::DirToLookUvFromCamera(vPos);
            Editor::SetCamAnimationGoTo(lookDir, vPos, dist);
            // log_trace('set editor vehicle pos cam anim');
        }
        if (lockCam) {
            UnlockEditorCamera();
            startnew(CoroutineFunc(this.LockEditorCameraLoop));
        }
    }

    bool lockingEditorCamera = true;
    // the local player locked their camera to this player
    void LockEditorCameraLoop() {
        lockingEditorCamera = true;
        while (lockingEditorCamera) {
            @g_CamLockedToPlayer = this;
            FocusEditorCamera();
            log_trace('locking editor cam');
            yield();
        }
        log_trace('break loop locking editor cam');
    }

    void UnlockCamera() {
        lockingEditorCamera = false;
    }


    void DrawStatusUI() {
        if (UI::TreeNode("Player: " + name)) {
            UI::Text("ID: " + id);
            UI::Text("Joined: " + Time::FormatString("%Y-%m-%d %H:%M:%S", joinTime / 1000));
            UI::Text("Last Update: " + tostring(lastUpdate));
            if (lastUpdate == PlayerUpdateTy::Cursor) {
                UI::Text("In-Editor");
                UI::Indent();
                lastCamCursor.DrawUI();
                UI::Unindent();
            } else {
                UI::Text("In-Vehicle");
                UI::Indent();
                lastVehiclePos.DrawUI();
                UI::Unindent();
            }
            if (UI::TreeNode("Actions Summary##"+id)) {
                DrawStatsUI();
                UI::TreePop();
            }
            UI::TreePop();
        }
    }

    void DrawStatsUI() {
        UI::Columns(2);
        UI::Text("Blocks Placed");
        UI::Text("Blocks Removed");
        UI::Text("Items Placed");
        UI::Text("Items Removed");
        UI::Text("Skins Changed");

        auto nbToDraw = Math::Min(actionCounts.Length, uint(MTUpdateTy::XXX_LAST));
        for (int i = 0; i < nbToDraw; i++) {
            UI::Text(tostring(MTUpdateTy(i)));
        }
        UI::NextColumn();
        UI::Text(tostring(blocksPlaced));
        UI::Text(tostring(blocksRemoved));
        UI::Text(tostring(itemsPlaced));
        UI::Text(tostring(itemsRemoved));
        UI::Text(tostring(skinsChanged));

        for (int i = 0; i < nbToDraw; i++) {
            UI::Text(tostring(actionCounts[i]));
        }
        UI::Columns(1);
    }
}

enum RulesFlags {
    AllowCustomItems = 1,
    AllowSweeps = 2,
    AllowSelectionCut = 3,
}

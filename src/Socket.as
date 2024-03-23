class MapTogetherConnection {
    Net::Socket@ socket;
    string op_token;
    bool hasErrored = false;
    string error;

    string remote_domain;
    string roomId;
    string roomPassword;
    uint actionRateLimit;

    PlayerInRoom@[] playersInRoom;

    // create a room
    MapTogetherConnection(const string &in password, uint roomMsBetweenActions = 0) {
        remote_domain = ServerToEndpoint(m_CurrServer);
        dev_trace("Creating new room on server: " + remote_domain);
        IS_CONNECTING = true;
        InitSock();
        dev_trace('Connected to server');
        if (socket is null) {
            warn("socket is null");
            return;
        }
        // 1 = create
        dev_trace('writing room request type');
        socket.Write(uint8(1));
        roomPassword = password;
        dev_trace('writing room pw');
        WriteLPString(socket, roomPassword);
        dev_trace('writing room action limit');
        socket.Write(roomMsBetweenActions);
        dev_trace('Sent create room request');
        ExpectOKResp();
        dev_trace('Got okay response');
        ExpectRoomDetails();
        dev_trace('Got room details');
        startnew(Editor::EditorFeedGen_Loop);
        // startnew(CoroutineFunc(this.ReadUpdatesLoop));
        this.SendMapAsMacroblock();
        IS_CONNECTING = false;
    }

    // join a room
    MapTogetherConnection(const string &in roomId, const string &in password = "") {
        remote_domain = ServerToEndpoint(m_CurrServer);
        dev_trace("Joining room on server: " + remote_domain);
        IS_CONNECTING = true;
        InitSock();
        if (socket is null) {
            warn("socket is null");
            return;
        }
        // 2 = join
        dev_trace('writing room request type');
        socket.Write(uint8(2));
        WriteLPString(socket, roomId);
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        ExpectOKResp();
        ExpectRoomDetails();
        startnew(Editor::EditorFeedGen_Loop);
        // startnew(CoroutineFunc(this.ReadUpdatesLoop));
        IS_CONNECTING = false;
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

    void ExpectRoomDetails() {
        dev_trace('Expecting room details, avail: ' + socket.Available());
        dev_trace('socket can read: ' + socket.CanRead());
        while (!socket.CanRead() && socket.Available() < 2) yield();
        dev_trace('Got enough bytes to read len. avail: ' + socket.Available());
        // let _ = write_lp_string(&mut stream, &self.id_str).await;
        // let _ = stream.write_u32_le(self.action_rate_limit).await;
        roomId = ReadLPString(socket);
        dev_trace("Read room id: " + roomId);
        if (roomId.Length != 6) {
            CloseWithErr("Invalid room id from server: " + roomId);
            return;
        }
        m_RoomId = roomId;
        actionRateLimit = socket.ReadUint32();
        dev_trace("Read action rate limit: " + actionRateLimit);
    }

    void ExpectOKResp() {
        dev_trace('Expecting OK response');
        while (!socket.CanRead() && socket.Available() < 3) yield();
        dev_trace('Got enough bytes to read, avail: ' + socket.Available());
        auto resp = socket.ReadRaw(3);
        dev_trace('Read bytes OK_/ERR, avail: ' + socket.Available());
        if (resp == "OK_") return;
        dev_trace("Not OK_, got: " + resp);
        if (resp != "ERR") {
            CloseWithErr("Unexpected response from server: " + resp);
        } else {
            auto msg = ReadLPString(socket);
            CloseWithErr("Error from Server: " + msg);
        }
    }

    protected void InitSock() {
        string op_token = GetAuthToken();
        dev_trace('token: ' + op_token);
        @this.socket = Net::Socket();
        uint startTime = Time::Now;
        auto timeoutAt = Time::Now + 7500;
        trace('Connecting to: ' + remote_domain + ':19796');
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
            warn("Connected in " + (Time::Now - startTime) + " ms");
        }
        trace('Connected to: ' + remote_domain + ':19796');
        if (!socket.Write(uint16(op_token.Length))) {
            CloseWithErr("Failed to write auth token length");
            return;
        }
        if (!socket.WriteRaw(op_token)) {
            CloseWithErr("Failed to write auth token");
            return;
        }
        trace('Sent auth to server');
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
        ignorePlace++;
        ignorePlaceSkins += mapMb.setSkins.Length;
        this.WritePlaced(mapMb.macroblock);
        this.WriteSetSkins(mapMb.setSkins);
    }

    void WriteSetSkins(const Editor::SetSkinSpec@[]@ skins) {
        if (socket is null) return;
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
        //     trace('Writing placed: mb.blocks[0].mobilVariant: ' + mb.blocks[0].mobilVariant);
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

    bool PauseAutoRead = false;

    void ReadUpdatesLoop() {
        return;
        while (IsConnecting) yield();
        while (IsConnected) {
            while (PauseAutoRead) yield();
            auto updates = ReadUpdates(50);
            // pendingUpdates
            if (updates !is null) {
                for (uint i = 0; i < updates.Length; i++) {
                    pendingUpdates.InsertLast(updates[i]);
                }
            }
            yield();
        }
    }

    MTUpdate@[]@ ReadUpdates(uint max) {
        if (socket is null) return null;
        if (socket.Available() < 1) return {};
        MTUpdate@[] updates;
        uint start = Time::Now;
        MTUpdate@ next = ReadMTUpdateMsg(socket);
        uint count = 0;
        while (next !is null && count < max) {
            dev_trace('read update: ' + count);
            if (ignorePlace > 0 && next.ty == MTUpdateTy::Place) {
                ignorePlace--;
            } else if (ignorePlaceSkins > 0 && next.ty == MTUpdateTy::SetSkin) {
                ignorePlaceSkins--;
            } else if (next.ty == MTUpdateTy::PlayerJoin) {
                next.Apply(null);
            } else if (next.ty == MTUpdateTy::PlayerLeave) {
                next.Apply(null);
            } else if (next.ty == MTUpdateTy::PlayerCamCursor) {
                next.Apply(null);
            } else if (next.ty == MTUpdateTy::VehiclePos) {
                next.Apply(null);
            } else {
                updates.InsertLast(next);
            }
            @next = ReadMTUpdateMsg(socket);
            count++;
            if (Time::Now - start > 2) {
                dev_trace('breaking read loop due to yield');
                break;
            }
        }
        dev_trace('finished reading: ' + updates.Length);
        dev_trace('remaining bytes: ' + socket.Available());
        return updates;
    }

    void AddPlayer(PlayerInRoom@ player) {
        playersInRoom.InsertLast(player);
    }

    void RemovePlayer(const string &in playerId) {
        for (uint i = 0; i < playersInRoom.Length; i++) {
            if (playersInRoom[i].id == playerId) {
                playersInRoom.RemoveAt(i);
                return;
            }
        }
    }

    void UpdatePlayerCamCursor(PlayerCamCursor@ cursor) {
        for (uint i = 0; i < playersInRoom.Length; i++) {
            if (playersInRoom[i].id == cursor.meta.playerId) {
                playersInRoom[i].lastUpdate = PlayerUpdateTy::Cursor;
                playersInRoom[i].lastCamCursor.UpdateFrom(cursor);
                return;
            }
        }
    }

    void UpdatePlayerVehiclePos(VehiclePos@ pos) {
        for (uint i = 0; i < playersInRoom.Length; i++) {
            if (playersInRoom[i].id == pos.meta.playerId) {
                playersInRoom[i].lastUpdate = PlayerUpdateTy::Vehicle;
                playersInRoom[i].lastVehiclePos.UpdateFrom(pos);
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
}

// must match server; u8
enum MTUpdateTy {
    Place = 1,
    Delete = 2,
    // should never be recieved
    Resync = 3,
    SetSkin = 4,
    SetWaypoint = 5,
    SetMapName = 6,
    PlayerJoin = 7,
    PlayerLeave = 8,
    PromoteMod = 9,
    DemoteMod = 10,
    KickPlayer = 11,
    BanPlayer = 12,
    ChangeAdmin = 13,
    PlayerCamCursor = 14,
    VehiclePos = 15,
}

class MTUpdate {
    MTUpdateTy ty;
    MsgMeta@ meta;

    bool Apply(CGameCtnEditorFree@ editor) {
        throw("implemented elsewhere");
        return false;
    }
}


class MTPlaceUpdate : MTUpdate {
    Editor::MacroblockSpec@ mb;
    MTPlaceUpdate(Editor::MacroblockSpec@ mb) {
        this.ty = MTUpdateTy::Place;
        @this.mb = mb;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        print('Applying place update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::PlaceMacroblock(mb, false)) {
            NotifyError("Failed to place macroblock: blocks: " + mb.Blocks.Length + "; items: " + mb.Items.Length);
        }
        return true;
    }
}


class MTDeleteUpdate : MTUpdate {
    Editor::MacroblockSpec@ mb;
    MTDeleteUpdate(Editor::MacroblockSpec@ mb) {
        this.ty = MTUpdateTy::Delete;
        @this.mb = mb;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        print('Applying delete update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        bool freeOnly = mb.Items.Length == 0;
        if (freeOnly) {
            for (uint i = 0; i < mb.Blocks.Length; i++) {
                if (!mb.Blocks[i].isFree) {
                    freeOnly = false;
                    break;
                }
            }
        }
        if (!Editor::DeleteMacroblock(mb, false)) {
            if (!freeOnly) warn("Failed to delete macroblock");
        }
        return !freeOnly;
    }
}

class MTSetSkinUpdate : MTUpdate {
    Editor::SetSkinSpec@ skin;
    MTSetSkinUpdate(Editor::SetSkinSpec@ skin) {
        this.ty = MTUpdateTy::SetSkin;
        @this.skin = skin;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        print('Applying set skin update');
        if (!Editor::SetSkins({skin})) {
            NotifyError("Failed to set skin");
        }
        return false;
    }
}


MTUpdate@ ReadMTUpdateMsg(Net::Socket@ socket) {
    // min size: 17 (u8 + 0u32 + 0u32 + u64)
    if (socket.Available() < 17) {
        return null;
    }
    auto start_avail = socket.Available();
    auto ty = MTUpdateTy(socket.ReadUint8());
    auto len = socket.ReadUint32();
    auto avail = socket.Available();
    while (socket.Available() < int(len)) {
        dev_trace("Waiting for more bytes to read update: " + len + "; available: " + socket.Available() + "; start_avail: " + start_avail + "; ty: " + ty);
        yield();
    }
    avail = socket.Available();
    dev_trace("!!!! Read update ("+tostring(ty)+") len: " + Text::Format("0x%08x", len) + "; available: " + socket.Available());
    if (socket.Available() < int(len)) {
        NotifyWarning("Not enough available bytes to read!!! Expected: " + len + "; Available: " + socket.Available());
    }
    MTUpdate@ update;
    if (len > 0) {
        while (socket.Available() < int(len)) {
            trace("(if len > 0) Waiting for more bytes to read update: " + len + "; available: " + socket.Available());
            yield();
        }
        dev_trace("Reading socket into buf, len: " + len + "; available: " + socket.Available());
        auto buf = ReadBufFromSocket(socket, len);
        if (buf.GetSize() != len) {
            warn("ReadMTUpdateMsg1: Read wrong number of bytes: Expected: " + len + "; Read: " + int32(buf.GetSize()));
        }
        dev_trace("Buf to update now");
        @update = BufToMTUpdate(ty, buf);
        dev_trace("Got update");
    }
    if (avail - socket.Available() > int(len)) {
        warn("ReadMTUpdateMsg2: Read wrong number of bytes: Expected: " + len + "; before - after available: " + (avail - socket.Available()));
    }
    dev_trace("reading msg tail");
    // trace('remaining before meta: ' + socket.Available());
    // trace('reading 8 bytes: ' + Text::FormatPointer(socket.ReadInt64()));
    auto meta = ReadMsgTail(socket);
    // trace('remaining after meta: ' + socket.Available());
    // trace('meta.playerId: ' + meta.playerId);
    dev_trace('meta.timestamp: ' + Text::FormatPointer(meta.timestamp));
    if (update is null) {
        warn("Failed to read update from server");
        return null;
    }
    @update.meta = meta;
    if (update.ty != ty) {
        warn("Mismatched update type: " + tostring(update.ty) + " != " + tostring(ty));
    }
    return update;
}

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
            // NotifyWarning("Unimplemented: PlayerLeaveUpdateFromBuf");
            // return null;
        case MTUpdateTy::PromoteMod:
            //return PromoteModUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: PromoteModUpdateFromBuf");
            return null;
        case MTUpdateTy::DemoteMod:
            //return DemoteModUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: DemoteModUpdateFromBuf");
            return null;
        case MTUpdateTy::KickPlayer:
            //return KickPlayerUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: KickPlayerUpdateFromBuf");
            return null;
        case MTUpdateTy::BanPlayer:
            //return BanPlayerUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: BanPlayerUpdateFromBuf");
            return null;
        case MTUpdateTy::ChangeAdmin:
            //return ChangeAdminUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: ChangeAdminUpdateFromBuf");
            return null;
        case MTUpdateTy::PlayerCamCursor:
            return PlayerCamCursor(buf);
        case MTUpdateTy::VehiclePos:
            return VehiclePos(buf);
    }
    return null;
}

MTUpdate@ PlaceUpdateFromBuf(MemoryBuffer@ buf) {
    auto mt = Editor::MacroblockSpecFromBuf(buf);
    @lastPlaced = mt;
    return MTPlaceUpdate(mt);
}

MTUpdate@ DeleteUpdateFromBuf(MemoryBuffer@ buf) {
    auto mt = Editor::MacroblockSpecFromBuf(buf);
    @lastDeleted = mt;
    return MTDeleteUpdate(mt);
}

MTUpdate@ SetSkinUpdateFromBuf(MemoryBuffer@ buf) {
    return MTSetSkinUpdate(Editor::SetSkinSpecFromBuf(buf));
}

MTUpdate@ PlayerLeaveUpdateFromBuf(MemoryBuffer@ buf) {
    return null;
}

MemoryBuffer@ ReadBufFromSocket(Net::Socket@ socket, uint32 len) {
    if (len > 10000000) throw('bad msg length! > 10MB');
    auto buf = MemoryBuffer(len);
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
    if (buf.GetSize() != len || !buf.AtEnd()) {
        NotifyWarning("ReadBufFromSocket: Read wrong number of bytes: Expected: " + len + "; Read: " + buf.GetSize());
    }
    buf.Seek(0);
    return buf;
}

MsgMeta ReadMsgTail(Net::Socket@ socket) {
    auto playerId = ReadLPString(socket);
    auto timestamp = socket.ReadUint64();
    return MsgMeta(playerId, timestamp);
}

class MsgMeta {
    string playerId;
    uint64 timestamp;
    MsgMeta(const string &in playerId, uint64 timestamp) {
        this.playerId = playerId;
        this.timestamp = timestamp;
    }
}

const string ReadLPString(Net::Socket@ socket) {
    auto len = socket.ReadUint16();
    // trace("Reading LPString: len = " + len);
    auto resp = socket.ReadRaw(len);
    // trace("Read LPString: len = " + resp.Length);
    return resp;
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

class PlayerJoinUpdate : MTUpdate {
    string playerName;
    PlayerJoinUpdate(MemoryBuffer@ buf) {
        this.ty = MTUpdateTy::PlayerJoin;
        playerName = ReadLPStringFromBuffer(buf);
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        print('Applying player joined: ' + playerName);
        if (g_MTConn !is null) g_MTConn.AddPlayer(PlayerInRoom(playerName, meta.playerId, meta.timestamp));
        return false;
    }
}

class PlayerLeaveUpdate : MTUpdate {
    string playerName;
    PlayerLeaveUpdate(MemoryBuffer@ buf) {
        this.ty = MTUpdateTy::PlayerLeave;
        playerName = ReadLPStringFromBuffer(buf);
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        print('Applying player left: ' + playerName);
        if (g_MTConn !is null) g_MTConn.RemovePlayer(meta.playerId);
        return false;
    }
}

enum PlayerUpdateTy {
    Cursor, Vehicle
}

class PlayerInRoom {
    string name;
    string id;
    uint64 joinTime;
    bool isMod;
    bool isAdmin;
    bool isLocal;
    // bool gameDead = false;

    PlayerUpdateTy lastUpdate = PlayerUpdateTy::Cursor;
    PlayerCamCursor lastCamCursor = PlayerCamCursor();
    VehiclePos lastVehiclePos = VehiclePos();

    PlayerInRoom(const string &in name, const string &in id, uint64 joinTime) {
        this.name = name;
        this.id = id;
        this.joinTime = joinTime;
        this.isMod = false;
        this.isAdmin = false;
        isLocal = name == GetApp().LocalPlayerInfo.Name;
    }

    void DrawStatusUI() {
        if (UI::TreeNode("Player: " + name)) {
            UI::Text("ID: " + id);
            UI::Text("Joined: " + Time::FormatString("%Y-%m-%d %H:%M:%S", joinTime / 1000));
            UI::Text("Last Update: " + tostring(lastUpdate));
            if (lastUpdate == PlayerUpdateTy::Cursor) {
                lastCamCursor.DrawUI();
            } else {
                lastVehiclePos.DrawUI();
            }
            UI::TreePop();
        }
    }
}

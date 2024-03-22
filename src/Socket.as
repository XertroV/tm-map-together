class MapTogetherConnection {
    Net::Socket@ socket;
    string op_token;
    bool hasErrored = false;
    string error;

    string roomId;
    string roomPassword;
    uint actionRateLimit;

    // create a room
    MapTogetherConnection(const string &in password, uint roomMsBetweenActions = 0) {
        IS_CONNECTING = true;
        InitSock();
        if (socket is null) return;
        // 1 = create
        socket.Write(uint8(1));
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        socket.Write(roomMsBetweenActions);
        ExpectOKResp();
        ExpectRoomDetails();
        startnew(Editor::EditorFeedGen_Loop);
        IS_CONNECTING = false;
    }

    // join a room
    MapTogetherConnection(const string &in roomId, const string &in password = "") {
        IS_CONNECTING = true;
        InitSock();
        if (socket is null) return;
        // 2 = join
        socket.Write(uint8(2));
        WriteLPString(socket, roomId);
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        ExpectOKResp();
        ExpectRoomDetails();
        startnew(Editor::EditorFeedGen_Loop);
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
        // let _ = write_lp_string(&mut stream, &self.id_str).await;
        // let _ = stream.write_u32_le(self.action_rate_limit).await;
        roomId = ReadLPString(socket);
        if (roomId.Length != 6) {
            CloseWithErr("Invalid room id from server: " + roomId);
            return;
        }
        m_RoomId = roomId;
        actionRateLimit = socket.ReadUint32();
    }

    void ExpectOKResp() {
        while (socket.Available() < 3) yield();
        auto resp = socket.ReadRaw(3);
        if (resp == "OK_") return;
        if (resp != "ERR") {
            CloseWithErr("Unexpected response from server: " + resp);
        } else {
            auto msg = ReadLPString(socket);
            CloseWithErr("Error from Server: " + msg);
        }
    }

    protected void InitSock() {
        string op_token = GetAuthToken();
        trace('token: ' + op_token);
        @this.socket = Net::Socket();
        if (!socket.Connect("127.0.0.1", 19796)) {
            CloseWithErr("Failed to connect to MapTogether server");
            return;
        }
        socket.Write(uint16(op_token.Length));
        socket.WriteRaw(op_token);
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

    void WritePlaced(Editor::MacroblockSpec@ mb) {
        socket.Write(uint8(MTUpdateTy::Place));
        auto buf = MemoryBuffer();
        mb.WriteToNetworkBuffer(buf);
        if (mb.blocks.Length > 0) {
            trace('Writing placed: mb.blocks[0].mobilVariant: ' + mb.blocks[0].mobilVariant);
        }
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    void WriteDeleted(Editor::MacroblockSpec@ mb) {
        socket.Write(uint8(MTUpdateTy::Delete));
        auto buf = MemoryBuffer();
        mb.WriteToNetworkBuffer(buf);
        buf.Seek(0);
        socket.Write(uint32(buf.GetSize()));
        socket.Write(buf, buf.GetSize());
    }

    MTUpdate@[]@ ReadUpdates() {
        if (socket is null) return null;
        if (socket.Available() < 1) return {};
        MTUpdate@[] updates;
        MTUpdate@ next = ReadMTUpdateMsg(socket);
        while (next !is null) {
            trace('read update: ' + updates.Length);
            updates.InsertLast(next);
            @next = ReadMTUpdateMsg(socket);
        }
        trace('finished reading: ' + updates.Length);
        trace('remaining bytes: ' + socket.Available());
        return updates;
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
}

class MTUpdate {
    MTUpdateTy ty;
    MsgMeta@ meta;

    void Apply(CGameCtnEditorFree@ editor) {
        throw("implemented elsewhere");
    }
}


class MTPlaceUpdate : MTUpdate {
    Editor::MacroblockSpec@ mb;
    MTPlaceUpdate(Editor::MacroblockSpec@ mb) {
        this.ty = MTUpdateTy::Place;
        @this.mb = mb;
    }

    void Apply(CGameCtnEditorFree@ editor) override {
        print('Applying place update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::PlaceMacroblock(mb, false)) {
            NotifyError("Failed to place macroblock: blocks: " + mb.Blocks.Length + "; items: " + mb.Items.Length);
        }
    }
}


class MTDeleteUpdate : MTUpdate {
    Editor::MacroblockSpec@ mb;
    MTDeleteUpdate(Editor::MacroblockSpec@ mb) {
        this.ty = MTUpdateTy::Delete;
        @this.mb = mb;
    }

    void Apply(CGameCtnEditorFree@ editor) override {
        print('Applying delete update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::DeleteMacroblock(mb, false)) {
            NotifyError("Failed to delete macroblock");
        }
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
    trace("!!!! Read update len: " + Text::Format("0x%08x", len) + "; available: " + socket.Available());
    if (socket.Available() < int(len)) {
        NotifyWarning("Not enough available bytes to read!!! Expected: " + len + "; Available: " + socket.Available());
    }
    MTUpdate@ update;
    if (len > 0) {
        auto buf = ReadBufFromSocket(socket, len);
        if (buf.GetSize() != len) {
            NotifyWarning("ReadMTUpdateMsg: Read wrong number of bytes: Expected: " + len + "; Read: " + buf.GetSize());
        }
        @update = BufToMTUpdate(ty, buf);
    }
    if (avail - socket.Available() != int(len)) {
        NotifyWarning("ReadMTUpdateMsg: Read wrong number of bytes: Expected: " + len + "; Read: " + (avail - socket.Available()));
    }
    trace('remaining before meta: ' + socket.Available());
    // trace('reading 8 bytes: ' + Text::FormatPointer(socket.ReadInt64()));
    auto meta = ReadMsgTail(socket);
    trace('remaining after meta: ' + socket.Available());
    trace('meta.playerId: ' + meta.playerId);
    trace('meta.timestamp: ' + Text::Format('%ll', meta.timestamp));
    if (update is null) {
        warn("Failed to read update from server");
        return null;
    }
    @update.meta = meta;
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
            //return SetSkinUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: SetSkinUpdateFromBuf");
            return null;
        case MTUpdateTy::SetWaypoint:
            //return SetWaypointUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: SetWaypointUpdateFromBuf");
            return null;
        case MTUpdateTy::SetMapName:
            //return SetMapNameUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: SetMapNameUpdateFromBuf");
            return null;
        case MTUpdateTy::PlayerJoin:
            //return PlayerJoinUpdateFromBuf(buf);
            NotifyWarning("Unimplemented: PlayerJoinUpdateFromBuf");
            return null;
        case MTUpdateTy::PlayerLeave:
            return PlayerLeaveUpdateFromBuf(buf);
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

MTUpdate@ PlayerLeaveUpdateFromBuf(MemoryBuffer@ buf) {
    return null;
}

MemoryBuffer@ ReadBufFromSocket(Net::Socket@ socket, uint32 len) {
    if (len > 1000000) throw('bad length!');
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
    trace("Reading LPString: len = " + len);
    auto resp = socket.ReadRaw(len);
    trace("Read LPString: len = " + resp.Length);
    return resp;
}

void WriteLPString(Net::Socket@ socket, const string &in str) {
    socket.Write(uint16(str.Length));
    socket.WriteRaw(str);
}

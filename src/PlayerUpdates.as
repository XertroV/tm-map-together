uint MTUpdateCount_Created = 0;
uint MTUpdateCount_Destroyed = 0;
uint MTUpdateCount_Place_Created = 0;
uint MTUpdateCount_Place_Destroyed = 0;
uint MTUpdateCount_Delete_Created = 0;
uint MTUpdateCount_Delete_Destroyed = 0;
uint MTUpdateCount_SetSkin_Created = 0;
uint MTUpdateCount_SetSkin_Destroyed = 0;
uint MTUpdateCount_PlayerJoin_Created = 0;
uint MTUpdateCount_PlayerJoin_Destroyed = 0;
uint MTUpdateCount_PlayerLeave_Created = 0;
uint MTUpdateCount_PlayerLeave_Destroyed = 0;
uint MTUpdateCount_SetActionLimit_Created = 0;
uint MTUpdateCount_SetActionLimit_Destroyed = 0;
uint MTUpdateCount_PlayerCamCursor_Created = 0;
uint MTUpdateCount_PlayerCamCursor_Destroyed = 0;
uint MTUpdateCount_VehiclePos_Created = 0;
uint MTUpdateCount_VehiclePos_Destroyed = 0;

uint MTUpdateCount_ChatUpdate_Created = 0;
uint MTUpdateCount_ChatUpdate_Destroyed = 0;

uint MTUpdateCount_Meta_Created;
uint MTUpdateCount_Meta_Destroyed;

class MTUpdate {
    MTUpdateTy ty;
    MsgMeta@ meta;

    MTUpdate() {
        MTUpdateCount_Created++;
    }

    ~MTUpdate() {
        MTUpdateCount_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) {
        throw("implemented elsewhere");
        return false;
    }
    bool get_isUndoable() {
        return false;
    }
    void DrawAdminRow(uint i) {
        throw("implemented elsewhere");
    }
}

class MTUpdateUndoable : MTUpdate {
    MTUpdateUndoable() {
        super();
    }

    bool Undo(CGameCtnEditorFree@ editor) {
        throw("implemented elsewhere");
        return false;
    }
    bool get_isUndoable() override {
        return true;
    }
    MTUpdateUndoable@ Invese() {
        throw("implemented elsewhere");
        return null;
    }

    string _SummaryText = "Unknown Update";
    string get_SummaryText() {
        return _SummaryText;
    }

    uint activateTime = 0;
    void DrawAdminRow(uint i) override {
        UI::AlignTextToFramePadding();
        UI::BeginDisabled(activateTime + 500 > Time::Now);
        if (UI::Button("Undo##" + i)) {
            activateTime = Time::Now;
            g_MTConn.WriteUpdate(this.Invese());
        }
        UI::SameLine();
        UI::EndDisabled();
        UI::Text(StatusText());
    }

    string _StatusText;
    const string StatusText() {
        if (_StatusText.Length == 0) {
            GenerateStatusText();
        }
        return _StatusText;
    }

    void GenerateStatusText() {
        throw("implemented elsewhere");
    }
}

class MTPlaceUpdate : MTUpdateUndoable {
    Editor::MacroblockSpec@ mb;
    MTPlaceUpdate(Editor::MacroblockSpec@ mb) {
        super();
        this.ty = MTUpdateTy::Place;
        @this.mb = mb;
        MTUpdateCount_Place_Created++;
    }

    ~MTPlaceUpdate() {
        MTUpdateCount_Place_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        log_info('Applying place update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::PlaceMacroblock(mb, false)) {
            NotifyError("Failed to place macroblock: blocks: " + mb.Blocks.Length + "; items: " + mb.Items.Length);
        }
        return true;
    }

    bool Undo(CGameCtnEditorFree@ editor) override {
        log_info('Undoing place update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::DeleteMacroblock(mb, false)) {
            log_warn("Failed to undo place macroblock: blocks: " + mb.Blocks.Length + "; items: " + mb.Items.Length);
        }
        return true;
    }

    void GenerateStatusText() override {
        string name = g_MTConn !is null ? g_MTConn.FindPlayerEver(meta.playerMwId).name : meta.playerId;
        _StatusText = name + " | Place: " + mb.Blocks.Length + " blocks, " + mb.Items.Length + " items";
    }

    MTUpdateUndoable@ Invese() override {
        return MTDeleteUpdate(mb);
    }
}


class MTDeleteUpdate : MTUpdateUndoable {
    Editor::MacroblockSpec@ mb;
    MTDeleteUpdate(Editor::MacroblockSpec@ mb) {
        super();
        this.ty = MTUpdateTy::Delete;
        @this.mb = mb;
        MTUpdateCount_Delete_Created++;
    }

    ~MTDeleteUpdate() {
        MTUpdateCount_Delete_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        log_info('Applying delete update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
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
            if (!freeOnly) log_warn("Failed to delete macroblock (note: this is often okay and not a problem.)");
        }
        return !freeOnly;
    }

    bool Undo(CGameCtnEditorFree@ editor) override {
        log_info('Undoing delete update: ' + mb.Blocks.Length + '; ' + mb.Items.Length);
        if (!Editor::PlaceMacroblock(mb, false)) {
            log_warn("Failed to undo delete macroblock: blocks: " + mb.Blocks.Length + "; items: " + mb.Items.Length);
        }
        return true;
    }

    MTUpdateUndoable@ Invese() override {
        return MTPlaceUpdate(mb);
    }

    void GenerateStatusText() override {
        string name = g_MTConn !is null ? g_MTConn.FindPlayerEver(meta.playerMwId).name : meta.playerId;
        _StatusText = name + " | Delete: " + mb.Blocks.Length + " blocks, " + mb.Items.Length + " items";
    }
}

class MTSetSkinUpdate : MTUpdate {
    Editor::SetSkinSpec@ skin;
    MTSetSkinUpdate(Editor::SetSkinSpec@ skin) {
        super();
        this.ty = MTUpdateTy::SetSkin;
        @this.skin = skin;
        MTUpdateCount_SetSkin_Created++;
    }

    ~MTSetSkinUpdate() {
        MTUpdateCount_SetSkin_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        log_info('Applying set skin update');
        if (!Editor::SetSkins({skin})) {
            NotifyError("Failed to set skin");
        }
        return false;
    }
}

class PlayerJoinUpdate : MTUpdate {
    string playerName;
    PlayerJoinUpdate(MemoryBuffer@ buf) {
        super();
        this.ty = MTUpdateTy::PlayerJoin;
        playerName = ReadLPStringFromBuffer(buf);
        MTUpdateCount_PlayerJoin_Created++;
    }

    ~PlayerJoinUpdate() {
        MTUpdateCount_PlayerJoin_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        log_info('Applying player joined: ' + playerName);
        if (g_MTConn !is null) g_MTConn.AddPlayer(PlayerInRoom(playerName, meta.playerId, meta.timestamp));
        return false;
    }
}

class PlayerLeaveUpdate : MTUpdate {
    string playerName;
    PlayerLeaveUpdate(MemoryBuffer@ buf) {
        super();
        this.ty = MTUpdateTy::PlayerLeave;
        playerName = ReadLPStringFromBuffer(buf);
        MTUpdateCount_PlayerLeave_Created++;
    }

    ~PlayerLeaveUpdate() {
        MTUpdateCount_PlayerLeave_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        log_info('Applying player left: ' + playerName);
        if (g_MTConn !is null) g_MTConn.RemovePlayer(meta.playerId);
        return false;
    }
}

class SetActionLimitUpdate : MTUpdate {
    uint limit;
    SetActionLimitUpdate(MemoryBuffer@ buf) {
        super();
        this.ty = MTUpdateTy::Admin_SetActionLimit;
        limit = buf.ReadUInt32();
        MTUpdateCount_SetActionLimit_Created++;
    }

    ~SetActionLimitUpdate() {
        MTUpdateCount_SetActionLimit_Destroyed++;
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        if (g_MTConn !is null) {
            auto p = g_MTConn.FindAdmin(meta.playerMwId);
            if (p is null) {
                log_warn("Player " + meta.playerId + " is not an admin and cannot set action limit");
                return false;
            }
            log_info('Applying set action limit: ' + limit);
            g_MTConn.actionRateLimit = limit;
            g_MTConn.statusMsgs.AddGameEvent(MTEventAdminSetActionLimit(p, limit));
        }
        return false;
    }
}

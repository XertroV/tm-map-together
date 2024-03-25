
class MTUpdate {
    MTUpdateTy ty;
    MsgMeta@ meta;

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
        this.ty = MTUpdateTy::Place;
        @this.mb = mb;
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
        string name = g_MTConn !is null ? g_MTConn.FindPlayerEver(meta.playerId).name : meta.playerId;
        _StatusText = name + " | Place: " + mb.Blocks.Length + " blocks, " + mb.Items.Length + " items";
    }

    MTUpdateUndoable@ Invese() override {
        return MTDeleteUpdate(mb);
    }
}


class MTDeleteUpdate : MTUpdateUndoable {
    Editor::MacroblockSpec@ mb;
    MTDeleteUpdate(Editor::MacroblockSpec@ mb) {
        this.ty = MTUpdateTy::Delete;
        @this.mb = mb;
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
        string name = g_MTConn !is null ? g_MTConn.FindPlayerEver(meta.playerId).name : meta.playerId;
        _StatusText = name + " | Delete: " + mb.Blocks.Length + " blocks, " + mb.Items.Length + " items";
    }
}

class MTSetSkinUpdate : MTUpdate {
    Editor::SetSkinSpec@ skin;
    MTSetSkinUpdate(Editor::SetSkinSpec@ skin) {
        this.ty = MTUpdateTy::SetSkin;
        @this.skin = skin;
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
        this.ty = MTUpdateTy::PlayerJoin;
        playerName = ReadLPStringFromBuffer(buf);
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
        this.ty = MTUpdateTy::PlayerLeave;
        playerName = ReadLPStringFromBuffer(buf);
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
        this.ty = MTUpdateTy::Admin_SetActionLimit;
        limit = buf.ReadUInt32();
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        if (g_MTConn !is null) {
            if (g_MTConn.FindAdmin(meta.playerId) is null) {
                log_warn("Player " + meta.playerId + " is not an admin and cannot set action limit");
                return false;
            }
            log_info('Applying set action limit: ' + limit);
            g_MTConn.actionRateLimit = limit;
        }
        return false;
    }
}

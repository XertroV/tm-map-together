#if !DEPENDENCY_EDITOR



void Render() {
    UI::SetNextWindowSize(400, 200, UI::Cond::Always);
    if (UI::Begin("Map Together")) {
        UI::TextWrapped("\\$f80Map Together requires that you install Editor++");
    }
    UI::End();
}



#else



MapTogetherConnection@ g_MTConn = null;

void Main() {
    CheckTokenUpdate();
    Notify("Got token");
    // startnew(ConnectToMapTogether);
}

void ConnectToMapTogether() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    @g_MTConn = MapTogetherConnection("", 0);
}

bool g_WindowOpen = true;


void Render() {
    if (!g_WindowOpen) return;
    if (UI::Begin("Map Together", g_WindowOpen)) {
        DrawMainUI_Inner();
        if (UI::Button("Test E++ api")) {
            RunTestEppApi();
        }
    }
    UI::End();
}

/** Called when the plugin is unloaded and completely removed from memory.
*/
void OnDestroyed() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    UserUndoRedoDisablePatchEnabled = false;
}

void RunTestEppApi() {
    trace("Calling: Editor::DeleteBlocksAndItems");
    Editor::DeleteBlocksAndItems({}, {});
    trace("Called: Editor::DeleteBlocksAndItems");
    trace("Calling: Editor::PlaceBlocksAndItems");
    Editor::PlaceBlocksAndItems({}, {});
    trace("Called: Editor::PlaceBlocksAndItems");
    trace("Calling: Editor::DeleteMacroblock");
    Editor::DeleteMacroblock(null);
    trace("Called: Editor::DeleteMacroblock");
    trace("Calling: Editor::PlaceMacroblock");
    Editor::PlaceMacroblock(null);
    trace("Called: Editor::PlaceMacroblock");
    trace("Calling: Editor::GetMapAsMacroblock");
    auto x = Editor::GetMapAsMacroblock();
    trace("Called: Editor::GetMapAsMacroblock");
    trace("Calling: Editor::ThisFrameItemsDeleted");
    auto y = Editor::ThisFrameItemsDeleted();
    trace("Called: Editor::ThisFrameItemsDeleted");
    trace("Calling: Editor::ThisFrameItemsPlaced");
    auto z = Editor::ThisFrameItemsPlaced();
    trace("Called: Editor::ThisFrameItemsPlaced");
    trace("Calling: Editor::ThisFrameSkinsSet");
    auto a = Editor::ThisFrameSkinsSet();
    trace("Called: Editor::ThisFrameSkinsSet");
    trace("Calling: Editor::ThisFrameBlocksPlaced");
    auto b = Editor::ThisFrameBlocksPlaced();
    trace("Called: Editor::ThisFrameBlocksPlaced");
    trace("Calling: Editor::ThisFrameBlocksDeleted");
    auto c = Editor::ThisFrameBlocksDeleted();
    trace("Called: Editor::ThisFrameBlocksDeleted");
}

bool IS_CONNECTING = false;

void JoinMapTogetherRoom() {
    string roomId = m_RoomId;
    string password = m_Password;
    @g_MTConn = MapTogetherConnection(roomId, "");
}

string m_Password;
string m_RoomId;

void DrawMainUI_Inner() {
    if (IS_CONNECTING) {
        UI::Text("Connecting...");
        return;
    }

    if (g_MTConn is null) {
        UI::Text("MTConn null.");
        if (UI::Button("Connect New")) {
            startnew(ConnectToMapTogether);
        }
        UI::Separator();
        m_RoomId = UI::InputText("Room ID", m_RoomId);
        UI::BeginDisabled(m_RoomId.Length != 6);
        if (UI::Button("Join")) {
            startnew(JoinMapTogetherRoom);
        }
        UI::EndDisabled();
        return;
    }
    if (g_MTConn.hasErrored) {
        UI::Text("Error: " + g_MTConn.error);
        return;
    }
    if (g_MTConn.IsConnecting) {
        UI::Text("Connecting...");
        return;
    }
    if (g_MTConn.IsShutdown) {
        UI::Text("Disconnected.");
        return;
    }
    UI::Text("Connected.");

    UI::Separator();

    CopiableLabeledValue("Room ID", g_MTConn.roomId);
    CopiableLabeledPassword("Password", g_MTConn.roomPassword);
    UI::Text("Action Rate Limit (ms): " + g_MTConn.actionRateLimit);


    UI::Separator();

    if (UI::Button("Disconnect")) {
        g_MTConn.Close();
    }

    UI::Separator();

    UI::AlignTextToFramePadding();
    UI::Text("Last Macroblock: ");
    DrawMacroblockDebug("lastPlacedMbDebug", lastPlaced);
    UI::Text("Last Deleted Macroblock: ");
    DrawMacroblockDebug("lastDeletedMbDebug", lastDeleted);
}


void DrawMacroblockDebug(const string &in id, Editor::MacroblockSpec@ mbs) {
    UI::PushID(id);
    UI::Indent();
    if (mbs is null) {
        UI::Text("\\$aaa>> null <<");
        UI::Unindent();
        UI::PopID();
        return;
    }
    if (UI::Button("Try Placing")) {
        trace('Placed MB: ' + Editor::PlaceMacroblock(mbs));
    }
    if (UI::TreeNode("Blocks (" + mbs.blocks.Length + ")###blks" + id)) {
        UI::Indent();
        for (uint i = 0; i < mbs.blocks.Length; i++) {
            DrawBlockDebug("Block " + (i + 1), "block" + i, mbs.blocks[i]);
        }
        UI::Unindent();
        UI::TreePop();
    }
    if (UI::TreeNode("Items (" + mbs.items.Length + ")###items" + id)) {
        UI::Indent();
        for (uint i = 0; i < mbs.items.Length; i++) {
            DrawItemDebug("Item " + (i + 1), "item"+i, mbs.items[i]);
        }
        UI::Unindent();
        UI::TreePop();
    }
    UI::Unindent();
    UI::PopID();
}


void DrawBlockDebug(const string &in label, const string &in id, Editor::BlockSpec@ blk) {
    UI::PushID(id);
    if (UI::TreeNode(label + " | " + blk.name + "###block" + id)) {
        // UI::Indent();
        CopiableLabeledValue("Type: ", blk.name);
        CopiableLabeledValue("Author", blk.author);
        CopiableLabeledValue("Collection", '' + blk.collection);
        CopiableLabeledValue("Coord", blk.coord.ToString());
        CopiableLabeledValue("Dir", tostring(CGameCtnBlock::ECardinalDirections(blk.dir)));
        CopiableLabeledValue("Dir2", tostring(CGameCtnBlock::ECardinalDirections(blk.dir2)));
        CopiableLabeledValue("Pos", blk.pos.ToString());
        CopiableLabeledValue("PYR", blk.pyr.ToString());
        CopiableLabeledValue("PYR (Deg)", MathX::ToDeg(blk.pyr).ToString());
        CopiableLabeledValue("Color", tostring(blk.color));
        CopiableLabeledValue("lmQual", tostring(blk.lmQual));
        CopiableLabeledValue("mobilIndex", tostring(blk.mobilIx));
        CopiableLabeledValue("mobilVariant", tostring(blk.mobilVariant));
        CopiableLabeledValue("variant", tostring(blk.variant));
        UI::Text("Gr: " + BoolIcon(blk.isGround) + " N: " + BoolIcon(blk.isNormal) + " Gh: " + BoolIcon(blk.isGhost) + " F: " + BoolIcon(blk.isFree));
        AddSimpleTooltip("Gr = Ground, N = Normal, Gh = Ghost, F = Free");
        auto waypoint = blk.waypoint;
        CopiableLabeledValue("Has Waypoint", '' + (waypoint !is null));
        // UI::Unindent();
        UI::TreePop();
    }

    UI::PopID();
}


void DrawItemDebug(const string &in label, const string &in id, Editor::ItemSpec@ item) {
    UI::PushID(id);
    if (UI::TreeNode(label + " | " + item.name + "###item" + id)) {
        // UI::Indent();
        CopiableLabeledValue("Type", item.name);
        CopiableLabeledValue("Author", item.author);
        CopiableLabeledValue("Collection", '' + item.collection);
        CopiableLabeledValue("Coord", item.coord.ToString());
        CopiableLabeledValue("Dir", tostring(CGameCtnBlock::ECardinalDirections(item.dir)));
        CopiableLabeledValue("Pos", item.pos.ToString());
        CopiableLabeledValue("PYR", item.pyr.ToString());
        CopiableLabeledValue("PYR (Deg)", MathX::ToDeg(item.pyr).ToString());
        CopiableLabeledValue("Color", tostring(item.color));
        CopiableLabeledValue("lmQual", tostring(item.lmQual));
        CopiableLabeledValue("lmQual", tostring(item.lmQual));
        CopiableLabeledValue("phase", tostring(item.phase));
        CopiableLabeledValue("variantIx", tostring(item.variantIx));
        CopiableLabeledValue("pivotPos", item.pivotPos.ToString());
        UI::Text("F: " + BoolIcon(item.isFlying > 0));
        AddSimpleTooltip("F = Flying");
        CopiableLabeledValue("Has Waypoint", '' + (item.waypoint !is null));
        CopiableLabeledValue("Has FG Skin", '' + (item.fgSkin !is null));
        CopiableLabeledValue("Has BG Skin", '' + (item.bgSkin !is null));
        // UI::Unindent();
        UI::TreePop();
    }
    UI::PopID();
}


Editor::MacroblockSpec@ lastPlaced;
Editor::MacroblockSpec@ lastDeleted;


#endif











const string _BoolCheck = Icons::Check;
const string _BoolTimes = Icons::Times;
const string _BoolCheckColored = "\\$<\\$af4" + _BoolCheck + "\\$>";
const string _BoolTimesColored = "\\$<\\$f66" + _BoolTimes + "\\$>";

string BoolIcon(bool val, bool colored = true) {
    return colored
        ? (val ? _BoolCheckColored : _BoolTimesColored)
        : (val ? _BoolCheck : _BoolTimes);
}



shared void AddMarkdownTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::Markdown(msg);
        UI::EndTooltip();
    }
}


shared void SetClipboard(const string &in msg) {
    IO::SetClipboard(msg);
    Notify("Copied: " + msg);
}

shared funcdef bool LabeledValueF(const string &in l, const string &in v);

shared bool ClickableLabel(const string &in label, const string &in value) {
    return ClickableLabel(label, value, ": ");
}
shared bool ClickableLabel(const string &in label, const string &in value, const string &in between) {
    UI::Text(label.Length > 0 ? label + between + value : value);
    if (UI::IsItemHovered(UI::HoveredFlags::None)) {
        UI::SetMouseCursor(UI::MouseCursor::Hand);
    }
    return UI::IsItemClicked();
}

// bool CopiableLabeledPtr(CMwNod@ nod) {
//     return CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(nod)));
// }
bool CopiableLabeledPtr(const uint64 ptr) {
    return CopiableLabeledValue("ptr", Text::FormatPointer(ptr));
}

shared bool CopiableLabeledValue(const string &in label, const string &in value) {
    if (ClickableLabel(label, value)) {
        SetClipboard(value);
        return true;
    }
    return false;
}

bool CopiableLabeledPassword(const string &in label, const string &in pw) {
    if (pw.Length == 0) {
        UI::Text(label + ": \\$aaa<None>");
        return false;
    }
    if (ClickableLabel(label, "********")) {
        IO::SetClipboard(pw);
        Notify("Copied password.");
        return true;
    }
    return false;
}

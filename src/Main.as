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
PlayerInRoom@ g_CamLockedToPlayer = null;

int f_Nvg_Montserrat;

UI::Font@ g_MonoFont;
UI::Font@ g_BoldFont;
UI::Font@ g_BigFont;
UI::Font@ g_MidFont;

void LoadFonts() {
    @g_BoldFont = UI::LoadFont("DroidSans-Bold.ttf");
    @g_MonoFont = UI::LoadFont("DroidSansMono.ttf");
    @g_BigFont = UI::LoadFont("DroidSans.ttf", 26);
    @g_MidFont = UI::LoadFont("DroidSans.ttf", 20);
}

void Main() {
#if DEV
    CheckTokenUpdate();
#endif
    // Notify("Got token");
    // startnew(ConnectToMapTogether);
    f_Nvg_Montserrat = nvg::LoadFont("Montserrat-SemiBoldItalic.ttf");
    startnew(LoadFonts);
    startnew(FindMsOffsetForTS);
    yield();
    m_Size.x = m_SizeX;
    m_Size.y = m_SizeY;
    m_Size.z = m_SizeZ;
    g_localPlayerWSID = GetApp().LocalPlayerInfo.WebServicesUserId;
    g_localPlayerName = GetApp().LocalPlayerInfo.Name;
    auto x = MwId();
    x.SetName(g_localPlayerWSID);
    g_localPlayerWsidMwIdValue = x.Value;
    g_EnableSuperAdmin = g_localPlayerWSID == XertroV_WSID;
}

bool g_EnableSuperAdmin;
string g_localPlayerName;
string g_localPlayerWSID;
uint g_localPlayerWsidMwIdValue;
const string XertroV_WSID = "0a2d1bc0-4aaa-4374-b2db-3d561bdab1c9";

[Setting category="normally hidden" name="window open"]
bool g_WindowOpen = true;

const string PLUGIN_ICON = "\\$d9F" + Icons::MapO + Icons::Times + Icons::Users;
const string PLUGIN_NICE_NAME = "\\$febM\\$eeba\\$debp\\$deb \\$cfbT\\$bfbo\\$bfbg\\$bfce\\$aedt\\$aeeh\\$aeee\\$aefr";
const string PLUGIN_NICE_NAME_STRIPPED = "Map Together";
const string PLUGIN_MENU_NAME = PLUGIN_ICON + " \\$z\\$s" + PLUGIN_NICE_NAME;
const string PLUGIN_WINDOW_NAME = PLUGIN_NICE_NAME + "  \\$aaa(by XertroV)";
const string PLUGIN_WINDOW_NAME_STRIPPED = PLUGIN_NICE_NAME_STRIPPED + "  \\$aaa(by XertroV)";

/** Render function called every frame intended only for menu items in `UI`.
*/
void RenderMenu() {
    if (UI::MenuItem(S_NiceName ? PLUGIN_MENU_NAME : PLUGIN_NICE_NAME_STRIPPED, "", g_WindowOpen)) {
        g_WindowOpen = !g_WindowOpen;
    }
}

vec2 g_screen;
const float referenceHeight = 1440;
float refScale = 1.0;
float playerLabelBaseHeight;
float stdTriHeight;
float textPad;


void UpdateGraphicsValues() {
    g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    refScale = g_screen.y / referenceHeight;
    playerLabelBaseHeight = S_PlayerLabelHeight * refScale;
    stdTriHeight = playerLabelBaseHeight * 0.8;
    textPad = playerLabelBaseHeight * 0.2;
}

bool IsInMainMenu;
bool IsInEditor;
bool IsInSubEditor;
bool IsTestingOrValidating;
bool IsLoading;
bool IsMenuDialogShown;
ActionMap CurrActionMap;
bool IsOpenplanetOverlayShown;

void RenderEarly() {
    // if (g_MTConn is null) return;
    UpdateGraphicsValues();
    IsOpenplanetOverlayShown = UI::IsOverlayShown();
    auto app = GetApp();
    if (app.Switcher.ModuleStack.Length > 0) {
        IsInMainMenu = cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) !is null
            && app.CurrentPlayground is null && app.Editor is null;
    } else {
        IsInMainMenu = false;
    }
    if (app.Editor is null) {
        IsInEditor = false;
        IsInSubEditor = false;
        IsTestingOrValidating = false;
    } else {
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        IsInEditor = editor !is null;
        IsInSubEditor = !IsInEditor;
        IsTestingOrValidating = app.CurrentPlayground !is null;
    }
    IsLoading = app.LoadProgress.State == NGameLoadProgress::EState::Displayed;
    IsMenuDialogShown = app.BasicDialogs.Dialogs.CurrentFrame !is null;
    SetCachedCurrActionMap(UI::CurrentActionMap());
}

void SetCachedCurrActionMap(const string &in actionMap) {
    if (actionMap == "CtnEditor") {
        CurrActionMap = ActionMap::CtnEditor;
    } else if (actionMap == "MenuInputsMap") {
        CurrActionMap = ActionMap::MenuInputsMap;
    } else if (actionMap == "SpectatorMap") {
        CurrActionMap = ActionMap::SpectatorMap;
    } else if (actionMap == "Vehicle") {
        CurrActionMap = ActionMap::Vehicle;
    } else {
        CurrActionMap = ActionMap::Unknown;
    }
}

enum ActionMap {
    Unknown,
    CtnEditor,
    MenuInputsMap,
    SpectatorMap,
    Vehicle,
}

float lastDt;

void Update(float dt) {
    lastDt = dt;
}

void UnlockEditorCamera() {
    if (g_CamLockedToPlayer !is null) {
        g_CamLockedToPlayer.UnlockCamera();
        @g_CamLockedToPlayer = null;
    }
}

void Render() {
    if (g_MTConn !is null && g_MTConn.IsConnected) {
        g_MTConn.RenderPlayersNvg();
        g_MTConn.RenderStatusHUD();
        if (g_OpenCentralChatWindow) {
            Chat::RenderMainWindow();
        }
        if (S_StatusEventsOnScreen) {
            g_MTConn.statusMsgs.RenderUpdate(lastDt);
        }
        if (g_CamLockedToPlayer !is null) {
            if (GetApp().Editor is null) {
                UnlockEditorCamera();
            } else {
                UI::PushFont(g_MidFont);
                if (UI::Begin("Editor Camera Locked", UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse)) {
                    if (UI::Button("Unlock Camera from " + g_CamLockedToPlayer.name)) {
                        UnlockEditorCamera();
                    }
                }
                UI::End();
                UI::PopFont();
            }
        }
    }
    if (IsOpenplanetOverlayShown) {
        RenderMainWindow();
    }
    // todo: check if connected and applying actions. if so, draw a status indicator

}

bool dev_TraceEachLoop = false;

bool g_RenderingChat = false;

void RenderMainWindow() {
    g_RenderingChat = false;
    if (!g_WindowOpen) return;
    UI::SetNextWindowSize(600, 600, UI::Cond::FirstUseEver);
    int flags = UI::WindowFlags::NoCollapse;
#if DEV
    flags |= UI::WindowFlags::MenuBar;
#endif
    if (UI::Begin(S_NiceName ? PLUGIN_WINDOW_NAME : PLUGIN_WINDOW_NAME_STRIPPED, g_WindowOpen, flags)) {
#if DEV
        if (UI::BeginMenuBar()) {
            if (UI::BeginMenu("Debug")) {
                if (UI::MenuItem("Log Trace each Loop")) dev_TraceEachLoop = !dev_TraceEachLoop;
                UI::EndMenu();
            }
            UI::EndMenuBar();
        }
#endif
        UI::BeginTabBar("mt-main-tabs", UI::TabBarFlags::None);
        if (UI::BeginTabItem("Main")) {
            DrawMainUI_Inner();
            UI::EndTabItem();
        }
        if (g_MTConn !is null) {
            if (UI::BeginTabItem("Chat")) {
                g_RenderingChat = true;
                DrawChatTab();
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("The Map")) {
                DrawMapInfoTab();
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("Players ("+g_MTConn.playersInRoom.Length+")###playersTab")) {
                DrawPlayersTab();
                UI::EndTabItem();
            }
            if (g_MTConn.HasLocalAdmin() && UI::BeginTabItem("Admin")) {
                DrawAdminTab();
                UI::EndTabItem();
            }
            if (g_EnableSuperAdmin && UI::BeginTabItem("Super Admin")) {
                DrawSuperAdminUI();
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("Desync")) {
                DrawDesyncTab();
                UI::EndTabItem();
            }
        }
        if (UI::BeginTabItem("Settings")) {
            DrawSettingsGameUiTab();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Limitations")) {
            DrawLimitationsTab();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Logs")) {
            DrawLogsTab();
            UI::EndTabItem();
        }
        if (UI::BeginTabItem("Yields")) {
            DrawYeildReasonUI();
            UI::EndTabItem();
        }
        UI::EndTabBar();
    }
    UI::End();
}

// only things that can be reloaded
void Unload() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    UserUndoRedoDisablePatchEnabled = false;
    Patch_DisableClubFavItems.Unapply();
    Patch_SkipClubFavItemUpdate.Unapply();
    CleanupEditorIntercepts();
    Patch_DisableSweeps.Unapply();
}


/** Called when the plugin is unloaded and completely removed from memory.
*/
void OnDestroyed() {
    Unload();
    if (g_tmpPtrReadBuf_128 > 0) Dev::Free(g_tmpPtrReadBuf_128);
}


void OnDisabled() {
    Unload();
}
void OnEnabled() {
    // nothing to do (yet?)
}


bool IS_CONNECTING = false;

enum MTServers {
    Au, De, Us, Dev
}

string ServerToName(MTServers server) {
    switch (server) {
        case MTServers::Au: return "Australia";
        case MTServers::De: return "Germany";
        case MTServers::Us: return "United States";
        case MTServers::Dev: return "Development";
    }
    return "Unknown";
}

string ServerToEndpoint(MTServers server) {
    switch (server) {
        case MTServers::Au: return "map-together-au.xk.io";
        case MTServers::De: return "map-together-de.xk.io";
        case MTServers::Us: return "map-together-us.xk.io";
        case MTServers::Dev: return "127.0.0.1";
    }
    NotifyWarning("Unknown server endpoint: " + tostring(server));
    throw("Unknown server endpoint: " + tostring(server));
    return "";
}

[Setting category="normally hidden" name="preferred server"]
MTServers m_CurrServer = MTServers::De;

[Setting category="normally hidden" name="last room id"]
string m_RoomId;

void DrawMainUI_Inner() {
    if (IS_CONNECTING) {
        UI::Text("\\$aaaEnter the editor if it gets stuck.");
        if (g_MTConn !is null) {
            UI::Text("Connected to " + g_MTConn.remote_domain);
            UI::SameLine();
            UI::Text("| Server Total Players: " + g_MTConn.nbPlayersOnServer);
            UI::Text("Status: " + tostring(g_ConnectionStage));
            if (UI::Button("Disconnect")) {
                g_MTConn.Close();
                @g_MTConn = null;
                IS_CONNECTING = false;
            }
        } else {
            UI::Text("Connecting...");
            UI::Text("Status: " + tostring(g_ConnectionStage));
            if (UI::Button("Reset")) {
                IS_CONNECTING = false;
                g_MTConn.Close();
                @g_MTConn = null;
                // this crashed the game i think b/c of some race condition nullifying and instantiating
                // startnew(ExitMTWhenItBecomesAvailable);
            }
        }
        if (g_MTConn !is null && g_MTConn.hasErrored) {
            UI::Text("Error: " + g_MTConn.error);
        }
        return;
    }

    if (g_MTConn is null) {
        // UI::Text("MTConn null.");
        DrawRoomMenuChoiceMain();

        // if (UI::Button("Connect New")) {
        //     startnew(ConnectToMapTogether);
        // }
        // UI::Separator();
        // m_RoomId = UI::InputText("Room ID", m_RoomId);
        // UI::BeginDisabled(m_RoomId.Length != 6);
        // if (UI::Button("Join")) {
        //     startnew(JoinMapTogetherRoom);
        // }
        // UI::EndDisabled();
        return;
    }


    if (g_MTConn.hasErrored) {
        if (UI::Button("Reset")) {
            g_MTConn.Close();
            @g_MTConn = null;
        } else {
            UI::Text("Error: " + g_MTConn.error);
        }
        return;
    }
    if (g_MTConn.IsConnecting) {
        UI::Text("Connecting...");
        return;
    }
    if (g_MTConn.IsShutdown) {
        // if (UI::Button("Reset")) {
        // }
        UI::Text("Disconnected.");
        @g_MTConn = null;
        g_MenuState = MenuState::None;
        return;
    }
    UI::Text("Connected to " + g_MTConn.remote_domain);
    UI::SameLine();
    UI::Text("| Server Total Players: " + g_MTConn.nbPlayersOnServer);

    UI::Separator();

    CopiableLabeledValue("Room ID", g_MTConn.roomId);
    CopiableLabeledPassword("Password", g_MTConn.roomPassword);
    UI::Text("Action Rate Limit: " + g_MTConn.actionRateLimit + " (ms between actions)");
    UI::Text("Pending Updates: " + g_MTConn.pendingUpdates.Length);

    UI::Separator();

    if (UI::Button("Disconnect")) {
        g_MTConn.Close();
    }

    UI::Separator();

    S_RenderPlayersNvg = UI::Checkbox("Render Player Positions", S_RenderPlayersNvg);
// #if DEV
    S_DrawOwnLabels = UI::Checkbox("Draw Own Labels", S_DrawOwnLabels);
// #endif

    if (UI::TreeNode("Players ("+g_MTConn.playersInRoom.Length+")###mt-players-main")) {
        for (uint i = 0; i < g_MTConn.playersInRoom.Length; i++) {
            g_MTConn.playersInRoom[i].DrawStatusUI();
        }
        // UI::Indent();
        // UI::Unindent();
        UI::TreePop();
    }

// #if DEV
    UI::Separator();
    if (UI::CollapsingHeader("Dev Last MBs")) {
        UI::Indent();
        UI::AlignTextToFramePadding();
        if (UI::Button("DEV: Try placing first macroblock again")) {
            try {
                auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                Editor::Editor_CachePosInUndoStack(editor);
                Editor::PlaceMacroblock(g_MTConn.firstMB, true);
                Editor::Editor_CachePosInUndoStack(editor);
            } catch {
                NotifyError("Error: " + getExceptionInfo());
            }
        }

        UI::AlignTextToFramePadding();
        UI::Text("Last Macroblock: ");
        DrawMacroblockDebug("lastRxPlaceMbMbDebug", lastRxPlaceMb);
        UI::Text("Last Deleted Macroblock: ");
        DrawMacroblockDebug("lastRxDeleteMbMbDebug", lastRxDeleteMb);
        UI::Unindent();
    }
// #endif
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
        log_trace('Placed MB: ' + Editor::PlaceMacroblock(mbs));
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
        // CopiableLabeledValue("Has FG Skin", '' + (item.fgSkin !is null));
        // CopiableLabeledValue("Has BG Skin", '' + (item.bgSkin !is null));
        // UI::Unindent();
        UI::TreePop();
    }
    UI::PopID();
}


Editor::MacroblockSpec@ lastLocalPlaceMb;
Editor::MacroblockSpec@ lastLocalDeleteMb;
Editor::MacroblockSpec@ lastRxPlaceMb;
Editor::MacroblockSpec@ lastRxDeleteMb;
Editor::MacroblockSpec@ lastAppliedPlaceMb;
Editor::MacroblockSpec@ lastAppliedDeleteMb;


/** Called whenever a key is pressed on the keyboard. See the documentation for the [`VirtualKey` enum](https://openplanet.dev/docs/api/global/VirtualKey).
*/
UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    // dev_trace('key press: ' + tostring(key) + ' down: ' + tostring(down) + ' shift: ' + tostring(IsShiftDown()) + ' ctrl: ' + tostring(IsCtrlDown()) + ' alt: ' + tostring(IsAltDown()));
    if (IsMenuDialogShown) return UI::InputBlocking::DoNothing;
    // dev_trace('no menu dialog');
    if (g_MTConn is null) return UI::InputBlocking::DoNothing;
    // dev_trace('MapT exists');
    // only do stuff when a connection is active
    if (!g_MTConn.IsConnected) return UI::InputBlocking::DoNothing;
    // dev_trace('MapT connected');

    // editor controls
    if (IsInEditor && CurrActionMap == ActionMap::CtnEditor) {
        if (down && key == VirtualKey::U) {
            // run in different context that we know runs before EditorFeed update
            startnew(OnPressUndoInEditor).WithRunContext(Meta::RunContext::MainLoop);
        }
    }
    if (IsInEditor || IsTestingOrValidating) {
        if (down && key == VirtualKey::Escape && g_OpenCentralChatWindow) {
            g_OpenCentralChatWindow = false;
            return UI::InputBlocking::Block;
        }
        if (down && key == VirtualKey::Return && Editor::IsShiftDown() && !Editor::IsCtrlDown() && !Editor::IsAltDown()) {
            dev_trace("Shift+Enter pressed");
            g_RefocusChat = true;
            g_OpenCentralChatWindow = !g_RenderingChat;
            return UI::InputBlocking::Block;
        } else if (down) {
            // dev_trace("got relevant keypress: " + tostring(key) + " shift/ctrl/alt: " + tostring(IsShiftDown()) + "/" + tostring(IsCtrlDown()) + "/" + tostring(IsAltDown()));
        }
    }

    return UI::InputBlocking::DoNothing;
}


void OnPressUndoInEditor() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null) return;
    auto currAutosaveIx = Editor::Editor_GetCurrPosInUndoStack(editor);
    if (currAutosaveIx > cacheAutosavedIx) {
        // allow the undo
        log_debug("Allowing undo since we have not recieved more updated action.");
        editor.PluginMapType.Undo();
        if (myUpdateStack.Length > 0) {
            myUpdateStack.RemoveLast();
        }
        Editor::m_ShouldIgnoreNextAction = true;
    } else if (currAutosaveIx == cacheAutosavedIx && AreMacroblockSpecsEq(lastLocalPlaceMb, lastAppliedPlaceMb)) {
        log_debug("Allowing undo since our last placed MB was the last applied");
        editor.PluginMapType.Undo();
        Editor::Editor_CachePosInUndoStack(editor);
        @lastLocalPlaceMb = null;
        if (myUpdateStack.Length > 0) {
            myUpdateStack.RemoveLast();
        }
        Editor::m_ShouldIgnoreNextAction = true;
    } else if (myUpdateStack.Length > 0) {
        log_debug("Doing virtual undo based on recorded actions.");
        auto lastUpdate = myUpdateStack[myUpdateStack.Length - 1];
        if (lastUpdate !is null) {
            lastUpdate.Undo(editor);
            editor.PluginMapType.AutoSave();
            Editor::m_ShouldIgnoreNextAction = true;
        }
        myUpdateStack.RemoveLast();
    } else {
        log_debug("Nothing to undo.");
    }
}



bool AreMacroblockSpecsEq(Editor::MacroblockSpec@ a, Editor::MacroblockSpec@ b) {
    if (a is null && b is null) return true;
    if (a is null || b is null) return false;
    if (a.blocks.Length != b.blocks.Length) return false;
    if (a.items.Length != b.items.Length) return false;
    if (a.CalcSize() != b.CalcSize()) return false;
    MemoryBuffer@ bufA = MemoryBuffer();
    MemoryBuffer@ bufB = MemoryBuffer();
    a.WriteToNetworkBuffer(bufA);
    b.WriteToNetworkBuffer(bufB);
    auto len = bufA.GetSize();
    if (len != bufB.GetSize()) return false;
    bufA.Seek(0);
    bufB.Seek(0);
    auto len8Bs = len / 8;
    auto lenRemBytes = len % 8;
    for (uint i = 0; i < len8Bs; i++) {
        if (bufA.ReadUInt64() != bufB.ReadUInt64()) return false;
    }
    for (uint i = 0; i < lenRemBytes; i++) {
        if (bufA.ReadUInt8() != bufB.ReadUInt8()) return false;
    }
    return true;
}



#endif





void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}




void SetLoadingScreenText(const string &in text, const string &in secondaryText = "Initializing...") {
    auto fm = GetApp().LoadProgress.FrameManialink;
    if (fm is null) return;
    if (fm.Childs.Length == 0) return;
    auto c1 = cast<CControlFrame>(fm.Childs[0]);
    if (c1 is null || c1.Childs.Length == 0) return;
    auto c2 = cast<CControlFrame>(c1.Childs[0]);
    if (c2 is null || c2.Childs.Length < 2) return;
    auto label = cast<CControlLabel>(c2.Childs[1]);
    if (label is null) return;
    label.Label = text;
    if (c2 is null || c2.Childs.Length < 3) return;
    auto secLabel = cast<CControlLabel>(c2.Childs[2]);
    if (secLabel is null) return;
    secLabel.Label = secondaryText;
}






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



namespace CheckPause {
    uint g_LastPause = Time::Now;
    bool g_workPaused = false;
    uint g_lastPauseAfterDuration;
    void ResetTime() {
        g_LastPause = Time::Now;
    }
    bool MbYield(uint workMs = 150) {
        if (g_workPaused) {
            while (g_workPaused) {
                yield();
            }
            // return true;
        }
        // uint workMs = Time::Now < 20000 ? 10 : 100;
        if (g_LastPause + workMs < Time::Now) {
            g_workPaused = true;
            g_lastPauseAfterDuration = Time::Now - g_LastPause;
            trace('pausing_ at '+Time::Now+' after duration: ' + g_lastPauseAfterDuration);
            yield();
            trace('unpaused at ' + Time::Now);
            g_LastPause = Time::Now;
            g_workPaused = false;
            return true;
        }
        return false;
    }
}

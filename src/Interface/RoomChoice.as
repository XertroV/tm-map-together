enum MenuState {
    None,
    RoomCreate,
    RoomInvite,
    RoomInvitePuzzle,
    RoomJoin,
    RoomJoinExisting,
    RoomJoinExistingPuzzle,
    RoomConnectingOrRunning,
};

MenuState g_MenuState = MenuState::None;

void DrawRoomMenuChoiceMain() {
    UI::SetNextItemWidth(200);
    auto preServer = m_CurrServer;
    if (UI::BeginCombo("Server", ServerToName(m_CurrServer))) {
        if (UI::Selectable("Australia", m_CurrServer == MTServers::Au)) {
            m_CurrServer = MTServers::Au;
        }
        if (UI::Selectable("Germany", m_CurrServer == MTServers::De)) {
            m_CurrServer = MTServers::De;
        }
        if (UI::Selectable("United States", m_CurrServer == MTServers::Us)) {
            m_CurrServer = MTServers::Us;
        }
        if (UI::Selectable("Development", m_CurrServer == MTServers::Dev)) {
            m_CurrServer = MTServers::Dev;
        }
        UI::EndCombo();
    }
    bool serverChanged = preServer != m_CurrServer;
    if (serverChanged) {
        m_RoomId = GetRoomIdNoServer(m_RoomId);
    }

    if (g_MenuState == MenuState::None) {
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("NEW ROOM");

        UI::BeginDisabled(!IsInMainMenu);
        if (UI::Button("Create New Map + Room")) {
            g_MenuState = MenuState::RoomCreate;
        }
        UI::EndDisabled();
        UI::BeginDisabled(!IsInEditor);
        if (UI::Button("Invite to Current Map")) {
            g_MenuState = MenuState::RoomInvite;
        }
        UI::EndDisabled();

        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("JOIN ROOM");

        UI::BeginDisabled(!IsInMainMenu);
        if (UI::Button("Join Map Room")) {
            g_MenuState = MenuState::RoomJoin;
        }
        UI::EndDisabled();
        UI::BeginDisabled(!IsInEditor);
        if (UI::Button("Join Map Room with Current Base (For NoStadium)")) {
            g_MenuState = MenuState::RoomJoinExisting;
        }
        UI::EndDisabled();

        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("PUZZLE TOGETHER");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (IsInMainMenu) {
            UI::TextWrapped("Load the puzzle map in the editor first.");
        } else if (IsInEditor && editor !is null && editor.PluginMapType !is null) {
            // auto map = editor.Challenge;
            auto mapType = string(editor.PluginMapType.GetMapType());
            if (mapType.ToLower().EndsWith("puzzle")) {
                if (UI::Button("Create Puzzle Room")) {
                    g_MenuState = MenuState::RoomInvitePuzzle;
                }
                if (UI::Button("Join Puzzle Room")) {
                    g_MenuState = MenuState::RoomJoinExistingPuzzle;
                }
            } else {
                UI::TextWrapped("Open a puzzle map. (Map type is: " + mapType + ")");
            }
        } else {
            UI::Text("Editor is null when it is expected to be not null.");
        }


        UI::Dummy(vec2(0, 10));
        UI::Separator();
        UI::Dummy(vec2(0, 10));
        UI::TextWrapped("Map Together: a multiplayer editor plugin for Trackmania 2020, by " + XERTROV_COLOR_NAME + ".");
        UI::Markdown("[Openplanet Plugin Page](https://openplanet.dev/plugin/map-together)");
        UI::Separator();
        UI::Markdown("Please consider donating to [server costs](https://paypal.me/xertrov) and ["+Icons::Heartbeat+" Openplanet](https://www.patreon.com/openplanet).");
    } else if (g_MenuState != MenuState::RoomConnectingOrRunning) {
        UI::SameLine();
        if (UI::Button("Back")) {
            g_MenuState = MenuState::None;
        }
        DrawMenuStateForm();
    } else {
        UI::Text("Connecting to room...");
        if (g_MTConn !is null) {
            if (UI::Button("Cancel")) {
                g_MTConn.Close();
                @g_MTConn = null;
                g_MenuState = MenuState::None;
            }
            if (g_MTConn.hasErrored) {
                UI::Text("Error: " + g_MTConn.error);
            }
        } else {
            if (UI::Button("Cancel")) {
                g_MenuState = MenuState::None;
                startnew(ExitMTWhenItBecomesAvailable);
            }
        }
    }
}

void ExitMTWhenItBecomesAvailable() {
    while (g_MTConn is null) {
        yield();
    }
    g_MTConn.Close();
    @g_MTConn = null;
}

void DrawMenuStateForm() {
    switch (g_MenuState) {
        case MenuState::RoomCreate:
            DrawRoomCreateForm();
            break;
        case MenuState::RoomInvite:
            DrawRoomInviteForm();
            break;
        case MenuState::RoomInvitePuzzle:
            DrawRoomInvitePuzzleForm();
            break;
        case MenuState::RoomJoin:
            DrawRoomJoinForm();
            break;
        case MenuState::RoomJoinExisting:
            DrawRoomJoinForm(true);
            break;
        case MenuState::RoomJoinExistingPuzzle:
            DrawRoomJoinForm(true, true);
            break;
        default:
            UI::Text("HUH?");
            break;
    }
    if (UI::Button("Cancel")) {
        g_MenuState = MenuState::None;
    }
}

void ConnectToMapTogether_FreshMap() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    bool m_saveToDisk = Meta::IsDeveloperMode();
    @g_MTConn = MapTogetherConnection(m_Password, false, m_newRoomActionLimit, m_Size, EncodeMapBaseByte(m_Base, m_Mood, m_Env), m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize, m_PlayerLimit, m_saveToDisk);
    // give a little time for the auth request to fire off
    yield(3);
    startnew(OnNewRoom_EditorOpenNewMap);
}

uint8 CalcRulesFlagFromForm() {
    uint8 rulesFlag = 0;
    if (m_AllowCustomItems) rulesFlag |= RulesFlags::AllowCustomItems;
    if (m_AllowSweeps) rulesFlag |= RulesFlags::AllowSweeps;
    if (m_AllowSelectionCut) rulesFlag |= RulesFlags::AllowSelectionCut;
    return rulesFlag;
}

// nat3 size, MapBase base, MapCar car, uint8 rulesFlag, uint8 itemMaxSize
void InviteToMapTogetherRoom_ExistingMap() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    bool m_saveToDisk = Meta::IsDeveloperMode();
    @g_MTConn = MapTogetherConnection(m_Password, true, m_newRoomActionLimit, m_Size, EncodeMapBaseByte(m_Base, m_Mood, m_Env), m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize, m_PlayerLimit, m_saveToDisk);
}

void InviteToMapTogetherRoom_ExistingMap_Puzzle() {
    InviteToMapTogetherRoom_ExistingMap();
    g_MTConn.isPuzzle = true;
}

void JoinMapTogetherRoom() {
    if (g_MTConn !is null) {
        g_MTConn.Close();
        @g_MTConn = null;
    }
    if (GetApp().Editor is null) {
        startnew(OnJoinRoom_EditorOpenNewMap);
    }
    bool m_saveToDisk = Meta::IsDeveloperMode();
    @g_MTConn = MapTogetherConnection(m_RoomId, m_Password, m_saveToDisk);
}

void JoinMapTogetherRoom_Puzzle() {
    JoinMapTogetherRoom();
    g_MTConn.isPuzzle = true;
}

void DrawRoomCreateForm() {
    DrawCreateRoomForm_SetAll();
    if (UI::Button("Create Room")) {
        startnew(ConnectToMapTogether_FreshMap);
        SetLoadingScreenText("Creating Map Together room...");
    }
}

void DrawRoomInviteForm() {
    DrawCreateRoomForm_InviteToRoom();
    if (UI::Button("Create Room")) {
        startnew(InviteToMapTogetherRoom_ExistingMap);
    }
}

void DrawRoomInvitePuzzleForm() {
    DrawCreateRoomForm_InviteToRoom();
    if (UI::Button("Create Room")) {
        startnew(InviteToMapTogetherRoom_ExistingMap_Puzzle);
    }
}

void DrawRoomJoinForm(bool allowLoadExisting = false, bool isPuzzle = false) {
    if (!allowLoadExisting && IsInEditor) {
        g_MenuState = MenuState::None;
        return;
    }
    UI::SetNextItemWidth(200);
    m_RoomId = NormalizeRoomId(UI::InputText("Room ID", m_RoomId));
    bool pwChanged;
    UI::SetNextItemWidth(200);
    m_Password = UI::InputText("Password (Optional)##joinroom", m_Password, pwChanged, UI::InputTextFlags::Password);
    UI::SameLine();
    if (UI::Button(Icons::TrashO+"##clearpw-join")) {
        m_Password = "";
    }
    if (!allowLoadExisting) {
        DrawCreateRoomForm_PatchOptions();
    }

    bool hasServerPrefix = RoomIdHasServerPrefix(m_RoomId);
    string roomIdNoServerPrefix = hasServerPrefix ? GetRoomIdNoServer(m_RoomId) : m_RoomId;
    if (hasServerPrefix) {
        m_CurrServer = ServerFromRoomId(m_RoomId);
    }

    bool badRoomIdLen = roomIdNoServerPrefix.Length != 6;
    UI::BeginDisabled(badRoomIdLen);
    if (UI::Button("Join Room")) {
        if (isPuzzle) {
            startnew(JoinMapTogetherRoom_Puzzle);
        } else {
            startnew(JoinMapTogetherRoom);
        }
        SetLoadingScreenText("Joining Map Together Room: " + m_RoomId);
    }
    UI::EndDisabled();
    if (badRoomIdLen) {
        UI::TextWrapped("Room ID must be 6 characters long, optionally with a server prefix (e.g. AU_, DE_, US_).");
    }
}

// Room-ID server prefixes, indexed by MTServers; match case-insensitively, write capitals.
const string[] ROOM_ID_PREFIXES = {"AU", "DE", "US", "DEV"};

string ServerToRoomIdPrefix(MTServers server) {
    uint i = uint(server);
    if (i >= ROOM_ID_PREFIXES.Length) return "DE";
    return ROOM_ID_PREFIXES[i];
}

// Length of the server prefix (including the underscore), or 0 if there is
// none. Sets `server` to the matched server, else leaves it at De.
uint RoomIdPrefixLen(const string &in roomId, MTServers &out server) {
    server = MTServers::De;
    string upper = roomId.ToUpper();
    for (uint i = 0; i < ROOM_ID_PREFIXES.Length; i++) {
        // The underscore disambiguates DE_ from DEV_, so order does not matter.
        string p = ROOM_ID_PREFIXES[i] + "_";
        if (upper.StartsWith(p)) {
            server = MTServers(i);
            return p.Length;
        }
    }
    return 0;
}

bool RoomIdHasServerPrefix(const string &in roomId) {
    MTServers ignored;
    return RoomIdPrefixLen(roomId, ignored) > 0;
}

string GetRoomIdNoServer(const string &in roomId) {
    MTServers ignored;
    return roomId.SubStr(RoomIdPrefixLen(roomId, ignored));
}

MTServers ServerFromRoomId(const string &in roomId) {
    MTServers server;
    RoomIdPrefixLen(roomId, server);
    return server;
}

// Tidy up a typed/pasted room ID: drop surrounding whitespace and rewrite any
// server prefix in canonical capitals ("au_abc123" -> "AU_abc123").
string NormalizeRoomId(const string &in roomId) {
    string id = roomId.Trim();
    MTServers server;
    uint prefixLen = RoomIdPrefixLen(id, server);
    if (prefixLen == 0) return id;
    return ServerToRoomIdPrefix(server) + "_" + id.SubStr(prefixLen);
}


void OnJoinRoom_EditorOpenNewMap() {
    while (g_MTConn is null) yield();
    while (g_MTConn !is null && g_MTConn.roomId.Length == 0) {
        yield();
    }
    trace("g_MTConn null: " + (g_MTConn is null));
    yield();
    if (g_MTConn !is null) {
        trace("g_MTConn.IsConnected: " + g_MTConn.IsConnected);
        trace("g_MTConn.IsConnecting: " + g_MTConn.IsConnecting);
        trace("g_MTConn.IsShutdown: " + g_MTConn.IsShutdown);
        trace("g_MTConn.hasErrored: " + g_MTConn.hasErrored);
        trace("g_MTConn.error: " + g_MTConn.error);
        // trace("g_MTConn.socket is null: " + (g_MTConn.socket is null));
    }
    while (g_MTConn !is null && g_MTConn.IsConnecting) yield_why("waiting for connection to establish");
    if (g_MTConn !is null && g_MTConn.IsConnected) {
        while (g_MTConn.mapSize.x == 0) {
            yield_why("waiting for room details");
        }
        trace('mapSize: ' + g_MTConn.mapSize.ToString() + ', mapBase: ' + tostring(g_MTConn.mapBase) + ', baseCar: ' + tostring(g_MTConn.baseCar));
        auto size = g_MTConn.mapSize;
        // todo: support more map bases; bit flags (high) after
        auto base = g_MTConn.mapBase >= 32 ? MapBase(g_MTConn.mapBase & 0b11100000) : MapBase::Stadium155;
        auto mood = g_MTConn.mapBase & 3;
        auto env = EncodedMapBaseToEnv(g_MTConn.mapBase);
        auto car = g_MTConn.baseCar;
        EditNewMapFrom(base, MapMood(mood), MapCar(car), size, MapEnvToCollection(env));
    } else {
        NotifyError("Failed to join room");
    }
}


void OnNewRoom_EditorOpenNewMap() {
    // todo: edit new map
    auto size = m_Size;
    auto base = m_Base;
    auto car = m_Car;
    auto mood = m_Mood;
    EditNewMapFrom(base, mood, car, size, MapEnvToCollection(m_Env));
}

string MoodToDecoSuffix(MapMood mood) {
    switch (mood) {
        case MapMood::Day: return "Day";
        case MapMood::Night: return "Night";
        case MapMood::Sunset: return "Sunset";
        case MapMood::Sunrise: return "Sunrise";
    }
    return "Day";
}

string BaseAndMoodToDecoId(MapBase base, MapMood mood, const string &in environment = "Stadium") {
    // Non-Stadium environments have exactly one base, in 4 moods.
    if (environment != "Stadium") {
        return "Base64x64" + MoodToDecoSuffix(mood);
    }
    switch (base) {
        case MapBase::NoStadium:
            switch (mood) {
                case MapMood::Day: return "NoStadium48x48Day";
                case MapMood::Night: return "NoStadium48x48Night";
                case MapMood::Sunset: return "NoStadium48x48Sunset";
                case MapMood::Sunrise: return "NoStadium48x48Sunrise";
            }
        case MapBase::StadiumOld:
            switch (mood) {
                case MapMood::Day: return "Base48x48Day";
                case MapMood::Night: return "Base48x48Night";
                case MapMood::Sunset: return "Base48x48Sunset";
                case MapMood::Sunrise: return "Base48x48Sunrise";
            }
        case MapBase::Stadium155:
            switch (mood) {
                case MapMood::Day: return "Base48x48Screen155Day";
                case MapMood::Night: return "Base48x48Screen155Night";
                case MapMood::Sunset: return "Base48x48Screen155Sunset";
                case MapMood::Sunrise: return "Base48x48Screen155Sunrise";
            }
    }
    NotifyWarning("BaseAndMoodToDecoId: Unknown base and mood: " + base + ", " + mood);
    return "Base48x48Screen155Day";
}

string BaseAndMoodToDecoMood(MapBase base, MapMood mood) {
    // 48x48Night 48x48Day 48x48Screen155Day 48x48Screen155Night 48x48Screen155Sunrise 48x48Screen155Sunset 48x48Sunrise 48x48Sunset NoStadium48x48Day NoStadium48x48Night NoStadium48x48Sunrise NoStadium48x48Sunset
    if (base == MapBase::StadiumOld) {
        switch (mood) {
            case MapMood::Day: return "48x48Day"; // 48x48Day / Base48x48Day
            case MapMood::Night: return "48x48Night";
            case MapMood::Sunset: return "Sunset";
            case MapMood::Sunrise: return "Sunrise";
        }
    }
    auto ret = BaseAndMoodToDecoId(base, mood);
    if (ret.StartsWith("Base")) {
        return ret.SubStr(4);
    }
    return ret;
}

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
        if (IsInMainMenu) {
            UI::TextWrapped("Load the puzzle map in the editor first.");
        } else if (IsInEditor) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
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
    startnew(OnNewRoom_EditorOpenNewMap);
    @g_MTConn = MapTogetherConnection(m_Password, false, m_newRoomActionLimit, m_Size, m_Mood | m_Base, m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize, m_PlayerLimit);
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
    @g_MTConn = MapTogetherConnection(m_Password, true, m_newRoomActionLimit, m_Size, m_Mood | m_Base, m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize, m_PlayerLimit);
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
    @g_MTConn = MapTogetherConnection(m_RoomId, m_Password);
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
    m_RoomId = UI::InputText("Room ID", m_RoomId);
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
    UI::BeginDisabled(m_RoomId.Length != 6);
    if (UI::Button("Join Room")) {
        if (isPuzzle) {
            startnew(JoinMapTogetherRoom_Puzzle);
        } else {
            startnew(JoinMapTogetherRoom);
        }
        SetLoadingScreenText("Joining Map Together Room: " + m_RoomId);
    }
    UI::EndDisabled();
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
        auto car = g_MTConn.baseCar;
        EditNewMapFrom(base, MapMood(mood), MapCar(car), size);
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
    EditNewMapFrom(base, mood, car, size);
}

string BaseAndMoodToDecoId(MapBase base, MapMood mood) {
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

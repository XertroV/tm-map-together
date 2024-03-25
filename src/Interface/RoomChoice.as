enum MenuState {
    None,
    RoomCreate,
    RoomInvite,
    RoomJoin,
    RoomJoinExisting,
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
        if (UI::Selectable("United States (Forwards to Aus atm)", m_CurrServer == MTServers::Us)) {
            m_CurrServer = MTServers::Us;
        }
        if (UI::Selectable("Development", m_CurrServer == MTServers::Dev)) {
            m_CurrServer = MTServers::Dev;
        }
        UI::EndCombo();
    }
    if (g_MenuState == MenuState::None) {
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
        case MenuState::RoomJoin:
            DrawRoomJoinForm();
            break;
        case MenuState::RoomJoinExisting:
            DrawRoomJoinForm(true);
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
    @g_MTConn = MapTogetherConnection(m_Password, false, m_newRoomActionLimit, m_Size, m_Base, m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize);
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
    @g_MTConn = MapTogetherConnection(m_Password, true, m_newRoomActionLimit, m_Size, m_Base, m_Car, CalcRulesFlagFromForm(), m_ItemMaxSize);
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

void DrawRoomCreateForm() {
    DrawCreateRoomForm_SetAll();
    if (UI::Button("Create Room")) {
        startnew(ConnectToMapTogether_FreshMap);
    }
}

void DrawRoomInviteForm() {
    DrawCreateRoomForm_InviteToRoom();
    if (UI::Button("Create Room")) {
        startnew(InviteToMapTogetherRoom_ExistingMap);
    }
}

void DrawRoomJoinForm(bool allowLoadExisting = false) {
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
        startnew(JoinMapTogetherRoom);
    }
    UI::EndDisabled();
}






void OnJoinRoom_EditorOpenNewMap() {
    while (g_MTConn is null) yield();
    while (g_MTConn !is null && g_MTConn.roomId.Length == 0) {
        yield();
    }
    if (g_MTConn !is null) {
        auto size = g_MTConn.mapSize;
        // todo: support more map bases; bit flags (high) after
        auto base = MapBase::Stadium155;
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
    return "NoStadium48x48Day";
}

string BaseAndMoodToDecoMood(MapBase base, MapMood mood) {
    auto ret = BaseAndMoodToDecoId(base, mood);
    if (ret.StartsWith("Base")) {
        return ret.SubStr(4);
    }
    return ret;
}


nat3 decoOrigSize;

void EditNewMapFrom(MapBase base, MapMood mood, MapCar vehicle, nat3 size) {
    auto decoId = BaseAndMoodToDecoId(base, mood);
    auto fid = Fids::GetGame("GameData/Stadium/GameCtnDecoration/" + decoId + ".Decoration.Gbx");
    auto deco = cast<CGameCtnDecoration>(Fids::Preload(fid));
    decoOrigSize.x = deco.DecoSize.SizeX;
    decoOrigSize.y = deco.DecoSize.SizeY;
    decoOrigSize.z = deco.DecoSize.SizeZ;
    deco.DecoSize.SizeX = size.x;
    deco.DecoSize.SizeY = size.y;
    deco.DecoSize.SizeZ = size.z;

    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app.ManiaTitleControlScriptAPI is null) {
        return;
    }

    if (m_DisableClubItems_Patch) {
        Patch_DisableClubFavItems.Apply();
    } else if (m_EnableClubItemsSkip) {
        Patch_SkipClubFavItemUpdate.Apply();
    }

    trace("Calling EditNewMap2(" + decoId + ", " + tostring(vehicle) + ")");
    trace("deco id name: " + deco.IdName);
    app.ManiaTitleControlScriptAPI.EditNewMap2(
        // m_Base == MapBase::NoStadium ? "NoStadium" : "Stadium",
        "Stadium",
        deco.IdName,
        "",
        tostring(vehicle),
        "", false, "", ""
    );

    while (app.Editor is null) yield();
    Patch_DisableClubFavItems.Unapply();
    Patch_SkipClubFavItemUpdate.Unapply();

    while (app.Editor !is null) yield();
    deco.DecoSize.SizeX = decoOrigSize.x;
    deco.DecoSize.SizeY = decoOrigSize.y;
    deco.DecoSize.SizeZ = decoOrigSize.z;
}

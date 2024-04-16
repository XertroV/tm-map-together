
string m_Password = "";
bool m_AllowCustomItems = false;
bool m_AllowSweeps = false;
// ignore for the moment
bool m_AllowSelectionCut = false;
[Setting category="normally hidden" name="saved mood"]
MapMood m_Mood = MapMood::Day;
[Setting category="normally hidden" name="saved base"]
MapBase m_Base = MapBase::Stadium155;
[Setting category="normally hidden" name="saved car"]
MapCar m_Car = MapCar::CarSport;

nat3 m_Size = nat3(48, 255, 48);

[Setting category="normally hidden" name="saved map SizeX"]
uint m_SizeX = 48;
[Setting category="normally hidden" name="saved map SizeY"]
uint m_SizeY = 255;
[Setting category="normally hidden" name="saved map SizeZ"]
uint m_SizeZ = 48;


uint m_ItemMaxSize = 0;
uint16 m_PlayerLimit = 0xFFFF;

void DrawCreateRoomForm_SetAll() {
    if (IsInEditor) {
        g_MenuState = MenuState::None;
        return;
    }
    DrawCreateRoomForm_TopPart();
    DrawCreateRoomForm_BottomPart_Mutable();
    DrawCreateRoomForm_PatchOptions();
}

void DrawCreateRoomForm_InviteToRoom() {
    if (!IsInEditor) {
        g_MenuState = MenuState::None;
        return;
    }
    DrawCreateRoomForm_TopPart();
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null) {
        UI::Text("\\$f40Error: you need to be in the map editor.");
    }
    m_Mood = MapDecoToMood(editor.Challenge.Decoration);
    m_Base = MapDecoToBase(editor.Challenge.Decoration);
    // if (m_Base != MapBase::Stadium155) {
    //     UI::Text("\\$f84Error: only Stadium 155 is supported for now. Mappers will load Stadium 155 unless joining from an existing map.");
    //     m_Base = MapBase::Stadium155;
    // }
    m_Car = MapToCar(editor.Challenge);
    DrawCreateRoomForm_BottomPart_Immutable(m_Mood, m_Base, m_Car, editor.Challenge.Size);
    // no patch for when you're already in the editor
    // DrawCreateRoomForm_PatchOptions();
}

bool m_EnableClubItemsSkip = true;
bool m_DisableClubItems_Patch = false;
void DrawCreateRoomForm_PatchOptions() {
    UI::Separator();
    UI::Text("Patch Options");
    m_DisableClubItems_Patch = UI::Checkbox("Disable Club Items (very fast)", m_DisableClubItems_Patch);
    UI::BeginDisabled(m_DisableClubItems_Patch);
    m_EnableClubItemsSkip = UI::Checkbox("Skip Checking Club Item Updates", m_EnableClubItemsSkip);
    UI::EndDisabled();
    UI::Separator();
}

MapMood MapDecoToMood(CGameCtnDecoration@ deco) {
    if (deco is null) {
        return MapMood::Day;
    }
    string idName = deco.IdName;
    if (idName.Contains("Day")) {
        return MapMood::Day;
    }
    if (idName.Contains("Night")) {
        return MapMood::Night;
    }
    if (idName.Contains("Sunset")) {
        return MapMood::Sunset;
    }
    if (idName.Contains("Sunrise")) {
        return MapMood::Sunrise;
    }
    return MapMood::Day;
}


MapBase EncodedMapBaseToName(uint8 enc) {
    if (enc == 32) return MapBase::NoStadium;
    if (enc == 64) return MapBase::StadiumOld;
    if (enc == 128) return MapBase::Stadium155;
    return MapBase::Stadium155;
}

MapMood EncodedMapBaseToMood(uint8 enc) {
    return MapMood(enc & 3);
}

MapBase MapDecoToBase(CGameCtnDecoration@ deco) {
    if (deco is null) {
        return MapBase::Stadium155;
    }
    string idName = deco.IdName;
    if (idName.StartsWith("48x48Screen155")) {
        return MapBase::Stadium155;
    }
    if (idName.StartsWith("NoStadium")) {
        return MapBase::NoStadium;
    }
    return MapBase::StadiumOld;
}

MapCar MapToCar(CGameCtnChallenge@ challenge) {
    if (challenge is null) {
        return MapCar::CarSport;
    }
    string idName = challenge.VehicleName.GetName();
    if (idName == "CarSnow") {
        return MapCar::CarSnow;
    }
    if (idName == "CarRally") {
        return MapCar::CarRally;
    }
    if (idName == "CarDesert") {
        return MapCar::CarDesert;
    }
    if (idName == "CarSport") {
        return MapCar::CarSport;
    }
    return MapCar::CarSport;
}

void DrawCreateRoomForm_TopPart() {
    UI::Text("Create Room");
    UI::Separator();
    UI::SetNextItemWidth(200);
    bool changed;
    m_Password = UI::InputText("Password (Optional)", m_Password, changed, UI::InputTextFlags::Password);
    UI::SameLine();
    if (UI::Button(Icons::Refresh+"##gen-pw")) {
        m_Password = Crypto::MD5(tostring('' + Math::Rand(-2147483648, 2147483647) + Time::Now + Math::Rand(-2147483648, 2147483647))).SubStr(0, 8);
        Notify("Generated and copied new password");
        IO::SetClipboard(m_Password);
    }
    UI::SameLine();
    if (UI::Button(Icons::FilesO+"##copy-pw")) {
        IO::SetClipboard(m_Password);
        Notify("Copied password to clipboard");
    }
    UI::SameLine();
    if (UI::Button(Icons::TrashO+"##clear-pw")) {
        m_Password = "";
    }
    UI::SetNextItemWidth(200);
    m_PlayerLimit = Math::Clamp(UI::InputInt("Player Limit", m_PlayerLimit), 2, 0xFFFF);


    UI::SameLine();
    if (UI::Button("8##max-players")) {
        m_PlayerLimit = 8;
    }
    UI::SameLine();
    if (UI::Button("16##max-players")) {
        m_PlayerLimit = 16;
    }
    UI::SameLine();
    if (UI::Button("32##max-players")) {
        m_PlayerLimit = 32;
    }
    UI::SameLine();
    if (UI::Button("64##max-players")) {
        m_PlayerLimit = 64;
    }
    UI::SameLine();
    if (UI::Button("128##max-players")) {
        m_PlayerLimit = 128;
    }
    UI::SameLine();
    if (UI::Button("∞##max-players")) {
        m_PlayerLimit = 0xFFFF;
    }

    UI::BeginDisabled();
    m_newRoomActionLimit = 0;
    m_AllowCustomItems = UI::Checkbox("(Disabled; Future Update) Allow Custom Items", m_AllowCustomItems);
    // m_AllowSweeps = UI::Checkbox("Allow Sweeps (Delete All)", m_AllowSweeps);
    UI::EndDisabled();
}


void DrawCreateRoomForm_BottomPart_Mutable() {
    UI::PushItemWidth(200);
    // Mood
    if (UI::BeginCombo("Map Mood", tostring(m_Mood))) {
        if (UI::Selectable("Day", m_Mood == MapMood::Day)) {
            m_Mood = MapMood::Day;
        }
        if (UI::Selectable("Night", m_Mood == MapMood::Night)) {
            m_Mood = MapMood::Night;
        }
        if (UI::Selectable("Sunset", m_Mood == MapMood::Sunset)) {
            m_Mood = MapMood::Sunset;
        }
        if (UI::Selectable("Sunrise", m_Mood == MapMood::Sunrise)) {
            m_Mood = MapMood::Sunrise;
        }
        UI::EndCombo();
    }

    // Base
    if (UI::BeginCombo("Map Base", tostring(m_Base))) {
        if (UI::Selectable("No Stadium", m_Base == MapBase::NoStadium)) {
            m_Base = MapBase::NoStadium;
        }
        if (UI::Selectable("Stadium 155", m_Base == MapBase::Stadium155)) {
            m_Base = MapBase::Stadium155;
        }
        if (UI::Selectable("Stadium Old", m_Base == MapBase::StadiumOld)) {
            m_Base = MapBase::StadiumOld;
        }
        UI::EndCombo();
    }

    // Car
    if (UI::BeginCombo("Map Car", tostring(m_Car))) {
        if (UI::Selectable("Default (Stadium)", m_Car == MapCar::CarSport)) {
            m_Car = MapCar::CarSport;
        }
        if (UI::Selectable("Snow", m_Car == MapCar::CarSnow)) {
            m_Car = MapCar::CarSnow;
        }
        if (UI::Selectable("Rally", m_Car == MapCar::CarRally)) {
            m_Car = MapCar::CarRally;
        }
        if (Time::Stamp > 1712008800) {
            if (UI::Selectable("Desert", m_Car == MapCar::CarDesert)) {
                m_Car = MapCar::CarDesert;
            }
        }
        UI::EndCombo();
    }

    UI::PopItemWidth();
    // Size

    UI::PushItemWidth(160.0 / 3.0);
    m_Size.x = Math::Clamp(TryParseUint8(UI::InputText("##mapsize-x", tostring(m_Size.x)), m_Size.x), 8, 255);
    UI::SameLine();
    m_Size.y = Math::Clamp(TryParseUint8(UI::InputText("##mapsize-y", tostring(m_Size.y)), m_Size.y), 8, 255);
    UI::SameLine();
    m_Size.z = Math::Clamp(TryParseUint8(UI::InputText("##mapsize-z", tostring(m_Size.z)), m_Size.z), 8, 255);
    UI::SameLine();
    m_SizeX = m_Size.x;
    m_SizeY = m_Size.y;
    m_SizeZ = m_Size.z;
    UI::Text("Size (X Y Z)");
    UI::SameLine();
    if (UI::Button("48²")) {
        m_Size.x = 48;
        // m_Size.y = 255;
        m_Size.z = 48;
    }
    UI::SameLine();
    if (UI::Button("64²")) {
        m_Size.x = 64;
        // m_Size.y = 255;
        m_Size.z = 64;
    }
    UI::SameLine();
    if (UI::Button("80²")) {
        m_Size.x = 80;
        // m_Size.y = 255;
        m_Size.z = 80;
    }
    UI::SameLine();
    if (UI::Button("128²")) {
        m_Size.x = 128;
        // m_Size.y = 255;
        m_Size.z = 128;
    }
    UI::SameLine();
    if (UI::Button("255²")) {
        m_Size.x = 255;
        // m_Size.y = 255;
        m_Size.z = 255;
    }
    UI::PopItemWidth();
}

uint8 TryParseUint8(const string &in str, uint8 defaultValue) {
    uint32 result = defaultValue;
    if (str != "") {
        try {
            result = Text::ParseUInt(str);
        } catch {
            result = defaultValue;
        }
    }
    if (result > 255) {
        result = 255;
    }
    return result;
}

string MapBaseToString(MapBase base) {
    switch (base) {
        case MapBase::NoStadium: return "No Stadium";
        case MapBase::Stadium155: return "Stadium 155";
        case MapBase::StadiumOld: return "Stadium Old";
    }
    return "Unknown";
}

string MapCarToString(MapCar car) {
    switch (car) {
        case MapCar::CarSport: return "Default (Stadium)";
        case MapCar::CarSnow: return "Snow";
        case MapCar::CarRally: return "Rally";
        case MapCar::CarDesert: return "Desert";
    }
    return "Unknown";
}

void DrawCreateRoomForm_BottomPart_Immutable(MapMood mood, MapBase base, MapCar car, nat3 size) {
    UI::Text("Map Mood: " + tostring(mood));
    UI::Text("Map Base: " + MapBaseToString(base));
    UI::Text("Map Car: " + MapCarToString(car));
    UI::Text("Map Size: " + size.ToString());
    m_Size = size;
}

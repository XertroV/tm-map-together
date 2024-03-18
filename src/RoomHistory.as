const string RecentRoomsJsonFile = IO::FromStorageFolder("RecentRooms.json");

// json array in reverse order
Json::Value@ RecentRooms = null;

void LoadRecentRooms() {
    @RecentRooms = Json::FromFile(RecentRoomsJsonFile);
    if (RecentRooms.GetType() != Json::Type::Array) {
        NotifyWarning("RecentRooms.json is not an array - resetting it.");
        @RecentRooms = Json::Array();
    }
}

void SaveRecentRooms() {
    if (RecentRooms is null) {
        NotifyWarning("RecentRooms is null - not saving.");
        return;
    }
    Json::ToFile(RecentRoomsJsonFile, RecentRooms);
}

void AddRecentRoom(const string &in roomId, const string &in password) {
    if (RecentRooms is null) {
        NotifyError("RecentRooms is null - not adding room.");
        return;
    }
    for (uint i = 0; i < RecentRooms.Length; i++) {
        if (RecentRooms[i]["id"] == roomId) {
            RecentRooms.Remove(i);
            break;
        }
    }
    Json::Value@ room = Json::Object();
    room["id"] = roomId;
    room["pw"] = password;
    room["ts"] = Time::Stamp;
    while (RecentRooms.Length > 49) {
        RecentRooms.Remove(0);
    }
    RecentRooms.Add(room);
    SaveRecentRooms();
}

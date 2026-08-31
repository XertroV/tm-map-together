namespace EditorPatches {
    import bool get_DisableClubItems_IsApplied() from "MapTogether";
    import void set_DisableClubItems_IsApplied(bool value) from "MapTogether";
    import bool get_SkipClubFavItemUpdate_IsApplied() from "MapTogether";
    import void set_SkipClubFavItemUpdate_IsApplied(bool value) from "MapTogether";
}

import void EditNewMapFrom(MapBase base, MapMood mood, MapCar vehicle, nat3 size, const string &in collection = "Stadium") from "MapTogether";

namespace MapTogether {
    import Json::Value@ GetStatus() from "MapTogether";
    import Json::Value@ SetServer(Json::Value &in opts) from "MapTogether";
    import Json::Value@ CreateRoom(Json::Value &in opts) from "MapTogether";
    import Json::Value@ InviteCurrentMap(Json::Value &in opts) from "MapTogether";
    import Json::Value@ JoinRoom(Json::Value &in opts) from "MapTogether";
    import Json::Value@ Disconnect(Json::Value &in opts) from "MapTogether";
    import Json::Value@ WaitUntilReady(Json::Value &in opts) from "MapTogether";
    import Json::Value@ WaitUntilIdle(Json::Value &in opts) from "MapTogether";
    import Json::Value@ GetPlayers(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SendChat(Json::Value &in opts) from "MapTogether";
    import Json::Value@ GetChat(Json::Value &in opts) from "MapTogether";
    import Json::Value@ FocusPlayer(Json::Value &in opts) from "MapTogether";
    import Json::Value@ UnlockCamera(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SetActionLimit(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SetDropPendingUpdates(Json::Value &in opts) from "MapTogether";
    import Json::Value@ ClearPurpleBoxes(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SetWindowOpen(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SetClubItemPatches(Json::Value &in opts) from "MapTogether";
    import Json::Value@ SetUiFlags(Json::Value &in opts) from "MapTogether";
    import Json::Value@ GetRecentRooms(Json::Value &in opts) from "MapTogether";
    import Json::Value@ CheckDesync(Json::Value &in opts) from "MapTogether";
    import Json::Value@ UndoUpdate(Json::Value &in opts) from "MapTogether";
    import Json::Value@ ListServers(Json::Value &in opts) from "MapTogether";
}

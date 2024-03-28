dictionary yieldReasons;
void yield_why(const string &in why) {
    if (!yieldReasons.Exists(why)) {
        yieldReasons[why] = 1;
    } else {
        yieldReasons[why] = 1 + int(yieldReasons[why]);
    }
    yield();
}

void DrawYeildReasonUI() {
    UI::Text("Time: " + Time::Now);
    UI::Separator();
    UI::AlignTextToFramePadding();
    if (yieldReasons.IsEmpty()) {
        UI::Text("No yield reasons");
    } else {
        UI::Text("Yield Reasons");
        auto keys = yieldReasons.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            string key = keys[i];
            int value = int(yieldReasons[key]);
            UI::Text(key + ": " + value);
        }
    }

    UI::Separator();

    // uint MTUpdateCount_Created = 0;
    // uint MTUpdateCount_Destroyed = 0;
    // uint MTUpdateCount_Place_Created = 0;
    // uint MTUpdateCount_Place_Destroyed = 0;
    // uint MTUpdateCount_Delete_Created = 0;
    // uint MTUpdateCount_Delete_Destroyed = 0;
    // uint MTUpdateCount_SetSkin_Created = 0;
    // uint MTUpdateCount_SetSkin_Destroyed = 0;
    // uint MTUpdateCount_PlayerJoin_Created = 0;
    // uint MTUpdateCount_PlayerJoin_Destroyed = 0;
    // uint MTUpdateCount_PlayerLeave_Created = 0;
    // uint MTUpdateCount_PlayerLeave_Destroyed = 0;
    // uint MTUpdateCount_SetActionLimit_Created = 0;
    // uint MTUpdateCount_SetActionLimit_Destroyed = 0;
    // uint MTUpdateCount_PlayerCamCursor_Created = 0;
    // uint MTUpdateCount_PlayerCamCursor_Destroyed = 0;
    // uint MTUpdateCount_VehiclePos_Created = 0;
    // uint MTUpdateCount_VehiclePos_Destroyed = 0;

    CopiableLabeledValue("MTUpdateCount_Created", tostring(MTUpdateCount_Created));
    CopiableLabeledValue("MTUpdateCount_Destroyed", tostring(MTUpdateCount_Destroyed));
    CopiableLabeledValue("MTUpdateCount_Meta_Created", tostring(MTUpdateCount_Meta_Created));
    CopiableLabeledValue("MTUpdateCount_Meta_Destroyed", tostring(MTUpdateCount_Meta_Destroyed));
    if (g_MTConn !is null) {
        UI::Indent();
        UI::Text("Place/Deletes in Log: " + g_MTConn.updateLog.Length);
        if (UI::Button("Clear Update Log")) {
            g_MTConn.updateLog.RemoveRange(0, g_MTConn.updateLog.Length);
        }
        UI::Unindent();
    }
    CopiableLabeledValue("MTUpdateCount_Place_Created", tostring(MTUpdateCount_Place_Created));
    CopiableLabeledValue("MTUpdateCount_Place_Destroyed", tostring(MTUpdateCount_Place_Destroyed));
    CopiableLabeledValue("MTUpdateCount_Delete_Created", tostring(MTUpdateCount_Delete_Created));
    CopiableLabeledValue("MTUpdateCount_Delete_Destroyed", tostring(MTUpdateCount_Delete_Destroyed));
    CopiableLabeledValue("MTUpdateCount_SetSkin_Created", tostring(MTUpdateCount_SetSkin_Created));
    CopiableLabeledValue("MTUpdateCount_SetSkin_Destroyed", tostring(MTUpdateCount_SetSkin_Destroyed));
    CopiableLabeledValue("MTUpdateCount_PlayerJoin_Created", tostring(MTUpdateCount_PlayerJoin_Created));
    CopiableLabeledValue("MTUpdateCount_PlayerJoin_Destroyed", tostring(MTUpdateCount_PlayerJoin_Destroyed));
    CopiableLabeledValue("MTUpdateCount_PlayerLeave_Created", tostring(MTUpdateCount_PlayerLeave_Created));
    CopiableLabeledValue("MTUpdateCount_PlayerLeave_Destroyed", tostring(MTUpdateCount_PlayerLeave_Destroyed));
    CopiableLabeledValue("MTUpdateCount_SetActionLimit_Created", tostring(MTUpdateCount_SetActionLimit_Created));
    CopiableLabeledValue("MTUpdateCount_SetActionLimit_Destroyed", tostring(MTUpdateCount_SetActionLimit_Destroyed));
    CopiableLabeledValue("MTUpdateCount_PlayerCamCursor_Created", tostring(MTUpdateCount_PlayerCamCursor_Created));
    CopiableLabeledValue("MTUpdateCount_PlayerCamCursor_Destroyed", tostring(MTUpdateCount_PlayerCamCursor_Destroyed));
    CopiableLabeledValue("MTUpdateCount_VehiclePos_Created", tostring(MTUpdateCount_VehiclePos_Created));
    CopiableLabeledValue("MTUpdateCount_VehiclePos_Destroyed", tostring(MTUpdateCount_VehiclePos_Destroyed));
    CopiableLabeledValue("MTUpdateCount_ChatUpdate_Created", tostring(MTUpdateCount_ChatUpdate_Created));
    CopiableLabeledValue("MTUpdateCount_ChatUpdate_Destroyed", tostring(MTUpdateCount_ChatUpdate_Destroyed));

}

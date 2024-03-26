/*
todo:
 - add follow player feature to camera
 - sync option: where you follow each other
 - stats in table
*/

void DrawPlayersTab() {
    if (g_MTConn is null) {
        UI::Text("Not connected to server");
        return;
    }
    PlayerInRoom@ p;
    for (uint i = 0; i < g_MTConn.playersEver.Length; i++) {
        @p = g_MTConn.playersEver[i];
        UI::BeginDisabled(!p.isInRoom);
        if (UI::Button(Icons::Eye + "##focus-" + i)) {
            p.FocusEditorCamera();
        }
        UI::SameLine();
        if (UI::Button(Icons::Eye + Icons::Lock + "##focus-lock-" + i)) {
            p.FocusEditorCamera(true);
        }
        // UI::SameLine();
        // if (UI::Button(Icons::Cross + "##kick-" + i)) {
        //     g_MTConn.KickPlayer(p.id);
        // }
        UI::SameLine();
        UI::AlignTextToFramePadding();
        UI::Text(p.name);

        UI::SameLine();
        UI::Text(p.lastUpdate == PlayerUpdateTy::Cursor ? Icons::HandPointerO : Icons::Car);
        UI::SameLine();

        UI::Text("P: " + (p.blocksPlaced + p.itemsPlaced) + " | D: " + (p.blocksRemoved + p.itemsRemoved));

        UI::EndDisabled();
    }
}

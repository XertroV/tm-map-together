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
            if (p.lastUpdate == PlayerUpdateTy::Cursor) {
                auto camPos = vec3(p.lastCamCursor.cam_matrix.tx, p.lastCamCursor.cam_matrix.ty, p.lastCamCursor.cam_matrix.tz);
                auto targetPos = p.lastCamCursor.target;
                float targetDist = (targetPos - camPos).Length();
                mat4 translation = mat4::Translate(camPos);
                mat4 camMat = mat4(p.lastCamCursor.cam_matrix);
		        auto camRot = mat4::Inverse(mat4::Inverse(translation) * camMat);
                auto pyr = PitchYawRollFromRotationMatrix(camRot);
                Editor::SetCamAnimationGoTo(vec2(pyr.y, pyr.x), targetPos, targetDist);
            } else {
                auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                if (editor !is null) {
                    auto camPos = editor.OrbitalCameraControl.Pos;
                    auto vMat = p.lastVehiclePos.mat;
                    auto vPos = vec3(vMat.tx, vMat.ty, vMat.tz);
                    Editor::SetCamAnimationGoTo(DirToLookUv((vPos - camPos).Normalized()), vPos, 90);
                }
            }
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

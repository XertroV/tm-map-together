class PlayerCamCursor : MTUpdate, HasPlayerLabelDraw {
    iso4 cam_matrix;
    vec3 target;
    uint8 edit_mode;
    uint8 place_mode;
    string cur_obj;
    nat3 coord;
    vec3 pos;

    PlayerCamCursor() {
        ty = MTUpdateTy::PlayerCamCursor;
    }

    PlayerCamCursor(MemoryBuffer@ buf) {
        ty = MTUpdateTy::PlayerCamCursor;
        ReadFromBuf(buf);
    }

    PlayerCamCursor@ ReadFromBuf(MemoryBuffer@ buf) {
        edit_mode = buf.ReadUInt8();
        place_mode = buf.ReadUInt8();
        cam_matrix = ReadIso4FromBuf(buf);
        target = ReadVec3FromBuffer(buf);
        cur_obj = ReadLPStringFromBuffer(buf);
        coord = ReadNat3FromBuffer(buf);
        pos = ReadVec3FromBuffer(buf);
        return this;
    }

    void WriteToNetworkBuffer(MemoryBuffer@ buf) const {
        buf.Write(edit_mode);
        buf.Write(place_mode);
        WriteIso4ToBuf(buf, cam_matrix);
        WriteVec3ToBuffer(buf, target);
        WriteLPStringToBuffer(buf, cur_obj);
        WriteNat3ToBuffer(buf, coord);
        WriteVec3ToBuffer(buf, pos);
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        if (g_MTConn is null) return false;
        g_MTConn.UpdatePlayerCamCursor(this);
        return false;
    }

    void UpdateFrom(PlayerCamCursor@ other) {
        cam_matrix = other.cam_matrix;
        target = other.target;
        edit_mode = other.edit_mode;
        place_mode = other.place_mode;
        cur_obj = other.cur_obj;
        coord = other.coord;
        pos = other.pos;
    }

    bool UpdateFromGame(CGameCtnEditorFree@ editor) {
        if (editor is null) return false;
        auto cursor = editor.Cursor;
        if (cursor is null) return false;
        auto itemCursor = editor.ItemCursor;
        if (itemCursor is null) return false;
        if (!editor.PluginMapType.IsEditorReadyForRequest) return false;
        auto cam = Camera::GetCurrent();
        if (cam is null) return false;
        auto _place_mode = uint8(Editor::GetPlacementMode(editor));
        auto _coord = cursor.Coord;
        vec3 _pos;
        if (_place_mode == CGameEditorPluginMap::EPlaceMode::Item) {
            _pos = itemCursor.CurrentPos;
        } else {
            _pos = cursor.FreePosInMap;
        }
        auto _edit_mode = uint8(Editor::GetEditMode(editor));
        auto _cam_mat = cam.NextLocation;
        auto _target = editor.OrbitalCameraControl.m_TargetedPosition;
        if (editor.CurrentBlockInfo !is null) {
            cur_obj = editor.CurrentBlockInfo.IdName;
        } else if (editor.CurrentGhostBlockInfo !is null) {
            cur_obj = editor.CurrentGhostBlockInfo.IdName;
        } else if (editor.CurrentItemModel !is null) {
            cur_obj = editor.CurrentItemModel.IdName;
        } else if (editor.CurrentMacroBlockInfo !is null) {
            cur_obj = editor.CurrentMacroBlockInfo.IdName;
        } else if (editor.CurrentTrafficItemModel !is null) {
            cur_obj = editor.CurrentTrafficItemModel.IdName;
        } else {
            cur_obj = "";
        }

        if (edit_mode != _edit_mode || place_mode != _place_mode || !MathX::Nat3Eq(coord, _coord) || !MathX::Vec3Eq(pos, _pos) || !MathX::Vec3Eq(target, _target)
            || cam_matrix.tx != _cam_mat.tx || cam_matrix.ty != _cam_mat.ty || cam_matrix.tz != _cam_mat.tz || cur_obj != cur_obj
        ) {
            edit_mode = _edit_mode;
            place_mode = _place_mode;
            coord = _coord;
            pos = _pos;
            cam_matrix = _cam_mat;
            target = _target;
            return true;
        }

        return false;
    }

    void DrawUI() {
        UI::Text("Cursor Pos: " + pos.ToString());
        UI::Text("Cursor Coords: " + coord.ToString());
        UI::Text("Obj: " + cur_obj);
        auto em = EditMode(int(edit_mode));
        auto pm = PlaceMode(int(place_mode));
        UI::Text("Edit mode: " + tostring(em));
        UI::Text("Place mode: " + tostring(pm));
        UI::Text("Cam Pos: " + vec3(cam_matrix.tx, cam_matrix.ty, cam_matrix.tz).ToString());
    }

    vec3 lastScreenTextPos;

    void RenderNvg(const string &in name) {
        bool isPlacing = this.edit_mode == EditMode::Place;
        bool isPlacingCoord = this.place_mode == PlaceMode::Block || this.place_mode == PlaceMode::Macroblock || this.place_mode == PlaceMode::GhostBlock;
        lastScreenTextPos = Camera::ToScreen(target);
        bool drawCamAndTarget = lastScreenTextPos.z < 0.0;
        // if ()
        if (drawCamAndTarget) {
            DrawPlayerLabel(name, lastScreenTextPos.xy, cWhite, cBlack);
        }
    }
}

mixin class HasPlayerLabelDraw {
    vec2 textBounds;

    void DrawPlayerLabel(const string &in name, vec2 textPos, const vec4 &in fg, const vec4 &in bg) {
        auto labelPos = textPos;
        textPos += vec2(playerLabelBaseHeight * .8, 0);
        nvg::FontSize(playerLabelBaseHeight);
        textBounds = nvg::TextBounds(name) + vec2(textPad * 2.0, 0);
        nvg::Reset();
        nvg::FontFace(f_Nvg_Montserrat);
        nvg::BeginPath();
        nvg::LineCap(nvg::LineCapType::Round);
        drawLabelBackgroundTagLines(labelPos, playerLabelBaseHeight, stdTriHeight, textBounds);
        nvg::FillColor(bg);
        nvg::Fill();
        nvg::ClosePath();

        nvg::FontSize(playerLabelBaseHeight);
        nvg::BeginPath();
        nvg::FillColor(fg);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Middle);
        nvg::Text(textPos, name);
        nvg::ClosePath();
    }
}

enum EditMode {
    Unknown,
    Place,
    FreeLook,
    Erase,
    Pick,
    SelectionAdd,
    SelectionRemove,
}

enum PlaceMode {
    Unknown,
    Terraform,
    Block,
    Macroblock,
    Skin,
    CopyPaste,
    Test,
    Plugin,
    CustomSelection,
    OffZone,
    BlockProperty,
    Path,
    GhostBlock,
    Item,
    Light,
    FreeBlock,
    FreeMacroblock,
}


class VehiclePos : MTUpdate, HasPlayerLabelDraw {
    iso4 mat;
    vec3 vel;

    VehiclePos() {
        ty = MTUpdateTy::VehiclePos;
    }

    VehiclePos(MemoryBuffer@ buf) {
        ty = MTUpdateTy::VehiclePos;
        ReadFromBuf(buf);
    }

    VehiclePos@ ReadFromBuf(MemoryBuffer@ buf) {
        mat = ReadIso4FromBuf(buf);
        vel = ReadVec3FromBuffer(buf);
        return this;
    }

    void WriteToNetworkBuffer(MemoryBuffer@ buf) const {
        WriteIso4ToBuf(buf, mat);
        WriteVec3ToBuffer(buf, vel);
    }

    bool Apply(CGameCtnEditorFree@ editor) override {
        if (g_MTConn is null) return false;
        g_MTConn.UpdatePlayerVehiclePos(this);
        return false;
    }

    void UpdateFrom(VehiclePos@ other) {
        mat = other.mat;
        vel = other.vel;
    }

    bool UpdateFromGame(CSceneVehicleVis@ vis) {
        if (vis is null) return false;
        // this will always be true if we're driving
        mat = Dev::GetOffsetIso4(vis, O_VEHICLEVIS_ISO4);
        vel = vis.AsyncState.WorldVel;
        return true;
    }

    void DrawUI() {
        UI::Text("Pos: " + vec3(mat.tx, mat.ty, mat.tz).ToString());
        UI::Text("Vel: " + vel.ToString());
    }

    void RenderNvg(const string &in name) {
        auto pos = vec3(mat.tx, mat.ty, mat.tz);
        auto screenPos = Camera::ToScreen(pos);
        if (screenPos.z > 0.0) return;
        DrawPlayerLabel(name, screenPos.xy, cWhite, cRed25);
        nvgDrawPointCross(screenPos.xy, S_PlayerLabelHeight * .5, cLimeGreen);
    }
}


iso4 ReadIso4FromBuf(MemoryBuffer@ buf) {
    auto ptr = Dev::Allocate(64);
    for (int i = 0; i < 12; i++) {
        Dev::Write(ptr + i * 4, buf.ReadFloat());
    }
    auto ret = Dev::ReadIso4(ptr);
    Dev::Free(ptr);
    return ret;
}

void WriteIso4ToBuf(MemoryBuffer@ buf, iso4 mat) {
    auto ptr = Dev::Allocate(64);
    Dev::Write(ptr, mat);
    for (int i = 0; i < 12; i++) {
        buf.Write(Dev::ReadFloat(ptr + i * 4));
    }
    Dev::Free(ptr);
}

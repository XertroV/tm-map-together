nat3 decoOrigSize;
CGameCtnDecoration@ decoEditMap;

void EditNewMapFrom(MapBase base, MapMood mood, MapCar vehicle, nat3 size, const string &in environment = "Stadium") {
    if (!Permissions::OpenAdvancedMapEditor()) {
        NotifyError("You don't have permission to open the advanced map editor");
        return;
    }
    if (decoEditMap !is null) {
        trace('releasing deco');
        decoEditMap.MwRelease();
        @decoEditMap = null;
        yield();
    }

    bool isStadium = environment == "Stadium";
    auto decoId = BaseAndMoodToDecoId(base, mood, environment);
    auto fid = Fids::GetGame("GameData/" + environment + "/GameCtnDecoration/" + decoId + ".Decoration.Gbx");
    auto deco = cast<CGameCtnDecoration>(Fids::Preload(fid));
    string decoNodIdName;
    if (deco is null) {
        log_warn("deco is null");
        if (!isStadium) {
            NotifyError("Failed to load decoration " + decoId + " for environment " + environment);
            return;
        }
        decoNodIdName = "48x48Screen155Day";
    } else {
        @decoEditMap = deco;
        deco.MwAddRef();
        decoOrigSize.x = deco.DecoSize.SizeX;
        decoOrigSize.y = deco.DecoSize.SizeY;
        decoOrigSize.z = deco.DecoSize.SizeZ;
        deco.DecoSize.SizeX = size.x;
        deco.DecoSize.SizeY = size.y;
        deco.DecoSize.SizeZ = size.z;
        if (isStadium) {
            // Stadium only accepts the standard deco nod name, so swap our deco
            // in behind that fid for the duration of the load.
            startnew(SwapDecoHack);
            decoNodIdName = "48x48Screen155Day";
        } else {
            // Other environments resolve their own nod IdName directly -- and it
            // is not derivable from the file name: RedIsland/WhiteShore are
            // "Day"/"Night"/..., GreenCoast/BlueBay are "Day64"/"Night64"/....
            decoNodIdName = deco.IdName;
        }
    }

    yield();

    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app.ManiaTitleControlScriptAPI is null) {
        return;
    }

    if (m_DisableClubItems_Patch) {
        EditorPatches::DisableClubItems_IsApplied = true;
    } else if (m_EnableClubItemsSkip) {
        EditorPatches::SkipClubFavItemUpdate_IsApplied = true;
    }

    trace("Calling EditNewMap2(" + decoId + ", " + tostring(vehicle) + ")");
    trace("deco id name: " + decoNodIdName);
    app.ManiaTitleControlScriptAPI.EditNewMap2(
        environment,
        decoNodIdName,
        "",
        tostring(vehicle),
        "", false, "", ""
    );
    trace("called open editor");
    yield();
    trace("called open editor + 1 frame");
    trace("result: " + tostring(app.ManiaTitleControlScriptAPI.LatestResult));
    // app.ManiaTitleControlScriptAPI.LatestResult == EResult::Success
    auto success = app.ManiaTitleControlScriptAPI.LatestResult == CGameManiaTitleControlScriptAPI::EResult::Success;
    if (!success) {
        NotifyWarning("Failed to edit new map");
    } else {
        trace('edit map: waiting for editor');
        while (app.Editor is null) yield();
        trace('edit map: disabling patches');
        EditorPatches::UnapplyAny();

        trace('edit map: waiting for editor null');
        while (app.Editor !is null) yield();
        trace('edit map: resetting deco size');
        deco.DecoSize.SizeX = decoOrigSize.x;
        deco.DecoSize.SizeY = decoOrigSize.y;
        deco.DecoSize.SizeZ = decoOrigSize.z;
    }

    if (decoEditMap !is null) {
        trace('edit map: releasing deco');
        decoEditMap.MwRelease();
        @decoEditMap = null;
    }
}


void SwapDecoHack() {
    auto deco = decoEditMap;
    deco.MwAddRef();
    auto stdDecoFid = Fids::GetGame("GameData/Stadium/GameCtnDecoration/Base48x48Screen155Day.Decoration.Gbx");
    Fids::Preload(stdDecoFid);
    if (stdDecoFid.Nod !is null && stdDecoFid.Nod.IdName == deco.IdName) {
        // same deco, do nothing
        trace('standard deco, do nothing');
    } else if (stdDecoFid.Nod !is null && S_EnableNoStadiumHack) {
        log_warn("Swapping decos: " + stdDecoFid.Nod.IdName + " <-> " + deco.IdName);
        auto origNod = stdDecoFid.Nod;
        origNod.MwAddRef();
        Dev::SetOffset(stdDecoFid, GetOffset("CSystemFidFile", "Nod"), deco);
        while (GetApp().Editor is null) yield();
        Dev::SetOffset(stdDecoFid, GetOffset("CSystemFidFile", "Nod"), origNod);
    } else {
        log_warn("Failed to preload std deco");
    }
    trace('releasing deco end swap hack');
    deco.MwRelease();
    @deco = null;
}

nat3 decoOrigSize;
CGameCtnDecoration@ decoEditMap;

void EditNewMapFrom(MapBase base, MapMood mood, MapCar vehicle, nat3 size) {
    if (decoEditMap !is null) {
        trace('releasing deco');
        decoEditMap.MwRelease();
        @decoEditMap = null;
        yield();
    }

    auto decoId = BaseAndMoodToDecoId(base, mood);
    auto fid = Fids::GetGame("GameData/Stadium/GameCtnDecoration/" + decoId + ".Decoration.Gbx");
    auto deco = cast<CGameCtnDecoration>(Fids::Preload(fid));
    string decoNodIdName;
    if (deco is null) {
        log_warn("deco is null");
        decoNodIdName = "48x48Screen155Day";
    } else {
        @decoEditMap = deco;
        deco.MwAddRef();
        // decoNodIdName = deco.IdName;
        decoOrigSize.x = deco.DecoSize.SizeX;
        decoOrigSize.y = deco.DecoSize.SizeY;
        decoOrigSize.z = deco.DecoSize.SizeZ;
        deco.DecoSize.SizeX = size.x;
        deco.DecoSize.SizeY = size.y;
        deco.DecoSize.SizeZ = size.z;
        startnew(SwapDecoHack);
        decoNodIdName = "48x48Screen155Day";
    }

    yield();

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
    trace("deco id name: " + decoNodIdName);
    app.ManiaTitleControlScriptAPI.EditNewMap2(
        // m_Base == MapBase::NoStadium ? "NoStadium" : "Stadium",
        "Stadium",
        decoNodIdName,
        "",
        tostring(vehicle),
        "", false, "", ""
    );
    yield();
    trace("result: " + tostring(app.ManiaTitleControlScriptAPI.LatestResult));
    // app.ManiaTitleControlScriptAPI.LatestResult == EResult::Success
    auto success = app.ManiaTitleControlScriptAPI.LatestResult == CGameManiaTitleControlScriptAPI::EResult::Success;
    if (!success) {
        NotifyWarning("Failed to edit new map");
    } else {
        while (app.Editor is null) yield();
        Patch_DisableClubFavItems.Unapply();
        Patch_SkipClubFavItemUpdate.Unapply();

        while (app.Editor !is null) yield();
        deco.DecoSize.SizeX = decoOrigSize.x;
        deco.DecoSize.SizeY = decoOrigSize.y;
        deco.DecoSize.SizeZ = decoOrigSize.z;
    }

    if (decoEditMap !is null) {
        // trace('releasing deco');
        // decoEditMap.MwRelease();
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
    } else if (stdDecoFid.Nod !is null) {
        log_warn("Swapping decos: " + stdDecoFid.Nod.IdName + " <-> " + deco.IdName);
        auto origNod = stdDecoFid.Nod;
        origNod.MwAddRef();
        Dev::SetOffset(stdDecoFid, GetOffset("CSystemFidFile", "Nod"), deco);
        while (GetApp().Editor is null) yield();
        Dev::SetOffset(stdDecoFid, GetOffset("CSystemFidFile", "Nod"), origNod);
    } else {
        log_warn("Failed to preload std deco");
    }
    trace('releasing deco');
    deco.MwRelease();
    @deco = null;
}

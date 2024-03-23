#if DEPENDENCY_EDITOR


void RunEditorFeedGenerator() {
    startnew(Editor::EditorFeedGen_Loop);
}

void ResetOnLeaveEditor() {
    cacheAutosavedIx = 0;
}

void ResetOnEnterEditor() {
    cacheAutosavedIx = GetAutosaveStackPos(GetAutosaveStructPtr(GetApp()));
    // Main loop works. Main is 50/50
    startnew(Editor::CheckForFreeblockDel).WithRunContext(Meta::RunContext::GameLoop);
}

uint cacheAutosavedIx = 0;
MTUpdate@[] pendingUpdates;

namespace Editor {
    // todo: find run context
    void CheckForFreeblockDel() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor;
        while (true) {
            @editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null && app.Editor is null) break;
            if (app.CurrentPlayground !is null || cast<CGameCtnEditorFree>(app.Editor) is null || app.LoadProgress.State != NGameLoadProgress::EState::Disabled) {
                // yield();
            } else {
                if (HasPendingFreeBlocksToDelete()) {
                    Editor_UndoToLastCached(editor);
                    // this will autosave
                    RunDeleteFreeBlockDetection();
                    Editor_CachePosInUndoStack(editor);
                }
            }
            yield();
        }
    }

    void ReadIntoPendingMessagesWithDiscard() {
        if (g_MTConn is null) return;
        auto updates = g_MTConn.ReadUpdates(50);
        if (updates is null) return;
        for (uint i = 0; i < updates.Length; i++) {
            auto ty = updates[i].ty;
            if (ty == MTUpdateTy::VehiclePos || ty == MTUpdateTy::PlayerCamCursor) {
                continue;
            }
            pendingUpdates.InsertLast(updates[i]);
        }
    }

    void EditorFeedGen_Loop() {
        ResetOnEnterEditor();
        UserUndoRedoDisablePatchEnabled = true;

        CGameCtnApp@ app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            warn("EditorFeedGen_Loop: Editor is null");
            return;
        }
        const array<BlockSpec@>@ placedB;
        const array<BlockSpec@>@ delB;
        const array<ItemSpec@>@ placedI;
        const array<ItemSpec@>@ delI;
        const array<SetSkinSpec@>@ setSkins;
        MacroblockSpec@ placeMb;
        MacroblockSpec@ delMb;

        while (app.Editor !is null) {
            while (app.CurrentPlayground !is null || cast<CGameCtnEditorFree>(app.Editor) is null || app.LoadProgress.State != NGameLoadProgress::EState::Disabled) {
                CheckUpdateVehicle(cast<CSmArenaClient>(app.CurrentPlayground));
                // g_MTConn.PauseAutoRead = true;
                // ReadIntoPendingMessagesWithDiscard();
                yield();
            }
            // g_MTConn.PauseAutoRead = false;
            @editor = cast<CGameCtnEditorFree>(app.Editor);
            CheckUpdateCursor(editor);


            // by getting the placed/del for this frame at this point, our actions will be cleared before the next frame.
            @placedB = Editor::ThisFrameBlocksPlaced();
            @delB = Editor::ThisFrameBlocksDeleted();
            @placedI = Editor::ThisFrameItemsPlaced();
            @delI = Editor::ThisFrameItemsDeleted();
            @setSkins = Editor::ThisFrameSkinsSet();

            if (placedB.Length > 0 || placedI.Length > 0) {
                @placeMb = Editor::MakeMacroblockSpec(placedB, placedI);
            } else {
                @placeMb = null;
            }

            if (delB.Length > 0 || delI.Length > 0) {
                @delMb = Editor::MakeMacroblockSpec(delB, delI);
            } else {
                @delMb = null;
            }

            if (setSkins.Length > 0) {
                Notify("Todo: set skins; got len: " + setSkins.Length);
            }

            bool reportUpdates = false;

            if (delMb !is null) {
                trace("sending deleted");
                g_MTConn.WriteDeleted(delMb);
            }

            if (placeMb !is null) {
                trace("sending placed");
                g_MTConn.WritePlaced(placeMb);
                @lastPlaced = placeMb;
                reportUpdates = true;
            }

            if (setSkins.Length > 0) {
                trace("sending set skins");
                g_MTConn.WriteSetSkins(setSkins);
                reportUpdates = true;
            }

            // if (!g_MTConn.socket.CanRead()) {
            //     warn('can read: false');
            //     break;
            // }
            auto nbPendingUpdates = pendingUpdates.Length;
            if (reportUpdates) {
                trace("nbPendingUpdates: " + nbPendingUpdates);
            }

            if (nbPendingUpdates > 0) {
                auto pmt = editor.PluginMapType;

                auto _NextMapElemColor = pmt.NextMapElemColor;
                auto _NextPhaseOffset = pmt.NextItemPhaseOffset;
                auto _NextMbOffset = pmt.NextMbAdditionalPhaseOffset;
                auto _NextMbColor = pmt.ForceMacroblockColor;

                pmt.NextMapElemColor = CGameEditorPluginMap::EMapElemColor::Default;
                pmt.NextItemPhaseOffset = CGameEditorPluginMap::EPhaseOffset::None;
                pmt.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset::None;
                pmt.ForceMacroblockColor = false;

                trace("applying updates: " + nbPendingUpdates);
                Editor_UndoToLastCached(editor);

                bool autosave = false;
                for (uint i = 0; i < pendingUpdates.Length; i++) {
                    autosave = pendingUpdates[i].Apply(editor) || autosave;
                    trace("!!!!!!!!!!!!!!!!!!           applied pending update: " + i);
                }
                pendingUpdates.RemoveRange(0, pendingUpdates.Length);

                // for (uint i = 0; i < nbUpdates; i++) {
                //     updates[i].Apply(editor);
                //     trace("!!!!!!!!!!!!!!!!!!           applied update: " + i);
                // }

                if (autosave) {
                    editor.PluginMapType.AutoSave();
                }
                // we track this to note player placements. When we get new packets, we undo back to the last cached point, and then apply updates
                Editor_CachePosInUndoStack(editor);
                trace("cacheAutosavedIx: " + cacheAutosavedIx);

                pmt.NextMapElemColor = _NextMapElemColor;
                pmt.NextItemPhaseOffset = _NextPhaseOffset;
                pmt.NextMbAdditionalPhaseOffset = _NextMbOffset;
                pmt.ForceMacroblockColor = _NextMbColor;
            }
            yield();
        }
        trace('exited Editor::EditorFeedGen_Loop');
        g_MTConn.Close();
        @g_MTConn = null;
        trace('Closed connection and set to null');
        UserUndoRedoDisablePatchEnabled = false;
    }

    void Editor_CachePosInUndoStack(CGameCtnEditorFree@ editor) {
        cacheAutosavedIx = GetAutosaveStackPos(GetAutosaveStructPtr(editor));
    }

    void Editor_UndoToLastCached(CGameCtnEditorFree@ editor) {
        auto autosaveStruct = GetAutosaveStructPtr(editor);
        auto currAutosaveIx = GetAutosaveStackPos(autosaveStruct);
        trace("currAutosaveIx: " + currAutosaveIx + ", cacheAutosavedIx: " + cacheAutosavedIx);
        if (currAutosaveIx >= 0 && cacheAutosavedIx >= 0) {
            while (currAutosaveIx > int(cacheAutosavedIx)) {
                editor.PluginMapType.Undo();
                trace("undid: " + currAutosaveIx);
                currAutosaveIx--;
            }
        } else {
            NotifyWarning("EditorFeedGen_Loop: Autosave stack null?! ptr: " + Text::FormatPointer(autosaveStruct));
        }
    }

    VehiclePos@ lastVehiclePos = VehiclePos();

    void CheckUpdateVehicle(CSmArenaClient@ pg) {
        if (pg is null || pg.GameTerminals.Length == 0) return;
        auto player = cast<CSmPlayer>(pg.GameTerminals[0].ControlledPlayer);
        if (player is null) return;
        CSceneVehicleVis@ vis = VehicleState::GetVis(pg.GameScene, player);
        if (vis is null) return;
        if (lastVehiclePos.UpdateFromGame(vis)) {
            g_MTConn.WriteVehiclePos(lastVehiclePos);
        }
    }

    PlayerCamCursor@ lastPlayerCamCursor = PlayerCamCursor();

    void CheckUpdateCursor(CGameCtnEditorFree@ editor) {
        if (lastPlayerCamCursor.UpdateFromGame(editor)) {
            g_MTConn.WritePlayerCamCursor(lastPlayerCamCursor);
        }
    }
}



#endif

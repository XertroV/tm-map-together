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
// MTUpdate@[] pendingUpdates;

bool placedLastFrame = false;

namespace Editor {
    // Run Context: MainLoop and GameLoop seem to work
    void CheckForFreeblockDel() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor;
        while (true) {
            @editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null && app.Editor is null) break;
            if (app.CurrentPlayground !is null || cast<CGameCtnEditorFree>(app.Editor) is null || app.LoadProgress.State != NGameLoadProgress::EState::Disabled) {
                // testing or item/mt editor or something
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

    // void ReadIntoPendingMessagesWithDiscard() {
    //     if (g_MTConn is null) return;
    //     auto updates = g_MTConn.ReadUpdates(50);
    //     if (updates is null) return;
    //     for (uint i = 0; i < updates.Length; i++) {
    //         // auto ty = updates[i].ty;
    //         // if (ty == MTUpdateTy::VehiclePos || ty == MTUpdateTy::PlayerCamCursor) {
    //         //     continue;
    //         // }
    //         pendingUpdates.InsertLast(updates[i]);
    //     }
    // }

    void EditorFeedGen_Loop() {
        ResetOnEnterEditor();
        UserUndoRedoDisablePatchEnabled = true;
        sleep(200);

        CGameCtnApp@ app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            warn("EditorFeedGen_Loop: Editor is null");
            return;
        }
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        @editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            warn("EditorFeedGen_Loop: Editor is null");
            return;
        }
        trace('initial autosave now.');
        editor.PluginMapType.AutoSave();
        yield();

        const array<BlockSpec@>@ placedB;
        const array<BlockSpec@>@ delB;
        const array<ItemSpec@>@ placedI;
        const array<ItemSpec@>@ delI;
        const array<SetSkinSpec@>@ setSkins;
        MacroblockSpec@ placeMb;
        MacroblockSpec@ delMb;

        while (app.Editor !is null) {
            while (app.CurrentPlayground !is null || cast<CGameCtnEditorFree>(app.Editor) is null || app.LoadProgress.State != NGameLoadProgress::EState::Disabled) {
                if (g_MTConn is null) break;
                CheckUpdateVehicle(cast<CSmArenaClient>(app.CurrentPlayground));
                // g_MTConn.PauseAutoRead = true;
                // ReadIntoPendingMessagesWithDiscard();
                yield();
            }

            if (g_MTConn is null) break;

            // g_MTConn.PauseAutoRead = false;
            @editor = cast<CGameCtnEditorFree>(app.Editor);
            if (editor is null) { yield(); continue; }
            if (!editor.PluginMapType.IsEditorReadyForRequest) { yield(); continue; }
            CheckUpdateCursor(editor);

            // by getting the placed/del for this frame at this point, our actions will be cleared before the next frame.
            @placedB = Editor::ThisFrameBlocksPlaced();
            @delB = Editor::ThisFrameBlocksDeleted();
            @placedI = Editor::ThisFrameItemsPlaced();
            @delI = Editor::ThisFrameItemsDeleted();
            @setSkins = Editor::ThisFrameSkinsSet();

            uint origPlacedTotal = placedB.Length + placedI.Length;
            uint origDelTotal = delB.Length + delI.Length;

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

            // ignore set skins for now (infinite loop glitch oops)
            // if (setSkins.Length > 0) {
            //     trace("sending set skins");
            //     g_MTConn.WriteSetSkins(setSkins);
            //     reportUpdates = true;
            // }

            // if (!g_MTConn.socket.CanRead()) {
            //     warn('can read: false');
            //     break;
            // }
            // auto nbPendingUpdates = pendingUpdates.Length;
            // auto updates = g_MTConn.ReadUpdates(50);
            // if (updates is null) break;
            auto nbPendingUpdates = Math::Clamp(g_MTConn.pendingUpdates.Length, 0, 50);
            // auto nbUpdates = updates.Length;
            // if (reportUpdates || nbUpdates > 0 || nbPendingUpdates > 0) {
            if (reportUpdates || nbPendingUpdates > 0) {
                // trace("updates: " +updates.Length+ ", nbPendingUpdates: " + nbPendingUpdates);
                trace("nbPendingUpdates: " + nbPendingUpdates);
            }

            // if (nbPendingUpdates > 0 || nbUpdates > 0) {
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

                uint startPlacing = Time::Now;
                uint maxPlacingTime = startPlacing + 1500;
                bool autosave = false;
                for (uint i = 0; i < nbPendingUpdates; i++) {
                    autosave = g_MTConn.pendingUpdates[i].Apply(editor) || autosave;
                    trace("!!!!!!!!!!!!!!!!!!    "+tostring(g_MTConn.pendingUpdates[i].ty)+"       applied pending update: " + i);
                    if (maxPlacingTime < Time::Now) {
                        NotifyWarning("EditorFeedGen_Loop: max placing time exceeded. Breaking.");
                        nbPendingUpdates = i + 1;
                        break;
                    }
                }
                g_MTConn.pendingUpdates.RemoveRange(0, nbPendingUpdates);

                // for (uint i = 0; i < nbUpdates; i++) {
                //     autosave = updates[i].Apply(editor) || autosave;
                //     trace("!!!!!!!!!!!!!!!!!!           applied update: " + i);
                // }

                // uint newPlacedTotal = placedB.Length + placedI.Length;
                // uint newDelTotal = delB.Length + delI.Length;
                // if (origPlacedTotal != newPlacedTotal || origDelTotal != newDelTotal) {
                //     Notify("EditorFeedGen_Loop: placed/del changed during update processing. origPlacedTotal: " + origPlacedTotal + ", newPlacedTotal: " + newPlacedTotal + ", origDelTotal: " + origDelTotal + ", newDelTotal: " + newDelTotal);
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
        warn('exited Editor::EditorFeedGen_Loop');
        if (g_MTConn !is null) {
            g_MTConn.Close();
            @g_MTConn = null;
        }
        warn('Closed connection and set to null');
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
    uint lastUpdateVehicleCheck = 0;
    uint lastUpdateCursorCheck = 0;
    uint updateEveryMs = 100;

    void CheckUpdateVehicle(CSmArenaClient@ pg) {
        if (lastUpdateVehicleCheck + updateEveryMs > Time::Now) return;
        if (pg is null || pg.GameTerminals.Length == 0) return;
        auto player = cast<CSmPlayer>(pg.GameTerminals[0].ControlledPlayer);
        if (player is null) return;
        CSceneVehicleVis@ vis = VehicleState::GetVis(pg.GameScene, player);
        if (vis is null) return;
        if (lastVehiclePos.UpdateFromGame(vis)) {
            lastUpdateVehicleCheck = Time::Now;
            g_MTConn.WriteVehiclePos(lastVehiclePos);
        }
    }

    PlayerCamCursor@ lastPlayerCamCursor = PlayerCamCursor();

    void CheckUpdateCursor(CGameCtnEditorFree@ editor) {
        if (lastUpdateCursorCheck + updateEveryMs > Time::Now) return;
        if (g_MTConn !is null && lastPlayerCamCursor.UpdateFromGame(editor)) {
            lastUpdateCursorCheck = Time::Now;
            g_MTConn.WritePlayerCamCursor(lastPlayerCamCursor);
        }
    }
}



#endif

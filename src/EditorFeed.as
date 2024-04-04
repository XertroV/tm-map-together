#if DEPENDENCY_EDITOR


void RunEditorFeedGenerator() {
    startnew(Editor::EditorFeedGen_Loop);
}

void ResetOnLeaveEditor() {
    cacheAutosavedIx = 0;
    myUpdateStack.RemoveRange(0, myUpdateStack.Length);
}

void ResetOnEnterEditor() {
    Editor::desyncCheckNonce = 0;
    myUpdateStack.RemoveRange(0, myUpdateStack.Length);
    cacheAutosavedIx = GetAutosaveStackPos(GetAutosaveStructPtr(GetApp()));
    // Main loop works. Main is 50/50
    startnew(Editor::CheckForFreeblockDel).WithRunContext(Meta::RunContext::GameLoop);
}

uint cacheAutosavedIx = 0;

MTUpdateUndoable@[] myUpdateStack = {};

namespace Editor {
    // Run Context: MainLoop and GameLoop seem to work
    void CheckForFreeblockDel() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor;
        while (g_MTConn !is null && g_MTConn.IsConnected) {
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

    bool m_ShouldIgnoreNextAction = false;

    void EditorFeedGen_Loop() {
        ResetOnEnterEditor();
        UserUndoRedoDisablePatchEnabled = true;
        SetupEditorIntercepts();
        Patch_DisableSweeps.Apply();
        sleep(200);

        CGameCtnApp@ app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            log_warn("EditorFeedGen_Loop: Editor is null");
            return;
        }
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        @editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            log_warn("EditorFeedGen_Loop: Editor is null");
            return;
        }
        log_trace('initial autosave now.');
        editor.PluginMapType.AutoSave();
        yield();

        const array<BlockSpec@>@ placedB;
        const array<BlockSpec@>@ delB;
        const array<ItemSpec@>@ placedI;
        const array<ItemSpec@>@ delI;
        const array<SetSkinSpec@>@ setSkins;
        const array<SetSkinSpec@>@ lastSetSkins;
        MacroblockSpec@ placeMb;
        MacroblockSpec@ delMb;

        bool wasInPlayground = false;
        while (app.Editor !is null) {
            wasInPlayground = false;
            while (app.CurrentPlayground !is null || cast<CGameCtnEditorFree>(app.Editor) is null || app.LoadProgress.State != NGameLoadProgress::EState::Disabled) {
                if (g_MTConn is null) break;
                CheckUpdateVehicle(cast<CSmArenaClient>(app.CurrentPlayground));
                wasInPlayground = true;
                // g_MTConn.PauseAutoRead = true;
                // ReadIntoPendingMessagesWithDiscard();
                yield();
            }
            if (wasInPlayground) {
                wasInPlayground = false;
                yield();
            }
            if (g_MTConn is null) break;

            // g_MTConn.PauseAutoRead = false;
            @editor = cast<CGameCtnEditorFree>(app.Editor);
            if (editor is null) { yield(); continue; }

            // Note: editor.PluginMapType.IsEditorReadyForRequest is false when in skinning mode
            // we still want to listen for updates, though, so we continue through until we get to actually applying updates and skip at that point.

            CheckUpdateCursor(editor);

            // by getting the placed/del for this frame at this point, our actions will be cleared before the next frame.
            @placedB = Editor::ThisFrameBlocksPlaced();
            @delB = Editor::ThisFrameBlocksDeleted();
            @placedI = Editor::ThisFrameItemsPlaced();
            @delI = Editor::ThisFrameItemsDeleted();
            @setSkins = Editor::ThisFrameSkinsSet();
            @lastSetSkins = Editor::LastFrameSkinsSet();
            // trace('setSkins: ' + setSkins.Length);
            // trace('setSkinsApi: ' + Editor::ThisFrameSkinsSetByAPI().Length);
            // trace('setSkinsLastFrame: ' + Editor::LastFrameSkinsSet().Length);

            uint origPlacedTotal = placedB.Length + placedI.Length;
            uint origDelTotal = delB.Length + delI.Length;

            if (placedB.Length > 0 || placedI.Length > 0) {
                @placeMb = Editor::MakeMacroblockSpec(placedB, placedI);
                // update last local action MB so only both are non-null if they took place on the same frame.
                @lastLocalPlaceMb = placeMb;
                @lastLocalDeleteMb = null;
            } else {
                @placeMb = null;
            }

            if (delB.Length > 0 || delI.Length > 0) {
                @delMb = Editor::MakeMacroblockSpec(delB, delI);
                @lastLocalDeleteMb = delMb;
                if (placeMb is null) {
                    @lastLocalPlaceMb = null;
                }
            } else {
                @delMb = null;
            }

            if (setSkins.Length > 0) {
                Notify("Todo: set skins; got len: " + setSkins.Length);
            }

            if (delMb is null && placeMb is null && setSkins.Length > 0) {
                // cache autosave to avoid overwriting skins set
                Editor_CachePosInUndoStack(editor);
                log_trace("Cached autosave pos b/c skins set: " + setSkins.Length);
            }

            bool reportUpdates = false;

            if (delMb !is null) {
                log_trace("sending deleted: " + delMb.Blocks.Length + " / " + delMb.Items.Length);
                g_MTConn.WriteDeleted(delMb);
                if (!m_ShouldIgnoreNextAction) {
                    myUpdateStack.InsertLast(MTDeleteUpdate(delMb));
                }
                reportUpdates = true;
            }

            if (placeMb !is null) {
                log_trace("sending placed " + placeMb.Blocks.Length + " / " + placeMb.Items.Length);
                for (uint i = 0; i < placeMb.Items.Length; i++) {
                    auto item = placeMb.Items[i];
                    // set all items flying and block coord before sending
                    // this solves some problems placing them on free blocks
                    item.isFlying = 1;
                    item.coord = PosToCoord(item.pos);

                    if (S_PrintItemPlacingDebug) {
                        PrintItemSpecDebug(item);
                    }
                }
                g_MTConn.WritePlaced(placeMb);
                if (!m_ShouldIgnoreNextAction) {
                    myUpdateStack.InsertLast(MTPlaceUpdate(placeMb));
                }
                reportUpdates = true;
            }

            if (S_EnableSettingSkins && setSkins.Length > 0) {
                log_trace("sending set skins");
                g_MTConn.WriteSetSkins(setSkins);
                reportUpdates = true;
            } else if (!S_EnableSettingSkins && setSkins.Length > 0) {
                log_debug("ignoring " + setSkins.Length + " set skins");
            }

            if (m_ShouldIgnoreNextAction) {
                @lastLocalDeleteMb = null;
                @lastLocalPlaceMb = null;
                m_ShouldIgnoreNextAction = false;
            }

            if (!editor.PluginMapType.IsEditorReadyForRequest) {
                yield();
                continue;
            }


            // if (!g_MTConn.socket.CanRead()) {
            //     log_warn('can read: false');
            //     break;
            // }
            // auto nbPendingUpdates = pendingUpdates.Length;
            // auto updates = g_MTConn.ReadUpdates(50);
            // if (updates is null) break;
            auto nbPendingUpdates = Math::Clamp(g_MTConn.pendingUpdates.Length, 0, 50);
            // auto nbUpdates = updates.Length;
            // if (reportUpdates || nbUpdates > 0 || nbPendingUpdates > 0) {
            if (reportUpdates || nbPendingUpdates > 0) {
                // log_trace("updates: " +updates.Length+ ", nbPendingUpdates: " + nbPendingUpdates);
                log_trace("nbPendingUpdates: " + nbPendingUpdates);
            }

            // if (nbPendingUpdates > 0 || nbUpdates > 0) {
            // special case: the last update is the thing we just placed, and that's the only change
            bool skipNormalProcessing = false;
            if (S_EnablePlacementOptmization_Skip1TrivialMine && nbPendingUpdates == 1 && Editor_GetCurrPosInUndoStack(editor) == cacheAutosavedIx + 1) {
                auto placeUpdate = cast<MTPlaceUpdate>(g_MTConn.pendingUpdates[0]);
                auto delUpdate = cast<MTDeleteUpdate>(g_MTConn.pendingUpdates[0]);
                if (g_MTConn.pendingUpdates[0].ty == MTUpdateTy::Place
                    && AreMacroblockSpecsEq(lastLocalPlaceMb, placeUpdate.mb)
                ) {
                    log_debug("skipping normal processing: trivial place");
                    skipNormalProcessing = true;
                    @lastAppliedPlaceMb = placeUpdate.mb;
                } else if (g_MTConn.pendingUpdates[0].ty == MTUpdateTy::Delete
                    && AreMacroblockSpecsEq(lastLocalDeleteMb, delUpdate.mb)
                ) {
                    log_debug("skipping normal processing: trivial delete");
                    skipNormalProcessing = true;
                    @lastAppliedDeleteMb = delUpdate.mb;
                }

                // update state
                if (skipNormalProcessing) {
                    Editor_CachePosInUndoStack(editor);
                    g_MTConn.pendingUpdates.RemoveAt(0);
                    log_trace("cacheAutosavedIx: " + cacheAutosavedIx);
                }
            }

            if (!skipNormalProcessing && nbPendingUpdates > 0) {
                auto pmt = editor.PluginMapType;

                auto _NextMapElemColor = pmt.NextMapElemColor;
                auto _NextPhaseOffset = pmt.NextItemPhaseOffset;
                auto _NextMbOffset = pmt.NextMbAdditionalPhaseOffset;
                auto _NextMbColor = pmt.ForceMacroblockColor;

                pmt.NextMapElemColor = CGameEditorPluginMap::EMapElemColor::Default;
                pmt.NextItemPhaseOffset = CGameEditorPluginMap::EPhaseOffset::None;
                pmt.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset::None;
                pmt.ForceMacroblockColor = false;

                auto editMode = pmt.EditMode;

                log_trace("applying updates: " + nbPendingUpdates);
                Editor_UndoToLastCached(editor);

                uint startPlacing = Time::Now;
                uint maxPlacingTime = startPlacing + S_MaximumPlacementTime;
                bool autosave = false;
                MTUpdate@ update;
                for (int i = 0; i < nbPendingUpdates; i++) {
                    if (maxPlacingTime < Time::Now) {
                        auto remainingUpdates = nbPendingUpdates - i;
                        auto timeTaken = Time::Now - startPlacing;
                        log_warn("EditorFeedGen_Loop: max placing time exceeded ("+timeTaken+"ms). Remaining updates: "+remainingUpdates+" / "+nbPendingUpdates);
                        nbPendingUpdates = i;
                        break;
                    }
                    @update = g_MTConn.pendingUpdates[i];
                    autosave = update.Apply(editor) || autosave;
                    log_trace("!!!!!!!!!!!!!!!!!!    "+tostring(update.ty)+"       applied pending update: " + i);
                    CheckUpdateForMissingBlocksItems(update);
                }
                if (g_MTConn.pendingUpdates[nbPendingUpdates - 1].ty == MTUpdateTy::Place) {
                    @lastAppliedPlaceMb = cast<MTPlaceUpdate>(g_MTConn.pendingUpdates[nbPendingUpdates - 1]).mb;
                } else if (g_MTConn.pendingUpdates[nbPendingUpdates - 1].ty == MTUpdateTy::Delete) {
                    @lastAppliedDeleteMb = cast<MTDeleteUpdate>(g_MTConn.pendingUpdates[nbPendingUpdates - 1]).mb;
                }
                g_MTConn.pendingUpdates.RemoveRange(0, nbPendingUpdates);

                if (g_MTConn.pendingUpdates.Length == 0) {
                    // only check for desync after we're done processing everything
                    if (desyncCheckNonce % S_DesyncCheckPlacePeriod == 0) {
                        autosave = CheckForDesyncObjects() || autosave;
                        log_trace("checked for desync objects");
                    }
                    desyncCheckNonce++;
                }

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
                log_trace("cacheAutosavedIx: " + cacheAutosavedIx);

                pmt.NextMapElemColor = _NextMapElemColor;
                pmt.NextItemPhaseOffset = _NextPhaseOffset;
                pmt.NextMbAdditionalPhaseOffset = _NextMbOffset;
                pmt.ForceMacroblockColor = _NextMbColor;
                pmt.EditMode = editMode;
                log_debug("restored edit mode: " + tostring(pmt.EditMode));
            }
            yield();
        }
        log_warn('exited Editor::EditorFeedGen_Loop');
        if (g_MTConn !is null) {
            g_MTConn.Close();
            @g_MTConn = null;
            g_MenuState = MenuState::None;
        }
        log_warn('Closed connection and set to null');
        UserUndoRedoDisablePatchEnabled = false;
        CleanupEditorIntercepts();
        Patch_DisableSweeps.Unapply();
    }

    uint desyncCheckNonce = 0;

    // return true to autosave; if desync objects were found and fixed
    bool CheckForDesyncObjects() {
        if (g_MTConn is null) return false;
        if (g_MTConn.pendingUpdates.Length > 0) return false;
        auto extra = Editor::SubtractTreeFromMapCache(g_MTConn.mapTree);
        if (extra !is null) {
            log_warn("Desync objects found: " + extra.Length);
            // for (uint i = 0; i < extra.Blocks.Length; i++) {
            //     log_warn("Extra block: " + extra.Blocks[i].name + " at " + extra.Blocks[i].pos.ToString());
            // }
            // for (uint i = 0; i < extra.Items.Length; i++) {
            //     log_warn("Extra item: " + extra.Items[i].name + " at " + extra.Items[i].pos.ToString());
            // }
        }
        auto missing = g_MTConn.mapTree.Subtract(Editor::GetCachedMapOctTree());
        log_warn("Missing objects found: " + missing.Length);
        for (uint i = 0; i < missing.Length; i++) {
            log_warn("Missing: " + missing[i].ToString() + " at " + missing[i].point.ToString());
            if (missing[i].item !is null) {
                auto item = missing[i].item;
                item.isFlying = 1;
                item.coord = PosToCoord(item.pos);
                // trace('name: ' + item.name);
                // trace('collection: ' + item.collection);
                // trace('author: ' + item.author);
                // trace('coord: ' + item.coord.ToString());
                // trace('dir: ' + item.dir);
                // trace('pos: ' + item.pos.ToString());
                // trace('pyr: ' + item.pyr.ToString());
                // trace('scale: ' + item.scale);
                // trace('color: ' + item.color);
                // trace('lmQual: ' + item.lmQual);
                // trace('phase: ' + item.phase);
                // trace('pivotPos: ' + item.pivotPos.ToString());
                // trace('isFlying: ' + item.isFlying);
                // trace('variantIx: ' + item.variantIx);
            }
        }
        bool gotExtra = extra !is null && extra.Length > 0;
        bool gotMissing = missing.Length > 0;

        if (gotExtra && gotMissing) {
            // auto e1b = extra.Blocks.Length > 0 ? extra.Blocks[0] : null;
            // auto e1i = extra.Items.Length > 0 ? extra.Items[0] : null;
            // auto m1 = missing[0];
            // auto m1b = m1.block;
            // auto m1i = m1.item;
            // if (e1b !is null && m1b !is null) {
            //     log_warn("Desync: extra block: " + e1b.name + " at " + e1b.pos.ToString() + ", missing block: " + m1b.name + " at " + m1b.pos.ToString());
            //     log_trace('eq: ' + (e1b == m1b));
            // } else if (e1i !is null && m1i !is null) {
            //     log_warn("Desync: extra item: " + e1i.name + " at " + e1i.pos.ToString() + ", missing item: " + m1i.name + " at " + m1i.pos.ToString());
            //     log_trace('eq: ' + (e1i == m1i));
            // }
            // for (uint i = 0; i < extra.Items.Length; i++) {
            //     for (uint j = 0; j < missing.Length; j++) {
            //         if (missing[j].item is null) continue;
            //         if (extra.Items[i].name == missing[j].item.name && MathX::Vec3Eq(extra.Items[i].pos, missing[j].item.pos)) {
            //             log_warn("Desync: extra item: " + extra.Items[i].name + " at " + extra.Items[i].pos.ToString() + ", missing item: " + missing[j].item.name + " at " + missing[j].item.pos.ToString());
            //             log_debug("Eq: " + (extra.Items[i] == missing[j].item));
            //             if (S_PrintItemPlacingDebug) {
            //                 PrintItemSpecDebug(extra.Items[i]);
            //                 PrintItemSpecDebug(missing[j].item);
            //             }
            //         }
            //     }
            // }
        }
        bool shouldAutosave = gotExtra || gotMissing;
        if (gotExtra) {
            Editor::DeleteMacroblock(extra, false);
            log_trace("Deleted extra objects: " + extra.Length);
        }
        if (gotMissing) {
            Editor::PlaceMacroblock(missing.PopulateMacroblock(Editor::MakeMacroblockSpec()), false);
            log_trace("Placed missing objects: " + missing.Length);
        }
        return shouldAutosave;
    }

    dictionary missingBlocksAndItems;

    void CheckUpdateForMissingBlocksItems(MTUpdate@ update) {
        if (!update.isUndoable) return;
        auto place = cast<MTPlaceUpdate>(update);
        if (place !is null) {
            for (uint i = 0; i < place.mb.Blocks.Length; i++) {
                if (place.mb.Blocks[i].BlockInfo is null) {
                    g_MTConn.statusMsgs.AddGameEvent(UserPlacedMissingBlockItemEvent(update.meta.GetPlayer(), place.mb.Blocks[i].name));
                    if (!missingBlocksAndItems.Exists(place.mb.Blocks[i].name)) {
                        missingBlocksAndItems[place.mb.Blocks[i].name] = true;
                    }
                    // remove to avoid desync trigger
                    g_MTConn.mapTree.Remove(place.mb.Blocks[i]);
                }
            }
            for (uint i = 0; i < place.mb.Items.Length; i++) {
                if (place.mb.Items[i].Model is null) {
                    g_MTConn.statusMsgs.AddGameEvent(UserPlacedMissingBlockItemEvent(update.meta.GetPlayer(), place.mb.Items[i].name));
                    if (!missingBlocksAndItems.Exists(place.mb.Items[i].name)) {
                        missingBlocksAndItems[place.mb.Items[i].name] = true;
                    }
                    // remove to avoid desync trigger
                    g_MTConn.mapTree.Remove(place.mb.Items[i]);
                }
            }
            return;
        }
    }

    void Editor_CachePosInUndoStack(CGameCtnEditorFree@ editor) {
        cacheAutosavedIx = GetAutosaveStackPos(GetAutosaveStructPtr(editor));
    }

    uint Editor_GetCurrPosInUndoStack(CGameCtnEditorFree@ editor) {
        return GetAutosaveStackPos(GetAutosaveStructPtr(editor));
    }

    void Editor_UndoToLastCached(CGameCtnEditorFree@ editor) {
        auto autosaveStruct = GetAutosaveStructPtr(editor);
        auto currAutosaveIx = GetAutosaveStackPos(autosaveStruct);
        log_trace("currAutosaveIx: " + currAutosaveIx + ", cacheAutosavedIx: " + cacheAutosavedIx);
        if (currAutosaveIx >= 0 && cacheAutosavedIx >= 0) {
            while (currAutosaveIx > int(cacheAutosavedIx)) {
                editor.PluginMapType.Undo();
                log_trace("undid: " + currAutosaveIx);
                currAutosaveIx--;
            }
        } else {
            NotifyWarning("EditorFeedGen_Loop: Autosave stack null?! ptr: " + Text::FormatPointer(autosaveStruct));
        }
    }

    VehiclePos@ lastVehiclePos = VehiclePos();
    uint lastUpdateVehicleCheck = 0;
    uint lastUpdateCursorCheck = 0;
    uint updateEveryMs {
        get {
            return Math::Max(
                Math::Max(S_UpdateMS_Clamped, 50),
                g_MTConn !is null
                    ? Math::Min(g_MTConn.playersInRoom.Length * 50, 3000)
                    : 50
            );
        }
    }

    void CheckUpdateVehicle(CSmArenaClient@ pg) {
        // add some randomness to help break messages up so they don't all arrive at once
        if (lastUpdateVehicleCheck + updateEveryMs + uint(Math::Rand(0, 200)) > uint(Time::Now)) return;
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


void PrintItemSpecDebug(Editor::ItemSpec@ item) {
    log_info('item placing:');
    log_trace('name: ' + item.name);
    log_trace('collection: ' + item.collection);
    log_trace('author: ' + item.author);
    log_trace('coord: ' + item.coord.ToString());
    log_trace('dir: ' + item.dir);
    log_trace('pos: ' + item.pos.ToString());
    log_trace('pyr: ' + item.pyr.ToString());
    log_trace('scale: ' + item.scale);
    log_trace('color: ' + item.color);
    log_trace('lmQual: ' + item.lmQual);
    log_trace('phase: ' + item.phase);
    log_trace('pivotPos: ' + item.pivotPos.ToString());
    log_trace('isFlying: ' + item.isFlying);
    log_trace('variantIx: ' + item.variantIx);
}


void UndoRestrictionPatches() {
    Patch_DisableSweeps.Unapply();
}


#endif

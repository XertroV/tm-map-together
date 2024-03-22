#if DEPENDENCY_EDITOR


void RunEditorFeedGenerator() {
    startnew(Editor::EditorFeedGen_Loop);
}

void ResetOnLeaveEditor() {
    cacheAutosavedIx = 0;
}

void ResetOnEnterEditor() {
    cacheAutosavedIx = GetAutosaveStackPos(GetAutosaveStructPtr(GetApp()));
}

uint cacheAutosavedIx = 0;

namespace Editor {
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
                yield();
            }
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

            // if (!g_MTConn.socket.CanRead()) {
            //     warn('can read: false');
            //     break;
            // }
            auto updates = g_MTConn.ReadUpdates();
            if (updates is null) {
                warn('updates is null');
                break;
            }
            auto nbUpdates = updates.Length;
            if (reportUpdates) {
                trace("nbUpdates: " + nbUpdates);
            }

            // if (placeMb !is null) {
            //     // Editor_UndoToLastCached(editor);
            //     if (!Editor::PlaceMacroblock(placeMb)) {
            //         NotifyWarning("EditorFeedGen_Loop: Failed to place macroblock");
            //     }
            //     // editor.PluginMapType.AutoSave();
            //     Editor_CachePosInUndoStack(editor);
            //     trace("(hackplace) cacheAutosavedIx: " + cacheAutosavedIx);
            //     yield();
            //     continue;
            // }

            if (nbUpdates > 0) {
                trace("applying updates: " + nbUpdates);
                Editor_UndoToLastCached(editor);

                for (uint i = 0; i < nbUpdates; i++) {
                    updates[i].Apply(editor);
                    trace("!!!!!!!!!!!!!!!!!!           applied update: " + i);
                }

                editor.PluginMapType.AutoSave();
                trace("autosaved");
                // we track this to note player placements. When we get new packets, we undo back to the last cached point, and then apply updates
                Editor_CachePosInUndoStack(editor);
                trace("cacheAutosavedIx: " + cacheAutosavedIx);
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
}



#endif

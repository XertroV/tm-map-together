#if DEPENDENCY_EDITOR

void DrawDesyncTab() {
    auto @extra = Editor::desyncLastExtra;
    auto @missing = Editor::desyncLastMissing;
    UI::AlignTextToFramePadding();
    UI::Text("Extra Blocks/Items");
    if (extra is null) {
        UI::Text("<null> (not run, or nothing detected)");
    } else if (extra.Length == 0) {
        UI::Text("No extra blocks detected.");
    } else {
        Desync_DrawMacroblockSummary("Extra Blocks", extra);
    }
    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("Missing Blocks/Items");
    if (missing is null) {
        UI::Text("<null> (not run, or nothing detected)");
    } else if (missing.Length == 0) {
        UI::Text("No missing blocks detected.");
    } else {
        Desync_DrawOctTreeSummary("Missing Blocks", missing);
    }
    UI::Separator();
    if (UI::Button("Check for Desync (but don't fix)")) {
        Editor::CheckForDesyncObjects(false);
        Notify("Updated desync status");
    }
    if (UI::Button("Check for Desync (and fix)")) {
        Editor::CheckForDesyncObjects(false);
        // need to cache and restore yolo mode if it's active because that ignores player actions
        _mWasYoloModeEnabled = S_YoloMode;
        S_YoloMode = false;
        dev_trace("disabled yolo mode, was: " + _mWasYoloModeEnabled);
        // add desync actions to pending actions so they're processed in the normal loop
        if (Editor::desyncLastExtra !is null) {
            g_MTConn.pendingUpdates.InsertLast(MTDeleteUpdate(Editor::desyncLastExtra));
        }
        if (Editor::desyncLastMissing !is null) {
            g_MTConn.pendingUpdates.InsertLast(MTPlaceUpdate(Editor::desyncLastMissing.PopulateMacroblock(Editor::MakeMacroblockSpec())));
        }
        Notify("Updated desync status and inserted updates");
        startnew(CheckDesyncAgainSoon);
    }
}

bool _mWasYoloModeEnabled = false;

void CheckDesyncAgainSoon() {
    // let updates be processed
    yield();
    // let free blocks be deleted
    yield();
    // one more for luck
    yield();
    Editor::CheckForDesyncObjects(false);
    S_YoloMode = _mWasYoloModeEnabled;
    dev_trace("restored yolo mode to: " + _mWasYoloModeEnabled);
}

void Desync_DrawMacroblockSummary(const string &in title, Editor::MacroblockSpec@ mb) {
    if (UI::TreeNode(title + " (" + mb.Length + ")##"+title)) {
        for (uint i = 0; i < mb.blocks.Length; i++) {
            Desync_DrawBlockDetails(mb.blocks[i]);
            // UI::Text("Block " + i + ". " + mb.blocks[i].name + " at " + mb.blocks[i].pos.ToString());
        }
        for (uint i = 0; i < mb.items.Length; i++) {
            Desync_DrawItemDetails(mb.items[i]);
            // UI::Text("Item " + i + ". " + mb.items[i].name + " at " + mb.items[i].pos.ToString());
        }
        UI::TreePop();
    }
}

void Desync_DrawBlockDetails(const Editor::BlockSpec@ block) {
    if (UI::TreeNode("Block " + block.name + " at " + block.pos.ToString())) {
        UI::Text("Name: " + block.name);
        UI::Text("Collection: " + block.collection);
        UI::Text("Author: " + block.author);
        UI::Text("Coord: " + block.coord.ToString());
        UI::Text("Dir: " + tostring(block.dir));
        UI::Text("Dir2: " + tostring(block.dir2));
        UI::Text("Pos: " + block.pos.ToString());
        UI::Text("Pyr: " + block.pyr.ToString());
        UI::Text("[c] Quat: " + quat(block.pyr).ToString());
        UI::Text("Color: " + tostring(block.color));
        UI::Text("LmQual: " + tostring(block.lmQual));
        UI::Text("MobilIx: " + block.mobilIx);
        UI::Text("MobilVariant: " + block.mobilVariant);
        UI::Text("Variant: " + block.variant);
        UI::Text("Flags: " + block.flags);
        UI::TreePop();
    }
}

void Desync_DrawItemDetails(const Editor::ItemSpec@ item) {
    if (UI::TreeNode("Item " + item.name + " at " + item.pos.ToString())) {
        UI::Text("Name: " + item.name);
        UI::Text("Collection: " + item.collection);
        UI::Text("Author: " + item.author);
        UI::Text("Coord: " + item.coord.ToString());
        UI::Text("Dir: " + tostring(item.dir));
        UI::Text("Pos: " + item.pos.ToString());
        UI::Text("Pyr: " + item.pyr.ToString());
        UI::Text("[c] Quat: " + quat(item.pyr).ToString());
        UI::Text("Scale: " + item.scale);
        UI::Text("Color: " + tostring(item.color));
        UI::Text("LmQual: " + tostring(item.lmQual));
        UI::Text("Phase: " + tostring(item.phase));
        UI::Text("PivotPos: " + item.pivotPos.ToString());
        UI::Text("IsFlying: " + item.isFlying);
        UI::Text("VariantIx: " + item.variantIx);
        UI::TreePop();
    }
}

void Desync_DrawOctTreeSummary(const string &in title, OctTreeNode@ ot) {
    if (UI::TreeNode(title + " (" + ot.Length + ")##"+title)) {
        for (uint i = 0; i < ot.Length; i++) {
            auto item = ot[i].item;
            auto block = ot[i].block;
            if (item !is null) {
                Desync_DrawItemDetails(item);
                // UI::Text("Item " + i + ". " + item.name + " at " + item.pos.ToString());
            } else if (block !is null) {
                Desync_DrawBlockDetails(block);
                // UI::Text("Block " + i + ". " + block.name + " at " + block.pos.ToString());
            } else {
                UI::Text("Unknown item/block: " + ot[i].ToString());
            }
        }
        UI::TreePop();
    }
}

#endif

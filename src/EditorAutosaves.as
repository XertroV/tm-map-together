const uint16 O_EDITOR_AUTOSAVE_STRUCT = GetOffset("CGameCtnEditorFree", "CamMode") + 0x8;

uint64 GetAutosaveStructPtr(CGameCtnApp@ app) {
    return GetAutosaveStructPtr(cast<CGameCtnEditorFree>(app.Editor));
}
uint64 GetAutosaveStructPtr(CGameCtnEditorFree@ editor) {
    if (editor is null) return 0;
    return Dev::GetOffsetUint64(editor, O_EDITOR_AUTOSAVE_STRUCT);
}

// Get the pointer from GetAutosaveStructPtr
int GetAutosaveStackPos(uint64 ptr) {
    if (ptr == 0) return -1;
    return Dev::ReadInt32(ptr + 0xC4);
}

// This is zero until the autosave buffer caps out at 64
int GetAutosaveStackMinPos(uint64 ptr) {
    if (ptr == 0) return -1;
    return Dev::ReadInt32(ptr + 0xC0);
}

// Get the pointer from GetAutosaveStructPtr
int GetAutosaveStackSize(uint64 ptr) {
    if (ptr == 0) return -1;
    return Dev::ReadInt32(ptr + 0xB8);
}

// Get the pointer from GetAutosaveStructPtr
int GetAutosaveStackCapacity(uint64 ptr) {
    if (ptr == 0) return -1;
    return Dev::ReadInt32(ptr + 0xBC);
}

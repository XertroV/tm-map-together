dictionary yieldReasons;
void yield_why(const string &in why) {
    if (!yieldReasons.Exists(why)) {
        yieldReasons[why] = 1;
    } else {
        yieldReasons[why] = 1 + int(yieldReasons[why]);
    }
    yield();
}

void DrawYeildReasonUI() {
    UI::AlignTextToFramePadding();
    if (yieldReasons.IsEmpty()) {
        UI::Text("No yield reasons");
        return;
    }
    UI::Text("Yield Reasons");
    auto keys = yieldReasons.GetKeys();
    for (uint i = 0; i < keys.Length; i++) {
        string key = keys[i];
        int value = int(yieldReasons[key]);
        UI::Text(key + ": " + value);
    }
}

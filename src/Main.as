#if !DEPENDENCY_EDITOR



void Render() {
    UI::SetNextWindowSize(400, 200, UI::Cond::Always);
    if (UI::Begin("Map Together")) {
        UI::TextWrapped("\\$f80Map Together requires that you install Editor++");
    }
    UI::End();
}



#else



MapTogetherConnection@ g_MTConn = null;

void Main() {
    CheckTokenUpdate();
    Notify("Got token");
    @g_MTConn = MapTogetherConnection("", 0);
}

bool g_WindowOpen = true;

void Render() {
    if (!g_WindowOpen) return;
    if (UI::Begin("Map Together", g_WindowOpen)) {
        DrawMainUI_Inner();
    }
    UI::End();
}

void DrawMainUI_Inner() {
    if (UI::Button("Re-Connect")) {
        @g_MTConn = MapTogetherConnection("", 0);
    }
    if (g_MTConn is null) {
        UI::Text("MTConn null.");
        return;
    }
    if (g_MTConn.hasErrored) {
        UI::Text("Error: " + g_MTConn.error);
        return;
    }
    if (g_MTConn.IsConnecting) {
        UI::Text("Connecting...");
        return;
    }
    if (g_MTConn.IsShutdown) {
        UI::Text("Disconnected.");
        return;
    }
    UI::Text("Connected.");

    UI::Separator();

    UI::Text("Room ID: " + g_MTConn.roomId);
    UI::Text("Action Rate Limit (ms): " + g_MTConn.actionRateLimit);


    UI::Separator();

    if (UI::Button("Disconnect")) {
        g_MTConn.Close();
    }
}



#endif

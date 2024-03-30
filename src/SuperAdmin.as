string m_SuperAdminMsg;

void DrawSuperAdminUI() {
    bool changed;
    m_SuperAdminMsg = UI::InputTextMultiline("Send Global Message", m_SuperAdminMsg, changed);
    if (UI::Button("Send")) {
        if (m_SuperAdminMsg.Length > 0) {
            // g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[SuperAdmin] " + m_SuperAdminMsg + "\n");

            Notify("Sent global chat message.");
            m_SuperAdminMsg = "";
        }
    }

    UI::Separator();

    if (UI::Button("Test Placing Custom Notif")) {
        auto p = g_MTConn.playersInRoom[0];
        g_MTConn.statusMsgs.AddGameEvent(UserPlacedMissingBlockItemEvent(p, "TEST.Item.Gbx"));
    }
}

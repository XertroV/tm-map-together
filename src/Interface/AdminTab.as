void DrawAdminTab() {
    if (g_MTConn is null) {
        UI::Text("\\$f40Not connected to server.");
        return;
    }
    UI::BeginTabBar("admintabs");

    if (UI::BeginTabItem("Actions")) {
        DrawAdminTabActions();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Skins")) {
        DrawAdminTabSkins();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Players")) {
        DrawAdminTabPlayers();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Settings")) {
        DrawAdminTabSettings();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem("Guide")) {
        DrawAdminTabGuide();
        UI::EndTabItem();
    }

    UI::EndTabBar();
}

void DrawAdminTabActions() {
    UI::AlignTextToFramePadding();
    UI::Text("Place/Delete Actions");
    if (UI::BeginChild("admin-actions", vec2(), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
        auto @log = g_MTConn.updateLog;
        UI::ListClipper clip(log.Length);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                UI::PushID('adm-actn' + i);
                log[i].DrawAdminRow(i);
                UI::PopID();
            }
        }
    }
    UI::EndChild();
}


void DrawAdminTabSkins() {
    UI::AlignTextToFramePadding();
    UI::Text("Skins");
    if (UI::BeginChild("admin-skins", vec2(), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
        auto @log = g_MTConn.setSkinLog;
        UI::ListClipper clip(log.Length);

        if (UI::BeginTable("adm-skin-table", 6, UI::TableFlags::SizingStretchSame)) {
            UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50);
            UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("FG Skin", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("BG Skin", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("View", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableHeadersRow();

            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID('adm-skn' + i);
                    log[i].DrawAdminTableRow(i);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }
    UI::EndChild();
}


void DrawAdminTabPlayers() {
    UI::AlignTextToFramePadding();
    UI::Text("Player List");
    UI::Text("\\$f80Todo");
}

uint m_newRoomActionLimit = 100;
uint setActionLimitTimeLast = 0;

void DrawAdminTabSettings() {
    UI::AlignTextToFramePadding();
    UI::Text("Settings");
    UI::Separator();
    UI::Text("Current room action limit: " + g_MTConn.ActionLimitHz + " Hz (Blocks or Items per second) | Raw: " + g_MTConn.actionRateLimit);
    float currActionLimitHz = ActionLimitToHz(m_newRoomActionLimit);
    float currActionLimitHzLog = Math::Log10(currActionLimitHz);
    float infLimit = 4.0;
    string label = currActionLimitHzLog > infLimit ? "Infinite" : Text::Format("%.2f Hz", currActionLimitHz);
    UI::Text("currActionLimitHz: " + currActionLimitHz);
    UI::Text("currActionLimitHzLog: " + currActionLimitHzLog);
    float newActionLimitLogHz = UI::SliderFloat("Room Action Limit", currActionLimitHzLog, -2.0, 4.2, label, UI::SliderFlags::None);
    float newActionLimitHz = Math::Pow(10, newActionLimitLogHz);
    uint newLimitNumber = uint(Math::Round(HzToActionLimit(newActionLimitHz)));
    UI::Text("newActionLimitLogHz: " + newActionLimitLogHz);
    UI::Text("newActionLimitHz: " + newActionLimitHz);
    UI::Text("newLimitNumber: " + newLimitNumber);
    if (m_newRoomActionLimit != newLimitNumber) {
        m_newRoomActionLimit = newLimitNumber;
    }
    UI::BeginDisabled(setActionLimitTimeLast + 1000 > Time::Now);
    if (UI::Button("Set Room Action Limit")) {
        g_MTConn.WriteSetActionLimit(m_newRoomActionLimit);
        setActionLimitTimeLast = Time::Now;
    }
    UI::EndDisabled();
}


float HzToActionLimit(float hz) {
    if (hz == 0.0) return 0.0;
    return 1000.0 / hz;
}

// limit is ms between each block/item

float ActionLimitToHz(float limit) {
    if (limit == 0.0) return 99999.0;
    return 1000.0 / limit;
}


void DrawAdminTabGuide() {
    UI::Markdown("# Admin Guide\n\n"
    "## Actions\n\n"
    "View the log of Place/Delete *Actions* and undo them.\n\n"
    "## Players\n\n"
    "View the list of players and stats.\n"
    "Kick, ban, or promote players.\n"
    "You can also undo all of a player's actions.\n\n"
    "## Guide\n\n"
    "This guide.\n\n"
    );
}

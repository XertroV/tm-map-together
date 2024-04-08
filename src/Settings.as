[Setting category="UI" name="Use a colorful plugin name." description="Affects menu and window title"]
bool S_NiceName = true;

[Setting category="normally hidden" name="render player tags"]
bool S_RenderPlayersNvg = true;

[Setting category="normally hidden" name="show status hud (pending actions)"]
bool S_RenderStatusHUD = true;

[Setting category="normally hidden" name="enable trivial placement optimizations" description="skip some undo-place or undo-delete operations when nothing has happened in the mean time."]
bool S_EnablePlacementOptmization_Skip1TrivialMine = true;

[Setting category="normally hidden" name="enable loading NoStadium bases" description="turning this off tries to load nostadium bases normally."]
bool S_EnableNoStadiumHack = true;

[Setting category="UI" name="Player Label Size" min=6 max=80 drag]
float S_PlayerLabelHeight = 16.0;

[Setting category="UI" name="Draw Own Labels?" description="it's for debug testing"]
bool S_DrawOwnLabels = false;

[Setting category="UI" name="Show Status Events on Screen" description="Show player joins/leaves, etc on screen"]
bool S_StatusEventsOnScreen = true;

[Setting category="UI" name="Player tags as camera target only" description="Other players' cursors will just show their camera target pos, not their cursor position."]
bool S_PlayerTagsAsCameraTargetOnly = false;

[Setting hidden]
uint S_MaximumPlacementTime = 1500;

[Setting hidden]
uint S_UpdateMS_Clamped = 200;

[Setting hidden]
bool S_PassthroughAllLogs = true;

[Setting hidden]
bool S_ShowChatAsStatusMsg = true;

[Setting hidden]
uint S_ChatMsgLenLimit = 45;


[SettingsTab name="Other"]
void RenderST_Other() {
    S_UpdateMS_Clamped = Math::Clamp(UI::InputInt("Cursor/V Update Frequence (ms)", S_UpdateMS_Clamped), 50, 100000);
}



[Setting hidden]
bool S_EnableSettingSkins = false;

[Setting hidden]
bool S_PrintItemPlacingDebug = false;

[Setting hidden]
uint S_DesyncCheckPlacePeriod = 5;

[Setting hidden]
bool S_DoDesyncCheckAutomatically = false;



[SettingsTab name="In-Game"]
void DrawSettingsGameUiTab() {
    // UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Overlay");

    S_PlayerLabelHeight = UI::SliderFloat("Player Label Height", S_PlayerLabelHeight, 6.0, 80.0, "%.1f", UI::SliderFlags::None);
    AddSimpleTooltip("Controls the scale of text for player labels, status events, pending actions, etc");

    S_RenderPlayersNvg = UI::Checkbox("Render Player Tags", S_RenderPlayersNvg);
    S_RenderStatusHUD = UI::Checkbox("Show Status HUD (Pending Actions)", S_RenderStatusHUD);

    S_PlayerTagsAsCameraTargetOnly = UI::Checkbox("Player Tags as Camera Target Only", S_PlayerTagsAsCameraTargetOnly);
    AddSimpleTooltip("Instead of showing the player's cursor, show their camera target");

    S_DrawOwnLabels = UI::Checkbox("Draw Own Labels", S_DrawOwnLabels);
    AddSimpleTooltip("Useful for testing.");

    S_StatusEventsOnScreen = UI::Checkbox("Show Status Events on Screen", S_StatusEventsOnScreen);
    AddSimpleTooltip("Show player joins/leaves, etc on screen");

    S_ShowChatAsStatusMsg = UI::Checkbox("Show Chat Messages as Status Messages", S_ShowChatAsStatusMsg);
    AddSimpleTooltip("Show chat messages where the player join/leave stuff shows up.");

    S_ChatMsgLenLimit = Math::Clamp(UI::InputInt("Chat Message Length Limit (Status Msgs)", S_ChatMsgLenLimit), 10, 500);
    AddSimpleTooltip("The maximum length of a chat message to show as a status message.");

    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Optional Features");

    S_EnableSettingSkins = UI::Checkbox("Enable Setting Skins   \\$f84" + Icons::ExclamationTriangle, S_EnableSettingSkins);
    AddSimpleTooltip("This will send skin updates and apply recieved updates. Disable if there's like an infinite loop or something going on.");


    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Placement");

    S_EnablePlacementOptmization_Skip1TrivialMine = UI::Checkbox("Enable Trivial Placement Optimizations", S_EnablePlacementOptmization_Skip1TrivialMine);
    AddSimpleTooltip("This will skip placementes and deletions when there is only one thing to process and it was what you last did.");

    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Performance / Debug");

    RenderST_Other();
    S_MaximumPlacementTime = uint(UI::SliderFloat("Max Placement Time (ms)", float(S_MaximumPlacementTime), 1.0, 3000.0, "%.0f", UI::SliderFlags::None));
    if (S_MaximumPlacementTime > 10000) {
        S_MaximumPlacementTime = 10000;
    }
    S_PassthroughAllLogs = UI::Checkbox("Pass Through All Logs", S_PassthroughAllLogs);
    AddSimpleTooltip("This will print all log messages to the openplanet log (this is much more useful when you might need the log later). Only applies to TRACE and DEBUG messages since the others are passed through automatically.");

    S_DoDesyncCheckAutomatically = UI::Checkbox("Do Desync Check Automatically", S_DoDesyncCheckAutomatically);
    UI::BeginDisabled(!S_DoDesyncCheckAutomatically);
    S_DesyncCheckPlacePeriod = Math::Clamp(UI::SliderInt("Desync Check Place Period", S_DesyncCheckPlacePeriod, 1, 100), 1, 100);
    AddSimpleTooltip("The number of non-trivial placement operations to wait between checking for desyncs. Lower means more checks. If 2 incompatible blocks are placed in normal mode, there will be a cycle where one replaces the other whenever this check happens. To fix, you'll need to manually delete one of the conflicting blocks.");
    UI::EndDisabled();

#if DEV
    S_PrintItemPlacingDebug = UI::Checkbox("Log Item Placing Debug", S_PrintItemPlacingDebug);
#endif

    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Loading Editor");

    S_EnableNoStadiumHack = UI::Checkbox("Enable Loading NoStadium Bases", S_EnableNoStadiumHack);
    AddSimpleTooltip("This uses a hack to load nostadium bases, and it may (rarely) crash your game when entering the editor. If you have problems entering the editor (and disabling this option fixes it), please report it to XertroV.");

    // UI::Separator();
    // UI::AlignTextToFramePadding();
    // UI::Text("\\$ddd >> Loading Editor");

}

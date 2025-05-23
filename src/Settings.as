[Setting category="UI" name="Use a colorful plugin name." description="Affects menu and window title"]
bool S_NiceName = true;

[Setting category="In-Room" name="render player tags"]
bool S_RenderPlayersNvg = true;

[Setting category="In-Room" name="show status hud (pending actions)"]
bool S_RenderStatusHUD = true;

[Setting category="In-Room" name="enable trivial placement optimizations" description="skip some undo-place or undo-delete operations when nothing has happened in the mean time."]
bool S_EnablePlacementOptmization_Skip1TrivialMine = true;

[Setting category="In-Room" name="enable loading NoStadium bases" description="turning this off tries to load nostadium bases normally."]
bool S_EnableNoStadiumHack = true;

[Setting category="In-Room" name="(Fixes resetting edit mode) Don't process updates when EditMode = Pick/Erase/FreeView"]
bool S_DontUpdateWhileBadEditMode = true;

[Setting category="UI" name="Player Label Size" min=6 max=80 drag]
float S_PlayerLabelHeight = 16.0;

[Setting category="UI" name="Draw Own Labels?" description="it's for debug testing"]
bool S_DrawOwnLabels = false;

[Setting category="UI" name="Show Status Events on Screen" description="Show player joins/leaves, etc on screen"]
bool S_StatusEventsOnScreen = true;

[Setting category="UI" name="Player tags as camera target only" description="Other players' cursors will just show their camera target pos, not their cursor position."]
bool S_PlayerTagsAsCameraTargetOnly = false;

[Setting category="Performance" name="Macorblock Chunk Size" description="The number of blocks to place or delete at once -- larger Macroblocks will be chunked. Lower values may be more stable, but higher values may be faster. 0 = no chunking. Exception: blocks on the same X,Z coordinate will not be chunked to prevent issues with placing pillars." min=0 max=1000 drag]
uint S_MacroblockChunkSize = 100;

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

[Setting hidden]
bool S_YoloMode = false;


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

    S_DontUpdateWhileBadEditMode = UI::Checkbox("Don't Process Updates When in Pick/Erase/FreeView", S_DontUpdateWhileBadEditMode);
    AddSimpleTooltip("This avoids a bug where other players placing blocks can reset you while you're in pick/erase/freeview modes.");

    S_EnablePlacementOptmization_Skip1TrivialMine = UI::Checkbox("Enable Trivial Placement Optimizations", S_EnablePlacementOptmization_Skip1TrivialMine);
    AddSimpleTooltip("This will skip placementes and deletions when there is only one thing to process and it was what you last did.");

    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("\\$ddd >> Performance / Debug");

    S_YoloMode = UI::Checkbox("YOLO Mode (up to 3x Performance)   \\$f84" + Icons::ExclamationTriangle, S_YoloMode);
    AddSimpleTooltip("YOLO mode disables the main consistency mechanism used by Map Together. Normally, Map Together will track the last action it executed (which was recieved from the server). When you make actions locally, they are sent to the server. When actions are recieved, Map Together calls Undo() on all your actions until the map is at the last known good state. Then actions are applied in the order recieved from the server. This adds performance overhead because of the redundant placing and deleting of blocks, but it keeps things consistent. By enabling YOLO mode, you will most likely run into more inconsistencies, but there will be significantly less overhead applying updates recieved from the server. In the case of desync situations, see the desync tab.\n\nWhen YOLO mode is active, Undo() is not called before applying updates, and your own actions recieved from the server are ignored.");

    S_MacroblockChunkSize = Math::Max(UI::SliderInt("Macroblock Chunk Size", S_MacroblockChunkSize, 0, 1000), 0);
    AddSimpleTooltip("The number of blocks to place or delete at once -- larger Macroblocks will be chunked. Lower values may be more stable, but higher values may be faster. 0 = no chunking. Exception: blocks on the same X,Z coordinate will not be chunked to prevent issues with placing pillars.");
    if (S_MacroblockChunkSize == 0) {
        UI::SameLine();
        UI::Text(" \\$iNo limit");
    }

    RenderST_Other();
    S_MaximumPlacementTime = uint(UI::SliderFloat("Max Placement Time (ms)", float(S_MaximumPlacementTime), 1.0, 3000.0, "%.0f", UI::SliderFlags::None));
    if (S_MaximumPlacementTime > 10000) {
        S_MaximumPlacementTime = 10000;
    }
    S_PassthroughAllLogs = UI::Checkbox("Pass Through All Logs", S_PassthroughAllLogs);
    AddSimpleTooltip("This will print all log messages to the openplanet log (this is much more useful when you might need the log later). Only applies to TRACE and DEBUG messages since the others are passed through automatically.");

    S_DoDesyncCheckAutomatically = UI::Checkbox("Do Desync Check Automatically", S_DoDesyncCheckAutomatically);
    AddSimpleTooltip("When this is true, every X actions the map will be checked for desync *and the desync fix will automatically be applied*. This can cause performance issues if pillars or structure supports are present and cannot be synchronized. (These are the main two problematic types of blocks at the moment.)");
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

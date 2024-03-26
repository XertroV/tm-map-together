[Setting category="UI" name="Use a colorful plugin name." description="Affects menu and window title"]
bool S_NiceName = true;

[Setting category="normally hidden" name="render player tags"]
bool S_RenderPlayersNvg = true;

[Setting category="normally hidden" name="show status hud (pending actions)"]
bool S_RenderStatusHUD = true;

[Setting category="normally hidden" name="enable trivial placement optimizations" description="skip some undo-place or undo-delete operations when nothing has happened in the mean time."]
bool S_EnablePlacementOptmization_Skip1TrivialMine = true;

[Setting category="UI" name="Player Label Size" min=6 max=80 drag]
float S_PlayerLabelHeight = 20.0;

[Setting category="UI" name="Draw Own Labels?" description="it's for debug testing"]
bool S_DrawOwnLabels = false;

[Setting category="UI" name="Show Status Events on Screen" description="Show player joins/leaves, etc on screen"]
bool S_StatusEventsOnScreen = true;

[Setting category="UI" name="Player tags as camera target only" description="Other players' cursors will just show their camera target pos, not their cursor position."]
bool S_PlayerTagsAsCameraTargetOnly = false;

[Setting hidden]
uint S_UpdateMS_Clamped = 100;

[SettingsTab name="Other"]
void RenderST_Other() {
    S_UpdateMS_Clamped = Math::Clamp(UI::InputInt("Cursor/V Update Frequence (ms)", S_UpdateMS_Clamped), 100, 100000);
}

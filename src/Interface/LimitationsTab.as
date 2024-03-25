void DrawLimitationsTab() {
    auto pos = UI::GetCursorPos();
    UI::Dummy(vec2(300, 0));
    UI::SetCursorPos(pos);

    UI::Markdown("# Limitations\n\n"
        "Map Together modifies the game in a few ways to make a multiplayer mapping practical.\n\n"
        "* Undo is modified to work on your own actions only, and only when they are able to be undone (which requires specific implementation).\n"
        "* Redo is completely disabled.\n"
        "* Mass deleting blocks/items via backspace is disabled (except admins).\n"
        "* Some E++ features work in a buggy way. This will be fixed in future updates where appropriate (e.g., nudging).\n"
        "* Waypoint changes (e.g., linking CPs) are not (yet) synced between mappers.\n"
        "* Skins are not (yet) synced between mappers.\n"
        "* Mediatracker is not synced and should be avoided.\n"
        "* Item Editor is not synced and should be avoided.\n"
        "* Custom Items are not (yet) supported and will not show up for other mappers (unless they have an item in the same location).\n"
        "* Custom Blocks are not supported and will not show up for other mappers.\n"
        "* Colors set by the selection tool are not propagated (delete and replace with the correct color instead).\n"
        "* More that I have forgotten.\n\n"
        "If you encounter any issues, please report them on the [Openplanet Discord Server](https://discord.com/channels/276076890714800129/1221391033649070111). (Suggestions welcome too.)\n\n"
        "GL HF\n\n"
    );
    UI::Dummy(vec2(0, 0));
    UI::Text("\t— \\$s\\$170\\$17bX\\$379e\\$567r\\$866t\\$a64r\\$c50o\\$e50V");
}

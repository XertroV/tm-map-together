bool g_OpenCentralChatWindow = false;

void DrawChatTab() {
    if (g_MTConn is null) {
        UI::Text("No server connection");
        return;
    }

    g_MTConn.serverChat.DrawChatUI();
}


namespace Chat {
    void RenderMainWindow() {
        if (!g_OpenCentralChatWindow) return;
        auto size = g_screen / 3.;
        auto pos = g_screen / 2. - size / 2.;
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
        if (UI::Begin("chat-window", g_OpenCentralChatWindow, UI::WindowFlags::NoCollapse)) {
            DrawChatTab();
        }
        UI::End();
        if (UI::IsWindowAppearing() && g_MTConn !is null) {
            g_MTConn.serverChat.scrollToBottom = true;
        }
    }
}


enum ChatMsgTy {
    Server = 0,
    Room = 1,
    Team = 2,
    Whisper = 3,
}

class ChatMessage {
    PlayerInRoom@ player;
    string message;
    string ui_msg;
    uint64 timestamp;
    ChatMsgTy msgTy;

    ChatMessage(PlayerInRoom@ player, uint8 type, const string &in msg, uint64 timestamp = 0) {
        if (type > 4) throw("Invalid chat msg type");
        msgTy = ChatMsgTy(type);
        if (timestamp == 0) {
            timestamp = GetAccurateTimestampMs();
        }
        this.timestamp = timestamp;
        @this.player = player;
        message = msg;
        ui_msg = "\\$ddd" + FormatTimestampMsShort(timestamp) + "\\$z [ " + player.nameAndTitle + " ]: " + msg;
    }

    void DrawChatRow() {
        UI::TextWrapped(ui_msg);
    }
}

bool g_RefocusChat = false;

class ServerChat {
    ChatMessage@[] messages;
    ServerChat() {}

    void AddMessage(ChatMessage@ msg) {
        messages.InsertLast(msg);
        if (g_MTConn !is null) {
            g_MTConn.statusMsgs.AddGameEvent(ChatMsgEvent(msg));
        }
    }

    string m_chatMsg = "";
    bool scrollToBottom = false;

    void DrawChatUI() {
        if (g_MTConn is null) return;
        auto avail = UI::GetContentRegionAvail();
        auto footerHeight = UI::GetFrameHeightWithSpacing() + UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x + UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x;
        if (UI::BeginChild("serverchat", vec2(0, avail.y - footerHeight), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
            UI::ListClipper clip(messages.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    messages[i].DrawChatRow();
                }
            }
            if (scrollToBottom) {
                scrollToBottom = false;
                // todo: figure out why we need +100 and where this call should be to avoid it.
                UI::SetScrollY(UI::GetScrollMaxY() + 100);
            }
        }
        UI::EndChild();
        DrawChatInput();
    }

    void DrawChatInput() {
        if (g_RefocusChat) {
            scrollToBottom = true;
            g_RefocusChat = false;
            UI::SetKeyboardFocusHere(0);
        }
        bool changed;
        UI::SetNextItemWidth(200);
        m_chatMsg = UI::InputText("##m-chat-msg", m_chatMsg, changed, UI::InputTextFlags::EnterReturnsTrue);
        bool chatFieldFocused = UI::IsItemFocused();
        if (changed && Editor::IsShiftDown()) {
            UI::SetKeyboardFocusHere(-1);
        } else if (changed) {
            g_OpenCentralChatWindow = false;
        }

        if (!chatFieldFocused && g_OpenCentralChatWindow && !UI::IsWindowAppearing()) {
            g_OpenCentralChatWindow = false;
        }


        UI::SameLine();
        if (UI::Button("Send##chat-msg")) {
            changed = true;
        }
        UI::SameLine();
        UI::Text("\\$cccShift+Enter to refocus input");
        // UI::SameLine();
        if (changed) {
            if (g_MTConn is null) {
                NotifyError("MapTogether connection null");
            } else if (m_chatMsg.Length > 0) {
                scrollToBottom = true;
                g_MTConn.SendChatMessage(ChatMsgTy::Room, m_chatMsg);
                m_chatMsg = "";
            }
        }
    }
}

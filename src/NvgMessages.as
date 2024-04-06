
float BaseFontHeight {
    get {
        return S_PlayerLabelHeight * refScale * 2.0;
    }
}

float EventLogSpacing {
    get {
        return BaseFontHeight / 4.;
    }
}

// purpose: keep an array of these. they are used to draw UI status elements.
// call .RenderUpdate(float dt, vec2 pos) and when it returns true, it's done
class MTGameEvent {
    vec4 col = vec4(1, 1, 1, 1);
    string msg = "undefined";
    float animDuration = 5.0;
    float fadeDuration = 1.0;
    float currTime = 0.0;
    float t = 0.0;
    float baseFontSize = BaseFontHeight;
    vec4 bgCol = vec4(0, 0, 0, 0.7);

    MTGameEvent() {
        startnew(CoroutineFunc(this.LogMsg));
    }

    void LogMsg() {
        log_debug("Status Msg: " + msg);
    }

    bool RenderUpdate(float dt, vec2 pos) {
        currTime += dt / 1000.;
        t = currTime / animDuration;
        if (t > 1.) return true;
        float alpha = Math::Clamp(animDuration * (1.0 - t) / fadeDuration, 0., 1.0);
        float fs = baseFontSize * 1.0; //Math::Clamp((t + .2), 1, 1.0);
        nvg::BeginPath();
        nvg::FontSize(fs);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);

        nvg::FillColor(bgCol * vec4(1, 1, 1, alpha));
        auto textBounds = nvg::TextBounds(msg);
        auto pad = vec2(3.);
        nvg::Rect(pos - pad, textBounds + pad * 2.);
        nvg::Fill();
        nvg::FillColor(col * vec4(1, 1, 1, alpha));
        nvg::Text(pos, msg);
        nvg::ClosePath();
        return false;
    }
}


class MTEventPlayer : MTGameEvent {
    MTEventPlayer(PlayerInRoom@ player, const string &in desc) {
        msg = player.nameAndTitle + " " + desc;
    }

    void XertroVJoinCheck(PlayerInRoom@ player) {
        if (player.name == "XertroV") {
            msg = "Boss Admin XertroV entered the room.";
            col = vec4(1, 0.1, 0.1, 1.);
            bgCol = vec4(0, 0.2, 0.2, 0.9);
        }
    }
}
class MTEventPlayerAdminJoined : MTEventPlayer {
    MTEventPlayerAdminJoined(PlayerInRoom@ player) {
        super(player, "is Admin");
        col = vec4(1, 1., .2, 1.);
        XertroVJoinCheck(player);
    }
}
class MTEventPlayerJoined : MTEventPlayer {
    MTEventPlayerJoined(PlayerInRoom@ player) {
        super(player, "Joined");
        col = vec4(.2, 1., .2, 1.);
        XertroVJoinCheck(player);
    }
}
class MTEventPlayerLeft : MTEventPlayer {
    MTEventPlayerLeft(PlayerInRoom@ player) {
        super(player, "Left");
        col = vec4(1., .4, 0, 1.);
    }
}
class MTEventAdminSetActionLimit : MTGameEvent {
    MTEventAdminSetActionLimit(PlayerInRoom@ player, uint limit) {
        msg = player.nameAndTitle + " set action limit to " + ActionLimitToHz(limit) + " Hz";
        col = vec4(1, 1., .2, 1.);
    }
}

class ChatMsgEvent : MTGameEvent {
    ChatMsgEvent(ChatMessage@ cmsg) {
        // PlayerInRoom@ player, const string &in msg, int64 ts
        col = vec4(.9, .9, .9, 1);
        if (cmsg.msgTy == ChatMsgTy::Server) {
            col = cCyan;
        } else if (cmsg.msgTy == ChatMsgTy::Team) {
            col = cGreen;
        }
        this.msg = FormatTimestampMsShort(cmsg.timestamp) + " [ " + cmsg.player.nameAndTitle + " ]: " + (
            uint(cmsg.message.Length) > S_ChatMsgLenLimit ? cmsg.message.SubStr(0, S_ChatMsgLenLimit) + "…" : cmsg.message
        );
    }
}

class UserPlacedMissingBlockItemEvent : MTGameEvent {
    UserPlacedMissingBlockItemEvent(PlayerInRoom@ player, const string &in item) {
        msg = (player is null ? "<??? null ???>" : player.nameAndTitle) + " placed " + item;
        col = vec4(1, .9, .9, 1.);
        bgCol = vec4(.2, 0, 0, 0.9);
        animDuration = 10.0;
    }
}




class StatusMsgs {
    MTGameEvent@[] eventLog;
    MTGameEvent@[] activeEvents;

    void AddGameEvent(MTGameEvent@ event) {
        eventLog.InsertLast(event);
        activeEvents.InsertLast(event);
    }
}



class StatusMsgUI {
    StatusMsgs state;

    void AddGameEvent(MTGameEvent@ event) {
        if (!S_StatusEventsOnScreen) return;
        state.AddGameEvent(event);
    }

    void RenderUpdate(float dt) {
        nvg::Reset();
        nvg::FontFace(f_Nvg_Montserrat);
        nvg::StrokeWidth(0);
        nvg::StrokeColor(vec4());
        // for game events
        vec2 pos = GameEventsTopLeft;
        // draw maps along top
        // draw game events
        float yDelta = BaseFontHeight + EventLogSpacing + 2.0;
        auto nbToDraw = int(state.activeEvents.Length);
        auto ix = nbToDraw - 1;
        for (int i = 0; i < nbToDraw; i++) {
            ix = nbToDraw - i - 1;
            if (state.activeEvents[ix].RenderUpdate(dt, pos)) {
                state.activeEvents.RemoveAt(ix);
                nbToDraw--;
                if (state.activeEvents.Length == 0) return;
            } else {
                pos.y += yDelta;
            }
        }
        nvg::BeginPath();
    }
}

vec2 GameEventsTopLeft {
    get {
        float h = Draw::GetHeight();
        float w = Draw::GetWidth();
        float hOffset = 0;
        float idealWidth = 1.7777777777777777 * h;
        if (w < idealWidth) {
            float newH = w / 1.7777777777777777;
            hOffset = (h - newH) / 2.;
            h = newH;
        }
        if (UI::IsOverlayShown()) hOffset += 24;
        float wOffset = (float(Draw::GetWidth()) - (1.7777777777777777 * h)) / 2.;
        vec2 tl = vec2(wOffset, hOffset) + vec2(h * 0.15, w * 0.025);
        return tl;
    }
}

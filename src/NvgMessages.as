
float BaseFontHeight {
    get {
        return S_PlayerLabelHeight * refScale * 1.2;
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
    float currTime = 0.0;
    float t = 0.0;
    float baseFontSize = BaseFontHeight;
    vec4 bgCol = vec4(0, 0, 0, 0.7);

    bool RenderUpdate(float dt, vec2 pos) {
        currTime += dt / 1000.;
        t = currTime / animDuration;
        if (t > 1.) return true;
        float alpha = Math::Clamp(5. - t * 5., 0., 1.);
        float fs = baseFontSize * Math::Clamp((t + .2), 1, 1.0);
        nvg::BeginPath();
        nvg::FontSize(fs);
        nvg::TextAlign(nvg::Align::Left | nvg::Align::Top);

        nvg::FillColor(bgCol * vec4(1, 1, 1, alpha));
        auto textBounds = nvg::TextBounds(msg);
        auto pad = vec2(3.);
        nvg::Rect(pos - pad - vec2(0, 2), textBounds + pad * 2.);
        nvg::Fill();
        nvg::FillColor(col * vec4(1, 1, 1, alpha));
        nvg::Text(pos, msg);
        nvg::ClosePath();
        return false;
    }
}


class MTEventPlayer : MTGameEvent {
    MTEventPlayer(const string &in name, const string &in desc) {
        msg = name + " " + desc;
    }

    void XertroVJoinCheck(const string &in name) {
        if (name == "XertroV") {
            msg = "Boss Admin XertroV enters the room.";
            col = vec4(1, 0.1, 0.1, 1.);
            bgCol = vec4(0, 0.2, 0.2, 0.9);
        }
    }
}
class MTEventPlayerAdminJoined : MTEventPlayer {
    MTEventPlayerAdminJoined(const string &in name) {
        super(name, "is Admin");
        col = vec4(1, 1., .2, 1.);
        XertroVJoinCheck(name);
    }
}
class MTEventPlayerJoined : MTEventPlayer {
    MTEventPlayerJoined(const string &in name) {
        super(name, "Joined");
        col = vec4(.2, 1., .2, 1.);
        XertroVJoinCheck(name);
    }
}
class MTEventPlayerLeft : MTEventPlayer {
    MTEventPlayerLeft(const string &in name) {
        super(name, "Left");
        col = vec4(1., .4, 0, 1.);
    }
}
class MTEventAdminSetActionLimit : MTGameEvent {
    MTEventAdminSetActionLimit(const string &in name, uint limit) {
        msg = name + " set action limit to " + ActionLimitToHz(limit) + " Hz";
        col = vec4(1, 1., .2, 1.);
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
        // for game events
        vec2 pos = GameEventsTopLeft;
        // draw maps along top
        // draw game events
        float yDelta = BaseFontHeight + EventLogSpacing;
        for (int i = 0; i < int(state.activeEvents.Length); i++) {
            if (state.activeEvents[i].RenderUpdate(dt, pos)) {
                state.activeEvents.RemoveAt(i);
                i--;
                if (state.activeEvents.Length == 0) return;
            } else {
                pos.y += yDelta;
            }
        }
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

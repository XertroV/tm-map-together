const vec4 cMagenta = vec4(1, 0, 1, 1);
const vec4 cCyan =  vec4(0, 1, 1, 1);
const vec4 cGreen = vec4(0, 1, 0, 1);
const vec4 cBlue =  vec4(0, 0, 1, 1);
const vec4 cRed =   vec4(1, 0, 0, 1);
const vec4 cRed25 =  vec4(1, .3, .1, .25);
const vec4 cOrange = vec4(1, .4, .05, 1);
const vec4 cBlack =  vec4(0,0,0, 1);
const vec4 cBlack75 =  vec4(0,0,0, .75);
const vec4 cBlack25 =  vec4(0,0,0, .25);
const vec4 cGray =  vec4(.5, .5, .5, 1);
const vec4 cWhite = vec4(1);
const vec4 cWhite75 = vec4(1,1,1,.75);
const vec4 cWhite25 = vec4(1,1,1,.25);
const vec4 cWhite15 = vec4(1,1,1,.15);
const vec4 cNone = vec4(0, 0, 0, 0);
const vec4 cLightYellow = vec4(1, 1, 0.5, 1);
const vec4 cSkyBlue = vec4(0.33, 0.66, 0.98, 1);
const vec4 cLimeGreen = vec4(0.2, 0.8, 0.2, 1);
const vec4 cDarkPurpleRed = vec4(0.203f, 0.014f, 0.119f, 1.000f);
const vec4 cDarkBlue = vec4(0.008f, 0.164f, 0.251f, 1.000f);
const vec4 cMidDarkRed = vec4(0.458f, 0.048f, 0.048f, 1.000f);
const vec4 cDarkGreen = vec4(0.018f, 0.258f, 0.008f, 1.000f);
const vec4 cDarkYellow = vec4(0.258f, 0.258f, 0.008f, 1.000f);
const vec4 cDarkPink = vec4(0.258f, 0.008f, 0.258f, 1.000f);


// this does not seem to be expensive
const float nTextStrokeCopies = 16;

vec2 DrawTextWithStroke(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1), float strokeWidth = 2., vec4 strokeColor = cBlack75) {
    if (strokeWidth > 0.0) {
        nvg::FillColor(strokeColor);
        for (float i = 0; i < nTextStrokeCopies; i++) {
            float angle = TAU * float(i) / nTextStrokeCopies;
            vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
            nvg::Text(pos + offs, text);
        }
    }
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}

vec2 DrawTextWithShadow(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1), float strokeWidth = 2., vec4 strokeColor = vec4(0, 0, 0, 1)) {
    if (strokeWidth > 0.0) {
        nvg::FillColor(strokeColor);
        float i = 1;
        float angle = TAU * float(i) / nTextStrokeCopies;
        vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
        nvg::Text(pos + offs, text);
    }
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}


void nvg_Reset() {
    nvg::Reset();
    if (scissorStack is null) return;
    scissorStack.RemoveRange(0, scissorStack.Length);
}

vec4[]@ scissorStack = {};
void PushScissor(const vec4 &in rect) {
    if (scissorStack is null) return;
    nvg::ResetScissor();
    nvg::Scissor(rect.x, rect.y, rect.z, rect.w);
    scissorStack.InsertLast(rect);
}
void PushScissor(vec2 xy, vec2 wh) {
    PushScissor(vec4(xy, wh));
}
void PopScissor() {
    if (scissorStack is null) return;
    if (scissorStack.IsEmpty()) {
        log_warn("PopScissor called on empty stack!");
        nvg::ResetScissor();
    } else {
        scissorStack.RemoveAt(scissorStack.Length - 1);
        if (!scissorStack.IsEmpty()) {
            vec4 last = scissorStack[scissorStack.Length - 1];
            nvg::ResetScissor();
            nvg::Scissor(last.x, last.y, last.z, last.w);
        } else {
            nvg::ResetScissor();
        }
    }
}






void nvgDrawPointCircle(const vec2 &in pos, float radius, const vec4 &in color = cWhite, const vec4 &in fillColor = cNone) {
    nvg::Reset();
    nvg::BeginPath();
    nvg::StrokeColor(color);
    nvg::StrokeWidth(radius * 0.3);
    nvg::Circle(pos, radius);
    nvg::Stroke();
    if (fillColor.w > 0) {
        nvg::FillColor(fillColor);
        nvg::Fill();
    }
    nvg::ClosePath();
}


void nvgDrawPointCross(const vec2 &in pos, float radius, const vec4 &in color = cWhite, const vec4 &in fillColor = cNone) {
    nvg::Reset();
    nvg::BeginPath();
    nvg::StrokeColor(color);
    nvg::StrokeWidth(radius * 0.3);
    nvg::MoveTo(pos - radius);
    nvg::LineTo(pos + radius);
    nvg::MoveTo(pos + radius * vec2(1, -1));
    nvg::LineTo(pos + radius * vec2(-1, 1));
    nvg::Stroke();
    if (fillColor.w > 0) {
        nvg::FillColor(fillColor);
        nvg::Fill();
    }
    nvg::ClosePath();
}

void drawLabelBackgroundTagLines(const vec2 &in origPos, float fontSize, float triHeight, const vec2 &in textBounds) {
    vec2 pos = origPos;
    nvg::PathWinding(nvg::Winding::CW);
    nvg::MoveTo(pos);
    pos += vec2(fontSize, triHeight);
    nvg::LineTo(pos);
    pos += vec2(textBounds.x, 0);
    nvg::LineTo(pos);
    pos += vec2(0, -2.0 * triHeight);
    nvg::LineTo(pos);
    pos -= vec2(textBounds.x, 0);
    nvg::LineTo(pos);
    nvg::LineTo(origPos);
}

void drawLabelBackgroundTagLinesRev(const vec2 &in origPos, float fontSize, float triHeight, const vec2 &in textBounds) {
    vec2 pos = origPos;
    nvg::PathWinding(nvg::Winding::CW);
    nvg::MoveTo(pos);
    pos -= vec2(fontSize, triHeight);
    nvg::LineTo(pos);
    pos -= vec2(textBounds.x, 0);
    nvg::LineTo(pos);
    pos -= vec2(0, -2.0 * triHeight);
    nvg::LineTo(pos);
    pos += vec2(textBounds.x, 0);
    nvg::LineTo(pos);
    nvg::LineTo(origPos);
}

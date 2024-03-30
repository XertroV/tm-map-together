enum LogLevel {
    ERROR,
    WARN,
    INFO,
    DEBUG,
    TRACE
}

string[] LogLevelNames = {
    "EROR",
    "WARN",
    "INFO",
    "DBUG",
    "TRCE"
};

void WaitForTSTick() {
    auto ts = Time::Stamp;
    do {
        yield();
    } while (ts == Time::Stamp);
}

uint _msOffsetBoundary = 1000;
uint lastTime = Time::Now;
bool msOffsetBoundaryFound = false;
// Time::Now is not synchronized to the timestamp, so we need to find the offset between the two
void FindMsOffsetForTS() {
    auto startTs = Time::Stamp;
    auto ts = startTs, lastTs = startTs;
    auto now = Time::Now;
    uint maxTimeNow = 0;
    uint minTimeNow = _msOffsetBoundary;
    int currDelta = 0;
    bool found = false;
    int runCount = 0;
    uint priorMaxTimeNow = 0, priorMinTimeNow = _msOffsetBoundary;
    while (!found) {
        yield();
        runCount++;
        while (Time::Stamp == ts) {
            now = Time::Now;
            maxTimeNow = now % 1000;
            yield();
        }
        ts = Time::Stamp;
        if (ts - lastTs != 1) {
            WaitForTSTick();
            lastTs = ts;
            ts = Time::Stamp;
            continue;
        }
        lastTs = ts;
        maxTimeNow = Math::Max(maxTimeNow, priorMaxTimeNow);
        priorMaxTimeNow = maxTimeNow;
        now = Time::Now;
        minTimeNow = Math::Min(now % 1000, priorMinTimeNow);
        priorMinTimeNow = minTimeNow;
        _msOffsetBoundary = minTimeNow;
        currDelta = int(minTimeNow) - int(maxTimeNow);
        log_trace('['+runCount+'] currDelta: ' + currDelta + ' = ' + minTimeNow + ' - ' + maxTimeNow);
        if (currDelta == 1) {
            found = true;
        } else if (currDelta == 0) {
            log_trace('currDelta: ' + currDelta + ' = ' + minTimeNow + ' - ' + maxTimeNow);
            if (runCount > 1) {
                print("currDelta == 0, incrementing minTimeNow");
                minTimeNow++;
                break;
            }
            throw("currDelta == 0");
        } else if (currDelta < 0) {
            log_info('find ms timestamp offset failed due to long frame time, restarting');
            _msOffsetBoundary = 1000;
            startnew(FindMsOffsetForTS);
            return;
        }
    }
    log_debug('Found offset: ' + minTimeNow + ' after ' + runCount + ' runs');
    _msOffsetBoundary = minTimeNow;
}

int64 GetAccurateTimestampMs() {
    return Time::Stamp * 1000 + (Time::Now - _msOffsetBoundary) % 1000;
}

string FormatTimestampMsLong(int64 timestamp) {
    return Time::FormatString("%Y-%m-%d %H:%M:%S", timestamp / 1000) + "." + Text::Format("%03d", (timestamp % 1000));
}

string FormatTimestampMsShort(int64 timestamp) {
    return Time::FormatString("%H:%M:%S", timestamp / 1000);
}

class LogMessage {
    string msg;
    LogLevel level;
    uint64 timestamp;
    string logLine;

    LogMessage() {}

    LogMessage(const string &in msg, LogLevel level) {
        this.msg = msg;
        this.level = level;
        auto msOffset = (Time::Now - _msOffsetBoundary) % 1000;
        this.timestamp = Time::Stamp * 1000 + msOffset;
        logLine = Time::FormatString("%Y-%m-%d %H:%M:%S", timestamp / 1000) + "." + Text::Format("%03d", msOffset) + "["+LogLevelNames[int(level)]+"] - " + msg;
    }
}

LogMessage@[] logs = array<LogMessage@>();

uint GetNbLogMsgs() {
    return logs.Length;
}

void log_error(const string &in msg) {
    error(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::ERROR));
}

void log_warn(const string &in msg) {
    warn(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::WARN));
}

void log_info(const string &in msg, bool passthrough = true) {
    if (passthrough) print(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::INFO));
}

void log_debug(const string &in msg) {
    log_debug(msg, S_PassthroughAllLogs);
}

void log_debug(const string &in msg, bool passthrough) {
    if (passthrough) trace(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::DEBUG));
}

void log_trace(const string &in msg) {
    log_trace(msg, S_PassthroughAllLogs);
}

void log_trace(const string &in msg, bool passthrough) {
    if (passthrough) trace(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::TRACE));
}

int PausedLogsLen = -1;

void DrawLogsTab() {
    UI::PushFont(g_MonoFont);
    int nbLogs = logs.Length;
    if (PausedLogsLen > nbLogs) PausedLogsLen = -1;
    UI::AlignTextToFramePadding();
    UI::Text("Logs: " + nbLogs);
    UI::SameLine();
    if (PausedLogsLen >= 0) {
        if (UI::Button("Resume")) {
            PausedLogsLen = -1;
        } else {
            nbLogs = PausedLogsLen;
        }
    } else {
        if (UI::Button("Pause Logs")) {
            PausedLogsLen = nbLogs;
        }
    }
    UI::SameLine();
    if (UI::Button("Clear Logs")) {
        logs.RemoveRange(0, logs.Length);
        nbLogs = 0;
    }
    if (UI::BeginChild("logschild", vec2(), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
        UI::ListClipper clip(nbLogs);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto @item = logs[nbLogs - i - 1];
                UI::PushID('log'+i);
                UI::PushStyleColor(UI::Col::Text, LogLevelColor(item.level));
                UI::Text(item.logLine);
                UI::PopStyleColor();
                UI::PopID();
            }
        }
    }
    UI::EndChild();
    UI::PopFont();
}

vec4 LogLevelColor(LogLevel level) {
    switch (level) {
        case LogLevel::ERROR: return vec4(1, 0.4, 0.3, 1);
        case LogLevel::WARN: return vec4(1, 1, 0.3, 1);
        case LogLevel::INFO: return vec4(1, 1, 1, 1);
        case LogLevel::DEBUG: return vec4(0.3, 1, 0.5, 1);
        case LogLevel::TRACE: return vec4(0.6, 0.6, 0.6, 1);
    }
    return vec4(1, 1, 1, 1);
}

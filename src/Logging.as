enum LogLevel {
    ERROR,
    WARN,
    INFO,
    DEBUG,
    TRACE
}

class LogMessage {
    string msg;
    LogLevel level;
    int64 timestamp;

    LogMessage() {}

    LogMessage(const string &in msg, LogLevel level) {
        this.msg = msg;
        this.level = level;
        this.timestamp = Time::Stamp;
    }
}

LogMessage[] logs = array<LogMessage>();

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

void log_debug(const string &in msg, bool passthrough = false) {
    if (passthrough) trace(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::DEBUG));
}

void log_trace(const string &in msg, bool passthrough = false) {
    if (passthrough) trace(msg);
    logs.InsertLast(LogMessage(msg, LogLevel::TRACE));
}

int PausedLogsLen = -1;

void DrawLogsTab() {
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
    if (UI::BeginChild("logschild", vec2(), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
        UI::ListClipper clip(nbLogs);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto @item = logs[nbLogs - i - 1];
                UI::PushID('log'+i);
                UI::PushStyleColor(UI::Col::Text, LogLevelColor(item.level));
                UI::Text(Time::FormatString("%Y-%m-%d %H:%M:%S", item.timestamp) + " - " + item.msg);
                UI::PopStyleColor();
                UI::PopID();
            }
        }
    }
    UI::EndChild();
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

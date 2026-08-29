uint lastAuthTime = 0;
string g_opAuthToken;

bool _IsRequestingAuthToken = false;
const string CheckTokenUpdate() {
    while (_IsRequestingAuthToken) yield_why("waiting for auth token");
    if (!HasAuthToken()) {
        _IsRequestingAuthToken = true;
        // Auth::GetToken can legitimately take 5+ seconds, and occasionally
        // throws transiently even with a valid siteid -- retry before failing.
        for (uint attempt = 1; attempt <= 3; attempt++) {
            try {
                auto task = Auth::GetToken();
                while (!task.Finished()) yield_why("waiting for auth token task to finish");
                g_opAuthToken = task.Token();
            } catch {
                log_warn("Exception refreshing auth token (attempt " + attempt + "/3): " + getExceptionInfo());
                g_opAuthToken = "";
            }
            if (g_opAuthToken != "") {
                lastAuthTime = Time::Now;
                break;
            }
            if (attempt < 3) sleep(3000);
        }
        // always reset, or every later connect hangs forever in the
        // while(_IsRequestingAuthToken) wait above
        _IsRequestingAuthToken = false;
    }
    return g_opAuthToken;
}

const string GetAuthToken() {
    return CheckTokenUpdate();
}

bool HasAuthToken() {
    return g_opAuthToken != "" && lastAuthTime > 0 && Time::Now < lastAuthTime + (180 * 1000);
}

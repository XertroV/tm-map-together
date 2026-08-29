uint lastAuthTime = 0;
string g_opAuthToken;

bool _IsRequestingAuthToken = false;
const string CheckTokenUpdate() {
    while (_IsRequestingAuthToken) yield_why("waiting for auth token");
    if (!HasAuthToken()) {
        try {
            _IsRequestingAuthToken = true;
            auto task = Auth::GetToken();
            while (!task.Finished()) yield_why("waiting for auth token task to finish");
            _IsRequestingAuthToken = false;
            g_opAuthToken = task.Token();
            lastAuthTime = Time::Now;
            // OnGotNewToken();
        } catch {
            log_warn("Got exception refreshing auth token: " + getExceptionInfo());
            g_opAuthToken = "";
            // without this, every later connect hangs forever in the
            // while(_IsRequestingAuthToken) wait above
            _IsRequestingAuthToken = false;
        }
    }
    return g_opAuthToken;
}

const string GetAuthToken() {
    return CheckTokenUpdate();
}

bool HasAuthToken() {
    return g_opAuthToken != "" && lastAuthTime > 0 && Time::Now < lastAuthTime + (180 * 1000);
}

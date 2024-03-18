namespace OPAuth {

}

bool _AuthLoopStartEarly = false;

uint lastAuthTime = 0;
string g_opAuthToken;

// don't bother with auth, we don't need it anymore with a local http server.
void AuthLoop() {
    // while (Time::Now < 120000 && !_AuthLoopStartEarly) yield();
    // while (true) {
    //     sleep(500);
    //     CheckTokenUpdate();
    // }
}

const string CheckTokenUpdate() {
    if (g_opAuthToken == "" || lastAuthTime == 0 || (Time::Now - lastAuthTime) > (50 * 60 * 1000)) {
        try {
            auto task = Auth::GetToken();
            while (!task.Finished()) yield();
            g_opAuthToken = task.Token();
            lastAuthTime = Time::Now;
            // OnGotNewToken();
        } catch {
            warn("Got exception refreshing auth token: " + getExceptionInfo());
            g_opAuthToken = "";
        }
    }
    return g_opAuthToken;
}

const string GetAuthToken() {
    return CheckTokenUpdate();
}

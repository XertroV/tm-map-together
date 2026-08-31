#if DEV && DEPENDENCY_EDITOR
namespace Tests {
    void MapTogether_ParseServerAliases(TestKit::Ctx@ ctx) {
        MTServers server;
        string err;
        ctx.AssertTrue(MapTogether::ParseServer("de", server, err), "de is valid");
        ctx.AssertSame(int(server), int(MTServers::De), "de -> De");
        ctx.AssertTrue(MapTogether::ParseServer("Australia", server, err), "Australia is valid");
        ctx.AssertSame(int(server), int(MTServers::Au), "Australia -> Au");
        ctx.AssertTrue(MapTogether::ParseServer("USA", server, err), "USA is valid");
        ctx.AssertSame(int(server), int(MTServers::Us), "USA -> Us");
        ctx.AssertTrue(MapTogether::ParseServer("development", server, err), "development is valid");
        ctx.AssertSame(int(server), int(MTServers::Dev), "development -> Dev");
        ctx.AssertFalse(MapTogether::ParseServer("moon", server, err), "moon is invalid");
        ctx.AssertTrue(err.Length > 0, "invalid server sets error");
    }

    void MapTogether_ParseMoodBaseCar(TestKit::Ctx@ ctx) {
        MapMood mood;
        MapBase base;
        MapCar car;
        string err;
        ctx.AssertTrue(MapTogether::ParseMood("sunset", mood, err), "sunset mood");
        ctx.AssertSame(int(mood), int(MapMood::Sunset), "sunset enum");
        ctx.AssertTrue(MapTogether::ParseBase("No Stadium", base, err), "no stadium base");
        ctx.AssertSame(int(base), int(MapBase::NoStadium), "nostadium enum");
        ctx.AssertTrue(MapTogether::ParseCar("rally", car, err), "rally car");
        ctx.AssertSame(int(car), int(MapCar::CarRally), "rally enum");
        ctx.AssertFalse(MapTogether::ParseCar("boat", car, err), "boat is invalid");
    }

    void MapTogether_DisconnectedStatusHasOk(TestKit::Ctx@ ctx) {
        auto prior = g_MTConn;
        @g_MTConn = null;
        auto status = MapTogether::GetStatus();
        ctx.AssertTrue(status !is null, "status is an object");
        ctx.AssertTrue(bool(status["ok"]), "disconnected status is ok");
        ctx.AssertFalse(bool(status["connected"]), "no connection");
        ctx.AssertFalse(bool(status["hasConnection"]), "hasConnection false");
        @g_MTConn = prior;
    }

    void MapTogether_RoomIdPrefixes(TestKit::Ctx@ ctx) {
        // Matching is case-insensitive, but canonical form is capitals.
        ctx.AssertSame(NormalizeRoomId("au_abc123"), "AU_abc123", "lowercase prefix is capitalised");
        ctx.AssertSame(NormalizeRoomId("  DE_abc123  "), "DE_abc123", "surrounding whitespace trimmed");
        ctx.AssertSame(NormalizeRoomId("dEv_abc123"), "DEV_abc123", "mixed case dev prefix");
        ctx.AssertSame(NormalizeRoomId("abc123"), "abc123", "bare id untouched");

        // DEV_ must not be matched as DE_.
        ctx.AssertSame(int(ServerFromRoomId("DEV_abc123")), int(MTServers::Dev), "DEV_ -> Dev");
        ctx.AssertSame(int(ServerFromRoomId("DE_abc123")), int(MTServers::De), "DE_ -> De");
        ctx.AssertSame(int(ServerFromRoomId("us_abc123")), int(MTServers::Us), "us_ -> Us");
        ctx.AssertSame(int(ServerFromRoomId("Au_abc123")), int(MTServers::Au), "legacy Au_ still parses");
        ctx.AssertSame(int(ServerFromRoomId("abc123")), int(MTServers::De), "no prefix -> De");

        // Stripping must handle both 3- and 4-char prefixes, in any case.
        ctx.AssertSame(GetRoomIdNoServer("DEV_abc123"), "abc123", "DEV_ stripped");
        ctx.AssertSame(GetRoomIdNoServer("au_abc123"), "abc123", "lowercase au_ stripped");
        ctx.AssertSame(GetRoomIdNoServer("abc123"), "abc123", "bare id unchanged");
        ctx.AssertTrue(RoomIdHasServerPrefix("Us_abc123"), "mixed case prefix detected");
        ctx.AssertFalse(RoomIdHasServerPrefix("abc123"), "bare id has no prefix");

        // Round trip: what we emit must parse back to the same server.
        for (uint i = 0; i < ROOM_ID_PREFIXES.Length; i++) {
            string id = ServerToRoomIdPrefix(MTServers(i)) + "_abc123";
            ctx.AssertSame(int(ServerFromRoomId(id)), int(i), "round trip " + id);
            ctx.AssertSame(GetRoomIdNoServer(id), "abc123", "round trip strip " + id);
        }
    }

    void MapTogether_ApplyJoinOptsValidatesRoomId(TestKit::Ctx@ ctx) {
        auto priorServer = m_CurrServer;
        auto priorRoom = m_RoomId;
        auto priorPw = m_Password;
        auto opts = Json::Object();
        opts["roomId"] = "abc";
        string err = MapTogether::ApplyJoinOpts(opts);
        ctx.AssertTrue(err.Length > 0, "short room id is rejected");

        auto ok = Json::Object();
        ok["roomId"] = "De_ABCDEF";
        err = MapTogether::ApplyJoinOpts(ok);
        ctx.AssertSame(err, "", "prefixed 6-char room id is accepted");
        ctx.AssertSame(int(m_CurrServer), int(MTServers::De), "prefix selects De");
        m_CurrServer = priorServer;
        m_RoomId = priorRoom;
        m_Password = priorPw;
    }

    void MapTogether_WaitUntilReadyFailsWhenIdle(TestKit::Ctx@ ctx) {
        auto prior = g_MTConn;
        bool priorConnecting = IS_CONNECTING;
        @g_MTConn = null;
        IS_CONNECTING = false;
        auto opts = Json::Object();
        opts["timeoutMs"] = 50;
        auto r = MapTogether::WaitUntilReady(opts);
        ctx.AssertFalse(bool(r["ok"]), "idle wait is not ok");
        ctx.AssertTrue(string(r["error"]).Length > 0, "idle wait has an error");
        @g_MTConn = prior;
        IS_CONNECTING = priorConnecting;
    }

    void MapTogether_FailShape(TestKit::Ctx@ ctx) {
        auto r = MapTogether::Fail("nope");
        ctx.AssertFalse(bool(r["ok"]), "fail is not ok");
        ctx.AssertSame(string(r["error"]), "nope", "fail keeps the error");
    }
}
#endif

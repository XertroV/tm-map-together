#if DEV && DEPENDENCY_EDITOR
namespace Tests {
    void MapTogether_PlayerTestModeRoundTrip(TestKit::Ctx@ ctx) {
        // pins the cross-repo constant (server: MAPPING_MSG_PLAYER_TEST_MODE)
        ctx.AssertSame(int(MTUpdateTy::PlayerTestMode), 23, "PlayerTestMode enum value");

        string url = "https://example.com/skin.zip";
        auto enter = PlayerTestModeUpdate();
        enter.entering = true;
        enter.skinUrl = url;
        auto buf = MemoryBuffer();
        enter.WriteToNetworkBuffer(buf);
        ctx.AssertSame(int(buf.GetSize()), int(3 + url.Length), "enter payload size = 3 + url len");
        buf.Seek(0);
        auto rt = PlayerTestModeUpdate(buf);
        ctx.AssertTrue(rt.entering, "entering round trips");
        ctx.AssertSame(rt.skinUrl, url, "skin url round trips");
        ctx.AssertSame(int(rt.ty), int(MTUpdateTy::PlayerTestMode), "ty set by ctor");

        auto leave = PlayerTestModeUpdate();
        leave.entering = false;
        auto buf2 = MemoryBuffer();
        leave.WriteToNetworkBuffer(buf2);
        ctx.AssertSame(int(buf2.GetSize()), 3, "leave payload is exactly 3 bytes");
        buf2.Seek(0);
        auto rt2 = PlayerTestModeUpdate(buf2);
        ctx.AssertFalse(rt2.entering, "leave round trips");
        ctx.AssertSame(rt2.skinUrl, "", "empty url round trips");
    }

    // VehiclePos (iso4 + vel) is the stand-in for the future 50ms
    // vehicle-update message. Perf (measured 2026-08-30, ms-resolution timer):
    // ~12us serialize, ~11.5us deserialize -- negligible at 20Hz.
    void MapTogether_VehiclePosRoundTrip(TestKit::Ctx@ ctx) {
        VehiclePos@ v = VehiclePos();
        v.vel = vec3(1, 2, 3);
        auto buf = MemoryBuffer();
        v.WriteToNetworkBuffer(buf);
        ctx.AssertSame(int(buf.GetSize()), 60, "VehiclePos wire size is 60 bytes");
        buf.Seek(0);
        VehiclePos@ v2 = VehiclePos();
        v2.ReadFromBuf(buf);
        ctx.AssertTrue(MathX::Vec3Eq(v2.vel, v.vel), "deserialized vel matches");
    }
}
#endif

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

    // Benchmarks VehiclePos (iso4 + vel) serialize/deserialize -- the stand-in
    // for the future 50ms vehicle-update message (iso4 + steering). Time::Now
    // is ms-resolution, so 1000-iteration batches repeat until ~20ms elapsed;
    // per-direction us/iter is printed as a greppable BENCH line.
    void MapTogether_VehicleMsgSerializationBench(TestKit::Ctx@ ctx) {
        VehiclePos@ v = VehiclePos();
        v.vel = vec3(1, 2, 3);
        const uint batch = 1000;
        const uint maxIters = 200000;

        uint iters = 0;
        uint start = Time::Now;
        while (Time::Now - start < 20 && iters < maxIters) {
            for (uint i = 0; i < batch; i++) {
                auto buf = MemoryBuffer();
                v.WriteToNetworkBuffer(buf);
            }
            iters += batch;
        }
        uint serMs = Time::Now - start;
        float serUsPerIter = float(serMs) * 1000.0 / float(iters);
        print("BENCH VehiclePos serialize: iters=" + iters + ", total=" + serMs + "ms, " + Text::Format("%.3f", serUsPerIter) + " us/iter");

        auto src = MemoryBuffer();
        v.WriteToNetworkBuffer(src);
        VehiclePos@ v2 = VehiclePos();
        iters = 0;
        start = Time::Now;
        while (Time::Now - start < 20 && iters < maxIters) {
            for (uint i = 0; i < batch; i++) {
                src.Seek(0);
                v2.ReadFromBuf(src);
            }
            iters += batch;
        }
        uint deMs = Time::Now - start;
        float deUsPerIter = float(deMs) * 1000.0 / float(iters);
        print("BENCH VehiclePos deserialize: iters=" + iters + ", total=" + deMs + "ms, " + Text::Format("%.3f", deUsPerIter) + " us/iter");

        ctx.AssertSame(int(src.GetSize()), 60, "VehiclePos wire size is 60 bytes");
        ctx.AssertTrue(MathX::Vec3Eq(v2.vel, v.vel), "deserialized vel matches");
        // loose sanity bounds only: this is informational, must not flake at load
        ctx.AssertTrue(serUsPerIter < 5000.0, "serialize < 5ms/iter");
        ctx.AssertTrue(deUsPerIter < 5000.0, "deserialize < 5ms/iter");
    }
}
#endif

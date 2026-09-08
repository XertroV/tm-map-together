#if DEV && DEPENDENCY_EDITOR
namespace Tests {
    VehicleSample@ _vsFilled() {
        auto s = VehicleSample();
        s.tMs = 7000350;
        s.pos = vec3(1, 2, 3);
        s.dir = vec3(0, 0, 1);
        s.up = vec3(0, 1, 0);
        s.vel = vec3(4, 5, 6);
        s.steer = -0.5;
        s.gas = 200;
        s.brake = 17;
        s.wheelContact = 0x0B;
        s.misc = VS_MISC_TURBO | VS_MISC_GROUND_CONTACT;
        s.rpm = 11000;
        return s;
    }

    void MapTogether_VehicleSampleRoundTrip(TestKit::Ctx@ ctx) {
        // pins the cross-repo constant (server: MAPPING_MSG_VEHICLE_SAMPLE)
        ctx.AssertSame(int(MTUpdateTy::VehicleSample), 24, "VehicleSample enum value");

        auto s = _vsFilled();
        auto buf = MemoryBuffer();
        s.WriteToNetworkBuffer(buf);
        ctx.AssertSame(int(buf.GetSize()), int(VEHICLE_SAMPLE_FMT1_SIZE), "fmt-1 wire size is 64 bytes");
        buf.Seek(0);
        auto rt = VehicleSample(buf);
        ctx.AssertSame(int(rt.fmt), int(VEHICLE_SAMPLE_FMT), "fmt round trips");
        ctx.AssertSame(int(rt.tMs), int(s.tMs), "tMs round trips");
        ctx.AssertTrue(MathX::Vec3Eq(rt.pos, s.pos), "pos round trips");
        ctx.AssertTrue(MathX::Vec3Eq(rt.dir, s.dir), "dir round trips");
        ctx.AssertTrue(MathX::Vec3Eq(rt.up, s.up), "up round trips");
        ctx.AssertTrue(MathX::Vec3Eq(rt.vel, s.vel), "vel round trips");
        ctx.AssertTrue(Math::Abs(rt.steer - s.steer) < 0.0001, "steer round trips");
        ctx.AssertSame(int(rt.gas), int(s.gas), "gas round trips");
        ctx.AssertSame(int(rt.brake), int(s.brake), "brake round trips");
        ctx.AssertSame(int(rt.wheelContact), int(s.wheelContact), "wheelContact round trips");
        ctx.AssertSame(int(rt.misc), int(s.misc), "misc round trips");
        ctx.AssertSame(int(rt.rpm), 11000, "rpm stored raw (not /50)");

        // append-only forward compat: a future fmt with appended tail bytes
        // must still parse its fmt-1 prefix on this reader
        auto buf2 = MemoryBuffer();
        s.WriteToNetworkBuffer(buf2);
        for (uint i = 0; i < 8; i++) buf2.Write(uint8(0xEE));
        buf2.Seek(0);
        auto rt2 = VehicleSample(buf2);
        ctx.AssertTrue(MathX::Vec3Eq(rt2.pos, s.pos), "prefix parses with appended future tail");
    }

    // Benchmarks VehicleSample serialize/deserialize. Time::Now is
    // ms-resolution, so 1000-iteration batches repeat until ~20ms elapsed;
    // per-direction us/iter is printed as a greppable BENCH line.
    void MapTogether_VehicleSampleBench(TestKit::Ctx@ ctx) {
        auto s = _vsFilled();
        const uint batch = 1000;
        const uint maxIters = 200000;

        uint iters = 0;
        uint start = Time::Now;
        while (Time::Now - start < 20 && iters < maxIters) {
            for (uint i = 0; i < batch; i++) {
                auto buf = MemoryBuffer();
                s.WriteToNetworkBuffer(buf);
            }
            iters += batch;
        }
        uint serMs = Time::Now - start;
        float serUsPerIter = float(serMs) * 1000.0 / float(iters);
        print("BENCH VehicleSample serialize: iters=" + iters + ", total=" + serMs + "ms, " + Text::Format("%.3f", serUsPerIter) + " us/iter");

        auto src = MemoryBuffer();
        s.WriteToNetworkBuffer(src);
        auto s2 = VehicleSample();
        iters = 0;
        start = Time::Now;
        while (Time::Now - start < 20 && iters < maxIters) {
            for (uint i = 0; i < batch; i++) {
                src.Seek(0);
                s2.ReadFromBuf(src);
            }
            iters += batch;
        }
        uint deMs = Time::Now - start;
        float deUsPerIter = float(deMs) * 1000.0 / float(iters);
        print("BENCH VehicleSample deserialize: iters=" + iters + ", total=" + deMs + "ms, " + Text::Format("%.3f", deUsPerIter) + " us/iter");

        // loose sanity bounds only: informational, must not flake at load
        ctx.AssertTrue(serUsPerIter < 5000.0, "serialize < 5ms/iter");
        ctx.AssertTrue(deUsPerIter < 5000.0, "deserialize < 5ms/iter");
    }

    void MapTogether_VehicleReplayInterp(TestKit::Ctx@ ctx) {
        auto replay = VehicleReplay();
        // Sender epoch deliberately huge vs local clock: per-player offset
        // mapping must make the epoch irrelevant.
        uint senderT0 = 7000000;
        uint64 localT0 = 1000;
        // straight line at 10 m/s along +x, one sample per 100ms
        for (uint k = 0; k < 6; k++) {
            auto s = VehicleSample();
            s.tMs = senderT0 + k * 100;
            s.pos = vec3(float(k) * 1.0, 0, 0); // 10 m/s * 0.1s
            s.vel = vec3(10, 0, 0);
            s.dir = vec3(1, 0, 0);
            s.up = vec3(0, 1, 0);
            replay.Add(s, localT0 + k * 100);
        }
        ctx.AssertSame(int(replay.Count), 6, "6 samples buffered");
        ctx.AssertTrue(replay.FreshWithin(localT0 + 600, 2000), "fresh after last add");

        // exact gaps of 100ms -> delay = clamp(250, 120, 500) = 250ms.
        // localNow 1600 -> target sender time 7000350: halfway k=3..k=4.
        auto st = VehicleInterpState();
        ctx.AssertTrue(replay.StateAt(localT0 + 600, st), "state available");
        ctx.AssertFalse(st.extrapolated, "interpolated, not extrapolated");
        ctx.AssertTrue(Math::Abs(st.pos.x - 3.5) < 0.01, "linear path: x=3.5 got " + st.pos.x);
        ctx.AssertTrue(Math::Abs(st.pos.z) < 0.01, "linear path stays on line");
        ctx.AssertTrue(MathX::Vec3Eq(st.dir, vec3(1, 0, 0)), "dir stable on straight");
        ctx.AssertTrue(MathX::Vec3Eq(st.left, Math::Cross(vec3(0, 1, 0), vec3(1, 0, 0))), "left = up x dir");

        // past the newest sample: bounded velocity extrapolation
        auto stEx = VehicleInterpState();
        ctx.AssertTrue(replay.StateAt(localT0 + 1000, stEx), "extrapolation window");
        ctx.AssertTrue(stEx.extrapolated, "flagged extrapolated");

        // cornering: Hermite must bend toward the entry direction, not chord
        auto replay2 = VehicleReplay();
        auto a = VehicleSample();
        a.tMs = 1000; a.pos = vec3(0, 0, 0); a.vel = vec3(10, 0, 0);
        a.dir = vec3(1, 0, 0); a.up = vec3(0, 1, 0);
        auto b = VehicleSample();
        b.tMs = 1100; b.pos = vec3(0.7, 0, 0.7); b.vel = vec3(0, 0, 10);
        b.dir = vec3(0, 0, 1); b.up = vec3(0, 1, 0);
        // three trailing keep-alive samples so the interp target (delay 250ms
        // behind) can land between a and b
        auto c = VehicleSample();
        c.tMs = 1200; c.pos = vec3(0.7, 0, 1.7); c.vel = vec3(0, 0, 10);
        c.dir = vec3(0, 0, 1); c.up = vec3(0, 1, 0);
        auto d = VehicleSample();
        d.tMs = 1300; d.pos = vec3(0.7, 0, 2.7); d.vel = vec3(0, 0, 10);
        d.dir = vec3(0, 0, 1); d.up = vec3(0, 1, 0);
        replay2.Add(a, 1000);
        replay2.Add(b, 1100);
        replay2.Add(c, 1200);
        replay2.Add(d, 1300);
        // localNow 1300 -> target 1300 - 0 - 250 = 1050: midway a..b
        auto stC = VehicleInterpState();
        ctx.AssertTrue(replay2.StateAt(1300, stC), "corner state available");
        // chord midpoint is (0.35, 0, 0.35); Hermite mid = (0.475, 0, 0.225)
        ctx.AssertTrue(stC.pos.x > 0.44, "corner bends toward entry dir: x got " + stC.pos.x);
        ctx.AssertTrue(stC.pos.z < 0.26, "corner bends: z got " + stC.pos.z);
        ctx.AssertTrue(Math::Abs(stC.dir.Length() - 1.0) < 0.001, "interp dir normalized");
    }

    void MapTogether_VehicleSampleCadence(TestKit::Ctx@ ctx) {
        ctx.AssertSame(int(VehicleSampleIntervalMs(1)), 50, "solo is 20Hz");
        ctx.AssertSame(int(VehicleSampleIntervalMs(4)), 50, "4 drivers stay 20Hz");
        ctx.AssertSame(int(VehicleSampleIntervalMs(5)), 63, "5 drivers lerp off 20Hz");
        ctx.AssertSame(int(VehicleSampleIntervalMs(6)), 75, "6 drivers midpoint");
        ctx.AssertSame(int(VehicleSampleIntervalMs(8)), 100, "8 drivers reach 10Hz");
        ctx.AssertSame(int(VehicleSampleIntervalMs(12)), 100, "10Hz floor");
        ctx.AssertTrue(VehiclePosDueThisSample(0), "first sample sends VehiclePos");
        ctx.AssertFalse(VehiclePosDueThisSample(1), "skip 1");
        ctx.AssertFalse(VehiclePosDueThisSample(2), "skip 2");
        ctx.AssertTrue(VehiclePosDueThisSample(3), "every 3rd sample");
    }
}
#endif

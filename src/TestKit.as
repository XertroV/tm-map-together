#if DEV && DEPENDENCY_EDITOR
// Test plumbing, after tm-dips-plus-plus/src/TestKit.as.
//
// Openplanet's `[Test]` facility only fires from a UI trigger, so nothing ran
// on plugin load and a broken assertion could sit unnoticed for weeks. This
// file adds a driver plus two sinks:
//
//   LogSink -- RunSelfChecks() at plugin load, printing SELFCHECK markers a
//              build script can grep out of Openplanet.log for an exit code.
//   CtxSink -- Tests::TestKit_AllRegisteredTests below, so the native UI runner
//              drives the same registry.
//
// Difference from dips++: those tests never dereference their context, so its
// driver can hand them a null. Ours assert through `ctx`, so the bodies take a
// TestKit::Ctx instead -- the same three assertions, routed to whichever sink
// is driving. That is why the test bodies below take TestKit::Ctx@ and the one
// `[Test]` entry point is the aggregate: a per-test `[Test]` shim would make
// the UI runner execute everything twice.
namespace TestKit {
    interface Sink {
        void Check(bool ok, const string &in msg);
    }

    // Adapts the native runner's context.
    class CtxSink : Sink {
        private Tests::Context@ ctx;
        CtxSink(Tests::Context@ c) { @ctx = c; }
        void Check(bool ok, const string &in msg) {
            ctx.AssertTrue(ok, msg);
        }
    }

    // Adapts to the log, so a build script can grep results.
    class LogSink : Sink {
        string suite;
        uint passed = 0;
        uint failed = 0;

        LogSink(const string &in suiteName) { suite = suiteName; }

        void Check(bool ok, const string &in msg) {
            if (ok) {
                passed++;
                print("SELFCHECK PASS: " + suite + " / " + msg);
            } else {
                failed++;
                warn("SELFCHECK FAIL: " + suite + " / " + msg);
            }
        }

        void Report() {
            print("SELFCHECK SUITE: " + suite + ", " + passed + " passed, " + failed + " failed");
        }
    }

    // What a test body is handed: the same assertions as Tests::Context, but
    // routed through a Sink and tagged with the test's name.
    class Ctx {
        private Sink@ sink;
        private string name;

        Ctx(Sink@ s, const string &in testName) {
            @sink = s;
            name = testName;
        }

        void AssertTrue(bool cond, const string &in msg) {
            sink.Check(cond, name + " / " + msg);
        }

        void AssertFalse(bool cond, const string &in msg) {
            sink.Check(!cond, name + " / " + msg);
        }

        void AssertSame(const string &in a, const string &in b, const string &in msg) {
            sink.Check(a == b, name + " / " + msg + (a == b ? "" : " (got \"" + a + "\", want \"" + b + "\")"));
        }

        void AssertSame(int a, int b, const string &in msg) {
            sink.Check(a == b, name + " / " + msg + (a == b ? "" : " (got " + a + ", want " + b + ")"));
        }
    }
}

namespace Tests {
    funcdef void TestFn(TestKit::Ctx@ ctx);

    class TestEntry {
        string name;
        TestFn@ fn;
        TestEntry(const string &in n, TestFn@ f) {
            name = n;
            @fn = f;
        }
    }

    TestEntry@[] g_registry;

    void Reg(const string &in name, TestFn@ fn) {
        g_registry.InsertLast(TestEntry(name, fn));
    }

    // Every test in the src/*_Test.as files, in file order. A test that is not
    // registered here never runs.
    void RegisterAll() {
        if (g_registry.Length > 0) return;
        Reg("ParseServerAliases", MapTogether_ParseServerAliases);
        Reg("ParseMoodBaseCar", MapTogether_ParseMoodBaseCar);
        Reg("DisconnectedStatusHasOk", MapTogether_DisconnectedStatusHasOk);
        Reg("RoomIdPrefixes", MapTogether_RoomIdPrefixes);
        Reg("ApplyJoinOptsValidatesRoomId", MapTogether_ApplyJoinOptsValidatesRoomId);
        Reg("WaitUntilReadyFailsWhenIdle", MapTogether_WaitUntilReadyFailsWhenIdle);
        Reg("FailShape", MapTogether_FailShape);
        Reg("PlayerTestModeRoundTrip", MapTogether_PlayerTestModeRoundTrip);
        Reg("VehiclePosRoundTrip", MapTogether_VehiclePosRoundTrip);
        Reg("VehicleSampleRoundTrip", MapTogether_VehicleSampleRoundTrip);
        Reg("VehicleSampleBench", MapTogether_VehicleSampleBench);
        Reg("VehicleReplayInterp", MapTogether_VehicleReplayInterp);
        Reg("VehicleSampleCadence", MapTogether_VehicleSampleCadence);
    }

    // Drives the registry through `sink`. A test that throws is reported as a
    // failure rather than taking the run down with it.
    uint RunAll(TestKit::Sink@ sink) {
        RegisterAll();
        uint failed = 0;
        for (uint i = 0; i < g_registry.Length; i++) {
            auto @t = g_registry[i];
            try {
                t.fn(TestKit::Ctx(sink, t.name));
            } catch {
                failed++;
                sink.Check(false, t.name + " threw: " + getExceptionInfo());
            }
        }
        return failed;
    }

    // Single native entry point, so the UI runner drives the same registry that
    // runs on load instead of a parallel set of shims.
    [Test]
    void TestKit_AllRegisteredTests(Tests::Context@ ctx) { // lsp: ignore unused
        RunAll(TestKit::CtxSink(ctx));
    }
}

// Called from Main() under #if DEV.
void RunSelfChecks() {
    Tests::RegisterAll();
    print("SELFCHECK BEGIN: map-together, " + Tests::g_registry.Length + " registered");
    TestKit::LogSink@ sink = TestKit::LogSink("map-together");
    Tests::RunAll(sink);
    sink.Report();
}
#endif

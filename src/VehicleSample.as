// VehicleSample (MTUpdateTy::VehicleSample = 24, protocol v6): replay-quality
// vehicle state, replacing VehiclePos for v6+ peers. The payload is
// self-versioned (leading fmt byte, append-only: readers parse the prefix they
// know and ignore the tail) and the server relays it as an opaque blob.
// Spec: map-together-server docs/vehicle-sample-plan.md.

const uint8 VEHICLE_SAMPLE_FMT = 1;
const uint VEHICLE_SAMPLE_FMT1_SIZE = 64;

// misc bit assignments (fmt 1)
const uint8 VS_MISC_IS_BRAKING = 1;
const uint8 VS_MISC_TURBO = 2;
const uint8 VS_MISC_GROUND_CONTACT = 4;
const uint8 VS_MISC_ENGINE_ON = 8;

// Per-wheel contact heuristic: damper compressed below this = touching.
// Calibrate in-game; the aggregate AsyncState.IsGroundContact bit in `misc`
// is the reliable signal, wheel bits are best-effort for animation.
const float VS_WHEEL_CONTACT_DAMPER_LEN = 0.10;

// 20Hz through 4 drivers, lerp to 10Hz by 8.
uint VehicleSampleIntervalMs(uint concurrentDrivers) {
    if (concurrentDrivers <= 4) return 50;
    if (concurrentDrivers >= 8) return 100;
    float t = float(concurrentDrivers - 4) / 4.0;
    return uint(Math::Lerp(50.0, 100.0, t) + 0.5);
}

// VehiclePos every 3rd sample (~150ms at 20Hz).
bool VehiclePosDueThisSample(uint sampleIx) {
    return (sampleIx % 3) == 0;
}

class VehicleSample : MTUpdate {
    uint8 fmt = VEHICLE_SAMPLE_FMT;
    uint8 flags = 0;
    uint tMs;       // sender Time::Now — epoch is per-sender (game-launch relative)
    vec3 pos;
    vec3 dir;
    vec3 up;
    vec3 vel;       // world m/s
    float steer;    // [-1, 1]
    uint8 gas;      // 0-255
    uint8 brake;    // 0-255
    uint8 wheelContact; // bits 0-3 = FL,FR,RL,RR
    uint8 misc;     // VS_MISC_* bits
    uint16 rpm;

    VehicleSample() {
        super();
        ty = MTUpdateTy::VehicleSample;
    }

    VehicleSample(MemoryBuffer@ buf) {
        super();
        ty = MTUpdateTy::VehicleSample;
        ReadFromBuf(buf);
    }

    // Sources "whatever is most recently available" from the vis AsyncState at
    // the send tick. Returns true when there is a car to sample.
    bool UpdateFromGame(CSceneVehicleVis@ vis) {
        if (vis is null) return false;
        auto state = vis.AsyncState;
        fmt = VEHICLE_SAMPLE_FMT;
        flags = 0;
        tMs = Time::Now;
        pos = state.Position;
        dir = state.Dir;
        up = state.WorldCarUp;
        vel = state.WorldVel;
        steer = state.InputSteer;
        gas = uint8(Math::Clamp(state.InputGasPedal, 0.0, 1.0) * 255.0);
        brake = uint8(Math::Clamp(state.InputBrakePedal, 0.0, 1.0) * 255.0);
        wheelContact =
              (state.FLDamperLen < VS_WHEEL_CONTACT_DAMPER_LEN ? 1 : 0)
            | (state.FRDamperLen < VS_WHEEL_CONTACT_DAMPER_LEN ? 2 : 0)
            | (state.RLDamperLen < VS_WHEEL_CONTACT_DAMPER_LEN ? 4 : 0)
            | (state.RRDamperLen < VS_WHEEL_CONTACT_DAMPER_LEN ? 8 : 0);
        misc =
              (state.InputIsBraking ? VS_MISC_IS_BRAKING : 0)
            | (state.IsTurbo ? VS_MISC_TURBO : 0)
            | (state.IsGroundContact ? VS_MISC_GROUND_CONTACT : 0)
            | (state.EngineOn ? VS_MISC_ENGINE_ON : 0);
        rpm = uint16(Math::Clamp(VehicleState::GetRPM(state), 0.0, 65535.0));
        return true;
    }

    // Wire order matches the spec table exactly; a straight run of writes.
    void WriteToNetworkBuffer(MemoryBuffer@ buf) const {
        buf.Write(fmt);
        buf.Write(flags);
        buf.Write(tMs);
        WriteVec3ToBuffer(buf, pos);
        WriteVec3ToBuffer(buf, dir);
        WriteVec3ToBuffer(buf, up);
        WriteVec3ToBuffer(buf, vel);
        buf.Write(steer);
        buf.Write(gas);
        buf.Write(brake);
        buf.Write(wheelContact);
        buf.Write(misc);
        buf.Write(rpm);
    }

    // Reads the fmt-1 prefix; any appended future-fmt tail is left unread
    // (the caller framed the payload, leftover bytes are simply ignored).
    VehicleSample@ ReadFromBuf(MemoryBuffer@ buf) {
        fmt = buf.ReadUInt8();
        flags = buf.ReadUInt8();
        tMs = buf.ReadUInt32();
        pos = ReadVec3FromBuffer(buf);
        dir = ReadVec3FromBuffer(buf);
        up = ReadVec3FromBuffer(buf);
        vel = ReadVec3FromBuffer(buf);
        steer = buf.ReadFloat();
        gas = buf.ReadUInt8();
        brake = buf.ReadUInt8();
        wheelContact = buf.ReadUInt8();
        misc = buf.ReadUInt8();
        rpm = buf.ReadUInt16();
        return this;
    }

    bool Apply(CGameCtnEditorFree@ editor, int chunkSize = -1) override {
        if (g_MTConn is null) return false;
        g_MTConn.UpdatePlayerVehicleSample(this);
        return false;
    }

    void CopyFrom(VehicleSample@ o) {
        fmt = o.fmt; flags = o.flags; tMs = o.tMs;
        pos = o.pos; dir = o.dir; up = o.up; vel = o.vel;
        steer = o.steer; gas = o.gas; brake = o.brake;
        wheelContact = o.wheelContact; misc = o.misc; rpm = o.rpm;
    }
}

// Interpolated state handed to renderers.
class VehicleInterpState {
    vec3 pos;
    vec3 dir;
    vec3 up;
    vec3 left;
    float steer;
    uint8 gas;
    uint8 brake;
    uint8 wheelContact;
    uint8 misc;
    uint16 rpm;
    bool extrapolated = false;
}

// Per-remote-player replay buffer: keeps recent samples and renders the car a
// little in the past (delayMs) so there are buffered future points to
// interpolate through, absorbing network jitter. All clock math is per-player:
// every sender's tMs epoch is different (game-launch relative).
class VehicleReplay : HasPlayerLabelDraw {
    private array<VehicleSample@> ring;
    private uint head = 0;   // next write index
    private uint count = 0;
    private double offsetEstMs = 0; // EWMA of (localRecvMs - tMs) for THIS sender
    private bool offsetInit = false;
    private double gapEwmaMs = 100; // EWMA of inter-sample sender-time gap
    private uint64 lastRecvLocalMs = 0;

    VehicleReplay() {
        ring.Resize(32);
        for (uint i = 0; i < ring.Length; i++) @ring[i] = VehicleSample();
    }

    void Add(VehicleSample@ s, uint64 localNowMs) {
        if (count > 0) {
            // At(0) is the newest existing sample (we haven't written yet)
            int64 gap = int64(s.tMs) - int64(At(0).tMs);
            if (gap <= 0) return; // stale/dup (out-of-order relay) — drop
            if (gap < 5000) gapEwmaMs = gapEwmaMs * 0.8 + double(gap) * 0.2;
        }
        // decode target is a shared tmp object; copy into the ring slot
        ring[head].CopyFrom(s);
        head = (head + 1) % ring.Length;
        if (count < ring.Length) count++;
        double offset = double(localNowMs) - double(s.tMs);
        if (!offsetInit) {
            offsetEstMs = offset;
            offsetInit = true;
        } else {
            // drift slowly; jump if wildly off (reconnect / clock restart)
            if (Math::Abs(float(offset - offsetEstMs)) > 5000.0) offsetEstMs = offset;
            else offsetEstMs = offsetEstMs * 0.9 + offset * 0.1;
        }
        lastRecvLocalMs = localNowMs;
    }

    bool FreshWithin(uint64 localNowMs, uint64 windowMs) {
        return count > 0 && localNowMs - lastRecvLocalMs <= windowMs;
    }

    uint get_Count() { return count; }

    private VehicleSample@ At(uint newestBack) {
        // newestBack = 0 → newest sample
        uint ix = (head + ring.Length - 1 - newestBack) % ring.Length;
        return ring[ix];
    }

    private VehicleSample@ Newest() { return At(0); }

    double get_DelayMs() {
        return Math::Clamp(gapEwmaMs * 2.5, 120.0, 500.0);
    }

    // Interpolated state at render time. Returns false when no usable data
    // (never received, or stale past the extrapolation cap).
    bool StateAt(uint64 localNowMs, VehicleInterpState@ outState) {
        if (count == 0) return false;
        double targetT = double(localNowMs) - offsetEstMs - DelayMs;

        VehicleSample@ newest = Newest();
        double newestT = double(newest.tMs);
        if (targetT >= newestT) {
            // underrun: extrapolate along velocity for a bounded window
            double dtMs = targetT - newestT;
            if (dtMs > 150.0) {
                if (dtMs > 2000.0) return false; // long stale: hide/fade upstream
                dtMs = 150.0;
            }
            FillFrom(newest, outState);
            outState.pos = newest.pos + newest.vel * float(dtMs / 1000.0);
            outState.extrapolated = true;
            OrthonormalizeInto(newest.dir, newest.up, outState);
            return true;
        }

        // find bracketing pair a (older) .. b (newer) around targetT
        VehicleSample@ b = newest;
        for (uint back = 1; back < count; back++) {
            VehicleSample@ a = At(back);
            if (double(a.tMs) <= targetT) {
                InterpBetween(a, b, targetT, outState);
                return true;
            }
            @b = a;
        }
        // target older than everything buffered: clamp to oldest
        FillFrom(At(count - 1), outState);
        OrthonormalizeInto(outState.dir, outState.up, outState);
        return true;
    }

    private void FillFrom(VehicleSample@ s, VehicleInterpState@ o) {
        o.pos = s.pos; o.dir = s.dir; o.up = s.up;
        o.steer = s.steer; o.gas = s.gas; o.brake = s.brake;
        o.wheelContact = s.wheelContact; o.misc = s.misc; o.rpm = s.rpm;
        o.extrapolated = false;
    }

    private void InterpBetween(VehicleSample@ a, VehicleSample@ b, double targetT, VehicleInterpState@ o) {
        double t0 = double(a.tMs), t1 = double(b.tMs);
        float span = float(t1 - t0);
        if (span <= 0.0) { FillFrom(b, o); OrthonormalizeInto(b.dir, b.up, o); return; }
        float s = float((targetT - t0)) / span;
        float dtSec = span / 1000.0;

        // teleport guard: if the gap is far larger than velocity explains, snap
        vec3 delta = b.pos - a.pos;
        float velDist = Math::Max(a.vel.Length(), b.vel.Length()) * dtSec;
        if (delta.Length() > Math::Max(velDist * 3.0 + 8.0, 16.0)) {
            FillFrom(b, o);
            OrthonormalizeInto(b.dir, b.up, o);
            return;
        }

        // cubic Hermite on pos+vel: follows the cornering arc, not the chord
        float s2 = s * s, s3 = s2 * s;
        float h00 = 2.0 * s3 - 3.0 * s2 + 1.0;
        float h10 = s3 - 2.0 * s2 + s;
        float h01 = -2.0 * s3 + 3.0 * s2;
        float h11 = s3 - s2;
        o.pos = a.pos * h00 + a.vel * (h10 * dtSec) + b.pos * h01 + b.vel * (h11 * dtSec);

        // nlerp orientation vectors, then orthonormalize
        vec3 dirL = Math::Lerp(a.dir, b.dir, s);
        vec3 upL = Math::Lerp(a.up, b.up, s);
        OrthonormalizeInto(dirL, upL, o);

        o.steer = Math::Lerp(a.steer, b.steer, s);
        // step-hold discrete-ish state from the newer bracketing sample
        o.gas = b.gas; o.brake = b.brake;
        o.wheelContact = b.wheelContact; o.misc = b.misc; o.rpm = b.rpm;
        o.extrapolated = false;
    }

    private void OrthonormalizeInto(const vec3 &in dirIn, const vec3 &in upIn, VehicleInterpState@ o) {
        vec3 d = dirIn.LengthSquared() > 0.0001 ? dirIn.Normalized() : vec3(0, 0, 1);
        vec3 u = upIn - d * Math::Dot(upIn, d);
        u = u.LengthSquared() > 0.0001 ? u.Normalized() : vec3(0, 1, 0);
        o.dir = d;
        o.up = u;
        o.left = Math::Cross(u, d);
    }

    // NVG label at the interpolated position; replaces the exp-smoothing hack
    // (the replay buffer IS the smoothing).
    void RenderNvg(const string &in name, uint64 localNowMs) {
        auto @st = g_vsInterpScratch;
        if (!StateAt(localNowMs, st)) return;
        vec3 screenPos = Camera::ToScreen(st.pos);
        if (screenPos.z > 0.0) return;
        DrawPlayerLabel(name, screenPos.xy, cWhite, st.extrapolated ? cBlack25 : cRed25);
        nvgDrawPointCross(screenPos.xy, S_PlayerLabelHeight * .5, cLimeGreen);
    }
}

// shared per-frame scratch for label rendering (interp results are consumed
// immediately; never retained across players/frames)
VehicleInterpState@ g_vsInterpScratch = VehicleInterpState();

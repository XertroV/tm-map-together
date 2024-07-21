const double TAU = 6.28318530717958647692;

namespace MathX {
    vec2 ToDeg(const vec2 &in rads) {
        return vec2(Math::ToDeg(rads.x), Math::ToDeg(rads.y));
    }

    vec3 ToDeg(const vec3 &in rads) {
        return vec3(Math::ToDeg(rads.x), Math::ToDeg(rads.y), Math::ToDeg(rads.z));
    }

    vec2 ToRad(const vec2 &in degs) {
        return vec2(Math::ToRad(degs.x), Math::ToRad(degs.y));
    }

    vec3 ToRad(const vec3 &in degs) {
        return vec3(Math::ToRad(degs.x), Math::ToRad(degs.y), Math::ToRad(degs.z));
    }

    vec3 Max(const vec3 &in a, const vec3 &in b) {
        return vec3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }
    nat3 Max(const nat3 &in a, const nat3 &in b) {
        return nat3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }

    vec3 Min(const vec3 &in a, const vec3 &in b) {
        return vec3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }
    nat3 Min(const nat3 &in a, const nat3 &in b) {
        return nat3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }

    bool Vec3Eq(const vec3 &in a, const vec3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
        // return (a-b).LengthSquared() < 1e10;
    }

    bool Nat3Eq(const nat3 &in a, const nat3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }
    bool Nat3XZEq(const nat3 &in a, const nat3 &in b) {
        return a.x == b.x && a.z == b.z;
    }

    bool Int3Eq(const int3 &in a, const int3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }

    bool QuatEq(const quat &in a, const quat &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
    }


    float AngleLerp(float start, float stop, float t) {
        float diff = stop - start;
        if (diff > Math::PI) { diff = (diff + Math::PI) % TAU - Math::PI; }
        if (diff < -Math::PI) { diff = -1. * ((-1. * diff + Math::PI) % TAU - Math::PI); }
        return start + diff * t;
    }

    float SimplifyRadians(float a) {
        uint count = 0;
        while (Math::Abs(a) > TAU / 2.0 && count < 100) {
            a += (a < 0 ? 1. : -1.) * TAU;
            count++;
        }
        return a;
    }

    bool Within(const vec3 &in pos, const vec3 &in min, const vec3 &in max) {
        return pos.x >= min.x && pos.x <= max.x
            && pos.y >= min.y && pos.y <= max.y
            && pos.z >= min.z && pos.z <= max.z;
    }
    bool Within(const nat3 &in pos, const nat3 &in min, const nat3 &in max) {
        return pos.x >= min.x && pos.x <= max.x
            && pos.y >= min.y && pos.y <= max.y
            && pos.z >= min.z && pos.z <= max.z;
    }
    bool Within(const vec2 &in pos, const vec4 &in rect) {
        return pos.x >= rect.x && pos.x < (rect.x + rect.z)
            && pos.y >= rect.y && pos.y < (rect.y + rect.w);
    }

    vec2 Floor(const vec2 &in val) {
        return vec2(Math::Floor(val.x), Math::Floor(val.y));
    }
}

namespace MathX {
    shared vec2 ToDeg(vec2 &in rads) {
        return vec2(Math::ToDeg(rads.x), Math::ToDeg(rads.y));
    }

    shared vec3 ToDeg(vec3 &in rads) {
        return vec3(Math::ToDeg(rads.x), Math::ToDeg(rads.y), Math::ToDeg(rads.z));
    }

    shared vec2 ToRad(vec2 &in degs) {
        return vec2(Math::ToRad(degs.x), Math::ToRad(degs.y));
    }

    shared vec3 ToRad(vec3 &in degs) {
        return vec3(Math::ToRad(degs.x), Math::ToRad(degs.y), Math::ToRad(degs.z));
    }
}

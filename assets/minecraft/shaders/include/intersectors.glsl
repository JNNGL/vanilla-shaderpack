#version 330

#ifndef _INTERSECTORS_GLSL
#define _INTERSECTORS_GLSL

vec2 raySphereIntersection(vec3 origin, vec3 direction, float radius) {
    float b = dot(origin, direction);
    float c = dot(origin, origin) - radius * radius;
    float h = b * b - c;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

#endif // _INTERSECTORS_GLSL
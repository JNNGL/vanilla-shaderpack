#version 330

#ifndef _PROJECTION_GLSL
#define _PROJECTION_GLSL

vec3 projectAndDivide(mat4 mat, vec4 vector) {
    vec4 homog = mat * vector;
    return homog.xyz / homog.w;
}

vec3 projectAndDivide(mat4 mat, vec3 v) {
    return projectAndDivide(mat, vec4(v, 1.0));
}

vec3 unprojectNdc(mat4 invProj, vec3 ndc) {
    return projectAndDivide(invProj, ndc);
}

vec3 unprojectScreenSpace(mat4 invProj, vec3 screenSpace) {
    return unprojectNdc(invProj, screenSpace * 2.0 - 1.0);
}

vec3 unprojectScreenSpace(mat4 invProj, vec2 uv, float z) {
    return unprojectScreenSpace(invProj, vec3(uv, z));
}

vec4 getPointOnNearPlane(mat4 invProj, vec2 ndc) {
    return invProj * vec4(ndc, -1.0, 1.0);
}

vec4 getPointOnFarPlane(mat4 invProj, vec2 ndc) {
    return invProj * vec4(ndc, 1.0, 1.0);
}

#endif // _PROJECTION_GLSL
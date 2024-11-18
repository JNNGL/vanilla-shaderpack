#version 330

#ifndef _SSRT_GLSL
#define _SSRT_GLSL

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>

float distanceSquared(vec2 a, vec2 b) {
    a -= b;
    return dot(a, b);
}

bool intersectsDepthBuffer(float sceneZMax, float rayZMin, float rayZMax) {
    float depthScale = min(1.0, abs(sceneZMax) / 100.0);
    sceneZMax -= mix(0.05, 0.0, depthScale);

    return (rayZMax >= sceneZMax - 50.0) && (rayZMin <= sceneZMax);
}

bool traceScreenSpaceRay(sampler2D depthSampler, mat4 projection, vec2 planes, vec2 screenSize, vec3 origin, vec3 direction, float stride, float jitter, float maxSteps, float maxDistance, out vec2 hitPixel, out vec3 hitPoint) {
    float rayLength = ((origin.z + direction.z * maxDistance) > -planes.x) ? (-planes.x - origin.z) / direction.z : maxDistance;
    vec3 endPoint = direction * rayLength + origin;

    vec4 h0 = projection * vec4(origin, 1.0);
    vec4 h1 = projection * vec4(endPoint, 1.0);

    float k0 = 1.0 / h0.w;
    float k1 = 1.0 / h1.w;

    vec3 q0 = origin * k0;
    vec3 q1 = endPoint * k1;

    vec2 p0 = h0.xy * k0;
    vec2 p1 = h1.xy * k1;

    p0 = (p0 * 0.5 + 0.5) * screenSize;
    p1 = (p1 * 0.5 + 0.5) * screenSize;

    hitPixel = vec2(-1.0, -1.0);

    p1 += vec2((distanceSquared(p0, p1) < 0.0001) ? 0.01 : 0.0);

    vec2 delta = p1 - p0;

    bool permute = false;
    if (abs(delta.x) < abs(delta.y)) {
        permute = true;

        delta = delta.yx;
        p1 = p1.yx;
        p0 = p0.yx;
    }

    float stepDirection = sign(delta.x);
    float invdx = stepDirection / delta.x;
    vec2 dP = vec2(stepDirection, invdx * delta.y);

    vec3 dQ = (q1 - q0) * invdx;
    float dk = (k1 - k0) * invdx;

    float zMin = min(endPoint.z, origin.z);
    float zMax = max(endPoint.z, origin.z);

    dP *= stride;
    dQ *= stride;
    dk *= stride;

    p0 += dP * jitter;
    q0 += dQ * jitter;
    k0 += dk * jitter;

    vec4 PQk = vec4(p0, q0.z, k0);
    vec4 dPQk = vec4(dP, dQ.z, dk);
    vec3 q = q0;

    float prevZMaxEstimate = origin.z;
    float rayZMax = prevZMaxEstimate;
    float rayZMin = prevZMaxEstimate;
    float sceneZMax = rayZMax + 10000.0;
    float stepCount = 0.0;

    float end = p1.x * stepDirection;

    for (; ((PQk.x * stepDirection) <= end) &&
        (stepCount < maxSteps) &&
        !intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax) &&
        (sceneZMax != 0.0);
        PQk += dPQk, stepCount += 1.0) {

        rayZMin = prevZMaxEstimate;
        rayZMax = (dPQk.z * 0.5 + PQk.z) / (dPQk.w * 0.5 + PQk.w);
        rayZMax = clamp(rayZMax, zMin, zMax);
        prevZMaxEstimate = rayZMax;
        if (rayZMin > rayZMax) {
            float t = rayZMin;
            rayZMin = rayZMax;
            rayZMax = t;
        }

        hitPixel = permute ? PQk.yx : PQk.xy;

        if (clamp(hitPixel, vec2(0.0), screenSize) != hitPixel) {
            return false;
        }

        sceneZMax = -linearizeDepth(texelFetch(depthSampler, ivec2(hitPixel), 0).r * 2.0 - 1.0, planes);
    }

    q.xy += dQ.xy * stepCount;
    q.z = PQk.z;
    hitPoint = q * (1.0 / PQk.w);
    hitPoint.z = stepCount;
    return intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax);
}

#endif // _SSRT_GLSL
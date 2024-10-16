#version 330

#ifndef _NORMALS_GLSL
#define _NORMALS_GLSL

#extension GL_MC_moj_import : enable
#moj_import <projections.glsl>
#moj_import <settings:settings.glsl>

// based on https://atyuwen.github.io/posts/normal-reconstruction/
vec3 reconstructNormal(sampler2D depthSampler, mat4 invProjView, vec2 uv, vec2 screenSize) {
    float depthCenter = texture(depthSampler, uv).r;
    if (depthCenter == 1.0) {
        return vec3(0.0);
    }

    vec3 positionCenter = unprojectScreenSpace(invProjView, uv, depthCenter);

    vec4 horizontal = vec4(
        texture(depthSampler, uv + vec2(-1.0, 0.0) / screenSize).r,
        texture(depthSampler, uv + vec2(+1.0, 0.0) / screenSize).r,
        texture(depthSampler, uv + vec2(-2.0, 0.0) / screenSize).r,
        texture(depthSampler, uv + vec2(+2.0, 0.0) / screenSize).r
    );

    vec4 vertical = vec4(
        texture(depthSampler, uv + vec2(0.0, -1.0) / screenSize).r,
        texture(depthSampler, uv + vec2(0.0, +1.0) / screenSize).r,
        texture(depthSampler, uv + vec2(0.0, -2.0) / screenSize).r,
        texture(depthSampler, uv + vec2(0.0, +2.0) / screenSize).r
    );

    vec3 positionLeft  = unprojectScreenSpace(invProjView, uv + vec2(-1.0, 0.0) / screenSize, horizontal.x);
    vec3 positionRight = unprojectScreenSpace(invProjView, uv + vec2(+1.0, 0.0) / screenSize, horizontal.y);
    vec3 positionDown  = unprojectScreenSpace(invProjView, uv + vec2(0.0, -1.0) / screenSize, vertical.x);
    vec3 positionUp    = unprojectScreenSpace(invProjView, uv + vec2(0.0, +1.0) / screenSize, vertical.y);

    vec3 left  = positionCenter - positionLeft;
    vec3 right = positionRight  - positionCenter;
    vec3 down  = positionCenter - positionDown;
    vec3 up    = positionUp     - positionCenter;

    vec2 he = abs((2.0 * horizontal.xy - horizontal.zw) - depthCenter);
    vec2 ve = abs((2.0 * vertical.xy - vertical.zw) - depthCenter);

    vec3 horizontalDeriv = he.x < he.y ? left : right;
    vec3 verticalDeriv = ve.x < ve.y ? down : up;

    return normalize(cross(horizontalDeriv, verticalDeriv));
}

vec2 wavedx(vec2 position, vec2 direction, float frequency, float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float wave = exp(sin(x) - 1.0);
    float dx = wave * cos(x);
    return vec2(wave, -dx);
}

vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float wave(vec2 position, float time) {
    float wavePhaseShift = length(position) * 0.1;

    float frequency = 1.0;
    float timeMultiplier = 2.0;
    float weight = 1.0;
    
    float value = 0.0;
    float totalWeight = 0.0;
    
    for(int i = 0; i < WATER_WAVE_ITERATIONS; i++) {
        vec2 p = vec2(sin(i * 1232.399963), cos(i * 1232.399963));
        vec2 res = wavedx(position, p, frequency, time + wavePhaseShift);
        position += p * res.y * weight * 0.38;
        
        value += res.x * weight;
        totalWeight += weight;
        
        weight *= 0.8;
        frequency *= 1.18;
        timeMultiplier *= 1.07;
    }

    value += snoise(position * 0.2);
    value += snoise(position * 0.1) * 2.0;
    totalWeight += 3.0;
  
    return (value / totalWeight) * WATER_WAVE_DEPTH;
}

vec3 waveNormal(vec2 pos, float time) {
    pos *= WATER_WAVE_SCALE;

    vec2 e = vec2(0.1, 0);
    float h = wave(pos, time);

    return normalize(cross(
        vec3(pos.x, h, pos.y) - vec3(pos.x - e.x, wave(pos - e.xy, time), pos.y),
        vec3(pos.x, h, pos.y) - vec3(pos.x, wave(pos + e.yx, time), pos.y + e.x)
    ));
}

#endif // _NORMALS_GLSL
#version 330

#extension GL_ARB_texture_query_lod : require
#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:intersectors.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform vec3 ModelOffset;
uniform float GameTime;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
flat in mat4 jitteredProj;
flat in int dataQuad;
flat in int shadow;
flat in float skyFactor;
flat in int quadId;
in vec2 lmCoord;
in vec3 fragPos;
in vec4 glPos;
flat in ivec2 atlasDim;
in vec3 texBound0;
in vec3 texBound1;
flat in vec2 planes;

// in float isSphere;
// flat in mat4 projView;
// flat in mat4 invProjView;
// in vec4 corner0;
// in vec4 corner1;

out vec4 fragColor;

vec4 unshadeBlock(vec4 color, vec3 normal) {
    if (abs(normal.x) - abs(normal.z) > 0.5) return vec4(color.rgb / 0.6, color.a);
    if (abs(normal.z) - abs(normal.x) > 0.5) return vec4(color.rgb / 0.8, color.a);
    if (normal.y < -0.5) return vec4(color.rgb / 0.5, color.a);
    return color;
}

void main() {
    gl_FragDepth = gl_FragCoord.z;

    vec4 color = shadow > 0 ? texture(Sampler0, texCoord0, 1) : texture(Sampler0, texCoord0);

    vec3 p1 = dFdx(fragPos);
    vec3 p2 = dFdy(fragPos);

    vec3 normal = normalize(cross(p1, p2));

    fragColor = color * unshadeBlock(vertexColor, normal) * ColorModulator;
}
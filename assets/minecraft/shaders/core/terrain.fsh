#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:datamarker.glsl>

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
flat in int dataQuad;
flat in int shadow;
flat in float skyFactor;
in vec3 fragPos;
in vec4 glPos;

out vec4 fragColor;

vec4 unshadeBlock(vec4 color, vec3 normal) {
    if (abs(normal.x) - abs(normal.z) > 0.5) return vec4(color.rgb / 0.6, color.a);
    if (abs(normal.z) - abs(normal.x) > 0.5) return vec4(color.rgb / 0.8, color.a);
    if (normal.y < -0.5) return vec4(color.rgb / 0.5, color.a);
    return color;
}

void main() {
    if (discardSunData(gl_FragCoord.xy)) {
        discard;
    }

    vec3 normal = normalize(cross(dFdx(fragPos), dFdy(fragPos)));
    
    if (dataQuad > 0) {
        ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
        if (discardDataMarker(pixel)) {
            discard;
        }

        fragColor = writeDataMarker(pixel, ProjMat, FogStart, FogEnd, ModelOffset, GameTime, shadow > 0, mat3(ModelViewMat), skyFactor);
        return;
    }

    vec4 color = shadow > 0 ? texture(Sampler0, texCoord0, 1) : texture(Sampler0, texCoord0);

#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif

    fragColor = color * unshadeBlock(vertexColor, normal) * ColorModulator;
    // fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    
    // if (shadowQuad > 0) {
    //     fragColor = vec4(packDepthClipSpaceRGB8(glPos.z / glPos.w), 1.0);
    // }
}
#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:bilinear.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D PreviousSampler;

uniform vec2 InSize;

flat in mat4 invProjViewMat;
flat in mat4 prevProjViewMat;
flat in vec3 viewOffset;
flat in int isShadowMap;
flat in int frame;
in vec2 texCoord;

out vec4 fragColor;

void main() {
    if (isShadowMap > 0) {
        fragColor = texelFetch(PreviousSampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    if (overlayTemporal(gl_FragCoord.xy, fragColor, (frame + 1) % 5)) {
        return;
    }

    if (int(gl_FragCoord.y) == 0) {
        fragColor = texelFetch(InSampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    fragColor = texture(InSampler, texCoord);

    float depth = texture(DepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }

    vec3 worldSpace = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    vec3 screenSpace = projectAndDivide(prevProjViewMat, worldSpace - viewOffset) * 0.5 + 0.5;

    if (clamp(screenSpace.xy, 1.0 / InSize, 1.0 - 1.0 / InSize) != screenSpace.xy) {
        return;
    }

    vec3 previousSample = textureBilinear(PreviousSampler, InSize, screenSpace.xy).rgb;
    vec3 mixedSample = mix(previousSample, fragColor.rgb, 0.2);
    fragColor = vec4(mixedSample.rgb, fragColor.a);
}
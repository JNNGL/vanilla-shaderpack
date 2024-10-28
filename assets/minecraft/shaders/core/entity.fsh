#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:srgb.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec4 vertexColor;
in vec4 vanillaLighting;
in vec4 lightMapColor;
in vec4 overlayColor;
in vec2 texCoord0;
in float isGUI;
in float isHand;
flat in ivec2 atlasDim;
in vec3 handDiffuse;

out vec4 fragColor;

void main() {
    if (discardSunData(gl_FragCoord.xy)) {
        discard;
    }

    if (isGUI > 0.0) {
        vec4 color = texture(Sampler0, texCoord0, -4);
        if (color.a < 1.0 && color.a >= 5.0 / 255.0) {
            ivec4 coord = ivec4(color * 255.0);
            int subX = coord.x & 0xF;
            int subY = coord.y & 0xF;

            int index = ((coord.x & 0xF0) | (coord.y >> 4)) * 256 + coord.z;
            int baseX = (index * 16) % atlasDim.x;
            int baseY = ((index * 16) / atlasDim.x) * 16;

            ivec2 texCoord = ivec2(baseX + subX, baseY + subY);
            fragColor = texelFetch(Sampler0, texCoord, 0);
        } else {
            fragColor = texture(Sampler0, texCoord0);
        }

#ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
#endif

        if (isHand > 0.0) {
            fragColor *= vertexColor;
            fragColor.rgb = srgbToLinear(fragColor.rgb);

            vec3 color = handDiffuse * fragColor.rgb;
            color = acesFitted(color);
            color = linearToSrgb(color);

            fragColor.rgb = color;
        } else {
            fragColor *= vanillaLighting;
        }
        return;
    }

    vec4 color = texture(Sampler0, texCoord0);
#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif
    color *= ColorModulator;
#ifndef NO_OVERLAY
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
#endif
    fragColor = color;
}

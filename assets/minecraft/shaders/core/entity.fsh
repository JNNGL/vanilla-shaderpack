#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:srgb.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <settings:settings.glsl>

#extension GL_ARB_texture_query_lod : require

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
in vec2 lmCoord;
in vec3 fragPos;
flat in int quadId;
flat in int isPBR;

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

    vec3 p1 = dFdx(fragPos);
    vec3 p2 = dFdy(fragPos);
    vec2 t1 = dFdx(texCoord0);
    vec2 t2 = dFdy(texCoord0);

    vec3 normal = normalize(cross(p1, p2));

    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;
    
    #if (ENABLE_DIRECTIONAL_LIGHTMAP == yes)
    vec2 lmDeriv = vec2(dFdx(lmCoord.x), dFdy(lmCoord.x));

    vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    vec3 lmDirection = dot(lmDeriv, lmDeriv) < 0.00001 ? vec3(0.0) : normalize(cross(p2, normal) * lmDeriv.x + cross(normal, p1) * lmDeriv.y) * tbn;
    
    lmDirection = sign(lmDirection) * vec3(greaterThan(abs(lmDirection), vec3(0.001))) + 1;
    uint lmPacked = uint(lmDirection.x) | (uint(lmDirection.y) << 2u);
#endif // ENABLE_DIRECTIONAL_LIGHTMAP

    int mipLevel = int(textureQueryLOD(Sampler0, texCoord0).x);

    vec4 color = texture(Sampler0, texCoord0);
    #ifdef ALPHA_CUTOUT
        if (color.a < ALPHA_CUTOUT) {
            discard;
        }
    #endif

    float lodAlpha = texelFetch(Sampler0, ivec2(texCoord0 * textureSize(Sampler0, 0)), 0).a;
    int textureAlpha = int(round(color.a * 255.0));
    if (isPBR > 0 && textureAlpha >= 5 && textureAlpha <= 250 && lodAlpha < 1.0 && lodAlpha >= 5.0 / 255.0) {
        color = textureLod(Sampler0, texCoord0, 0);
        vec3 tangent = normalize(cross(p2, normal) * t1.x + cross(normal, p1) * t2.x);

        fragColor = color;

        int powMip = int(round(pow(2.0, mipLevel)));
        int subX = (int(color.r * 255.0) / powMip) & 3;
        int subY = (int(color.g * 255.0) / powMip) & 3;
        int quadAlpha = quadId % 15;
        int alpha = (quadAlpha << 4) | (subX << 2) | subY;

        if (local == ivec2(0, 0)) {
            fragColor = vec4(vec2(lmCoord) / 255.0, encodeDirectionToF8(tangent), 1.0);
        } else if (local == ivec2(1, 1)) {
            vec3 fragmentColor = vertexColor.rgb;
#ifndef NO_OVERLAY
            fragmentColor.rgb = mix(overlayColor.rgb, fragmentColor.rgb, overlayColor.a);
#endif
#if (ENABLE_DIRECTIONAL_LIGHTMAP == yes)
            fragColor.rgb = encodeYCoCg776(fragmentColor, lmPacked);
#else
            fragColor.rgb = fragmentColor;
#endif // ENABLE_DIRECTIONAL_LIGHTMAP
        } else {
            alpha = (quadAlpha << 4) | mipLevel;
        }

        fragColor.a = float(alpha) / 255.0;
    } else {
        if (local == ivec2(0, 0)) {
            fragColor = vec4(vec2(lmCoord) / 255.0, 1.0, 1.0);
        } else {
            color *= ColorModulator;
#ifndef NO_OVERLAY
            color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
#endif
            fragColor = color;
        }
    }
}

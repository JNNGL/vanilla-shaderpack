#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <settings:settings.glsl>

#extension GL_ARB_texture_query_lod : require

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
flat in int quadId;
in vec2 lmCoord;
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
    
    if (dataQuad > 0) {
        ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
        if (discardDataMarker(pixel)) {
            discard;
        }

        fragColor = writeDataMarker(pixel, ProjMat, FogStart, FogEnd, ModelOffset, GameTime, shadow > 0, mat3(ModelViewMat), skyFactor);
        return;
    }

    vec4 color = shadow > 0 ? texture(Sampler0, texCoord0, 1) : texture(Sampler0, texCoord0);

    vec3 p1 = dFdx(fragPos);
    vec3 p2 = dFdy(fragPos);
    vec2 t1 = dFdx(texCoord0);
    vec2 t2 = dFdy(texCoord0);

    vec3 normal = normalize(cross(p1, p2));

#if (ENABLE_DIRECTIONAL_LIGHTMAP == yes)
    vec2 lmDeriv = vec2(dFdx(lmCoord.x), dFdy(lmCoord.x));

    vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    vec3 lmDirection = dot(lmDeriv, lmDeriv) < 0.00001 ? vec3(0.0) : normalize(cross(p2, normal) * lmDeriv.x + cross(normal, p1) * lmDeriv.y) * tbn;
    
    lmDirection = sign(lmDirection) * vec3(greaterThan(abs(lmDirection), vec3(0.001))) + 1;
    uint lmPacked = uint(lmDirection.x) | (uint(lmDirection.y) << 2u);
#endif // ENABLE_DIRECTIONAL_LIGHTMAP

    int mipLevel = clamp(int(textureQueryLOD(Sampler0, texCoord0).x), 0, 4);

#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif

    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;

    float lodAlpha = texelFetch(Sampler0, ivec2(texCoord0 * textureSize(Sampler0, 0)), 0).a;
    int textureAlpha = int(round(color.a * 255.0));
    if (textureAlpha >= 5 && textureAlpha <= 250 && lodAlpha < 1.0 && lodAlpha >= 5.0 / 255.0) {
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
            vec3 fragmentColor = unshadeBlock(vertexColor, normal).rgb;
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
        if (local == ivec2(0, 0) && color != vec4(0.0, 0.0, 0.0, 1.0)) {
            fragColor = vec4(vec2(lmCoord) / 255.0, encodeDirectionToF8(tangent), float(15 << 4) / 255.0);
        } else {
            fragColor = color * unshadeBlock(vertexColor, normal) * ColorModulator;
            fragColor.a = 1.0;
        }
    }

    // fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    
    // if (shadowQuad > 0) {
    //     fragColor = vec4(packDepthClipSpaceRGB8(glPos.z / glPos.w), 1.0);
    // }
}
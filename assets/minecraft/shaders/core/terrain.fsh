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

float sampleHeightmap(vec2 texCoord, vec4 texMinMax) {
    texCoord = fract(texCoord) * (texMinMax.zw - texMinMax.xy) + texMinMax.xy;
    vec4 color = texture(Sampler0, texCoord, 0);

    ivec4 coord = ivec4(color * 255.0);
    int subX = coord.x & 0xF;
    int subY = coord.y & 0xF;

    int index = ((coord.x & 0xF0) | (coord.y >> 4)) * 256 + coord.z;
    int baseX = (index * 16) % atlasDim.x;
    int baseY = ((index * 16) / atlasDim.x) * 16;

    ivec2 atlasCoord = ivec2(baseX + subX, baseY + subY);
    return 1.0 - texelFetch(Sampler0, atlasCoord, 0).a;
}

vec2 parallaxMapping(vec2 texCoords, vec3 viewDir, vec4 texMinMax, out float distance) {
    const float minLayers = 256;
    const float maxLayers = 256;
    float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0.0, 0.0, 1.0), viewDir)));  
    float layerDepth = 1.0 / numLayers;
    float currentLayerDepth = 0.0;
    vec2 P = viewDir.xy / viewDir.z * 0.25; 
    vec2 deltaTexCoords = P / numLayers;
  
    vec2  currentTexCoords     = texCoords;
    float currentDepthMapValue = sampleHeightmap(currentTexCoords, texMinMax);
    
    for (int i = 0; i < numLayers && currentLayerDepth < currentDepthMapValue; i++) {
        currentTexCoords -= deltaTexCoords;
        currentDepthMapValue = sampleHeightmap(currentTexCoords, texMinMax);
        currentLayerDepth += layerDepth;  
    }

    distance = currentLayerDepth;
    
    return fract(currentTexCoords);
}

void main() {
    gl_FragDepth = gl_FragCoord.z;

    if (discardSunData(gl_FragCoord.xy)) {
        discard;
    }
    
    if (dataQuad > 0) {
        ivec2 pixel = ivec2(floor(gl_FragCoord.xy));
        if (discardDataMarker(pixel)) {
            discard;
        }

        fragColor = writeDataMarker(pixel, jitteredProj, FogStart, FogEnd, ModelOffset, GameTime, shadow > 0, mat3(ModelViewMat), skyFactor, ProjMat[2].xy, FogColor.rgb);
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

    vec3 lmTangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 lmBitangent = cross(normal, lmTangent);
    mat3 lmTbn = mat3(lmTangent, lmBitangent, normal);

    vec3 lmDirection = dot(lmDeriv, lmDeriv) < 0.00001 ? vec3(0.0) : normalize(cross(p2, normal) * lmDeriv.x + cross(normal, p1) * lmDeriv.y) * lmTbn;
    
    lmDirection = sign(lmDirection) * vec3(greaterThan(abs(lmDirection), vec3(0.001))) + 1;
    uint lmPacked = uint(lmDirection.x) | (uint(lmDirection.y) << 2u);
#endif // ENABLE_DIRECTIONAL_LIGHTMAP

    int mipLevel = clamp(int(textureQueryLOD(Sampler0, texCoord0).x), 0, 4);

    // if (isSphere > 0.5) {
    //     vec4 near = getPointOnNearPlane(invProjView, glPos.xy / glPos.w);
    //     vec4 far = getPointOnFarPlane(invProjView, glPos.xy / glPos.w);

    //     vec3 origin = near.xyz / near.w;
    //     vec3 direction = normalize(far.xyz / far.w - origin);

    //     vec3 center = mix(corner0.xyz / corner0.w, corner1.xyz / corner1.w, 0.5) + ModelOffset;
    //     if (shadow > 0) center -= fract(ModelOffset);
    //     center -= normalize(normal.xyz) * 0.5;

    //     vec2 t0t1 = raySphereIntersection(origin - center, direction, 0.5);
    //     float t = t0t1.x < 0.0 ? t0t1.y : t0t1.x;
    //     if (t < 0.0) discard;

    //     vec3 it = origin + direction * t;
    //     vec4 clip = projView * vec4(it, 1.0);
    //     gl_FragDepth = (clip.z / clip.w) * 0.5 + 0.5;
    // }

#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif

    ivec2 fragCoord = ivec2(gl_FragCoord.xy);
    ivec2 local = fragCoord % 2;

    vec3 tangent = normalize(cross(p2, normal) * t1.x + cross(normal, p1) * t2.x);

    float lodAlpha = texelFetch(Sampler0, ivec2(texCoord0 * textureSize(Sampler0, 0)), 0).a;
    int textureAlpha = int(round(color.a * 255.0));
    if (textureAlpha >= 5 && textureAlpha <= 250 && lodAlpha < 1.0 && lodAlpha >= 5.0 / 255.0) {
        vec2 mappedTexCoord = texCoord0;
        // if (shadow == 0) {
        //     vec2 bound0 = texBound0.xy / texBound0.z;
        //     vec2 bound1 = texBound1.xy / texBound1.z;
        //     vec2 texMin = min(bound0, bound1);
        //     vec2 texMax = max(bound0, bound1);
        //     vec2 texLocal = (texCoord0 - texMin) / (texMax - texMin);

        //     mat3 tbn = mat3(tangent, cross(tangent, normal), normal);

        //     vec3 fragPosTangent = fragPos * tbn;
        //     vec3 viewDirTangent = normalize(fragPosTangent);

        //     float pomDistance;
        //     texLocal = parallaxMapping(texLocal, viewDirTangent, vec4(texMin, texMax), pomDistance);
        //     mappedTexCoord = texLocal * (texMax - texMin) + texMin;

        //     // float depth = linearizeDepth(gl_FragCoord.z * 2.0 - 1.0, planes);
        //     // depth += pomDistance * 0.25;
        //     // gl_FragDepth = unlinearizeDepth(depth, planes) * 0.5 + 0.5;
        // }

        color = textureLod(Sampler0, mappedTexCoord, 0);

        fragColor = color;

        int powMip = int(round(pow(2.0, mipLevel)));
        int subX = (int(color.r * 255.0) / powMip) & 3;
        int subY = (int(color.g * 255.0) / powMip) & 3;
        int quadAlpha = quadId % 15;
        int alpha = (quadAlpha << 4) | (subX << 2) | subY;

        if (local == ivec2(0, 0)) {
            fragColor = vec4(vec2(lmCoord) / 255.0, encodeDirectionToF8(tangent), 1.0);
            // if (isSphere > 0.5) fragColor.xy = vec2(0.0, 1.0);
        } else if (local == ivec2(1, 1)) {
            vec3 fragmentColor = clamp(unshadeBlock(vertexColor, normal).rgb, 0.0, 1.0);
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
}
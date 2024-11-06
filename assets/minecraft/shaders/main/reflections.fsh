#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:matrices.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:ssrt.glsl>
#moj_import <minecraft:metals.glsl>
#moj_import <minecraft:fresnel.glsl>
#moj_import <minecraft:brdf.glsl>
#moj_import <minecraft:srgb.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D AlbedoSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SpecularSampler;
uniform sampler2D SkySampler;
uniform sampler2D NoiseSampler;
uniform sampler2D LightmapSampler;

uniform mat4 ModelViewMat;
uniform vec2 InSize;

in vec2 texCoord;
flat in vec3 sunDirection;
flat in mat4 projection;
flat in mat4 invProjViewMat;
flat in vec2 planes;
flat in int shouldUpdate;
flat in float seed;
in vec4 near;

out vec4 fragColor;

void main() {
    float depth = texture(DepthSampler, texCoord).r;
    if (shouldUpdate == 0 || depth == 1.0) {
        return;
    }

    fragColor = encodeLogLuv(vec3(0.0));

#if (ENABLE_BLOCK_REFLECTIONS == yes)
    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    
    vec3 pointOnNearPlane = near.xyz / near.w;
    vec3 direction = normalize(fragPos - pointOnNearPlane);

    vec4 normalData = texture(NormalSampler, texCoord);
    vec3 normal = decodeDirectionFromF8x2(normalData.rg);

    vec4 specularData = texture(SpecularSampler, texCoord);
    float roughness = pow(1.0 - specularData.r, 2.0);
    if (roughness == 1.0) return;

    vec3 albedo = srgbToLinear(texture(AlbedoSampler, texCoord).rgb);
    int metalId = int(round(specularData.g * 255.0));

    vec3 rand = random(NoiseSampler, gl_FragCoord.xy, seed);

    mat3 tbn = constructTBN(normal);    

    vec3 N = normal;
    vec3 V = -direction;

    vec3 V_tangentSpace = V * tbn;
    vec3 H = tbn * sampleGGXVNDF(V_tangentSpace, roughness, rand.xy);
    vec3 L = reflect(-V, H);

    vec3 fragPosViewSpace = mat3(ModelViewMat) * (fragPos + normal * 0.025);
    vec3 L_viewSpace = mat3(ModelViewMat) * L;

    vec2 lightLevel = texture(LightmapSampler, texCoord).rg;
    vec3 radiance = sampleSkyLUT(SkySampler, L, sunDirection) * sunIntensity * LIGHT_COLOR_MULTIPLIER * lightLevel.y;

    vec2 strideSteps = roughness < 0.2 ? vec2(SMOOTH_BLOCK_REFLECTION_STRIDE, SMOOTH_BLOCK_REFLECTION_STEPS) : vec2(ROUGH_BLOCK_REFLECTION_STRIDE, ROUGH_BLOCK_REFLECTION_STEPS);

    vec2 hitPixel;
    vec3 hitPoint;
    bool hit = traceScreenSpaceRay(DepthSampler, projection, planes, InSize, fragPosViewSpace, L_viewSpace, strideSteps.x, rand.z, strideSteps.y, 1.0e6, hitPixel, hitPoint);
    float hitDepth = texelFetch(DepthSampler, ivec2(hitPixel), 0).r;
    if (hit && hitDepth != 1.0) {
        vec2 hitTexCoord = hitPixel / InSize;
        radiance = decodeLogLuv(texture(InSampler, hitTexCoord));
    }

    float G1 = SmithGGXMasking(N, V, roughness);
    float G2 = SmithGGXMaskingShadowing(N, V, L, roughness);

    vec3 F = fresnel(metalId, dot(H, V), albedo, vec3(specularData.g));
    vec3 specular = radiance * F * (G2 / G1);

    fragColor = encodeLogLuv(specular);
#endif // ENABLE_BLOCK_REFLECTIONS
}
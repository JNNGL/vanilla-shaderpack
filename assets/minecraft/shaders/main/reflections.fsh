#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:matrices.glsl>
#moj_import <minecraft:normals.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:ssrt.glsl>
#moj_import <minecraft:brdf.glsl>
#moj_import <minecraft:fresnel.glsl>
#moj_import <minecraft:metals.glsl>
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
flat in float timeSeed;
in vec4 near;

out vec4 fragColor;

void main() {
    if (shouldUpdate == 0) {
        return;
    }

    fragColor = encodeLogLuv(vec3(0.0));

    float depth = texture(DepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }

    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    
    vec3 pointOnNearPlane = near.xyz / near.w;
    vec3 direction = normalize(fragPos - pointOnNearPlane);

    vec4 normalData = texture(NormalSampler, texCoord);
    vec3 normal = decodeDirectionFromF8x2(normalData.rg);

    vec4 specularData = texture(SpecularSampler, texCoord);
    float roughness = pow(1.0 - specularData.r, 2.0);

    vec3 albedo = srgbToLinear(texture(AlbedoSampler, texCoord).rgb);
    int metalId = int(round(specularData.g * 255.0));

    vec3 rand = random(NoiseSampler, gl_FragCoord.xy, timeSeed);

    mat3 tbn = constructTBN(normal);    

    vec3 N = normalize(round(normal * 16.0) / 16.0);
    vec3 V = -direction;

    vec3 V_tangent = V * tbn;
    vec3 H = tbn * sampleGGXVNDF(V_tangent, roughness, rand.xy);
    vec3 L = reflect(-V, H);

    vec3 fragPosViewSpace = mat3(ModelViewMat) * fragPos;
    vec3 L_viewSpace = mat3(ModelViewMat) * L;

    vec2 lightLevel = texture(LightmapSampler, texCoord).rg;
    vec3 radiance = sampleSkyLUT(SkySampler, L, sunDirection) * sunIntensity * LIGHT_COLOR_MULTIPLIER * lightLevel.y * 0.75;

    vec2 hitPixel;
    vec3 hitPoint;
    bool hit = traceScreenSpaceRay(DepthSampler, projection, planes, InSize, fragPosViewSpace, L_viewSpace, 30.0, rand.z, 32.0, 1.0e6, hitPixel, hitPoint);
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
}
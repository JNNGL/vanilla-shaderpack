#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:normals.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:ssrt.glsl>
#moj_import <minecraft:brdf.glsl>
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

uniform mat4 ModelViewMat;
uniform vec2 InSize;

in vec2 texCoord;
flat in vec3 sunDirection;
flat in mat4 projection;
flat in mat4 invProjection;
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

    float depth = texture(DepthSampler, texCoord).r;
    if (depth == 1.0) {
        fragColor = encodeLogLuv(vec3(0.0));
        return;
    }

    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    
    vec3 pointOnNearPlane = near.xyz / near.w;
    vec3 direction = normalize(fragPos - pointOnNearPlane);

    vec4 normalData = texture(NormalSampler, texCoord);
    vec3 normal = decodeDirectionFromF8x2(normalData.rg);

    vec4 specularData = texture(SpecularSampler, texCoord);
    float roughness = pow(1.0 - specularData.r, 1.3);
    roughness *= roughness;

    vec3 N = normalize(round(normal * 16.0) / 16.0);
    vec3 V = -direction;

    vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    vec3 V_t = V * tbn;

    vec3 specular = vec3(0.0);
    float wSpecSum = 0.0;

    vec3 albedo = srgbToLinear(texture(AlbedoSampler, texCoord).rgb);
    int metalId = int(round(specularData.g * 255.0));

    vec3 viewFragPos = mat3(ModelViewMat) * fragPos;

    float G1 = SmithGGXMasking(N, V, roughness);
    for (int i = 0; i < 2; i++) {
        vec3 rand = random(NoiseSampler, gl_FragCoord.xy, i + timeSeed);

        vec3 R_H = tbn * sampleGGXVNDF(V_t, roughness, rand.xy);
        vec3 R_L = reflect(-V, R_H);

        vec3 R_radiance = sampleSkyLUT(SkySampler, R_L, sunDirection) * sunIntensity * LIGHT_COLOR_MULTIPLIER * 0.75;

        vec2 hitPixel;
        vec3 hitPoint;
        bool hit = traceScreenSpaceRay(DepthSampler, projection, planes, InSize, viewFragPos, mat3(ModelViewMat) * R_L, 30.0, rand.z, 32.0, 1.0e6, hitPixel, hitPoint);
        float hitDepth = texelFetch(DepthSampler, ivec2(hitPixel), 0).r;
        if (hit && hitDepth != 1.0) {
            vec2 hitTexCoord = hitPixel / InSize;
            vec3 screenSpaceReflection = decodeLogLuv(texture(InSampler, hitTexCoord));
            
            R_radiance = screenSpaceReflection;
        }

        vec3 R_F;
        if (metalId >= 230 && metalId <= 237) {
            mat2x3 NK = HARDCODED_METALS[metalId - 230];
            R_F = fresnelConductor(max(dot(R_H, V), 0.0), NK[0], NK[1]);
        } else {
            vec3 F0 = metalId > 237 ? albedo : vec3(specularData.g);
            R_F = fresnelSchlick(max(dot(R_H, V), 0.0), F0);
        }

        float G2 = SmithGGXMaskingShadowing(N, V, R_L, roughness);

        specular += R_radiance * R_F * (G2 / G1);
        wSpecSum += 1.0;
    }

    specular /= wSpecSum;
    fragColor = encodeLogLuv(specular);
}
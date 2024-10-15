#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:encodings.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:random.glsl>

uniform sampler2D DataSampler;
uniform sampler2D DepthSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D NormalSampler;
uniform sampler2D NoiseSampler;

uniform mat4 ModelViewMat;
uniform vec2 DataSize;

in vec2 texCoord;
flat in mat4 projection;
flat in mat4 invProjection;
flat in mat4 invViewProjMat;
flat in vec3 offset;
flat in mat4 shadowProjMat;
flat in vec3 lightDir;
flat in float timeSeed;
flat in int shouldUpdate;
flat in vec2 planes;
in vec4 near;

out vec4 fragColor;

vec3 projectShadowMap(mat4 lightProj, vec3 position, vec3 normal) {
    vec4 lightSpace = lightProj * vec4(position, 1.0);

    float bias;
    lightSpace = distortShadow(lightSpace, bias);
    lightSpace.xyz += (lightProj * vec4(normal, 1.0)).xyz * bias;

    vec3 projLightSpace = lightSpace.xyz * 0.5 + 0.5;
    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackF32fromF8x4(texture(ShadowMapSampler, projLightSpace.xy));
        return vec3(projLightSpace.z, closestDepth, bias);
    }

    return vec3(-1.0, -1.0, 0.0);
}

bool checkOcclusion(vec3 projection, vec3 lightDir, vec3 normal) {
    float NdotL = dot(normal, lightDir);
    return projection.x - projection.z / (abs(NdotL) * 0.1) > projection.y;
}

float estimateShadowContribution(mat4 lightProj, vec3 lightDir, vec3 fragPos, vec3 normal) {
    float filterSize = length(fragPos) * 0.07 + 1.0;

    vec3 tangent = normalize(cross(lightDir, normal)) * filterSize * 1.0;
    vec3 bitangent = normalize(cross(tangent, normal)) * filterSize * 2.0;

    float contribution = 0.0;
    float totalWeight = 0.0;

    float occluderDistance = 0.0;

    for (int i = 0; i < 6; i++) {
        float seed = (-i - 1) * 5 - timeSeed;
        vec2 offset = randomPointOnDisk(NoiseSampler, gl_FragCoord.xy, seed);
        vec3 jitter = offset.x * tangent + offset.y * bitangent * 1.5;

        vec3 projection = projectShadowMap(lightProj, fragPos + jitter * 0.1, normal);
        if (checkOcclusion(projection, lightDir, normal)) {
            occluderDistance += projection.y;
            contribution += 1.0;
        }

        totalWeight += 1.0;
    }

    if (contribution == totalWeight || contribution == 0.0) {
        return sign(contribution);
    }

    occluderDistance /= contribution;
    float receiverDistance = (lightProj * vec4(fragPos, 1.0)).z * 0.5 + 0.5;
    float penumbra = clamp(0.02 + 1.5 * ((receiverDistance - occluderDistance) / occluderDistance), 0.0, 0.1);

    float contributionWeight = pow(penumbra * 10.0, 2.0);
    contribution *= contributionWeight;
    totalWeight *= contributionWeight;

    for (int i = 0; i < 8; i++) {
        float seed = i * 5 + timeSeed;
        vec2 diskPoint = randomPointOnDisk(NoiseSampler, gl_FragCoord.xy, seed);
        vec3 jitter = (tangent * diskPoint.x + bitangent * diskPoint.y) * penumbra + bitangent * diskPoint.y * 0.03;

        if (checkOcclusion(projectShadowMap(lightProj, fragPos + jitter, normal), lightDir, normal)) {
            contribution += 1.0;
        }

        totalWeight += 1.0;
    }

    return contribution / totalWeight;
}

float estimateAmbientOcclusion(vec3 fragPos, vec3 normal) {
    const vec3 sampleVectors[] = vec3[](
        vec3(0.20784318, -0.23137254, 0.3019608), vec3(0.427451, 0.27843142, 0.60784316), 
        vec3(-0.16862744, 0.28627455, 0.18431373), vec3(0.3803922, 0.082352996, 0.27058825), 
        vec3(-0.29411763, 0.07450986, 0.043137256), vec3(-0.035294116, -0.18431371, 0.12156863), 
        vec3(0.13725495, 0.30196083, 0.16862746), vec3(-0.0039215684, -0.0039215684, 0.003921569),
        vec3(-0.27843136, 0.27058828, 0.007843138), vec3(-0.4588235, 0.12941182, 0.02745098), 
        vec3(-0.19215685, -0.0745098, 0.4), vec3(-0.019607842, 0.035294175, 0.003921569),
        vec3(0.06666672, 0.19215691, 0.4862745), vec3(0.019607902, 0.09803927, 0.38039216), 
        vec3(0.035294175, -0.0039215684, 0.0627451), vec3(0.019607902, -0.082352936, 0.06666667)
    );

    fragPos = mat3(ModelViewMat) * fragPos;
    normal = mat3(ModelViewMat) * normal;

    vec3 rnd = random(NoiseSampler, gl_FragCoord.xy, timeSeed);
    vec3 rndVec = vec3(rnd.xy * 2.0 - 1.0, 0.0);
    vec3 tangent = normalize(rndVec - normal);
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    const int samples = 16;

    float markerCutoff = 1.5 / DataSize.y;

    float occlusion = 0.0;
    for (int i = 0; i < samples; i++) {
        vec3 sample = sampleVectors[i] * 2.0;

        vec3 pos = tbn * sample;
        pos = fragPos + pos;

        vec4 offset = projection * vec4(pos, 1.0);
        offset = offset / offset.w * 0.5 + 0.5;
        offset.y = max(offset.y, markerCutoff);

        float z = texture(DepthSampler, offset.xy).r;
        if (z == 1.0) {
            continue;
        }

        float currentDepth = unprojectScreenSpace(invProjection, offset.xy, z).z;

        float dist = smoothstep(0.0, 1.0, 1.0 / abs(fragPos.z - currentDepth));
        occlusion += (currentDepth >= pos.z + 0.05 ? 1.0 : 0.0) * dist;
    }

    occlusion = 1.0 - (occlusion / float(samples));
    return occlusion;
}

float estimateVolumetricShadowing(mat4 lightProj, float rayLength, vec3 rayDirection, vec3 rayOrigin, vec3 normal, vec3 lightDir) {
    const int NUM_STEPS = 16;

    float rayStep = rayLength / NUM_STEPS;
    vec3 rayPos = rayOrigin + rayDirection * rayStep * random(NoiseSampler, gl_FragCoord.xy, timeSeed).x - offset;
    float accum = 0.0;

    for (int i = 0; i < NUM_STEPS; i++) {
        vec3 projection = projectShadowMap(lightProj, rayPos, normal);
        accum += checkOcclusion(projection, lightDir, normal) ? 0.0 : 1.0;
        rayPos += rayDirection * rayStep;
    }
    
    accum /= float(NUM_STEPS);
    return accum;
}

void main() {
    if (shouldUpdate == 0) {
        return;
    }

    if (int(gl_FragCoord.y) == 0) {
        fragColor = texture(DataSampler, texCoord);
        return;
    }

    float depth = texture(DepthSampler, texCoord).r;
    float translucentDepth = texture(TranslucentDepthSampler, texCoord).r;

    vec3 fragPos = unprojectScreenSpace(invViewProjMat, texCoord, depth);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;

    vec3 rayOrigin = near.xyz / near.w;
    vec3 rayDirection = normalize(fragPos - rayOrigin);

    fragColor = vec4(0.0, 1.0, 1.0, 0.0);
    if (translucentDepth == 1.0) {
        return;
    }

    float nearestDepth = min(translucentDepth, depth);
    float volumeDistance = linearizeDepth(nearestDepth * 2.0 - 1.0, planes) - planes.x;
    float volumetricShadow = estimateVolumetricShadowing(shadowProjMat, volumeDistance, rayDirection, rayOrigin, normal, lightDir);
    fragColor.a = volumetricShadow;
    
    if (depth == 1.0) {
        return;
    }

    float shadow = 0.0;
    float subsurface = 1.0;
    if (dot(lightDir, normal) < -0.01) {
        shadow = 0.0;

        vec3 rnd = random(NoiseSampler, gl_FragCoord.xy, timeSeed);
        vec3 rndVec = vec3(rnd.xy * 2.0 - 1.0, 0.0);
        vec3 tangent = normalize(rndVec - normal);
        vec3 bitangent = cross(normal, tangent);
        mat3 tbn = mat3(tangent, bitangent, normal);

        float occlusionDistance = 1024.0;
        for (int i = 0; i < 10; i++) {
            vec3 jitter = tbn * vec3(random(NoiseSampler, gl_FragCoord.xy, i * 5 + timeSeed).xy * 2.0 - 1.0, 0.0);
            vec3 projection = projectShadowMap(shadowProjMat, fragPos - offset + jitter * 0.15, normal);
            if (projection.y - 0.005 < projection.x) {
                float currentDistance = (projection.x - projection.y) / projection.x;
                occlusionDistance = max(0.0, min(occlusionDistance, currentDistance));
            }
        }

        float sz = occlusionDistance * 768.0;
        subsurface = 0.25 * (exp(-sz) + 3.0 * exp(-sz / 3.0));
    } else {
        shadow = estimateShadowContribution(shadowProjMat, lightDir, fragPos - offset, normal);
    }

    float ambientOcclusion = estimateAmbientOcclusion(fragPos, normal);

    fragColor = vec4(shadow, ambientOcclusion, subsurface, volumetricShadow);
}
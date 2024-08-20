#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D NormalSampler;
uniform sampler2D NoiseSampler;

uniform vec2 InSize;

in vec2 texCoord;
flat in mat4 invProjection;
flat in mat4 projection;
flat in mat3 viewMat;
flat in mat4 viewProj;
flat in mat4 invViewProj;
flat in vec3 offset;
flat in vec3 shadowEye;
flat in float time;
in vec4 near;

out vec4 fragColor;

vec3 getWorldSpacePosition(vec2 uv, float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProj * positionClip;
    return positionWorld.xyz / positionWorld.w;
}

vec3 getViewSpacePosition(vec2 uv, float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionView = invProjection * positionClip;
    return positionView.xyz / positionView.w;
}

vec3 getViewSpacePosition(vec2 uv) {
    return getViewSpacePosition(uv, texture(DiffuseDepthSampler, uv).r);
}

mat4 orthographicProjectionMatrix(float left, float right, float bottom, float top, float near, float far) {
    return mat4(
        2.0 / (right - left), 0.0, 0.0, 0.0,
        0.0, 2.0 / (top - bottom), 0.0, 0.0,
        0.0, 0.0, -2.0 / (far - near), 0.0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0
    );
}

mat4 lookAtTransformationMatrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 u = normalize(up);
    vec3 s = normalize(cross(f, u));
    u = cross(s, f);

    mat4 result = mat4(1.0);
    result[0][0] = s.x;
    result[1][0] = s.y;
    result[2][0] = s.z;
    result[0][1] = u.x;
    result[1][1] = u.y;
    result[2][1] = u.z;
    result[0][2] = -f.x;
    result[1][2] = -f.y;
    result[2][2] = -f.z;
    result[3][0] = -dot(s, eye);
    result[3][1] = -dot(u, eye);
    result[3][2] = dot(f, eye);
    return result;
}

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

vec3 random(float v) {
    ivec2 coord = ivec2(mod(gl_FragCoord.xy + vec2(0.75487762, 0.56984027) * 512 * v, 512));
    return texelFetch(NoiseSampler, coord, 0).xyz;
}

vec2 randomPointOnDisk(float seed) {
    vec3 rand = random(seed);
    float angle = rand.y * 2.0 * 3.1415926535;
    float sr = sqrt(rand.x);
    return vec2(sr * cos(angle), sr * sin(angle));
}

vec3 projectShadowMap(mat4 lightProj, vec3 position, vec3 normal) {
    vec4 lightSpace = lightProj * vec4(position, 1.0);
    
    float distortionFactor = length(lightSpace.xy) + 0.1;
    float numerator = distortionFactor * distortionFactor;
    float bias = 1.5 / 1024.0 * numerator / 0.1;

    lightSpace.xy /= distortionFactor;
    lightSpace.xyz += (lightProj * vec4(normal, 1.0)).xyz * bias;

    vec3 projLightSpace = lightSpace.xyz * 0.5 + 0.5;

    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackDepth(texture(ShadowMapSampler, projLightSpace.xy));
        return vec3(projLightSpace.z, closestDepth, bias);
        // return vec3(projLightSpace.z, closestDepth, 0.00135);
    }

    return vec3(-1.0, -1.0, 0.0);
}

bool checkOcclusion(vec3 projection, vec3 lightDir, vec3 normal) {
    float NdotL = dot(normal, lightDir);
    return projection.x - projection.z / (abs(NdotL) * 0.3) > projection.y;   
}

float estimateShadowContribution(mat4 lightProj, vec3 lightDir, vec3 fragPos, vec3 normal) {
    float filterSize = length(fragPos) * 0.07;
    filterSize = 1.0 + filterSize;
    // float filterSize = 1.7;

    vec3 tangent = normalize(cross(lightDir, normal)) * filterSize * 1.0;
    vec3 bitangent = normalize(cross(tangent, normal)) * filterSize * 2.0;

    float contribution = 0.0;
    float totalWeight = 0.0;

    float occluderDistance = 0.0;

    for (int i = 0; i < 6; i++) {
        float seed = (-i - 1) * 5 - time;
        vec2 offset = randomPointOnDisk(seed);
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
        float seed = i * 5 + time;
        vec2 diskPoint = randomPointOnDisk(seed);
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

    fragPos = viewMat * fragPos;
    normal = viewMat * normal;

    vec3 rnd = random(time);
    vec3 rndVec = vec3(rnd.xy * 2.0 - 1.0, 0.0);
    vec3 tangent = normalize(rndVec - normal);
    vec3 bitangent = cross(normal, tangent);
    mat3 tbn = mat3(tangent, bitangent, normal);

    const int samples = 16;

    float markerCutoff = 1.5 / InSize.y;

    float occlusion = 0.0;
    for (int i = 0; i < samples; i++) {
        vec3 sample = sampleVectors[i] * 2.0;

        vec3 pos = tbn * sample;
        pos = fragPos + pos;

        vec4 offset = projection * vec4(pos, 1.0);
        offset = offset / offset.w * 0.5 + 0.5;
        offset.y = max(offset.y, markerCutoff);

        float z = texture(DiffuseDepthSampler, offset.xy).r;
        if (z == 1.0) {
            continue;
        }

        float currentDepth = getViewSpacePosition(offset.xy, z).z;

        float dist = smoothstep(0.0, 1.0, 1.0 / abs(fragPos.z - currentDepth));
        occlusion += (currentDepth >= pos.z + 0.05 ? 1.0 : 0.0) * dist;
    }

    occlusion = 1.0 - (occlusion / float(samples));
    return occlusion;
}

float henyeyGreenstein(float cosTheta, float g) {
    return (1.0 - g * g) / (4.0 * 3.14159 * pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5));
}

float estimateVolumetricFogContribution(mat4 lightProj, vec3 fragPos, vec3 rayOrigin, vec3 normal, vec3 lightDir) {
    float rayLength = distance(fragPos, rayOrigin);
    vec3 rayDirection = (fragPos - rayOrigin) / rayLength;

    const int NUM_STEPS = 16;
    float rayStep = rayLength / NUM_STEPS;
    vec3 rayPos = rayOrigin + rayDirection * rayStep * random(0.0).x - offset;

    float phaseFunction = henyeyGreenstein(dot(rayDirection, lightDir), 0.3);

    float accum = 0.0;
    if (dot(normal, normal) < 0.01) {
        accum = phaseFunction * NUM_STEPS;
    } else {
        for (int i = 0; i < NUM_STEPS; i++) {
            vec3 projection = projectShadowMap(lightProj, rayPos, normal);
            float t = checkOcclusion(projection, lightDir, normal) ? 0.0 : 1.0;
            accum += phaseFunction * t;
            rayPos += rayDirection * rayStep;
        }
    }

    float d = accum * rayStep * 0.2;
    float powder = 1.0 - exp(-d * 2.0);
    float beer = exp(-d);

    return (1.0 - beer) * powder;
}

void main() {
    if (int(gl_FragCoord.y) == 0) {
        fragColor = texture(DiffuseSampler, texCoord);
        return;
    }

    float depth = texture(DiffuseDepthSampler, texCoord).r;
    
    vec3 fragPos = getWorldSpacePosition(texCoord, depth);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    
    vec3 lightDir = normalize(shadowEye);

    //mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 100.0);
    mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 64.0);
    mat4 view = lookAtTransformationMatrix(shadowEye, vec3(0.0), vec3(0.0, 1.0, 0.0));
    mat4 lightProj = proj * view;

    float volumetric = estimateVolumetricFogContribution(lightProj, fragPos, near.xyz / near.w, normal, lightDir);
    volumetric = sqrt(volumetric);
    fragColor = vec4(0.0, 1.0, 1.0, volumetric);

    if (depth == 1.0) {
        return;
    }

    float shadow = 0.0;
    float occlusionDistance = 10.0;
    if (dot(lightDir, normal) < -0.01) {
        shadow = 1.0;
        
        vec3 rnd = random(time);
        vec3 rndVec = vec3(rnd.xy * 2.0 - 1.0, 0.0);
        vec3 tangent = normalize(rndVec - normal);
        vec3 bitangent = cross(normal, tangent);
        mat3 tbn = mat3(tangent, bitangent, normal);

        for (int i = 0; i < 10; i++) {
            vec3 jitter = tbn * vec3(random(i * 5 + time).xy * 2.0 - 1.0, 0.0);
            vec3 projection = projectShadowMap(lightProj, fragPos - offset + jitter * 0.1, normal);
            if (projection.y < projection.x) {
                float currentDistance = (projection.x - projection.y) / projection.x;
                occlusionDistance = min(occlusionDistance, currentDistance);
            }
        }
    } else {
        shadow = estimateShadowContribution(lightProj, lightDir, fragPos - offset, normal);
    }

    float ambient = estimateAmbientOcclusion(fragPos, normal);

    float sz = occlusionDistance * 400.0;
    float subsurface = 0.25 * (exp(-sz) + 3 * exp(-sz / 3));
    fragColor = vec4(shadow, ambient, subsurface, volumetric);
}
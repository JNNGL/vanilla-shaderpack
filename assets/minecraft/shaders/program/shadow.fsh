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

    vec3 tangent = normalize(cross(lightDir, normal)) * filterSize * 1.2;
    vec3 bitangent = normalize(cross(tangent, normal)) * filterSize * 2.0;

    float contribution = 0.0;
    float totalWeight = 0.0;

    float occluderDistance = 0.0;

    for (int i = 0; i < 6; i++) {
        float seed = (-i - 1) * 5 - time;
        vec2 offset = randomPointOnDisk(seed);
        vec3 jitter = offset.x * tangent + offset.y * bitangent * 1.5;

        vec3 projection = projectShadowMap(lightProj, fragPos + jitter * 0.05, normal);
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
    float penumbra = clamp(0.005 + 0.5 * (receiverDistance - occluderDistance) / occluderDistance, 0.0, 0.05);

    for (int i = 0; i < 16; i++) {
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

const float aoRadius = 0.5;
const float aoRadiusSq = aoRadius * aoRadius;
const float nInvRadiusSq = - 1.0 / aoRadiusSq;
const float angleBias = 6.0;
const float tanAngleBias = tan(radians(angleBias));
const int numRays = 6;
const int numSamples = 4;
const float maxRadiusPixels = 50.0;

float tanToSin(float x) {
    return x * inversesqrt(x * x + 1.0);
}

float invLength(vec2 v) {
    return inversesqrt(dot(v, v));
}

float tangent(vec3 t) {
    return t.z * invLength(t.xy);
}

float biasedTangent(vec3 t) {
    return t.z * invLength(t.xy) + tanAngleBias;
}

float tangent(vec3 p, vec3 s) {
    return -(p.z - s.z) * invLength(s.xy - p.xy);
}

float lengthSquared(vec3 v) {
    return dot(v, v);
}

vec3 minDiff(vec3 p, vec3 pr, vec3 pl) {
    vec3 v1 = pr - p;
    vec3 v2 = p - pl;
    return (lengthSquared(v1) < lengthSquared(v2)) ? v1 : v2;
}

vec2 snapOffset(vec2 uv) {
    return round(uv * InSize) / InSize;
}

float falloff(float d2) {
    return d2 * nInvRadiusSq + 1.0f;
}

vec2 rotateDirections(vec2 dir, vec2 cosSin) {
    return vec2(dir.x * cosSin.x - dir.y * cosSin.y, dir.x * cosSin.y + dir.y * cosSin.x);
}

void computeSteps(inout vec2 stepSizeUv, inout float numSteps, float rayRadiusPix, float rand) {
    numSteps = min(numSamples, rayRadiusPix);
    float stepSizePix = rayRadiusPix / (numSteps + 1.0);
    float maxNumSteps = maxRadiusPixels / stepSizePix;
    if (maxNumSteps < numSteps) {
        numSteps = floor(maxNumSteps + rand);
        numSteps = max(numSteps, 1.0);
        stepSizePix = maxRadiusPixels / numSteps;
    }

    stepSizeUv = stepSizePix / InSize;
}

float horizonOcclusion(vec2 deltaUV, vec3 p, float numSamples, 
                       float randstep, vec3 dPdu, vec3 dPdv) {
    float ao = 0;

    vec2 uv = texCoord + snapOffset(randstep * deltaUV);
    deltaUV = snapOffset(deltaUV);

    vec3 tg = deltaUV.x * dPdu + deltaUV.y * dPdv;

    float tanH = biasedTangent(tg);
    float sinH = tanToSin(tanH);

    for (float i = 1.0; i <= numSamples; ++i) {
        uv += deltaUV;
        vec3 s = getViewSpacePosition(uv);
        float tanS = tangent(p, s);
        float d2 = lengthSquared(s - p);

        if (d2 < aoRadiusSq && tanS > tanH) {
            float sinS = tanToSin(tanS);
            ao += falloff(d2) * (sinS - sinH);

            tanH = tanS;
            sinH = sinS;
        }
    }
    
    return ao;
}

float estimateAmbientOcclusion(vec3 fragPos, vec3 normal) {
    vec3 p = getViewSpacePosition(texCoord);
    vec3 pr = getViewSpacePosition(texCoord + vec2(1, 0) / InSize);
    vec3 pl = getViewSpacePosition(texCoord + vec2(-1, 0) / InSize);
    vec3 pt = getViewSpacePosition(texCoord + vec2(0, 1) / InSize);
    vec3 pb = getViewSpacePosition(texCoord + vec2(0, -1) / InSize);

    vec3 dPdu = minDiff(p, pr, pl);
    vec3 dPdv = minDiff(p, pt, pb);

    vec3 random = random(time);

    vec2 rayRadiusUV = 0.5 * aoRadius * vec2(projection[0][0], projection[1][1]) / -p.z;
    float rayRadiusPix = rayRadiusUV.x * InSize.x;

    float ao = 1.0;

    if (rayRadiusPix > 1.0) {
        ao = 0.0;
        float numSteps;
        vec2 stepSizeUV;

        computeSteps(stepSizeUV, numSteps, rayRadiusPix, random.z);

        float alpha = 2.0 * 3.14159 / numRays;
        for (float d = 0; d < numRays; ++d) {
            float theta = alpha * d;
            vec2 dir = rotateDirections(vec2(cos(theta), sin(theta)), random.xy);
            vec2 deltaUV = dir * stepSizeUV;
            ao += horizonOcclusion(deltaUV, p, numSteps, random.z, dPdu, dPdv);
        }

        ao = 1.0 - pow(ao / numRays, 1.0 / 3.0);
    }
    
    return ao;
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

    float phaseFunction = henyeyGreenstein(dot(rayDirection, lightDir), 0.5);

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

    float sz = occlusionDistance * 70.0;
    float subsurface = 0.25 * (exp(-sz) + 3 * exp(-sz / 3));
    fragColor = vec4(shadow, ambient, subsurface, volumetric);
}
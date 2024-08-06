#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D NormalSampler;
uniform sampler2D NoiseSampler;

in vec2 texCoord;
flat in mat4 invViewProj;
flat in vec3 offset;

out vec4 fragColor;

vec3 getWorldSpacePosition(in vec2 uv, in float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProj * positionClip;
    return positionWorld.xyz / positionWorld.w;
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

float unpackDepthClipSpace(uint bits) {
    float sgn = (bits & (1u << 23u)) > 0u ? -1.0 : 1.0;
    bits = (bits & 0x007FFFFFu) | 0x3F800000u;
    float depth12 = uintBitsToFloat(bits);
    return (depth12 - 1.0) * sgn;
}

float unpackDepthClipSpaceRGB8(vec3 rgb) {
    uvec3 data = uvec3(round(rgb * 255.0));
    uint bits = (data.r << 16) | (data.g << 8) | data.b;
    return unpackDepthClipSpace(bits);
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
    
    // float distortionFactor = length(lightSpace.xy) + 0.1;
    // float numerator = distortionFactor * distortionFactor;
    // float bias = 1.5 / 1024.0 * numerator / 0.1;

    // lightSpace.xy /= distortionFactor;
    // lightSpace.xyz += (lightProj * vec4(normal, 1.0)).xyz * bias;

    vec3 projLightSpace = lightSpace.xyz * 0.5 + 0.5;

    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackDepthClipSpaceRGB8(texture(ShadowMapSampler, projLightSpace.xy).rgb) * 0.5 + 0.5;
        // return vec3(projLightSpace.z, closestDepth, bias);
        return vec3(projLightSpace.z, closestDepth, 0.00135);
    }

    return vec3(-1.0, -1.0, 0.0);
}

bool checkOcclusion(vec3 projection, vec3 lightDir, vec3 normal) {
    float NdotL = dot(normal, lightDir);
    return projection.x - projection.z / abs(NdotL) > projection.y;   
}

float estimateShadowContribution(mat4 lightProj, vec3 lightDir, vec3 fragPos, vec3 normal) {
    // float filterSize = length(fragPos) * 0.07;
    // filterSize = 1.0 + filterSize;
    float filterSize = 1.0;

    vec3 tangent = normalize(cross(lightDir, normal)) * filterSize * 1.2;
    vec3 bitangent = normalize(cross(tangent, normal)) * filterSize;

    float contribution = 0.0;
    float totalWeight = 0.0;

    float occluderDistance = 0.0;

    for (int i = 0; i < 6; i++) {
        vec2 offset = randomPointOnDisk(-i - 1);
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
        vec2 diskPoint = randomPointOnDisk(i);
        vec3 jitter = (tangent * diskPoint.x + bitangent * diskPoint.y) * penumbra + bitangent * diskPoint.y * 0.03;

        if (checkOcclusion(projectShadowMap(lightProj, fragPos + jitter, normal), lightDir, normal)) {
            contribution += 1.0;
        }
        
        totalWeight += 1.0;
    }
    
    return contribution / totalWeight;
}

void main() {
    uvec4 depthData = uvec4(texture(DiffuseDepthSampler, texCoord) * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    float depth = uintBitsToFloat(bits);
    
    fragColor = texture(DiffuseSampler, texCoord);

    vec3 fragPos = getWorldSpacePosition(texCoord, depth);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    
    vec3 lightDir = normalize(vec3(1.5, 10.0, 5.0));

    //mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 100.0);
    mat4 proj = orthographicProjectionMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 100.0);
    mat4 view = lookAtTransformationMatrix(vec3(3.0, 20.0, 10.0), vec3(0.0), vec3(0.0, 1.0, 0.0));
    mat4 lightProj = proj * view;

    if (depth == 1.0) {
        return;
    }

    float shadow = 0.0;
    if (dot(lightDir, normal) < -0.01) {
        shadow = 1.0;
    } else {
        shadow = estimateShadowContribution(lightProj, lightDir, fragPos - offset, normal);
    }

    fragColor.rgb *= 0.5 + (1.0 -shadow) * 0.5;
}
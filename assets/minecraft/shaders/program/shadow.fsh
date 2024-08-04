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

vec3 getPositionWorldSpace(in vec2 uv, in float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProj * positionClip;
    return positionWorld.xyz / positionWorld.w;
}

mat4 ortho(float left, float right, float bottom, float top, float near, float far) {
    return mat4(
        2.0 / (right - left), 0.0, 0.0, 0.0,
        0.0, 2.0 / (top - bottom), 0.0, 0.0,
        0.0, 0.0, -2.0 / (far - near), 0.0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0
    );
}

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
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

void main() {
    uvec4 depthData = uvec4(texture(DiffuseDepthSampler, texCoord) * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    float depth = uintBitsToFloat(bits);
    
    fragColor = texture(DiffuseSampler, texCoord);

    vec3 fragPos = getPositionWorldSpace(texCoord, depth);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    
    vec3 lightDir = normalize(vec3(1.5, 10.0, 5.0));
    float shadow = 0.0;

    mat4 proj = ortho(-10.0, 10.0, -10.0, 10.0, 0.05, 100.0);
    mat4 view = lookAt(vec3(3.0, 20.0, 10.0), vec3(0.0), vec3(0.0, 1.0, 0.0));
    mat4 lightMat = proj * view;

    vec4 lightSpace = lightMat * vec4(fragPos - offset, 1.0);
    vec3 projLightSpace = (lightSpace.xyz / lightSpace.w) * 0.5 + 0.5;

    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackDepthClipSpaceRGB8(texture(ShadowMapSampler, projLightSpace.xy).rgb) * 0.5 + 0.5;
        float currentDepth = projLightSpace.z;

        shadow += dot(lightDir, normal) < -0.01 || currentDepth - 0.00144 > closestDepth ? 0.5 : 1.0;
    } else {
        shadow += dot(lightDir, normal) < -0.01 ? 0.5 : 1.0;
    }

    fragColor.rgb *= shadow;
}
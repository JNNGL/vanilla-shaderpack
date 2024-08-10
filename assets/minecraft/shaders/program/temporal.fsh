#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D NormalSampler;
uniform sampler2D PreviousNormalSampler;
uniform sampler2D PreviousDiffuseSampler;
uniform sampler2D PreviousDepthSampler;

uniform vec2 OutSize;

flat in mat4 invViewProjMat;
flat in mat4 prevViewProjMat;
flat in vec3 position;
flat in vec3 prevPosition;
flat in int shadowMapFrame;
in vec2 texCoord;
in vec4 near;
in vec4 far;

out vec4 fragColor;

vec3 getPositionWorldSpace(vec2 uv, float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProjMat * positionClip;
    return positionWorld.xyz / positionWorld.w;
}

float unpackDepth(vec4 color) {
    uvec4 depthData = uvec4(color * 255.0);
    uint bits = (depthData.r << 24) | (depthData.g << 16) | (depthData.b << 8) | depthData.a;
    return uintBitsToFloat(bits);
}

void main() {
    if (shadowMapFrame > 0) {
        fragColor = texture(PreviousDiffuseSampler, texCoord);
        return;
    }

    if (ivec2(gl_FragCoord.xy) == ivec2(64, 0)) {
        int x = int(texelFetch(PreviousDiffuseSampler, ivec2(64, 0), 0).r * 255.0 + 1.0) % 4;
        fragColor = vec4(float(x) / 255.0, 0.0, 0.0, 1.0);
        return;
    }
    
    if (int(floor(gl_FragCoord.y)) == 0) {
        fragColor = texelFetch(DiffuseSampler, ivec2(gl_FragCoord.xy), 0);
        return;
    }

    vec3 color = texture(DiffuseSampler, texCoord).rgb;
    fragColor = vec4(color, 1.0);

    float depth = texture(DiffuseDepthSampler, texCoord).r;
    if (depth == 1.0) {
        return;
    }
    
    vec3 offset = mod(position - prevPosition + 8.0, 16.0) - 8.0;

    vec3 view = getPositionWorldSpace(texCoord, depth);
    vec4 clipSpace = prevViewProjMat * vec4(view - offset, 1.0);
    vec3 screenSpace = clipSpace.xyz / clipSpace.w * 0.5 + 0.5;

    if (clamp(screenSpace.xy, 1.0 / OutSize, 1.0 - 1.0 / OutSize) != screenSpace.xy) {
        return;
    }

    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    vec3 prevNormal = texture(PreviousNormalSampler, screenSpace.xy).rgb * 2.0 - 1.0;
    
    if (dot(normal, prevNormal) < 0.7) {
        return;
    }

    uvec4 prevDepthData = uvec4(texture(PreviousDepthSampler, screenSpace.xy) * 255.0);
    uint prevDepthBits = prevDepthData.r << 24 | prevDepthData.g << 16 | prevDepthData.b << 8 | prevDepthData.a;
    float prevDepth = uintBitsToFloat(prevDepthBits);
    if (abs(screenSpace.z - prevDepth) > 0.001 * screenSpace.z) {
        // return;
    }
    
    vec2 uv = screenSpace.xy * OutSize - 0.5;
    ivec2 coord = ivec2(floor(uv));
    vec2 frac = uv - coord;
    vec3 previousSample = mix(
        mix(texelFetch(PreviousDiffuseSampler, coord, 0).rgb, texelFetch(PreviousDiffuseSampler, coord + ivec2(1, 0), 0).rgb, frac.x), 
        mix(texelFetch(PreviousDiffuseSampler, coord + ivec2(0, 1), 0).rgb, texelFetch(PreviousDiffuseSampler, coord + ivec2(1, 1), 0).rgb, frac.x), 
        frac.y);

    // if (abs(previousSample.r - fragColor.r) > 0.1) {
        // return;
    // }

    vec3 mixedSample = mix(previousSample, color, 0.2);
    fragColor = vec4(mixedSample.rgb, 1.0);
}
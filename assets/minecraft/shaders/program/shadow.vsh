#version 330

uniform sampler2D DataSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D FrameSampler;

uniform vec2 InSize;

out vec2 texCoord;
flat out mat4 invProjection;
flat out mat4 projection;
flat out mat3 viewMat;
flat out mat4 viewProj;
flat out mat4 invViewProj;
flat out vec3 offset;
flat out vec3 shadowEye;
flat out float time;
out vec4 near;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 40000.0;
}

float decodeFloat1024(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 1024.0;
}

float unpackFloat(vec4 color) {
    uvec4 data = uvec4(color * 255.0);
    uint bits = (data.r << 24) | (data.g << 16) | (data.b << 8) | data.a;
    return uintBitsToFloat(bits);
}

const vec4[] corners = vec4[](
    vec4(-1, -1, 0, 1),
    vec4(1, -1, 0, 1),
    vec4(1, 1, 0, 1),
    vec4(-1, 1, 0, 1)
);

void main() {
    vec4 outPos = corners[gl_VertexID];
    gl_Position = outPos;

    // int shadowMapFrame = decodeInt(texelFetch(DataSampler, ivec2(30, 0), 0).rgb);
    mat4 modelView = mat4(1.0);

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DataSampler, ivec2(i, 0), 0);
        projection[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 9; i++) {
        vec4 color = texelFetch(DataSampler, ivec2(i + 16, 0), 0);
        modelView[i / 3][i % 3] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DataSampler, ivec2(27 + i, 0), 0);
        offset[i] = decodeFloat(color.rgb) * 16.0;
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DataSampler, ivec2(31 + i, 0), 0);
        shadowEye[i] = decodeFloat1024(color.rgb);
    }

    vec3 captureOffset;
    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(ShadowMapSampler, ivec2(64 + i, 0), 0);
        captureOffset[i] = unpackFloat(color);
    }

    invProjection = inverse(projection);
    viewMat = mat3(modelView);
    viewProj = projection * modelView;
    invViewProj = inverse(viewProj);
    offset = captureOffset + fract(offset);

    time = round(texelFetch(FrameSampler, ivec2(64, 0), 0).r * 255.0);

    texCoord = outPos.xy * 0.5 + 0.5;

    near = invViewProj * vec4(texCoord, -1.0, 1.0);
}
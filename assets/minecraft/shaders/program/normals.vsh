#version 150

uniform sampler2D DiffuseSampler;

out vec2 texCoord;
flat out mat4 invViewProj;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 40000.0;
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

    mat4 projection;
    mat4 modelView = mat4(1.0);

    for (int i = 0; i < 16; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i, 0), 0);
        projection[i / 4][i % 4] = decodeFloat(color.rgb);
    }

    for (int i = 0; i < 9; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(i + 16, 0), 0);
        modelView[i / 3][i % 3] = decodeFloat(color.rgb);
    }

    invViewProj = inverse(projection * modelView);

    texCoord = outPos.xy * 0.5 + 0.5;
}
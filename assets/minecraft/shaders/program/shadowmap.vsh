#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D PreviousDataSampler;

out vec2 texCoord;
flat out int part;
flat out vec3 offset;
flat out mat4 lightProjMat;
flat out mat4 invLightProjMat;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat(vec3 ivec) {
    int v = decodeInt(ivec);
    return float(v) / 40000.0;
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

const vec4[] corners = vec4[](
    vec4(-1, -1, 0, 1),
    vec4(1, -1, 0, 1),
    vec4(1, 1, 0, 1),
    vec4(-1, 1, 0, 1)
);

void main() {
    vec4 outPos = corners[gl_VertexID];
    gl_Position = outPos;

    part = decodeInt(texelFetch(DiffuseSampler, ivec2(30, 0), 0).rgb);

    vec3 position, prevPosition;

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(DiffuseSampler, ivec2(27 + i, 0), 0);
        position[i] = decodeFloat(color.rgb) * 16.0;
    }

    for (int i = 0; i < 3; i++) {
        vec4 color = texelFetch(PreviousDataSampler, ivec2(27 + i, 0), 0);
        prevPosition[i] = decodeFloat(color.rgb) * 16.0;
    }

    offset = mod(floor(position) - floor(prevPosition) + 8.0, 16.0) - 8.0;

    mat4 proj = ortho(-10.0, 10.0, -10.0, 10.0, 0.05, 100.0);
    mat4 view = lookAt(vec3(3.0, 20.0, 10.0), vec3(0.0), vec3(0.0, 1.0, 0.0));
    lightProjMat = proj * view;
    invLightProjMat = inverse(lightProjMat);

    texCoord = outPos.xy * 0.5 + 0.5;
}
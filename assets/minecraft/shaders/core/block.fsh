#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform vec3 ChunkOffset;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
flat in int dataQuad;

out vec4 fragColor;

vec4 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 256;
    return vec4(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0, 1.0);
}

vec4 encodeFloat1024(float v) {
    v *= 1024.0;
    v = floor(v);
    return encodeInt(int(v));
}

vec4 encodeFloat(float v) {
    v *= 40000.0;
    v = floor(v);
    return encodeInt(int(v));
}

void main() {
    if (dataQuad > 0) {
        vec2 pixel = floor(gl_FragCoord.xy);
        if (pixel.y >= 1.0 || pixel.x >= 30.0) {
            discard;
        }

        // layout
        // 0-15 - projection matrix
        // 16-24 - view matrix
        // 25 - fog start
        // 26 - fog end
        // 27-29 - chunk offset
        if (pixel.x <= 15) {
            int index = int(pixel.x);
            fragColor = encodeFloat(ProjMat[index / 4][index % 4]);
        } else if (pixel.x <= 24) {
            int index = int(pixel.x - 16);
            fragColor = encodeFloat(ModelViewMat[index / 3][index % 3]);
        } else if (pixel.x == 25) {
            fragColor = encodeFloat1024(FogStart);
        } else if (pixel.x == 26) {
            fragColor = encodeFloat1024(FogEnd);
        } else if (pixel.x <= 29) {
            int index = int(pixel.x) - 27;
            fragColor = encodeFloat(mod(ChunkOffset[index], 16.0) / 16.0);
        }
        return;
    }

    vec4 color = texture(Sampler0, texCoord0);
#ifdef DISCARD
    if (color.a < 0.1) {
        discard;
    }
#endif

    color *= vertexColor * ColorModulator;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
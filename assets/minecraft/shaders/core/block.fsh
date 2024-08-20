#moj_import <fog.glsl>
#moj_import <shadow.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform vec3 ChunkOffset;
uniform float GameTime;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
flat in int dataQuad;
flat in int shadow;
in vec3 fragPos;
in vec4 glPos;

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

uint packDepthClipSpace(float depth) {
    uint value = depth < 0.0 ? (1u << 23u) : 0u;
    float depth12 = abs(depth) + 1.0;
    uint bits = floatBitsToUint(depth12);
    value |= (bits & 0x7FFFFFu);
    return value;
}

vec3 packDepthClipSpaceRGB8(float depth) {
    uint bits = packDepthClipSpace(depth);
    return vec3(bits >> 16, (bits >> 8) & 0xFFu, bits & 0xFFu) / 255.0;
}

vec4 unshadeBlock(vec4 color, vec3 normal) {
    if (abs(normal.x) - abs(normal.z) > 0.5) return vec4(color.rgb / 0.6, color.a);
    if (abs(normal.z) - abs(normal.x) > 0.5) return vec4(color.rgb / 0.8, color.a);
    if (normal.y < -0.5) return vec4(color.rgb / 0.5, color.a);
    return color;
}

void main() {
    vec3 normal = normalize(cross(dFdx(fragPos), dFdy(fragPos)));
    
    if (dataQuad > 0) {
        vec2 pixel = floor(gl_FragCoord.xy);
        if (pixel.y >= 1.0 || pixel.x >= 34.0) {
            discard;
        }

        // layout
        // 0-15 - projection matrix
        // 16-24 - view matrix
        // 25 - fog start
        // 26 - fog end
        // 27-29 - chunk offset
        // 30 - shadowmap part
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
        } else if (pixel.x == 30) {
            fragColor = encodeInt(isShadowMapFrame(GameTime) ? 1 : 0);
        } else if (pixel.x <= 33) {
            int index = int(pixel.x) - 31;
            fragColor = encodeFloat1024(getShadowEyeLocation(GameTime)[index]);
        }
        return;
    }

    vec4 color = shadow > 0 ? texture(Sampler0, texCoord0, -4) : texture(Sampler0, texCoord0);
#ifdef DISCARD
    if (color.a < 0.1) {
        discard;
    }
#endif

    fragColor = color * unshadeBlock(vertexColor, normal) * ColorModulator;
    fragColor.a = 1.0;
    // fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    
    // if (shadowQuad > 0) {
    //     fragColor = vec4(packDepthClipSpaceRGB8(glPos.z / glPos.w), 1.0);
    // }
}
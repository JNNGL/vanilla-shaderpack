#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>
#moj_import <shadow.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform int FogShape;
uniform float GameTime;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec4 normal;
flat out int dataQuad;
flat out int shadow;
out vec3 fragPos;
out vec4 glPos;

#define PI 3.14159

void main() {
    ivec4 col = ivec4(round(texture(Sampler0, UV0) * 255.0));
    vec3 pos = Position + ChunkOffset;
    dataQuad = col.rgb == ivec3(76, 195, 86) ? 1 : 0;
    fragPos = pos;

    vec3 worldPos = pos;

    int alpha = int(textureLod(Sampler0, UV0, -4).a * 255.0);
    if (alpha == 251 || alpha == 4) {
        float animation = GameTime * PI;
        float magnitude = sin(animation * 136 + Position.z * PI / 4.0 + Position.y * PI / 4.0) * 0.04 + 0.04;
        float d0 = sin(animation * 636);
        float d1 = sin(animation * 446);
        float d2 = sin(animation * 570);
        vec3 wave;
        wave.x = sin(animation * 316 + d0 + d1 - Position.x * PI / 4.0 + Position.z * PI / 4.0 + Position.y * PI / 4.0) * magnitude;
        wave.z = sin(animation * 1120 + d1 + d2 + Position.x * PI / 4.0 - Position.z * PI / 4.0 + Position.y * PI / 4.0) * magnitude;
        wave.y = sin(animation * 70 + d2 + d0 + Position.z * PI / 4.0 + Position.y * PI / 4.0 - Position.y * PI / 4.0) * magnitude;
        worldPos.x += 0.2 * (wave.x * 2.0 + wave.y * 1.0);
        worldPos.z += 0.2 * (wave.z * 0.75);
        worldPos.x += 0.01 * sin(sin(animation * 100) * 8.0 + (Position.x + Position.y) / 4.0 * PI);
        worldPos.z += 0.01 * sin(sin(animation * 60) * 6.0 + 978.0 + (Position.z + Position.y) / 4.0 * PI);
    }

    gl_Position = ProjMat * ModelViewMat * vec4(worldPos, 1.0);
    glPos = gl_Position;

    shadow = 0;

    if (isShadowMapFrame(GameTime)) {
        if (ChunkOffset == vec3(0.0)) {
            gl_Position = vec4(-10.0);
            return;
        }

        // mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 100.0);
        mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 64.0);
        mat4 view = lookAtTransformationMatrix(getShadowEyeLocation(GameTime), vec3(0.0), vec3(0.0, 1.0, 0.0));

        pos -= fract(ChunkOffset);
        gl_Position = proj * view * vec4(pos, 1.0);
        float distortionFactor = length(gl_Position.xy) + 0.1;
        gl_Position.xy /= distortionFactor;
        glPos = gl_Position;
        
        shadow = 1;
    }

    vertexDistance = fog_distance(pos, FogShape);
    vertexColor = Color;
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);

    if (dataQuad > 0) {
        if (gl_VertexID >= 48 || ChunkOffset == vec3(0.0)) {
            gl_Position = vec4(-10.0);
            return;
        }

        vec2 bottomLeftCorner = vec2(-1.0, -1.0);
        vec2 topRightCorner = vec2(-0.9, -0.995);

        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   -1, 1); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, -1, 1); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, -1, 1); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   -1, 1); break;
        }
    }
}
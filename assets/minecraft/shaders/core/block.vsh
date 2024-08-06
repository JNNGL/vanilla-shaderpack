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
flat out int shadowQuad;
flat out int shadowMapPart;
out vec4 glPos;

void main() {
    ivec4 col = ivec4(round(texture(Sampler0, UV0) * 255.0));
    vec3 pos = Position + ChunkOffset;
    shadowQuad = col == ivec4(0, 0, 0, 1) || col == ivec4(0, 0, 0, 200) ? 1 : 0;
    dataQuad = col.rgb == ivec3(76, 195, 86) ? 1 : 0;
    shadowMapPart = getShadowMapPart(GameTime);

    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
    glPos = gl_Position;

    if (shadowQuad > 0) {
        if (ChunkOffset == vec3(0.0)) {
            gl_Position = vec4(-10.0);
            return;
        }

        // mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 100.0);
        mat4 proj = orthographicProjectionMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 100.0);
        mat4 view = lookAtTransformationMatrix(vec3(3.0, 20.0, 10.0), vec3(0.0), vec3(0.0, 1.0, 0.0));

        pos -= fract(ChunkOffset);
        gl_Position = proj * view * vec4(pos, 1.0);
        // float distortionFactor = length(gl_Position.xy) + 0.1;
        // gl_Position.xy /= distortionFactor;
        glPos = gl_Position;
        gl_Position.z = -0.5 + gl_Position.z * 0.5;
    }

    vertexDistance = fog_distance(pos, FogShape);
    vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
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
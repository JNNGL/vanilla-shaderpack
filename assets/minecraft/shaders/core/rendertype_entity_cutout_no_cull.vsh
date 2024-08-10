#version 150

#moj_import <shadow.glsl>
#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform int FogShape;
uniform float GameTime;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

out float vertexDistance;
out vec4 vertexColor;
out vec4 lightMapColor;
out vec4 overlayColor;
out vec2 texCoord0;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    if (isShadowMapFrame(GameTime)) {
        // mat4 proj = orthographicProjectionMatrix(-128.0, 128.0, -128.0, 128.0, 0.05, 100.0);
        mat4 proj = orthographicProjectionMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 64.0);
        mat4 view = lookAtTransformationMatrix(getShadowEyeLocation(GameTime), vec3(0.0), vec3(0.0, 1.0, 0.0));

        gl_Position = proj * view * vec4(Position, 1.0);
        // float distortionFactor = length(gl_Position.xy) + 0.1;
        // gl_Position.xy /= distortionFactor;
    }

    vertexDistance = fog_distance(Position, FogShape);
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
    lightMapColor = texelFetch(Sampler2, UV2 / 16, 0);
    overlayColor = texelFetch(Sampler1, UV1, 0);
    texCoord0 = UV0;
}
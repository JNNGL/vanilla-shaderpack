#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:constants.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform int FogShape;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;

void main() {
    gl_Position = GLPOS_DISCARD;

    vertexDistance = fog_distance(Position, FogShape);
    vertexColor = Color;
    texCoord0 = UV0;
}

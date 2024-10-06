#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

in vec3 Position;
in vec4 Color;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec4 vertexColor;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    // Discard the lower hemisphere of the sky
    if (ProjMat[2][3] != 0.0) gl_Position = GLPOS_DISCARD;

    vertexColor = Color;
}
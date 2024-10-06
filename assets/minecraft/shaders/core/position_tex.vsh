#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

in vec3 Position;
in vec2 UV0;

uniform sampler2D Sampler0;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec2 texCoord;
out float isSun;
out vec4 position0;
out vec4 position1;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vec2 texSize = textureSize(Sampler0, 0);

    isSun = 0.0;
    position0 = position1 = vec4(0.0);

    // TODO: A better way to detect sun/moon :P
    if (texSize.x == texSize.y) {
        vec2 bottomLeftCorner = vec2(-1.0);
        vec2 topRightCorner = vec2(1.0);

        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   -1.0, 1.0); position0 = vec4(Position, 1.0); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, -1.0, 1.0); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, -1.0, 1.0); position1 = vec4(Position, 1.0); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   -1.0, 1.0); break;
        }

        isSun = 1.0;
    }

    if (texSize.x / texSize.y == 2.0) {
        gl_Position = GLPOS_DISCARD;
    }
}
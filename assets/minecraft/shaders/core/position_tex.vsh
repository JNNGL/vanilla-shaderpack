#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

in vec3 Position;

uniform sampler2D Sampler0;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out float isSun;
out vec4 position0;
out vec4 position1;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vec2 texSize = textureSize(Sampler0, 0);

    isSun = 0.0;
    position0 = position1 = vec4(0.0);

    if (texSize.x == texSize.y) {
        vec4 corners = vec4(-1.0, -1.0, 1.0, 1.0);

        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(corners.xw, -1.0, 1.0); position0 = vec4(Position, 1.0); break;
            case 1: gl_Position = vec4(corners.xy, -1.0, 1.0); break;
            case 2: gl_Position = vec4(corners.zy, -1.0, 1.0); position1 = vec4(Position, 1.0); break;
            case 3: gl_Position = vec4(corners.zw, -1.0, 1.0); break;
        }

        isSun = 1.0;
    }

    if (texSize.x / texSize.y == 2.0) {
        gl_Position = GLPOS_DISCARD;
    }
}
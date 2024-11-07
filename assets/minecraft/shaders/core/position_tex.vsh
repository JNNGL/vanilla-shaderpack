#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>

in vec3 Position;
#ifdef TEX_COLOR
in vec2 UV0;
in vec4 Color;
#endif

uniform sampler2D Sampler0;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

#ifdef TEX_COLOR
out vec2 texCoord0;
out vec4 vertexColor;
#endif
out float isSun;
out vec4 position0;
out vec4 position1;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vec2 texSize = textureSize(Sampler0, 0);

    isSun = 0.0;
    position0 = position1 = vec4(0.0);

    ivec4 texel = ivec4(round(texelFetch(Sampler0, ivec2(0, 0), 0) * 255.0));
    if (texSize == vec2(32.0) && texel == ivec4(61, 162, 158, 7)) {
        vec4 corners = vec4(-1.0, -1.0, 1.0, 1.0);

        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(corners.xw, -1.0, 1.0); position0 = vec4(Position, 1.0); break;
            case 1: gl_Position = vec4(corners.xy, -1.0, 1.0); break;
            case 2: gl_Position = vec4(corners.zy, -1.0, 1.0); position1 = vec4(Position, 1.0); break;
            case 3: gl_Position = vec4(corners.zw, -1.0, 1.0); break;
        }

        isSun = 1.0;
    }

    if (texSize == vec2(128.0, 64.0) && texel == ivec4(61, 162, 158, 6)) {
        gl_Position = GLPOS_DISCARD;
    }

#ifdef TEX_COLOR
    texCoord0 = UV0;
    vertexColor = Color;
#endif
}
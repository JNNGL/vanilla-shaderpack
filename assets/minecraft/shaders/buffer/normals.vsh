#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out mat4 invProjViewMat;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    mat4 projection = decodeProjectionMatrix(DataSampler);
    invProjViewMat = inverse(projection * ModelViewMat);
}
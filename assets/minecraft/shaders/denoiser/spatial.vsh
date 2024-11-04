#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;

out vec2 texCoord;
flat out int isShadowMap;
flat out mat4 invProjection;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    isShadowMap = decodeIsShadowMap(DataSampler) ? 1 : 0;

    invProjection = inverse(decodeProjectionMatrix(DataSampler));
}
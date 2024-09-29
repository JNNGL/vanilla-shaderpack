#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;

flat out int isShadowMap;

void main() {
    gl_Position = screenquad[gl_VertexID];

    isShadowMap = decodeIsShadowMap(DataSampler) ? 1 : 0;
}
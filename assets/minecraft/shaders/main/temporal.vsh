#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;
uniform sampler2D PreviousSampler;

uniform mat4 ModelViewMat;

flat out mat4 invProjViewMat;
flat out mat4 prevProjViewMat;
flat out vec3 viewOffset;
flat out int isShadowMap;
flat out int frame;
out vec2 texCoord;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    mat4 projection = decodeProjectionMatrix(DataSampler);
    mat4 prevProjection = decodeProjectionMatrix(PreviousSampler);
    mat4 prevModelView = mat4(decodeModelViewMatrix(PreviousSampler));

    vec3 position = decodeChunkOffset(DataSampler);
    vec3 prevPosition = decodeChunkOffset(PreviousSampler);

    invProjViewMat = inverse(projection * ModelViewMat);
    prevProjViewMat = prevProjection * prevModelView;
    viewOffset = mod(position - prevPosition + 8.0, 16.0) - 8.0;
    isShadowMap = decodeIsShadowMap(DataSampler) ? 1 : 0;
    frame = decodeTemporalFrame(PreviousSampler);
}
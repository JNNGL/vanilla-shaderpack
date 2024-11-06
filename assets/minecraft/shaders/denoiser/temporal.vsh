#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>

uniform sampler2D DataSampler;
uniform sampler2D HistorySampler;
uniform sampler2D FrameSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out mat4 invProjViewMat;
flat out mat4 prevProjViewMat;
flat out vec3 viewOffset;
flat out int isShadowMap;
flat out vec2 planes;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    mat4 projection = decodeUnjitteredProjection(DataSampler);
    mat4 prevProjection = decodeUnjitteredProjection(HistorySampler);
    mat4 prevModelView = mat4(decodeModelViewMatrix(HistorySampler));
    vec3 position = decodeChunkOffset(DataSampler);
    vec3 prevPosition = decodeChunkOffset(HistorySampler);

    planes = getPlanes(projection);
    invProjViewMat = inverse(projection * ModelViewMat);
    prevProjViewMat = prevProjection * prevModelView;
    viewOffset = mod(position - prevPosition + 8.0, 16.0) - 8.0;
    isShadowMap = decodeIsShadowMap(DataSampler) ? 1 : 0;
}
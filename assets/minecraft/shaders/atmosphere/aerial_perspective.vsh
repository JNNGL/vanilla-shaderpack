#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:projections.glsl>

uniform sampler2D DataSampler;

uniform mat4 ModelViewMat;

flat out vec3 lightDirection;
flat out mat4 invProjViewMat;
flat out vec2 planes;

void main() {
    gl_Position = screenquad[gl_VertexID];
    
    mat4 projection = decodeProjectionMatrix(DataSampler);
    invProjViewMat = inverse(projection * ModelViewMat);
    lightDirection = decodeSunDirection(DataSampler);

    planes = getPlanes(projection);
}
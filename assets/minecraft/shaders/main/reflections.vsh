#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D DataSampler;
uniform sampler2D FrameSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out vec3 sunDirection;
flat out mat4 projection;
flat out mat4 invProjection;
flat out mat4 invProjViewMat;
flat out vec2 planes;
flat out int shouldUpdate;
flat out float timeSeed;
out vec4 near;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    shouldUpdate = decodeIsShadowMap(DataSampler) ? 0 : 1;

    projection = decodeProjectionMatrix(DataSampler);
    invProjection = inverse(projection);
    invProjViewMat = inverse(projection * ModelViewMat);
    sunDirection = decodeSunDirection(DataSampler);
    near = getPointOnNearPlane(invProjViewMat, gl_Position.xy);
    planes = getPlanes(projection);
    timeSeed = float(decodeTemporalFrame(FrameSampler)) / 10.0;
}
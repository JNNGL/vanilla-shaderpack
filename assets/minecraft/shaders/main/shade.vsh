#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>

uniform sampler2D DataSampler;
uniform sampler2D TransmittanceSampler;
uniform sampler2D MultipleScatteringSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out vec3 sunDirection;
flat out mat4 projViewMat;
flat out mat4 invProjViewMat;
flat out int shouldUpdate;
flat out vec3 transmittanceToSun;
out vec4 near;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    shouldUpdate = decodeIsShadowMap(DataSampler) ? 0 : 1;

    mat4 projection = decodeProjectionMatrix(DataSampler);

    projViewMat = projection * ModelViewMat;
    invProjViewMat = inverse(projViewMat);
    sunDirection = decodeSunDirection(DataSampler);
    near = getPointOnNearPlane(invProjViewMat, gl_Position.xy);

    transmittanceToSun = sampleTransmittanceLUT(TransmittanceSampler, vec3(0.0, earthRadius + cameraHeight, 0.0), sunDirection);
}
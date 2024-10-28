#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D DataSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D FrameSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out mat4 projection;
flat out mat4 invProjection;
flat out mat4 invViewProjMat;
flat out vec3 offset;
flat out mat4 shadowProjMat;
flat out vec3 lightDir;
flat out float timeSeed;
flat out int shouldUpdate;
flat out vec2 planes;
out vec4 near;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    shouldUpdate = decodeIsShadowMap(DataSampler) ? 0 : 1;

    vec3 chunkOffset = decodeChunkOffset(DataSampler);
    vec3 captureOffset = decodeShadowOffset(ShadowMapSampler);

    float time = decodeShadowTime(ShadowMapSampler);
    float skyFactor = decodeShadowSkyFactor(ShadowMapSampler);
    mat4 shadowProj = shadowProjectionMatrix();
    mat4 shadowView = shadowTransformationMatrix(skyFactor, time);
    vec3 shadowEye = getShadowEyeLocation(skyFactor, time);

    projection = decodeProjectionMatrix(DataSampler);
    invProjection = inverse(projection);
    invViewProjMat = inverse(projection * ModelViewMat);
    offset = captureOffset + fract(chunkOffset);
    near = getPointOnNearPlane(invViewProjMat, gl_Position.xy);
    shadowProjMat = shadowProj * shadowView;
    lightDir = normalize(shadowEye);
    timeSeed = decodeTemporalFrame(FrameSampler) / 5.0;
    planes = getPlanes(projection);
}
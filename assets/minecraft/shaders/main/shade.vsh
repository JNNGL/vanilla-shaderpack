#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D DataSampler;
uniform sampler2D ShadowMapSampler;

uniform mat4 ModelViewMat;

out vec2 texCoord;
flat out vec3 lightDir;
flat out mat4 invProjViewMat;
flat out mat4 shadowProjMat;
flat out vec3 offset;
out vec4 near;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    float time = decodeShadowTime(ShadowMapSampler);
    float skyFactor = decodeShadowSkyFactor(ShadowMapSampler);
    mat4 shadowProj = shadowProjectionMatrix();
    mat4 shadowView = shadowTransformationMatrix(skyFactor, time);
    vec3 shadowEye = getShadowEyeLocation(skyFactor, time);

    vec3 chunkOffset = decodeChunkOffset(DataSampler);
    vec3 captureOffset = decodeShadowOffset(ShadowMapSampler);

    mat4 projection = decodeProjectionMatrix(DataSampler);

    invProjViewMat = inverse(projection * ModelViewMat);
    lightDir = normalize(shadowEye);
    shadowProjMat = shadowProj * shadowView;
    offset = captureOffset + fract(chunkOffset);
    near = getPointOnNearPlane(invProjViewMat, gl_Position.xy);
}
#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D DataSampler;
uniform sampler2D PreviousSampler;

out vec2 texCoord;
flat out int shadowMapFrame;
flat out mat4 lightProjMat;
flat out mat4 invLightProjMat;
flat out vec3 offset;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    float gameTime = decodeGameTime(DataSampler);

    shadowMapFrame = decodeIsShadowMap(DataSampler) ? 1 : 0;

    mat4 lightProj = shadowProjectionMatrix();
    mat4 lightView = shadowTransformationMatrix(gameTime);
    lightProjMat = lightProj * lightView;
    invLightProjMat = inverse(lightProjMat);

    vec3 position = decodeChunkOffset(DataSampler);
    vec3 prevPosition = decodeChunkOffset(PreviousSampler);
    vec3 prevOffset = decodeShadowOffset(PreviousSampler);
    offset = prevOffset + mod(floor(position) - floor(prevPosition) + 8.0, 16.0) - 8.0;
}
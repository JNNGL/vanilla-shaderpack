#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:screenquad.glsl>
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D DataSampler;
uniform sampler2D PreviousSampler;

out vec2 texCoord;
flat out int shouldUpdate;
flat out mat4 lightProjMat;
flat out mat4 invLightProjMat;
flat out vec3 offset;
flat out float gameTime;
flat out float currentTime;
flat out float skyFactor;
flat out float currentSkyFactor;

void main() {
    gl_Position = screenquad[gl_VertexID];
    texCoord = sqTexCoord(gl_Position);

    gameTime = decodeGameTime(DataSampler);
    currentTime = decodeShadowTime(PreviousSampler);

    skyFactor = decodeSkyFactor(DataSampler);
    currentSkyFactor = decodeShadowSkyFactor(PreviousSampler);

    shouldUpdate = decodeIsShadowMap(DataSampler) ? 1 : 0;

    if (shouldUpdate > 0 && texelFetch(PreviousSampler, ivec2(60, 0), 0) != vec4(0.0)) {
        vec3 sunDirection = decodeSunDirection(DataSampler);
        
        // vec3 bestPosition = shadowMapLocations[0];
        // for (int i = 1; i < 65; i++) {
        //     if (dot(bestPosition, sunDirection) < dot(shadowMapLocations[i], sunDirection)) {
        //         bestPosition = shadowMapLocations[i];
        //     }
        // }

        // vec3 newShadowDirection = normalize(getShadowEyeLocation(gameTime));
        // if (dot(bestPosition, newShadowDirection) < 0.99999) {
        //     shouldUpdate = 0;
        // }

        vec3 currentShadowDirection = normalize(getShadowEyeLocation(currentSkyFactor, currentTime));
        vec3 newShadowDirection = normalize(getShadowEyeLocation(skyFactor, gameTime));
        if (dot(sunDirection, currentShadowDirection) > dot(sunDirection, newShadowDirection)) {
            shouldUpdate = 0;
        }
    }

    mat4 lightProj = shadowProjectionMatrix();
    mat4 lightView = shadowTransformationMatrix(skyFactor, gameTime);
    lightProjMat = lightProj * lightView;
    invLightProjMat = inverse(lightProjMat);

    vec3 position = decodeChunkOffset(DataSampler);
    vec3 prevPosition = decodeChunkOffset(PreviousSampler);
    vec3 prevOffset = decodeShadowOffset(PreviousSampler);
    offset = prevOffset + mod(floor(position) - floor(prevPosition) + 8.0, 16.0) - 8.0;
}
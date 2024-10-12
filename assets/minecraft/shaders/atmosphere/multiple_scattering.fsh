#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:constants.glsl>

uniform sampler2D TransmittanceSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    float cosTheta = 2.0 * texCoord.x - 1.0;
    float theta = acos(cosTheta);
    float height = mix(earthRadius, atmosphereRadius, texCoord.y);

    vec3 position = vec3(0.0, height, 0.0);
    vec3 sunDirection = normalize(vec3(0.0, cosTheta, -sin(theta)));

    vec3 fms;
    vec3 luminance = computeMultipleScattering(TransmittanceSampler, position, sunDirection, fms);

    vec3 psi = luminance / (1.0 - fms);
    fragColor = packR11G11B10LtoF8x4(psi * 5.0);
}
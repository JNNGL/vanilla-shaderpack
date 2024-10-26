#version 330

#extension GL_MC_moj_import : enable
#moj_import <atmosphere.glsl>

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec3 position = vec3(0.0, mix(earthRadius, atmosphereRadius, texCoord.y), 0.0);

    float theta = acos(2.0 * texCoord.x - 1.0);
    vec3 direction = normalize(vec3(0.0, cos(theta), -sin(theta)));

    float travelDistance = distanceToAtmosphereBoundary(position, direction);
    vec3 transmittance = computeTransmittanceToBoundary(position, direction, travelDistance);
    transmittance = clamp(transmittance, 0.0, 1.0);

    fragColor = encodeLogLuv(transmittance);
}
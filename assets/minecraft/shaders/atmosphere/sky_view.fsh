#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:constants.glsl>

uniform sampler2D TransmittanceSampler;

in vec2 texCoord;
flat in vec3 lightDirection;

out vec4 fragColor;

void main() {
    float azimuthAngle = (texCoord.x * 2.0 - 1.0) * PI;
    float altitudeLinear = texCoord.y * 2.0 - 1.0;
    float altitudeMapped = sign(altitudeLinear) * altitudeLinear * altitudeLinear;

    vec3 position = vec3(0.0, earthRadius + cameraHeight, 0.0);
    float height = position.y;
    vec3 normal = vec3(0.0, 1.0, 0.0);
    float horizonAngle = acos(sqrt(height * height - earthRadius * earthRadius) / height) - 0.5 * PI;
    float altitudeAngle = altitudeMapped * 0.5 * PI - horizonAngle;

    vec3 direction = vec3(cos(altitudeAngle) * sin(azimuthAngle), sin(altitudeAngle), -cos(altitudeAngle) * cos(azimuthAngle));
    
    float sunAltitude = 0.5 * PI - acos(dot(lightDirection, normal));
    vec3 sunDirection = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));
    
    float distanceToBoundary = distanceToAtmosphereBoundary(position, direction);

    vec3 luminance = raymarchAtmosphericScattering(TransmittanceSampler, position, direction, sunDirection, distanceToBoundary)[0];
    
    fragColor = packR11G11B10LtoF8x4(sqrt(luminance));
}
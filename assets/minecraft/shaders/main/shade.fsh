#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;
uniform sampler2D TransmittanceSampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D NoiseSampler;

in vec2 texCoord;
flat in vec3 lightDir;
flat in mat4 invProjViewMat;
flat in mat4 shadowProjMat;
flat in vec3 offset;
in vec4 near;

out vec4 fragColor;

void main() {
    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, texture(DepthSampler, texCoord).r);
    vec3 pointOnNearPlane = near.xyz / near.w;

    vec4 shadow = texelFetch(ShadowSampler, ivec2(gl_FragCoord.x, max(1.0, gl_FragCoord.y)), 0);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;

    vec3 position = vec3(0.0, earthRadius + cameraHeight, 0.0) + pointOnNearPlane;
    vec3 direction = normalize(fragPos - pointOnNearPlane);
    
    if (dot(normal, normal) < 0.01) {
        float atmosphereBoundary = distanceToAtmosphereBoundary(position, direction);
        vec2 earthDistance = raySphereIntersection(position, direction, earthRadius);
        float travelDistance = atmosphereBoundary;

        vec3 luminance = raymarchAtmosphericScattering(TransmittanceSampler, NoiseSampler, ShadowMapSampler, shadowProjMat, normal, gl_FragCoord.xy, position, direction, pointOnNearPlane - offset, lightDir, travelDistance, 1.0)[0] * 30.0;

        vec3 color = acesFitted(luminance);
        color = linearToSrgb(color);

        fragColor = vec4(color, 1.0);
        return; 
    }

    float NdotL = dot(normal, lightDir);

    vec3 color = srgbToLinear(texture(InSampler, texCoord).rgb);

    const float a = 0.85;
    vec3 sunColor = vec3(255.0 / 255.0, 167.0 / 255.0, 125.0 / 255.0) * 3.5 * a;
    vec3 ambient = vec3(0.1621, 0.1919, 0.2094) * 2.0 * a * shadow.g * (-max(-NdotL, 0.0) * 0.5 + 1.0);
    vec3 directional = sunColor * (1.0 - shadow.r) * max(0.0, NdotL);
    vec3 subsurface = shadow.b * sunColor * (abs(NdotL) + 0.5) * 0.5;
    color *= (ambient + directional + subsurface) * shadow.g;

    float fragDistance = length(fragPos - pointOnNearPlane);

    mat2x3 atmosphericFog = raymarchAtmosphericScattering(TransmittanceSampler, NoiseSampler, ShadowMapSampler, shadowProjMat, normal, gl_FragCoord.xy, position, direction, pointOnNearPlane - offset, lightDir, fragDistance, 30.0);
    color = color * atmosphericFog[1] + atmosphericFog[0] * 30.0;

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}
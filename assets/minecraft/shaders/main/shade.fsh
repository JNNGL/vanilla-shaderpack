#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SkySampler;
uniform sampler2D TransmittanceSampler;

in vec2 texCoord;
flat in vec3 sunDirection;
flat in mat4 invProjViewMat;
flat in int shouldUpdate;
in vec4 near;

out vec4 fragColor;

void main() {
    if (shouldUpdate == 0) {
        return;
    }

    float depth = texture(DepthSampler, texCoord).r;
    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);

    vec4 shadow = texelFetch(ShadowSampler, ivec2(gl_FragCoord.x, max(1.0, gl_FragCoord.y)), 0);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    
    vec3 color;
    if (depth == 1.0) {
        vec3 pointOnNearPlane = near.xyz / near.w;
        vec3 direction = normalize(fragPos - pointOnNearPlane);

        color = sampleSkyLUT(SkySampler, direction, sunDirection) * sunIntensity;
    } else {
        float NdotL = dot(normal, sunDirection);

        vec3 albedo = srgbToLinear(texture(InSampler, texCoord).rgb);

        vec3 transmittance = sampleTransmittanceLUT(TransmittanceSampler, vec3(0.0, earthRadius + cameraHeight, 0.0) + fragPos, sunDirection);
        vec3 lightColor = transmittance * 1.2;

        vec3 diffuse = (albedo / PI); // Lambert
        diffuse *= clamp(NdotL, 0.0, 1.0) * 4.0 * lightColor * clamp(1.0 + min(0.0, sunDirection.y) * 200.0, 0.0, 1.0);

        float lightColorLength = length(lightColor);
        vec3 ambientColor = pow(sampleSkyLUT(SkySampler, vec3(0.0001, 1.0, 0.0), sunDirection), vec3(1.0 / 3.0)) * 5.0;
        vec3 ambient = albedo * pow(shadow.g, 1.5) * ambientColor * 0.33 * (lightColorLength + 0.13) * (-clamp(-NdotL, 0.0, 0.6) * 0.6 * lightColorLength + 1.0);

        // lame subsurface scattering "approximation"
        float halfLambert = pow(NdotL * 0.25 + 0.75, 1.0);
        vec3 subsurface = halfLambert * shadow.z * albedo * lightColor;

        color = vec3(0.0);
        color += mix(diffuse, subsurface, 0.6) * (1.0 - shadow.x);
        color += ambient;
    }

    fragColor = encodeRGBM(color);
}
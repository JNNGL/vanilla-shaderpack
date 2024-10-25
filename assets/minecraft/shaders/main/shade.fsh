#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:srgb.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:brdf.glsl>
#moj_import <minecraft:metals.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SkySampler;
uniform sampler2D TransmittanceSampler;
uniform sampler2D SpecularSampler;
uniform sampler2D LightmapSampler;
uniform sampler2D NoiseSampler;

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
    vec3 normal = normalize(texture(NormalSampler, texCoord).rgb * 2.0 - 1.0);
    
    vec3 pointOnNearPlane = near.xyz / near.w;
    vec3 direction = normalize(fragPos - pointOnNearPlane);

    vec3 color;
    if (depth == 1.0) {
        color = sampleSkyLUT(SkySampler, direction, sunDirection) * sunIntensity;
    } else {
        float NdotL = dot(normal, sunDirection);

        vec3 albedo = srgbToLinear(texture(InSampler, texCoord).rgb);
        vec2 lightLevel = texture(LightmapSampler, texCoord).rg;

        vec4 specularData = texture(SpecularSampler, texCoord);
        float roughness = pow(1.0 - specularData.r, 1.3);
        float subsurfaceFactor = specularData.b;

        vec3 transmittance = sampleTransmittanceLUT(TransmittanceSampler, vec3(0.0, earthRadius + cameraHeight, 0.0) + fragPos, sunDirection);
        vec3 lightColor = transmittance * LIGHT_COLOR_MULTIPLIER;
        vec3 radiance = 4.0 * lightColor * clamp(1.0 + min(0.0, sunDirection.y) * 200.0, 0.0, 1.0);

        vec3 N = normalize(round(normal * 16.0) / 16.0);
        vec3 L = normalize(sunDirection);
        vec3 V = -direction;
        vec3 H = normalize(V + L);

        vec3 F;

        int metalId = int(round(specularData.g * 255.0));
        if (metalId >= 230 && metalId <= 237) {
            mat2x3 NK = HARDCODED_METALS[metalId - 230];
            F = fresnelConductor(max(dot(H, V), 0.0), NK[0], NK[1]);
        } else {
            vec3 F0 = metalId > 237 ? albedo : vec3(specularData.g);
            F = fresnelSchlick(max(dot(H, V), 0.0), F0);
        }

        vec3 diffuse = hammonDiffuse(albedo, N, V, L, H, F, roughness * roughness);
        diffuse *= clamp(NdotL, 0.0, 1.0) * radiance;

        float lightColorLength = length(lightColor);
        vec3 ambientColor = pow(sampleSkyLUT(SkySampler, vec3(0.0001, 1.0, 0.0), sunDirection), vec3(1.0 / 3.0)) * 5.0;
        vec3 ambient = albedo * pow(shadow.g, 1.0) * ambientColor * 0.2 * (lightColorLength + 0.13) * (-sqrt(clamp(-NdotL, 0.0, 0.6)) * 0.2 * lightColorLength + 1.0);

#if (ENABLE_SUBSURFACE_SCATTERING == yes)
        // lame subsurface scattering "approximation"
        float halfLambert = pow(NdotL * 0.25 + 0.75, 1.0);
        vec3 subsurface = halfLambert * shadow.z * albedo * lightColor;
        
        diffuse = mix(diffuse, subsurface, subsurfaceFactor);
#endif // ENABLE_SUBSURFACE_SCATTERING

        // TODO: Refactor this shit
        
        float NDF = DistributionGGX(N, H, roughness);
        float G = GeometrySmith(N, V, L, roughness);
        
        vec3 numerator = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) + 0.0001;

        vec3 specular = radiance * numerator / denominator;
        if (metalId >= 230) specular *= albedo;

        const vec3 BLOCKLIGHT_COLOR = vec3(255.0, 212.0, 160.0) / 255.0;

        vec3 absNormal = abs(normal) * vec3(0.6, 1.0, 0.8);
        float ambientFactor = 0.6 + 0.1 * float(absNormal.x > absNormal.z);
        if (absNormal.y > absNormal.x && absNormal.y > absNormal.z) ambientFactor += 0.2;

        vec3 blockLight = BLOCKLIGHT_COLOR * BLOCKLIGHT_COLOR * 2.5 * albedo * mix(0.1, 1.0, shadow.g) * ambientFactor;

        vec3 ambient0 = vec3(0.7, 0.8, 1.0) * 0.025 * albedo;

        color = vec3(0.0);
        color += (diffuse + specular) * (1.0 - shadow.x) * mix(0.5, 1.0, lightLevel.y);
        color += mix(ambient0 * 0.5, ambient, lightLevel.y * lightLevel.y);
        color += mix(ambient0 * 0.5, blockLight, lightLevel.x * lightLevel.x);

        if (fract(specularData.a) != 0.0) {
            color += pow(albedo, vec3(1.8)) * 13.0 * mix(0.0, 1.0, pow(specularData.a, 1.0 / 2.0));
        }
    }

    fragColor = encodeRGBM(color);
}
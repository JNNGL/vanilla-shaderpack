#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SkySampler;
uniform sampler2D ShadowMapSampler;
uniform sampler2D AerialPerspectiveSampler;
uniform sampler2D TransmittanceSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D NoiseSampler;

uniform mat4 ModelViewMat;

in vec2 texCoord;
flat in vec3 lightDir;
flat in vec3 sunDirection;
flat in mat4 invProjViewMat;
flat in mat4 shadowProjMat;
flat in vec3 offset;
flat in vec2 planes;
flat in int shouldUpdate;
in vec4 near;

out vec4 fragColor;

mat2x3 readAerialPerspective(ivec2 coord) {
    vec3 atmosphereLuminance000 = unpackR11G11B10LfromF8x4(texelFetch(AerialPerspectiveSampler, coord, 0));
    vec3 atmosphereTransmittance000 = unpackR11G11B10LfromF8x4(texelFetch(AerialPerspectiveSampler, coord + ivec2(0, 1), 0));
    atmosphereLuminance000 *= atmosphereLuminance000;
    atmosphereTransmittance000 = sqrt(atmosphereTransmittance000);
    return mat2x3(atmosphereLuminance000, atmosphereTransmittance000);
}

mat2x3 mixAerial(mat2x3 a, mat2x3 b, float alpha) {
    return mat2x3(mix(a[0], b[0], alpha), mix(a[1], b[1], alpha));
}

vec3 projectShadowMap(mat4 lightProj, vec3 position, vec3 normal) {
    vec4 lightSpace = lightProj * vec4(position, 1.0);

    float bias;
    lightSpace = distortShadow(lightSpace, bias);
    lightSpace.xyz += (lightProj * vec4(normal, 1.0)).xyz * bias;

    vec3 projLightSpace = lightSpace.xyz * 0.5 + 0.5;
    if (clamp(projLightSpace, 0.0, 1.0) == projLightSpace) {
        float closestDepth = unpackF32fromF8x4(texture(ShadowMapSampler, projLightSpace.xy));
        return vec3(projLightSpace.z, closestDepth, bias);
    }

    return vec3(-1.0, -1.0, 0.0);
}

bool checkOcclusion(vec3 projection, vec3 lightDir, vec3 normal) {
    float NdotL = dot(normal, lightDir);
    return projection.x - projection.z > projection.y;
}

float estimateVL(mat4 lightProj, vec3 fragPos, vec3 rayDirection, vec3 rayOrigin, vec3 normal, vec3 lightDir) {
    const int NUM_STEPS = 16;
    
    float rayLength = distance(fragPos, rayOrigin);

    float rayStep = rayLength / NUM_STEPS;
    vec3 rayPos = rayOrigin + rayDirection * rayStep * random(NoiseSampler, gl_FragCoord.xy, 0.0).x - offset;
    float accum = 0.0;

    for (int i = 0; i < NUM_STEPS; i++) {
        vec3 projection = projectShadowMap(lightProj, rayPos, normal);
        float t = checkOcclusion(projection, lightDir, normal) ? 0.0 : 1.0;
        accum += t;
        rayPos += rayDirection * rayStep;
    }
    
    accum /= float(NUM_STEPS);
    return accum;
}

void main() {
    if (shouldUpdate == 0) {
        return;
    }

    float depth = texture(DepthSampler, texCoord).r;
    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);
    vec3 pointOnNearPlane = near.xyz / near.w;

    vec4 shadow = texelFetch(ShadowSampler, ivec2(gl_FragCoord.x, max(1.0, gl_FragCoord.y)), 0);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;

    vec3 direction = normalize(fragPos - pointOnNearPlane);

    float translucentDepth = texture(TranslucentDepthSampler, texCoord).r;
    
    vec3 color;
    if (translucentDepth == 1.0) {
        color = sampleSkyLUT(SkySampler, direction, sunDirection) * sunIntensity;
    } else {
        float NdotL = dot(normal, sunDirection);

        vec3 albedo = srgbToLinear(texture(InSampler, texCoord).rgb);

        vec3 transmittance = sampleTransmittanceLUT(TransmittanceSampler, vec3(0.0, earthRadius + cameraHeight, 0.0) + fragPos, sunDirection);
        vec3 lightColor = transmittance * 1.2;

        vec3 diffuse = (albedo / PI); // Lambert
        diffuse *= clamp(NdotL, 0.0, 1.0) * 4.0 * lightColor * clamp(1.0 + min(0.0, sunDirection.y) * 200.0, 0.0, 1.0);

        float lightColorLength = length(lightColor);
        vec3 ambientColor = pow(sampleSkyLUT(SkySampler, vec3(0.000001, 1.0, 0.0), sunDirection), vec3(1.0 / 3.0)) * 5.0;
        vec3 ambient = albedo * pow(shadow.g, 1.5) * ambientColor * 0.33 * (lightColorLength + 0.13) * (-clamp(-NdotL, 0.0, 0.6) * 0.6 * lightColorLength + 1.0);

        // lame subsurface scattering "approximation"
        float halfLambert = pow(NdotL * 0.25 + 0.75, 1.0);
        vec3 subsurface = halfLambert * shadow.z * albedo * lightColor;

        color = vec3(0.0);
        color += mix(diffuse, subsurface, 0.6) * (1.0 - shadow.x);
        color += ambient;

        float linearDepth = linearizeDepth(depth * 2.0 - 1.0, planes);
        vec3 screenSpace = vec3(texCoord, (linearDepth - planes.x) / (planes.y - planes.x));
        vec3 aerialFrag = screenSpace * aerialPerspectiveResolution;
        ivec3 aerialCoord3 = ivec3(floor(aerialFrag));
        aerialCoord3.z -= 1;
        vec3 aerialFract = fract(aerialFrag);
        ivec2 aerialCoord = ivec2(aerialCoord3.z * aerialPerspectiveResolution.x + aerialCoord3.x, aerialCoord3.y * 2);
        ivec3 mask = ivec3(bvec3(aerialCoord3.x >= 0 && aerialCoord3.x != aerialPerspectiveResolution.x - 1,
                                aerialCoord3.y >= 0 && aerialCoord3.y != aerialPerspectiveResolution.y - 1,
                                aerialCoord3.z != aerialPerspectiveResolution.z - 1));

        mat2x3 z0 = mat2x3(vec3(0.0), vec3(1.0));
        if (aerialCoord3.z >= 0) {
            z0 = mixAerial(
                mixAerial(readAerialPerspective(aerialCoord + ivec2(0, 0)), readAerialPerspective(aerialCoord + ivec2(mask.x * 1, 0)), aerialFract.x),
                mixAerial(readAerialPerspective(aerialCoord + ivec2(0, mask.y * 2)), readAerialPerspective(aerialCoord + ivec2(mask.x * 1, mask.y * 2)), aerialFract.x),
                aerialFract.y
            );
        }
        mat2x3 z1 = mixAerial(
            mixAerial(readAerialPerspective(aerialCoord + ivec2(mask.z * aerialPerspectiveResolution.x, 0)), readAerialPerspective(aerialCoord + ivec2(mask.z * aerialPerspectiveResolution.x + mask.x * 1, 0)), aerialFract.x),
            mixAerial(readAerialPerspective(aerialCoord + ivec2(mask.z * aerialPerspectiveResolution.x, mask.y * 2)), readAerialPerspective(aerialCoord + ivec2(mask.z * aerialPerspectiveResolution.x + mask.x * 1, mask.y * 2)), aerialFract.x),
            aerialFract.y
        );
        mat2x3 aerial = mixAerial(z0, z1, aerialFract.z);

        float volumetricShadowing = estimateVL(shadowProjMat, fragPos, direction, pointOnNearPlane, normal, lightDir);
        
        color = color * aerial[1] + aerial[0] * sunIntensity * volumetricShadowing;
    }

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}
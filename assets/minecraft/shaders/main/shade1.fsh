#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:normals.glsl>
#moj_import <minecraft:random.glsl>
#moj_import <minecraft:ssrt.glsl>
#moj_import <minecraft:brdf.glsl>
#moj_import <settings:settings.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;
uniform sampler2D SkySampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D AerialPerspectiveSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D NoiseSampler;

uniform mat4 ModelViewMat;
uniform vec2 InSize;
uniform float GameTime;

in vec2 texCoord;
flat in vec3 sunDirection;
flat in mat4 projection;
flat in mat4 invProjection;
flat in mat4 invProjViewMat;
flat in vec2 planes;
flat in vec3 totalOffset;
flat in int shouldUpdate;
in vec4 near;

out vec4 fragColor;

void main() {
    if (shouldUpdate == 0) {
        return;
    }

    float depth = texture(DepthSampler, texCoord).r;
    float translucentDepth = texture(TranslucentDepthSampler, texCoord).r;

    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, depth);

    vec3 pointOnNearPlane = near.xyz / near.w;
    vec3 direction = normalize(fragPos - pointOnNearPlane);
    
    if (translucentDepth == 1.0) {
        fragColor = texture(InSampler, texCoord);
        return;
    }

    vec3 color = decodeLogLuv(texture(InSampler, texCoord));

    vec4 shadow = texelFetch(ShadowSampler, ivec2(gl_FragCoord.x, max(1.0, gl_FragCoord.y)), 0);

    float linearDepth = linearizeDepth(depth * 2.0 - 1.0, planes);
    float apLinearDepth = linearDepth;

    vec3 translucentColor = texture(TranslucentSampler, texCoord).rgb;

    if (translucentDepth < depth) {
        vec3 ambientColor = pow(sampleSkyLUT(SkySampler, vec3(0.0001, 1.0, 0.0), sunDirection), vec3(1.0 / 3.0));

        vec3 waterNormal = reconstructNormal(TranslucentDepthSampler, invProjViewMat, texCoord, InSize);

        vec3 viewSpacePos = unprojectScreenSpace(invProjection, texCoord, translucentDepth);

        vec2 wavePosition = (viewSpacePos * mat3(ModelViewMat)).xz + totalOffset.xz;

#if (ENABLE_WATER_WAVES == yes)
        if (translucentColor == vec3(0.0)) {
            waterNormal = waveNormal(wavePosition, GameTime * 2000.0 * WATER_WAVE_SPEED);
            waterNormal = mix(waterNormal, vec3(0.0, 1.0, 0.0), 1.0 - dot(-direction, vec3(0.0, 1.0, 0.0)));
        }
#endif // ENABLE_WATER_WAVES

        vec3 reflected = reflect(direction, waterNormal);
        float fresnel = pow(1.0 - clamp(dot(waterNormal, -direction), 0.0, 1.0), 5.0);
        float reflectance = mix(WATER_F0, WATER_F90, fresnel);

        vec3 viewDirection = mat3(ModelViewMat) * reflected;

        vec3 reflection = sampleSkyLUT(SkySampler, reflected, sunDirection) * sunIntensity;

        float linearDepthWater = linearizeDepth(translucentDepth * 2.0 - 1.0, planes);
        apLinearDepth = linearDepthWater;

#if (ENABLE_WATER_SSR == yes)
        vec2 hitPixel;
        vec3 hitPoint;
        bool hit = traceScreenSpaceRay(DepthSampler, projection, planes, InSize, viewSpacePos, viewDirection, float(WATER_SSR_STRIDE), random(NoiseSampler, gl_FragCoord.xy, 0).x, float(WATER_SSR_STEPS), 1.0e6, hitPixel, hitPoint);
        float hitDepth = texelFetch(DepthSampler, ivec2(hitPixel), 0).r;
        if (hit && hitDepth != 1.0) {
            vec2 hitTexCoord = hitPixel / InSize;
            vec3 screenSpaceReflection = decodeLogLuv(texture(InSampler, hitTexCoord));
            
            vec2 falloff = max(vec2(0.0), abs(hitTexCoord * 2.0 - 1.0) - 0.9) * 10.0;
            vec2 edgeFactor = max(vec2(0.0), abs(texCoord * 2.0 - 1.0) - 0.9) * 10.0;
            float alpha = max(falloff.x, falloff.y) - max(edgeFactor.x, edgeFactor.y);
            alpha = smoothstep(0.0, 1.0, clamp(alpha, 0.0, 1.0));

            float apOffset = (1.0 - alpha) * distance(unprojectScreenSpace(invProjection, hitTexCoord, hitDepth), viewSpacePos);
            apLinearDepth += pow(apOffset, 1.0 / 1.3);
            apLinearDepth = clamp(apLinearDepth, planes.x, planes.y);

            reflection = mix(screenSpaceReflection, reflection, alpha);
        }
#endif // ENABLE_WATER_SSR

        vec3 waterTransmittance = exp(-WATER_ABSORPTION * (linearDepth - linearDepthWater));
        vec3 waterColor = ambientColor * WATER_COLOR;

        color = color * waterTransmittance + waterColor * (1.0 - waterTransmittance);
        color = mix(color, reflection, reflectance);
    }

#if (ENABLE_AERIAL_PERSPECTIVE == yes)
    mat2x3 aerial = sampleAerialPerspectiveLUT(AerialPerspectiveSampler, texCoord, apLinearDepth, planes);

#if (ENABLE_VOLUMETRIC_SHADOWS == yes)
    float volumetricShadowing = shadow.w;
#else
    const float volumetricShadowing = 1.0;
#endif // ENABLE_VOLUMETRIC_SHADOWS

    color = color * aerial[1] + aerial[0] * sunIntensity * volumetricShadowing;
#endif // ENABLE_AERIAL_PERSPECTIVE

    fragColor = encodeLogLuv(color);
}
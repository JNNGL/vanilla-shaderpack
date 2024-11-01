#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:light.glsl>
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:lightmap.glsl>
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat4 TextureMat;
uniform float FogStart;
uniform int FogShape;
uniform float GameTime;
uniform vec2 ScreenSize;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

out float vertexDistance;
out vec4 vertexColor;
out vec4 vanillaLighting;
out vec4 lightMapColor;
out vec4 overlayColor;
out vec2 texCoord0;
out float isGUI;
out float isHand;
flat out ivec2 atlasDim;
out vec3 handDiffuse;
out vec2 lmCoord;
out vec3 fragPos;
flat out int quadId;
flat out int isPBR;

float halton(int i, int b) {
    float f = 1.0;
    float r = 0.0;

    while (i > 0) {
        f /= float(b);
        r  += f * float(i % b);
        i = int(floor(float(i) / float(b)));
    }

    return r;
}

void main() {
    quadId = gl_VertexID / 4;

    lmCoord = vec2(UV2);
    fragPos = Position;

    vec4 atlasData = texelFetch(Sampler0, ivec2(0, 0), 0);
    ivec2 dimLog2 = ivec2(atlasData.xy * 255.0);
    atlasDim = ivec2(round(pow(vec2(2.0), vec2(dimLog2))));

    isHand = float(FogStart > 3e38 && ProjMat[2][3] != 0.0);
    isGUI = float(ProjMat[2][3] == 0.0 || isHand > 0.0);

    isPBR = int(ivec4(round(texelFetch(Sampler0, ivec2(1, 0), 0) * 255.0)) == ivec4(90, 187, 3, 120));

    handDiffuse = vec3(0.0);
    if (isHand > 0.0) {
        vec3 position = vec3(0.0, earthRadius + cameraHeight, 0.0);

        vec3 sunDirection;
        float skyFactor = getSkyFactor(Sampler2);
        if (skyFactor > 0.24 && skyFactor < 1.0) {
            float x = acos(0.5 * (((skyFactor - 0.05) / 0.95 - 0.2) / 0.8) - 0.1);
            float alpha = 2.0 * PI - x;

            sunDirection = rotateAroundZMatrix(3.0 * PI / 2.0 - alpha) * vec3(1.0, 0.0, 0.0);
            sunDirection = sunRotationMatrix * sunDirection;
        } else {
            sunDirection = sunRotationMatrix * normalize(vec3(0.0, 1.0, 0.5));
        }

        float travelDistance = distanceToAtmosphereBoundary(position, sunDirection);
        vec3 transmittance = computeTransmittanceToBoundary(position, sunDirection, travelDistance, 6);

        vec3 lightColor = transmittance * LIGHT_COLOR_MULTIPLIER;
        vec3 radiance = 4.0 * lightColor * clamp(1.0 + min(0.0, sunDirection.y) * 200.0, 0.0, 1.0);            
        float NdotL = dot(mat3(ModelViewMat) * Normal, normalize(vec3(0.0, 1.7, 1.0)));

        handDiffuse += (1.0 / PI) * clamp(NdotL, 0.0, 1.0) * radiance * length(transmittance);
        handDiffuse += 0.3 * dot(transmittance, transmittance) * vec3(70, 90, 115) / 255.0;
    }

    vertexDistance = fog_distance(Position, FogShape);
    vertexColor = Color;
    lightMapColor = vec4(1.0);
    overlayColor = texelFetch(Sampler1, UV1, 0);

#ifdef NO_CARDINAL_LIGHTING
    vanillaLighting = Color;
#else
    vanillaLighting = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
#endif

    texCoord0 = UV0;
#ifdef APPLY_TEXTURE_MATRIX
    texCoord0 = (TextureMat * vec4(UV0, 0.0, 1.0)).xy;
#endif

    int jitterIndex = int(hash(floatBitsToUint(GameTime)) % 8u);
    float haltonX = 2.0 * halton(jitterIndex + 1, 2) - 1.0;
    float haltonY = 2.0 * halton(jitterIndex + 1, 3) - 1.0;

    mat4 jitteredProj = ProjMat;
    if (isGUI < 0.5) {
        jitteredProj[2][0] += haltonX / ScreenSize.x;
        jitteredProj[2][1] += haltonY / ScreenSize.y;
    }

    gl_Position = jitteredProj * ModelViewMat * vec4(Position, 1.0);
}

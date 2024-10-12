#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:atmosphere.glsl>
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:projections.glsl>

uniform sampler2D TransmittanceSampler;
uniform sampler2D MultipleScatteringSampler;

flat in vec3 lightDirection;
flat in mat4 invProjViewMat;
flat in vec2 planes;

out vec4 fragColor;

void main() {
    ivec2 fragCoord = ivec2(gl_FragCoord.xy);

    int x = fragCoord.x % aerialPerspectiveResolution.x;
    int y = fragCoord.y / 2;
    int z = fragCoord.x / aerialPerspectiveResolution.x + 1;
    int index = fragCoord.y % 2;

    vec3 screenSpace = vec3(x, y, z) / vec3(aerialPerspectiveResolution);
    float linearDepth = screenSpace.z * (planes.y - planes.x) + planes.x;
    vec3 ndc = screenSpace * 2.0 - 1.0;
    ndc.z = unlinearizeDepth(linearDepth, planes);
    vec3 froxelPosition = projectAndDivide(invProjViewMat, ndc);

    vec4 nearHomog = getPointOnNearPlane(invProjViewMat, ndc.xy);
    vec3 near = nearHomog.xyz / nearHomog.w;

    vec3 position = near + vec3(0.0, earthRadius + cameraHeight, 0.0);
    vec3 froxelOffset = froxelPosition - near;
    float travelDistance = length(froxelOffset);
    vec3 direction = froxelOffset / travelDistance;

    mat2x3 atmosphericScattering = raymarchAtmosphericScattering(TransmittanceSampler, MultipleScatteringSampler, position, direction, lightDirection, travelDistance * aerialPerspectiveScale);

    vec3 value = atmosphericScattering[index];
    fragColor = packR11G11B10LtoF8x4(index == 0 ? sqrt(value) : value * value);
}
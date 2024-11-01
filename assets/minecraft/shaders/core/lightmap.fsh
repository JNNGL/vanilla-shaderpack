#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:encodings.glsl>

uniform float AmbientLightFactor;
uniform float SkyFactor;
uniform float BlockFactor;
uniform int UseBrightLightmap;
uniform vec3 SkyLightColor;
uniform float NightVisionFactor;
uniform float DarknessScale;
uniform float DarkenWorldFactor;
uniform float BrightnessFactor;

out vec4 fragColor;

float getFloat(int index) {
    switch (index) {
        case 0: return AmbientLightFactor;
        case 1: return SkyFactor;
        case 2: return BlockFactor;
        case 3: return float(UseBrightLightmap);
        case 4: return SkyLightColor[0];
        case 5: return SkyLightColor[1];
        case 6: return SkyLightColor[2];
        case 7: return NightVisionFactor;
        case 8: return DarknessScale;
        case 9: return DarkenWorldFactor;
        case 10: return BrightnessFactor;
    }
    return 0.0;
}

void main() {
    if (int(gl_FragCoord.y) == 15) {
        fragColor = vec4(1.0);
        return;
    }

    int index = int(floor(gl_FragCoord.y) * 16.0 + floor(gl_FragCoord.x));
    float value = getFloat(index);
    fragColor = packF32toF8x4(value);
}
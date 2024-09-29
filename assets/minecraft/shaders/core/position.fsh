#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:fog.glsl>

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;

out vec4 fragColor;

void main() {
    vec4 color = ColorModulator;
	if (color.a < 1.0) { 
		discard;
    }

    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}

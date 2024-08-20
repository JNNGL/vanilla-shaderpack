#version 150

#moj_import <fog.glsl>

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform float GameTime;

in float vertexDistance;
in vec4 position;

out vec4 fragColor;

void main() {
	vec4 color = ColorModulator;
	if (color.a < 1.0) { 
		discard;
    }
	
	fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}
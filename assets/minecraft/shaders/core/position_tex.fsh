#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:datamarker.glsl>
#moj_import <minecraft:shadow.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

#ifdef TEX_COLOR
in vec2 texCoord0;
in vec4 vertexColor;
#endif
in float isSun;
in vec4 position0;
in vec4 position1;

out vec4 fragColor;

void main() {
    if (isSun > 0.0) {
        vec3 p0 = position0.xyz / position0.w;
        vec3 p1 = position1.xyz / position1.w;

        vec3 sunDirection = sunRotationMatrix * normalize(mix(p0, p1, 0.5));
        if (overlaySunData(gl_FragCoord.xy, fragColor, sunDirection)) {
            return;
        }

        discard;
    }

#ifdef TEX_COLOR
    vec4 color = texture(Sampler0, texCoord0) * vertexColor;
    if (color.a == 0.0) {
        discard;
    }
    fragColor = color * ColorModulator;
#endif
}
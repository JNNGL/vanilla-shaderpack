#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:tonemapping/aces.glsl>
#moj_import <minecraft:projections.glsl>
#moj_import <minecraft:srgb.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;

in vec2 texCoord;
flat in vec3 lightDir;
flat in mat4 invProjViewMat;

out vec4 fragColor;

void main() {
    vec3 fragPos = unprojectScreenSpace(invProjViewMat, texCoord, texture(DepthSampler, texCoord).r);

    vec4 shadow = texelFetch(ShadowSampler, ivec2(gl_FragCoord.x, max(1.0, gl_FragCoord.y)), 0);
    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    
    if (dot(normal, normal) < 0.01) {
        vec4 data = texture(InSampler, texCoord);
        vec3 color = data.rgb;

        color = color * color * 1.5;
        color = acesFitted(color);
        color = linearToSrgb(color);

        fragColor = vec4(color, 1.0);
        return; 
    }

    float NdotL = dot(normal, lightDir);

    vec3 color = srgbToLinear(texture(InSampler, texCoord).rgb);

    vec3 sunColor = vec3(255.0 / 255.0, 167.0 / 255.0, 125.0 / 255.0) * 3.0;
    vec3 ambient = vec3(0.1621, 0.1919, 0.2094) * 2.0 * shadow.g * (-max(-NdotL, 0.0) * 0.5 + 1.0);
    vec3 directional = sunColor * (1.0 - shadow.r) * max(0.0, NdotL);
    vec3 subsurface = shadow.b * sunColor * 0.5;
    color *= (ambient + directional + subsurface) * shadow.g;

    // color += shadow.a * sunColor * 0.8;

    color = acesFitted(color);
    color = linearToSrgb(color);

    fragColor = vec4(color, 1.0);
}
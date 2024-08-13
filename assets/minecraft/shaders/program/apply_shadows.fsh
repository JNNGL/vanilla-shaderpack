#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D ShadowSampler;
uniform sampler2D NormalSampler;

in vec2 texCoord;
flat in vec3 shadowEye;
flat in mat4 invViewProj;

out vec4 fragColor;

vec3 getPositionWorldSpace(vec2 uv, float z) {
    vec4 positionClip = vec4(uv, z, 1.0) * 2.0 - 1.0;
    vec4 positionWorld = invViewProj * positionClip;
    return positionWorld.xyz / positionWorld.w;
}

vec3 acesFilm(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

vec3 acesInverse(vec3 x) {
    return (sqrt(-10127.0 * x * x + 13702.0 * x + 9.0) + 59.0 * x - 3.0) / (502.0 - 486.0 * x);
}

vec3 applyFog( in vec3  col,   // color of pixel
               in float t,     // distance to point
               in vec3  rd,    // camera to point
               in vec3  lig )  // sun direction
{
    float fogAmount = 1.0 - exp(-pow(t*0.0015, 2));
    float sunAmount = max( dot(rd, lig), 0.0 );
    vec3  fogColor  = mix( vec3(0.5,0.6,0.7), // blue
                           vec3(1.0,0.9,0.7), // yellow
                           pow(sunAmount,8.0) )*5;
    return mix( col, fogColor, fogAmount );
}

void main() {
    vec3 fragPos = getPositionWorldSpace(texCoord, texture(DiffuseDepthSampler, texCoord).r);

    vec3 normal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    vec3 lightDir = normalize(shadowEye);

    if (dot(normal, normal) < 0.01) {
        vec3 color = texture(DiffuseSampler, texCoord).rgb;
        color = pow(color, vec3(2.2));
        color = acesInverse(color);
        color *= pow(color.r / color.b, 1.1) * 80.0;
        color = acesFilm(color);
        color = pow(color, vec3(1.0 / 2.2));
        fragColor = vec4(color, 1.0);
        return;
    }

    vec4 shadow = texture(ShadowSampler, texCoord);
    float wSum = 1.0;

    vec3 centerNormal = texture(NormalSampler, texCoord).rgb * 2.0 - 1.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) continue;
            vec2 offset = vec2(float(x), float(y));
            ivec2 coord = ivec2(gl_FragCoord.xy + offset);
            vec3 normal = texelFetch(NormalSampler, coord, 0).rgb * 2.0 - 1.0;
            vec4 sample = texelFetch(ShadowSampler, coord, 0);
            if (dot(normal, centerNormal) < 0.8) continue;
            shadow += sample;
            wSum += 1.0;
        }
    }

    shadow /= wSum;

    float NdotL = dot(normal, lightDir);

    vec3 color = pow(texture(DiffuseSampler, texCoord).rgb, vec3(2.2));

    vec3 ambient = vec3(0.10435, 0.14235, 0.19934) * 1.7 * pow(shadow.g, 2.0);
    vec3 directional = vec3(0.9, 0.55, 0.4) * 1.9 * (1.0 - shadow.r) * max(0.0, NdotL);
    vec3 subsurface = shadow.b * vec3(0.9, 0.55, 0.4) * sqrt(color);

    color *= (ambient + directional + subsurface);

    color = applyFog(color, length(fragPos), normalize(fragPos), lightDir);

    color = acesFilm(color * 2.0);
    color = pow(color, vec3(1.0 / 2.2));

    fragColor = vec4(color, 1.0);

    fragColor.rgb = vec3(shadow.g);
}
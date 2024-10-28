#version 330

#extension GL_MC_moj_import : enable
#moj_import <normals.glsl>
#moj_import <encodings.glsl>
#moj_import <atlas.glsl>

uniform sampler2D DepthSampler;
uniform sampler2D TangentSampler;
uniform sampler2D UvSampler;
uniform sampler2D AtlasSampler;

uniform vec2 OutSize;

in vec2 texCoord;
flat in mat4 invProjViewMat;

out vec4 fragColor;

void main() {
    vec3 normal = reconstructNormal(DepthSampler, invProjViewMat, texCoord, OutSize);
    vec3 normalMapped = normal;

    vec4 tangentEncoded = texture(TangentSampler, texCoord);
    vec4 uv = texture(UvSampler, texCoord);

    float ao = 1.0;
    if (tangentEncoded.a != 1.0 && uv.a != 1.0 && (int(uv.a * 255.0) >> 4) != 15 && dot(normal, normal) > 0.0001) {
        vec3 tangent = decodeDirectionFromF8(tangentEncoded.z);
        vec4 normalMapping = sampleCombinedAtlas(AtlasSampler, uv, ATLAS_NORMAL);
        if (normalMapping != vec4(0.0)) {
            normalMapping.xy = normalMapping.xy * 2.0 - 1.0;
            normalMapping.z = sqrt(1.0 - dot(normalMapping.xy, normalMapping.xy));

            mat3 tbn = mat3(tangent, cross(tangent, normal), normal);
            normalMapped = tbn * normalMapping.xyz;

            ao = normalMapping.z;
        }
    }

    fragColor = vec4(encodeDirectionToF8x2(normalMapped), encodeDirectionToF8(normal), ao);
}
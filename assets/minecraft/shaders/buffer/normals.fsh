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

    vec4 tangentEncoded = texture(TangentSampler, texCoord);
    vec4 uv = texture(UvSampler, texCoord);

    if (tangentEncoded.a != 1.0 && uv.a != 1.0 && dot(normal, normal) > 0.0001) {
        vec3 tangent = decodeDirectionFromF8(tangentEncoded.z);
        vec3 normalMapping = sampleCombinedAtlas(AtlasSampler, uv.rgb, ATLAS_NORMAL).xyz;
        normalMapping.xy = normalMapping.xy * 2.0 - 1.0;
        normalMapping.z = sqrt(1.0 - dot(normalMapping.xy, normalMapping.xy));

        mat3 tbn = mat3(tangent, cross(tangent, normal), normal);
        normal = tbn * normalMapping;
    }

    fragColor = vec4(normal * 0.5 + 0.5, 1.0);
}
#version 330

#extension GL_MC_moj_import : enable
#moj_import <minecraft:constants.glsl>
#moj_import <minecraft:light.glsl>
#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:shadow.glsl>
#moj_import <minecraft:waving.glsl>
#moj_import <minecraft:lightmap.glsl>
#moj_import <minecraft:projections.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ModelOffset;
uniform int FogShape;
uniform float GameTime;
uniform vec2 ScreenSize;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec4 normal;
flat out mat4 jitteredProj;
flat out int dataQuad;
flat out int shadow;
flat out float skyFactor;
flat out int quadId;
out vec2 lmCoord;
out vec3 fragPos;
out vec4 glPos;
flat out ivec2 atlasDim;
out vec3 texBound0;
out vec3 texBound1;
flat out vec2 planes;

// out float isSphere;
// flat out mat4 projView;
// flat out mat4 invProjView;
// out vec4 corner0;
// out vec4 corner1;

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
    ivec4 col = ivec4(round(texture(Sampler0, UV0) * 255.0));
    vec3 pos = Position + ModelOffset;
    dataQuad = col.rgb == ivec3(76, 195, 86) ? 1 : 0;
    fragPos = pos;

    vec4 atlasData = texelFetch(Sampler0, ivec2(0, 0), 0);
    ivec2 dimLog2 = ivec2(atlasData.xy * 255.0);
    atlasDim = ivec2(round(pow(vec2(2.0), vec2(dimLog2))));

    quadId = gl_VertexID / 8;
    lmCoord = vec2(UV2);

    // texBound0 = texBound1 = vec3(0.0);
    // corner0 = corner1 = vec4(0.0);
    // switch (gl_VertexID % 4) {
    //     case 0: texBound0 = vec3(UV0, 1.0); corner0 = vec4(Position, 1.0); break;
    //     case 2: texBound1 = vec3(UV0, 1.0); corner1 = vec4(Position, 1.0); break;
    // }

    vec3 worldPos = pos;

    int alpha = int(textureLod(Sampler0, UV0, -4).a * 255.0);
    if (alpha == 251 || alpha == 4) {
        worldPos = applyWaving(worldPos, GameTime);
    }

    int jitterIndex = int(hash(floatBitsToUint(GameTime)) % 8u);
    float haltonX = 2.0 * halton(jitterIndex + 1, 2) - 1.0;
    float haltonY = 2.0 * halton(jitterIndex + 1, 3) - 1.0;
    
    jitteredProj = ProjMat;
    jitteredProj[2][0] += haltonX / ScreenSize.x;
    jitteredProj[2][1] += haltonY / ScreenSize.y;

    // isSphere = 0.0;
    // int subX = col.x & 0xF;
    // int subY = col.y & 0xF;
    // int index = ((col.x & 0xF0) | (col.y >> 4)) * 256 + col.z;
    // int baseX = (index * 16) % atlasDim.x;
    // int baseY = ((index * 16) / atlasDim.x) * 16;
    // ivec2 texCoord = ivec2(baseX + subX, baseY + subY);
    // ivec4 texColor = ivec4(round(texelFetch(Sampler0, texCoord, 0) * 255.0));
    // if (texColor.rgb == ivec3(226, 22, 8) || texColor.rgb == ivec3(91, 230, 42) || texColor.rgb == ivec3(42, 78, 230) || texColor.rgb == ivec3(237, 229, 228)) {
    //     isSphere = 1.0;
    //     projView = jitteredProj * ModelViewMat;
    //     invProjView = inverse(projView);
    // }

    gl_Position = jitteredProj * ModelViewMat * vec4(worldPos, 1.0);
    glPos = gl_Position;

    shadow = 0;
    skyFactor = getSkyFactor(Sampler2);

    if (isShadowMapFrame(GameTime)) {
        if (ModelOffset == vec3(0.0)) {
            gl_Position = GLPOS_DISCARD;
            return;
        }

        mat4 proj = shadowProjectionMatrix();
        mat4 view = shadowTransformationMatrix(skyFactor, GameTime);

        pos -= fract(ModelOffset);
        gl_Position = proj * view * vec4(pos, 1.0);
        glPos = gl_Position;
        gl_Position = distortShadow(gl_Position);

        // if (isSphere > 0) {
        //     projView = proj * view;
        //     invProjView = inverse(projView);
        // }
        
        shadow = 1;
    }

    vertexDistance = fog_distance(worldPos, FogShape);
    vertexColor = Color;
    texCoord0 = UV0;
    normal = vec4(Normal, 0.0);

    if (dataQuad > 0) {
        if (ModelOffset == vec3(0.0)) {
            gl_Position = GLPOS_DISCARD;
            return;
        }

        vec2 bottomLeftCorner = vec2(-1.0, -1.0);
        vec2 topRightCorner = vec2(-0.9, -0.995);

        switch (gl_VertexID % 4) {
            case 0: gl_Position = vec4(bottomLeftCorner.x, topRightCorner.y,   -1.0, 1.0); break;
            case 1: gl_Position = vec4(bottomLeftCorner.x, bottomLeftCorner.y, -1.0, 1.0); break;
            case 2: gl_Position = vec4(topRightCorner.x,   bottomLeftCorner.y, -1.0, 1.0); break;
            case 3: gl_Position = vec4(topRightCorner.x,   topRightCorner.y,   -1.0, 1.0); break;
        }
    }

    planes = getPlanes(ProjMat);
}
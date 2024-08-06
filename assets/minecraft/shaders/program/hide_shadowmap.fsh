#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D PreviousDiffuseSampler;

uniform vec2 InSize;

flat in int part;

out vec4 fragColor;

const ivec2 shadowOffsets[] = ivec2[](ivec2(0, 0), ivec2(1, 1), ivec2(1, 0), ivec2(0, 1));

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    fragColor = texelFetch(DiffuseSampler, coord, 0);
    if (coord.x <= InSize.x && coord.y <= InSize.y) {
        if (((coord + shadowOffsets[part]) % 2) == ivec2(0, 0)) {
            bool canReuse = true;
            if (texelFetch(PreviousDiffuseSampler, coord - ivec2(1, 0), 0) != texelFetch(DiffuseSampler, coord - ivec2(1, 0), 0)) canReuse = false;
            if (texelFetch(PreviousDiffuseSampler, coord - ivec2(0, 1), 0) != texelFetch(DiffuseSampler, coord - ivec2(0, 1), 0)) canReuse = false;
            if (texelFetch(PreviousDiffuseSampler, coord + ivec2(1, 0), 0) != texelFetch(DiffuseSampler, coord + ivec2(1, 0), 0)) canReuse = false;
            if (texelFetch(PreviousDiffuseSampler, coord + ivec2(0, 1), 0) != texelFetch(DiffuseSampler, coord + ivec2(0, 1), 0)) canReuse = false;
            fragColor = texelFetch(PreviousDiffuseSampler, coord, 0);
            if (!canReuse) {
                fragColor = texelFetch(DiffuseSampler, coord - ivec2(0, 1), 0);
                fragColor += texelFetch(DiffuseSampler, coord - ivec2(1, 0), 0);
                // fragColor += texelFetch(DiffuseSampler, coord + ivec2(0, 1), 0);
                // fragColor += texelFetch(DiffuseSampler, coord + ivec2(1, 0), 0);
                // fragColor *= 0.25;
                fragColor *= 0.5;
            }
            // return;
        }
    }
}
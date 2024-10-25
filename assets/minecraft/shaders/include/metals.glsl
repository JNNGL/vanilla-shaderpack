#version 330

#ifndef _METALS_GLSL
#define _METALS_GLSL

const mat2x3 HARDCODED_METALS[] = mat2x3[](
    mat2x3(vec3(2.9114, 2.9497, 2.5845), vec3(3.0893, 2.9318, 2.7670)), // Iron
    mat2x3(vec3(0.18299, 0.42108, 1.3734), vec3(3.4242, 2.3459, 1.7704)), // Gold
    mat2x3(vec3(1.3456, 0.96521, 0.61722), vec3(7.4746, 6.3995, 5.3031)), // Aluminum
    mat2x3(vec3(3.1071, 3.1812, 2.3230), vec3(3.3314, 3.3291, 3.1350)), // Chrome
    mat2x3(vec3(0.27105, 0.67693, 1.3164), vec3(3.6092, 2.6248, 2.2921)), // Copper
    mat2x3(vec3(1.9100, 1.8300, 1.4400), vec3(	3.5100, 3.4000, 3.1800)), // Lead
    mat2x3(vec3(2.3757, 2.0847, 1.8453), vec3(4.2655, 3.7153, 3.1365)), // Platinum
    mat2x3(vec3(0.15943, 0.14512, 0.13547), vec3(3.9291, 3.1900, 2.3808)) // Silver
);

#endif // _METALS_GLSL
#version 330

#ifndef _MATRICES_GLSL
#define _MATRICES_GLSL

mat3 constructTBN(vec3 normal) {
    vec3 tangent = normalize(cross(normal, vec3(0.0, 1.0, 1.0)));
    vec3 bitangent = cross(normal, tangent);
    return mat3(tangent, bitangent, normal);
}

mat4 orthographicProjectionMatrix(float left, float right, float bottom, float top, float near, float far) {
    return mat4(
        2.0 / (right - left), 0.0, 0.0, 0.0,
        0.0, 2.0 / (top - bottom), 0.0, 0.0,
        0.0, 0.0, -2.0 / (far - near), 0.0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0
    );
}

mat4 lookAtTransformationMatrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 u = normalize(up);
    vec3 s = normalize(cross(f, u));
    u = cross(s, f);

    mat4 result = mat4(1.0);
    result[0][0] = s.x;
    result[1][0] = s.y;
    result[2][0] = s.z;
    result[0][1] = u.x;
    result[1][1] = u.y;
    result[2][1] = u.z;
    result[0][2] = -f.x;
    result[1][2] = -f.y;
    result[2][2] = -f.z;
    result[3][0] = -dot(s, eye);
    result[3][1] = -dot(u, eye);
    result[3][2] = dot(f, eye);
    return result;
}

mat3 rotateAroundZMatrix(float theta) {
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return mat3(
        cosTheta, -sinTheta, 0.0, 
        sinTheta, cosTheta, 0.0,
        0.0, 0.0, 1.0
    );
}

#define MAT3_ROTATE_X(alpha) mat3(1.0, 0.0, 0.0, 0.0, cos(alpha), sin(alpha), 0.0, -sin(alpha), cos(alpha))
#define MAT3_ROTATE_Y(alpha) mat3(cos(alpha), 0.0, -sin(alpha), 0.0, 1.0, 0.0, sin(alpha), 0.0, cos(alpha))

#endif // _MATRICES_GLSL
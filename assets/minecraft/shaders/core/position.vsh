#version 330

in vec3 Position;

uniform mat4 ProjMat;

void main() {
    gl_Position = ProjMat * vec4(Position.xz, -Position.y, 1.0);
}
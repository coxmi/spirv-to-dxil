// glsl triangle vertex shader. pass-through form so it lowers to all four
// targets (avoids std140 uniform blocks / mat row-major quirks).

#version 450
precision highp float;

layout(location = 0) in vec3 inPosition;
layout(location = 0) out vec3 vColor;

void main() {
    gl_Position = vec4(inPosition, 1.0);
    vColor = inPosition;
}
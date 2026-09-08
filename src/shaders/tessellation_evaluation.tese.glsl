// glsl tessellation evaluation shader. barycentrically interpolates the
// control point from gl_TessCoord across the triangle patch. same target
// story as the control shader: spirv + metal, hlsl fails in spirv-cross.

#version 450

layout(triangles, equal_spacing, ccw) in;

layout(location = 0) in vec3 tePos[];
layout(location = 0) out vec3 fCol;

void main() {
    vec3 p = tePos[0] * gl_TessCoord.x +
             tePos[1] * gl_TessCoord.y +
             tePos[2] * gl_TessCoord.z;
    gl_Position = vec4(p, 1.0);
    fCol = p * 0.5 + 0.5;
}
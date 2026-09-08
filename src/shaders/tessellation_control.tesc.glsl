// glsl tessellation control shader. sets per-patch tess levels and forwards
// a single control point along the pipeline. lowers to spirv + metal; hlsl
// fails in spirv-cross on the gl_TessCoord-family builtins (see tests).

#version 450

layout(vertices = 3) out;

layout(location = 0) in vec3 tcPos[];
layout(location = 0) out vec3 tePos[];

void main() {
    tePos[gl_InvocationID] = tcPos[gl_InvocationID];
    gl_out[gl_InvocationID].gl_Position = vec4(tcPos[gl_InvocationID], 1.0);
    if (gl_InvocationID == 0) {
        gl_TessLevelOuter[0] = 4.0;
        gl_TessLevelOuter[1] = 4.0;
        gl_TessLevelOuter[2] = 4.0;
        gl_TessLevelInner[0] = 4.0;
    }
}
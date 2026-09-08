// glsl compute shader writing to a bindless storage-image array via a
// nonuniform runtime index. exercises bindless_image_store on dxil (UAV
// descriptor-heap indexing) and storage-image arrays on hlsl/msl.

#version 450
precision highp float;
#extension GL_EXT_nonuniform_qualifier : require

layout(local_size_x = 32) in;
layout(set = 0, binding = 0, rgba8) uniform image2D img[];
layout(set = 0, binding = 1) buffer BindlessIdx {
    uint id;
} b;

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    imageStore(img[nonuniformEXT(b.id)], p, vec4(1.0));
}
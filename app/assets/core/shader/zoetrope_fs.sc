$input vWorldPos, vNormal, vTexCoord0, vTexCoord1, vTangent, vBinormal

#include <forward_pipeline.sh>

// Surface attributes
uniform vec4 uDiffuseColor;

// Texture slot
SAMPLER2D(uPackedImage, 3);

#define FRAMERATE 15.0

// Utility function to remap values
float remap(float value, float low1, float high1, float low2, float high2) {
    return low2 + (value - low1) * (high2 - low2) / (high1 - low1);
}

// Main entry point for the fragment shader
void main() {
    vec3 diff = uDiffuseColor.xyz;

    // Fragment world position
    vec3 P = vWorldPos; 
    vec3 N = normalize(vNormal); // Geometry normal

    // Calculate the frame index based on FRAMERATE
    float time_in_seconds = uClock.x; // Time from the uniform, in seconds
    float frame_duration = 1.0 / FRAMERATE; // Duration of each frame
    float frame_index = mod(floor(time_in_seconds / frame_duration), 256.0); // Current frame (0–255)
    
    // Determine the RGBA channel and UV coordinates
    int channel = int(floor(frame_index / 64.0)); // Determine the RGBA channel
    vec2 grid_coord = vec2(mod(frame_index, 8.0), floor(mod(frame_index, 64.0) / 8.0)); // 8x8 grid
    vec2 tex_coord = (grid_coord + vTexCoord0.xy) * (1.0 / 8.0); // Scale to grid UVs

    // Sample the texture and extract the appropriate channel
    vec4 packed_data = texture2D(uPackedImage, tex_coord);
    float intensity = 0.0;
    if (channel == 0) {
        intensity = packed_data.r; // Red channel
    } else if (channel == 1) {
        intensity = packed_data.g; // Green channel
    } else if (channel == 2) {
        intensity = packed_data.b; // Blue channel
    } else if (channel == 3) {
        intensity = packed_data.a; // Alpha channel
    }

    // Final color computation
    vec3 color = diff * intensity;
    gl_FragColor = vec4(color, 1.0); // Output the color with full alpha
}

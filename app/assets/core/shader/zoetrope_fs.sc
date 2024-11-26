$input vWorldPos, vNormal, vTexCoord0, vTexCoord1, vTangent, vBinormal

#include <forward_pipeline.sh>

// Surface attributes
uniform vec4 uDiffuseColor;

// Texture slot
SAMPLER2D(uPackedImage, 3);

// Define the framerate
#define FRAMERATE 24.0

// Function to compute intensity from the packed texture
float getPackedIntensity(vec2 baseTexCoord, float time)
{
    // Calculate the frame index based on FRAMERATE
    float frame_duration = 1.0 / FRAMERATE; // Duration of each frame
    float frame_index = mod(floor(time / frame_duration), 256.0); // Current frame

    // Determine the RGBA channel and UV coordinates
    int channel = int(floor(frame_index / 64.0)); // Determine the RGBA channel
    vec2 grid_coord = vec2(mod(frame_index, 8.0), floor(mod(frame_index, 64.0) / 8.0)); // 8x8 grid
    vec2 tex_coord = (grid_coord + baseTexCoord) * (1.0 / 8.0); // Scale to grid UVs

    // Sample the texture and extract the appropriate channel
    vec4 packed_data = texture2D(uPackedImage, tex_coord);
    if (channel == 0) return packed_data.r; // Red channel
    if (channel == 1) return packed_data.g; // Green channel
    if (channel == 2) return packed_data.b; // Blue channel
    return packed_data.a; // Alpha channel
}

// Main entry point for the fragment shader
void main() {
    vec3 diff = uDiffuseColor.xyz;

    // Fragment world position
    vec3 P = vWorldPos; 
    vec3 N = normalize(vNormal); // Geometry normal

    // Get the intensity from the packed texture
    float intensity = getPackedIntensity(vTexCoord0.xy, uClock.x);

    // Final color computation
    vec3 color = diff * intensity;
    gl_FragColor = vec4(color, 1.0); // Output the color with full alpha
}

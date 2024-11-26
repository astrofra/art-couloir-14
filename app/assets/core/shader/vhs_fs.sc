$input vWorldPos, vNormal, vTexCoord0, vTexCoord1, vTangent, vBinormal

#include <forward_pipeline.sh>

#define SAMPLE_WIDTH 20

float	EaseInOutQuick(float x)
{
	x = clamp(x, 0.0, 1.0);
	return	(x * x * (3.0 - 2.0 * x));
}

vec3 SimpleReinhardToneMapping(vec3 color, float exposure) { // 1.5
	color.x = mix(color.x, EaseInOutQuick(color.x), 0.5);	
	color.y = pow(color.y, 1.25);
	color.z = pow(color.z, 1.5);
	color = pow(color, 0.9);
	color *= exposure / (1. + color / exposure);
	return color;
}

vec3 _RGB2YUV(vec3 rgbColor) {
    float y = 0.299 * rgbColor.r + 0.587 * rgbColor.g + 0.114 * rgbColor.b;
    float u = -0.14713 * rgbColor.r - 0.28886 * rgbColor.g + 0.436 * rgbColor.b;
    float v = 0.615 * rgbColor.r - 0.51499 * rgbColor.g - 0.10001 * rgbColor.b;

	return vec3(y,u,v);
}

vec3 _YUV2RGB(vec3 yuvColor) {
    float r = yuvColor.x + 1.13983 * yuvColor.z;
    float g = yuvColor.x - 0.39465 * yuvColor.y - 0.58060 * yuvColor.z;
    float b = yuvColor.x + 2.03211 * yuvColor.y;

    return vec3(r, g, b);
}

// Surface attributes
uniform vec4 uDiffuseColor;
uniform vec4 uCustom;
uniform vec4 uControl; // VHS FX -> x : noise_intensity, y : chroma_distortion, z : time offset

// Texture slots
SAMPLER2D(uDiffuseMap, 0); // Photo
SAMPLER2D(uSelfMap, 4); // Video FX

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
    vec4 packed_data = texture2D(uSelfMap, tex_coord);
    if (channel == 0) return packed_data.r; // Red channel
    if (channel == 1) return packed_data.g; // Green channel
    if (channel == 2) return packed_data.b; // Blue channel
    return packed_data.a; // Alpha channel
}

void main() {
	vec4 final_color;
#if USE_DIFFUSE_MAP
	final_color = texture2D(uDiffuseMap, vTexCoord0) * uDiffuseColor;

	vec4 vhs_noise = getPackedIntensity(vTexCoord0, uClock + uControl.z);
	// vec2 vTexCoord0_mirror = vec2(1.0, 0.0) + vTexCoord0 * vec2(-1.0, 1.0);
	vec4 photo0;
	float intensity_accumulation = 0.0;
	float i;
	vec2 noise_offset = vec2(0.0, 0.0);

	for(i = 0.0; i < 1.0; i += 1.0/SAMPLE_WIDTH){
		noise_offset = vTexCoord0 + vec2(i * 0.01, 0.0);
		intensity_accumulation += getPackedIntensity(vTexCoord0 + noise_offset, uClock + uControl.z);
	}

	intensity_accumulation = intensity_accumulation * (10.0 / SAMPLE_WIDTH);
	intensity_accumulation = min(1.0, intensity_accumulation) * 0.1;
	intensity_accumulation = max(0.0, intensity_accumulation - 0.05);

	photo0 = texture2D(uDiffuseMap, vTexCoord0 + vec2(intensity_accumulation * uControl.x, 0.0));
	final_color = photo0 + vhs_noise * uControl.x;
	final_color = vec4(_RGB2YUV(final_color.xyz), 1.0);
	final_color.y += intensity_accumulation * 4.0 * uControl.y;
	final_color = vec4(_YUV2RGB(final_color.xyz), 1.0);

#else
	final_color = uDiffuseColor;
#endif
	float rgb_gamma = uCustom.y;
	vec3 rgb_color = pow(final_color.xyz, vec3_splat(1. / rgb_gamma));
	rgb_color = SimpleReinhardToneMapping(rgb_color, uCustom.x);
	gl_FragColor = vec4(rgb_color.xyz, 1.0);
}

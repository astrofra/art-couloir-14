// Copyright (c) NWNC HARFANG and contributors. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.

#define SAMPLE_WIDTH 20

$input vTexCoord0

#include <bgfx_shader.sh>

uniform vec4 control; // VHS FX -> x : noise_intensity, y : chroma_distortion
uniform vec4 uCustomClock;

SAMPLER2D(u_video, 0);
SAMPLER2D(u_photo0, 1);

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


void main() {
	vec4 vhs_noise = texture2D(u_video, vTexCoord0 - vec2(mod(uCustomClock.x * 1.123456, 1.0), 0.0));
	vec2 vTexCoord0_mirror = vec2(1.0, 0.0) + vTexCoord0 * vec2(-1.0, 1.0);
	vec4 photo0, photo1;
	float intensity_accumulation = 0.0;
	float i;
	vec2 noise_offset = vec2(0.0, 0.0);

	for(i = 0.0; i < 1.0; i += 1.0/SAMPLE_WIDTH){
		noise_offset = vTexCoord0 + vec2(i * 0.01, 0.0);
		intensity_accumulation += texture2D(u_video, vTexCoord0 + noise_offset);
	}

	intensity_accumulation = intensity_accumulation * (10.0 / SAMPLE_WIDTH);
	intensity_accumulation = min(1.0, intensity_accumulation) * 0.1;
	intensity_accumulation = max(0.0, intensity_accumulation - 0.05);

	// photo0 = vec4(1.0, 0.0, 0.0, 1.0);
	// photo1 = vec4(0.0, 1.0, 0.0, 1.0);

	photo0 = texture2D(u_photo0, vTexCoord0_mirror + vec2(intensity_accumulation * control.x, 0.0));
	vec4 final_color = photo0 + vhs_noise * control.x;
	final_color = vec4(_RGB2YUV(final_color.xyz), 1.0);
	final_color.y += intensity_accumulation * 4.0 * control.y;
	final_color = vec4(_YUV2RGB(final_color.xyz), 1.0);

	// gl_FragColor = vec4(control.x, control.y, 0.0, 1.0);
	// gl_FragColor = vec4(intensity_accumulation, intensity_accumulation, intensity_accumulation, 1.0);
	gl_FragColor = final_color;
}
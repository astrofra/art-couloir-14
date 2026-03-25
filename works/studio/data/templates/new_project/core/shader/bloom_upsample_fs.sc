$input v_texcoord0

// HARFANG(R) Copyright (C) 2022 Emmanuel Julien, NWNC HARFANG. Released under GPL/LGPL/Commercial Licence, see licence.txt for details.
#include <forward_pipeline.sh>

SAMPLER2D(u_source, 0);
uniform vec4 u_source_rect;
uniform vec4 u_params;

vec2 clip_uv(vec2 uv, vec2 center, vec4 bounds) {
#if BGFX_SHADER_LANGUAGE_GLSL
	vec2 flipped_uv = vec2(uv.x, 1 - uv.y);
	vec4 clip_fn = vec4(step(bounds.xy, flipped_uv), step(flipped_uv, bounds.zw));
#else
	vec4 clip_fn = vec4(step(bounds.xy, uv), step(uv, bounds.zw));
#endif
	return mix(center, uv, vec2(clip_fn.x * clip_fn.z, clip_fn.y * clip_fn.w));
}

void main() {
	vec2 uv = v_texcoord0.xy;
	vec4 offset = vec4(-u_params.x, u_params.x, u_params.x, 0.) / uResolution.xxyy;

	vec2 center = (floor(v_texcoord0.xy * uResolution.xy) + vec2_splat(0.5)) / uResolution.xy;
	vec4 bounds = (floor(u_source_rect.xyzw) + vec4(1.,1.,-1.,-1.)) / uResolution.xyxy;

	vec4 t0 = texture2D(u_source, clip_uv(uv - offset.yz, center, bounds)); // -1,-1
	vec4 t1 = texture2D(u_source, clip_uv(uv - offset.wz, center, bounds)); //  0,-1
	vec4 t2 = texture2D(u_source, clip_uv(uv - offset.xz, center, bounds)); //  1,-1

	vec4 t3 = texture2D(u_source, clip_uv(uv + offset.xw, center, bounds)); // -1, 0
	vec4 t4 = texture2D(u_source, clip_uv(uv, center, bounds));
	vec4 t5 = texture2D(u_source, clip_uv(uv + offset.yw, center, bounds)); //  1, 0

	vec4 t6 = texture2D(u_source, clip_uv(uv + offset.xz, center, bounds)); // -1, 1
	vec4 t7 = texture2D(u_source, clip_uv(uv + offset.wz, center, bounds)); //  0, 1
	vec4 t8 = texture2D(u_source, clip_uv(uv + offset.yz, center, bounds)); //  1, 1

	gl_FragColor = (t0 + t2 + t6 + t8 + 2. * (t1 + t3 + t5 + t7) + 4. * t4) / 16.;
}

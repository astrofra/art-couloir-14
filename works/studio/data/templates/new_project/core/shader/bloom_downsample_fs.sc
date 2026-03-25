$input v_texcoord0

// HARFANG(R) Copyright (C) 2022 Emmanuel Julien, NWNC HARFANG. Released under GPL/LGPL/Commercial Licence, see licence.txt for details.
#include <forward_pipeline.sh>

SAMPLER2D(u_source, 0);
uniform vec4 u_source_rect;

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
	vec4 offset = vec4(-1., 1., 1., 0.) / uResolution.xxyy;

	vec2 center = (floor(v_texcoord0.xy * uResolution.xy) + vec2_splat(0.5)) / uResolution.xy;
	vec4 bounds = (floor(u_source_rect.xyzw) + vec4(1.,1.,-1.,-1.)) / uResolution.xyxy; // source rect -1px on all axises

	vec4 s0 = texture2D(u_source, clip_uv(uv - offset.yz, center, bounds)); // -1,-1 
	vec4 s1 = texture2D(u_source, clip_uv(uv - offset.wz, center, bounds)); //  0,-1
	vec4 s2 = texture2D(u_source, clip_uv(uv - offset.xz, center, bounds)); //  1,-1

	vec4 s3 = texture2D(u_source, clip_uv(uv + offset.xw, center, bounds)); // -1, 0
	vec4 s4 = texture2D(u_source, clip_uv(uv, center, bounds));			   //  0, 0
	vec4 s5 = texture2D(u_source, clip_uv(uv + offset.yw, center, bounds)); //  1, 0

	vec4 s6 = texture2D(u_source, clip_uv(uv + offset.xz, center, bounds)); // -1, 1
	vec4 s7 = texture2D(u_source, clip_uv(uv + offset.wz, center, bounds)); //  0, 1
	vec4 s8 = texture2D(u_source, clip_uv(uv + offset.yz, center, bounds)); //  1, 1

	offset = 0.5 * offset;

	vec4 t0 = texture2D(u_source, clip_uv(uv - offset.yz, center, bounds)); // -1,-1
	vec4 t1 = texture2D(u_source, clip_uv(uv - offset.xz, center, bounds)); //  1,-1
	vec4 t2 = texture2D(u_source, clip_uv(uv + offset.xz, center, bounds)); // -1, 1
	vec4 t3 = texture2D(u_source, clip_uv(uv + offset.yz, center, bounds)); //  1, 1

	vec4 v0 = s0 + s1 + s3 + s4;
	vec4 v1 = s1 + s2 + s4 + s5;
	vec4 v2 = s3 + s4 + s6 + s7;
	vec4 v3 = s4 + s5 + s7 + s8;
	vec4 v4 = t0 + t1 + t2 + t3;

	gl_FragColor = (((v0 + v1 + v2 + v3) / 4.) + v4) / 8.;
}

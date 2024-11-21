// Copyright (c) NWNC HARFANG and contributors. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.

$input a_position, a_texcoord0,
$output vTexCoord0

#include <bgfx_shader.sh>

void main() {
	vTexCoord0 = a_texcoord0;
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0) );
}

// Copyright (c) NWNC HARFANG and contributors. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.

$input vTexCoord0

#include <bgfx_shader.sh>

SAMPLER2D(u_source, 0);

void main() {
	gl_FragColor = texture2D(u_source, vTexCoord0);
}
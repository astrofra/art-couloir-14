$input v_texcoord0

// HARFANG(R) Copyright (C) 2022 Emmanuel Julien, NWNC HARFANG. Released under GPL/LGPL/Commercial Licence, see licence.txt for details.
#include <bgfx_shader.sh>

SAMPLER2D(u_color, 0);

void main() {
	vec4 color = texture2D(u_color, v_texcoord0);
	gl_FragColor = color;
}

$input a_position
$output vPickId

#include <bgfx_shader.sh>

uniform vec4 uPickId;

void main() {
	vPickId = uPickId;
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));
}

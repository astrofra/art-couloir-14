$input a_position
$output v_position

#include <bgfx_shader.sh>

void main() {
    gl_Position = vec4(a_position, 1.0);
    v_position = a_position;
}

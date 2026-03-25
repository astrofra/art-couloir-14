$input vNormal

#include <bgfx_shader.sh>

void main() {
	vec3 normal = normalize(vNormal);
	float k = max(-normal.z, 0.0);
	k = pow(k, 2.2);
	gl_FragColor = vec4(k, k, k, 1.0);
}

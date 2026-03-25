$input v_position

uniform vec4 u_nearFarIsOrtho;
uniform vec4 u_axes;
uniform vec4 u_color0;
uniform vec4 u_color1;
uniform vec4 u_colorGrid;
uniform vec4 u_gridParams;

#include <bgfx_shader.sh>


mat3 to_mat3(mat4 m)
{
#if BGFX_SHADER_LANGUAGE_GLSL
    return mat3(m);
#else
    return (mat3)(m);
#endif
}

vec4 calc_color(vec3 pos_world, float cell_size, int axis0, int axis1, vec3 color0, vec3 color1, vec3 color_grid)
{
    float line_width = 1.0;
    
    // scale the coordinates depending on the grid level
    vec2 coord;
    coord.x = axis0 == 0 ? pos_world.x : axis0 == 1 ? pos_world.y : pos_world.z;
    coord.y = axis1 == 0 ? pos_world.x : axis1 == 1 ? pos_world.y : pos_world.z;
    vec2 coord_scale = coord / cell_size;
    
    // constant width lines by using the coordinates derivatives
    vec2 derivative = fwidth(coord_scale);
    vec2 fractional = vec2(1.0, 1.0) - abs(fract(coord_scale - 0.5) - 0.5) / (line_width * derivative);
    float alpha = clamp(max(fractional.x, fractional.y), 0, 1);
    vec4 color = vec4(color_grid, alpha);

    // identify the grid axes    
    vec2 truncated = trunc((coord_scale) / (line_width * derivative));
    if (truncated.x == 0)
        color = vec4(color1, color.a);
    if (truncated.y == 0)
        color = vec4(color0, color.a);
    
    // blend away lines for which the derivative is very large to limit aliasing at high angle or high distances
    float max_fwidth = 0.1 * pow(cell_size, line_width * 0.75);
    if (length(fwidth(coord)) > max_fwidth)
        color.a /= length(fwidth(coord)) / max_fwidth;

    return color;
}

void main() {
  
    bool is_ortho = u_nearFarIsOrtho.z == 1.0;
    float n_subdivs = u_gridParams[0];
    float subdiv_size = u_gridParams[1];
    float grid_opacity = u_gridParams[2];
    float grid_offset = u_gridParams[3];
    float near = u_nearFarIsOrtho.x;
    float far = u_nearFarIsOrtho.y;
    
    int axis0 = int(u_axes[0]);
    vec3 color0 = u_color0.xyz;
    int axis1 = int(u_axes[1]);
    vec3 color1 = u_color1.xyz;
    vec3 color_grid = u_colorGrid.xyz;

    vec4 out_color = vec4(0.0, 0.0, 0.0, 0.0);

    // we'll compute these depending on whether we use a perspective projection or not
    vec3 pos_world;
    bool visible = true;
    float distance_fading = 1.0;
    float point_distance;
    float depth_offset_sign = 1.0f; // direction in which we adjust the depth buffer

    if (!is_ortho)
    {
        vec3 camera_pos = mul(u_invView, vec4(0, 0, 0, 1)).xyz;

        vec3 grid_normal = vec3(0, 1, 0);
        vec3 grid_origin = vec3(0, grid_offset, 0);

        // intersect camera direction with the horizontal grid
        vec4 camera_direction = vec4(v_position.xy, 0.0, 1.0);
        camera_direction = mul(u_invProj, camera_direction);
        camera_direction.w = 0.0;
        camera_direction = mul(u_invView, camera_direction);
        
        float u = dot(grid_normal, (grid_origin - camera_pos)) / dot(grid_normal, camera_direction.xyz);
        pos_world = camera_pos + camera_direction.xyz * u;
        visible = u > 0.0;
        point_distance = length(pos_world - camera_pos);
        
        vec4 pos_view = mul(u_view, vec4(pos_world.xyz, 1.0));
        float near = u_nearFarIsOrtho.x;
        float far = u_nearFarIsOrtho.y;
        float depth_linear = ((pos_view.z / pos_view.w) - near) / (far - near);
        distance_fading = 1.0 - smoothstep(0.5, 1.0, depth_linear);

        // adjust depth offset sign depending on the camera position
        depth_offset_sign = sign(grid_offset * -camera_pos.y);
    }
    else
    {
        vec4 proj = mul(u_proj, vec4(1.0, 1.0, 0.0, 1.0));
        proj.xyz /= proj.w;

        mat3 invView3 = to_mat3(u_invView);
        vec3 camera_at = mul(invView3, vec3(0.0, 0.0, 1.0));
        vec3 camera_right = mul(invView3, vec3(1.0, 0.0, 0.0));
        vec3 camera_up = mul(invView3, vec3(0.0, 1.0, 0.0));
        
        vec3 camera_pos = mul(u_invView, vec4(0, 0, 0, 1)).xyz;
        camera_pos += camera_at * near;
        camera_pos += camera_right * v_position.x / proj.x;
        camera_pos += camera_up * v_position.y / proj.y;

        vec3 grid_normal = vec3(0, 1, 0);
        
        grid_normal = u_axes[0] != 0 && u_axes[1] != 0 ? vec3(1, 0, 0) : grid_normal;
        grid_normal = u_axes[0] != 1 && u_axes[1] != 1 ? vec3(0, 1, 0) : grid_normal;
        grid_normal = u_axes[0] != 2 && u_axes[1] != 2 ? vec3(0, 0, 1) : grid_normal;
        
        vec3 grid_origin = vec3(0, grid_offset, 0);

        // intersect camera direction with the horizontal grid
        float u = dot(grid_normal, (grid_origin - camera_pos)) / dot(grid_normal, camera_at);
        pos_world = camera_pos + camera_at * u;
        visible = u > 0.0;

        // there's no distance in an orth matrix so we use the proj matrix size
        point_distance = 2.0 / max(proj.x, proj.y);
        
        // adjust world pos with offset
        pos_world.x += u_axes[0] != 0 && u_axes[1] != 0 ? grid_offset : 0;
        pos_world.y += u_axes[0] != 1 && u_axes[1] != 1 ? grid_offset : 0;
        pos_world.z += u_axes[0] != 2 && u_axes[1] != 2 ? grid_offset : 0;
        
        // adjust depth offset sign depending on the direction we're looking at
        depth_offset_sign = sign(grid_offset * proj.x * -proj.y);
    }
    
    int min_iter = 0;
    int max_iter = 10; // display grids up to this level
    
    for (int iter = min_iter; iter < max_iter; iter++)
    {
        float cell_size = subdiv_size * pow(n_subdivs, iter);
        vec4 color = calc_color(pos_world, cell_size, axis0, axis1, color0, color1, color_grid);
       
        // we use those heights to blend between grid levels:
        float target_height_factor = 10.0;
        float p0 = target_height_factor * subdiv_size * pow(n_subdivs, iter - 2);
        float p1 = target_height_factor * subdiv_size * pow(n_subdivs, iter - 1);
        float p2 = target_height_factor * cell_size;
        float p3 = target_height_factor * subdiv_size * pow(n_subdivs, iter + 1);
        
        float alpha = 0.0;
        
        if (point_distance > p0 && point_distance <= p1)    // alpha goes from 0 to 1
            alpha = (point_distance - p0) / (p1 - p0);
        else if (point_distance > p1 && point_distance <= p2)   // alpha is 1
            alpha = 1.0;
        else if (point_distance > p2 && point_distance <= p3)   // alpha goes from 1 to 0
            alpha = 1.0 - (point_distance - p2) / (p3 - p2);

        color.a *= 0.5 * alpha; // half the contributions so that the max sum at a given level is 1

        out_color.rgb = color.rgb; // color is the same for each level so it's fine to overwrite it
        out_color.a += color.a; // add alpha contributions
    }

    // clamp just in case
    out_color.a = min(out_color.a, 1.0);

    // visible part of the grid    
    out_color *= float(visible);
   
    // fade in the distance
    out_color.a *= distance_fading;

    // grid opacity    
    out_color.a *= grid_opacity;

    // output color    
    gl_FragColor = out_color;
    
    // output depth
    vec4 pos_proj = mul(u_viewProj, vec4(pos_world, 1.0));
    gl_FragDepth = pos_proj.z / pos_proj.w;
}

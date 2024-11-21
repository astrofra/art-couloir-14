-- Maps a value from one range to another.
function map(value, min1, max1, min2, max2)
    return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
end

-- Clamps a value between a minimum and maximum value.
function clamp(value, min1, max1)
    return math.min(math.max(value, min1), max1)
end

function make_triangle_wave(i)
-- 1 ^   ^
--   |  / \
--   | /   \
--   |/     \
--   +-------->
-- 0    0.5    1
    local s = i >= 0 and 1 or -1
    i = math.abs(i)

    if i < 0.5 then
        return s * i * 2.0
    else
        return s * (1.0 - (2.0 * (i - 0.5)))
    end
end


-- Frame rate independent damping using Lerp.
-- Takes into account delta time to provide consistent damping across variable frame rates.
function dtAwareDamp(source, target, smoothing, dt)
    return hg.Lerp(source, target, 1.0 - (smoothing^dt))
end

-- Returns a new resolution based on a multiplier.
function resolution_multiplier(w, h, m)
    return math.floor(w * m), math.floor(h * m)
end

-- Returns a random angle in radians between -π and π.
function rand_angle()
    local a = math.random() * math.pi
    if math.random() > 0.5 then
        return a
    else
        return -a
    end
end

-- Ease-in-out function for smoother transitions.
function EaseInOutQuick(x)
	x = clamp(x, 0.0, 1.0)
	return	(x * x * (3 - 2 * x))
end

-- Detects if the current OS is Linux based on path conventions.
function IsLinux()
    if package.config:sub(1,1) == '/' then
        return true
    else
        return false
    end
end

-- Reads and decodes a JSON file.
function read_json(filename)
    local json = require("dkjson")
    local file = io.open(filename, "r")
 
    if not file then
       print("Couldn't open file!")
       return nil
    end
 
    local content = file:read("*all")
    file:close()
 
    local data = json.decode(content)
 
    return data
end

-- Applies advanced rendering (AAA) settings from a JSON file to the provided configuration.
function apply_aaa_settings(aaa_config, scene_path)
    scene_config = read_json(scene_path)
    if scene_config == nil then
       print("Could not apply settings from: " .. scene_path)
    else
       aaa_config.bloom_bias = scene_config.bloom_bias
       aaa_config.bloom_intensity = scene_config.bloom_intensity
       aaa_config.bloom_threshold = scene_config.bloom_threshold
       aaa_config.exposure = scene_config.exposure
       aaa_config.gamma = scene_config.gamma
       aaa_config.max_distance = scene_config.max_distance
       aaa_config.motion_blur = scene_config.motion_blur
       aaa_config.sample_count = scene_config.sample_count
       aaa_config.taa_weight = scene_config.taa_weight
       aaa_config.z_thickness = scene_config.z_thickness
    end
end  

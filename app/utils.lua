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

function increase_saturation(rgb, factor)
    -- Extract RGB values
    local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255

    -- Find the maximum and minimum values of R, G, B
    local max_val = math.max(r, g, b)
    local min_val = math.min(r, g, b)
    local delta = max_val - min_val

    -- Calculate Lightness
    local l = (max_val + min_val) / 2

    -- Calculate Saturation
    local s = 0
    if delta ~= 0 then
        if l < 0.5 then
            s = delta / (max_val + min_val)
        else
            s = delta / (2.0 - max_val - min_val)
        end
    end

    -- Calculate Hue
    local h = 0
    if delta ~= 0 then
        if max_val == r then
            h = (g - b) / delta
        elseif max_val == g then
            h = 2.0 + (b - r) / delta
        else
            h = 4.0 + (r - g) / delta
        end
    end
    h = (h * 60) % 360  -- Ensure hue is in [0, 360)

    -- Adjust Saturation
    s = math.min(s * factor, 1)  -- Increase saturation by the given factor, clamped to 1

    -- Convert back to RGB
    local function hsl_to_rgb(h, s, l)
        local function hue_to_rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end

        if s == 0 then
            local gray = math.floor(l * 255 + 0.5)
            return gray, gray, gray
        end

        local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
        local p = 2 * l - q

        local r = hue_to_rgb(p, q, h / 360 + 1/3)
        local g = hue_to_rgb(p, q, h / 360)
        local b = hue_to_rgb(p, q, h / 360 - 1/3)

        return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
    end

    local new_r, new_g, new_b = hsl_to_rgb(h, s, l)
    return {new_r, new_g, new_b}
end

function LerpColor(a, b, k)
    local va = hg.Vec4(a.r, a.g, a.b, a.a)
    local vb = hg.Vec4(b.r, b.g, b.b, b.a)
    local vl = hg.Lerp(va, vb, k)
    return hg.Color(vl.x, vl.y, vl.z, vl.w)
end

function array_find(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i -- Return the index as soon as the value is found
        end
    end
    return nil -- Return nil if the value is not found
end

-- Function to read an .ini file with missing file handling
function read_ini(file_path)
    -- Check if the file exists
    local file = io.open(file_path, "r")
    if not file then
        print("Warning: Configuration file not found: " .. file_path)
        return nilt
    end

    local config = {}

    -- Read and parse the file
    local section
    for line in file:lines() do
        local s = line:match("^%[([^%]]+)%]$")
        if s then
            section = s
            config[section] = config[section] or {}
        else
            local key, value = line:match("^([^=]+)%s-=%s-(.+)$")
            if key and value then
                key = key:match("^%s*(.-)%s*$") -- Trim whitespace
                value = value:match("^%s*(.-)%s*$") -- Trim whitespace
                if tonumber(value) then
                    value = tonumber(value)
                elseif value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                end
                if section then
                    config[section][key] = value
                else
                    config[key] = value
                end
            end
        end
    end

    file:close()
    return config
end

-- Function to write an .ini file
function write_ini(file_path, config)
    local file = io.open(file_path, "w")
    if not file then
        error("Could not open file for writing: " .. file_path)
    end

    for section, values in pairs(config) do
        if type(values) == "table" then
            file:write(string.format("[%s]\n", section))
            for key, value in pairs(values) do
                local value_str = tostring(value)
                file:write(string.format("%s = %s\n", key, value_str))
            end
        else
            file:write(string.format("%s = %s\n", section, tostring(values)))
        end
        file:write("\n")
    end

    file:close()
end
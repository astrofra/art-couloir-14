hg = require("harfang")
require("utils")

function PhotoChangeCoroutine(state)
    -- load next photo
    state.current_photo = state.current_photo + 1
    if state.current_photo > #state.photo_table then
        state.current_photo = 1
        state.current_folder = state.current_folder + 1
        if state.current_folder > #folder_table then
            state.current_folder = 1
        end
    end
    state.next_tex = LoadPhotoFromTable(state.photo_table, state.current_photo, folder_table[state.current_folder])
    coroutine.yield()
    
    -- ramp up the noise intensity
    local start_clock = hg.GetClock()
    local clock
    while true do
        clock = hg.GetClock() - start_clock
        clock_s = hg.time_to_sec_f(clock)
        state.noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)
        if clock_s >= 1.0 then
            break
        end
        coroutine.yield()
    end

    -- sound fx
    local src_ref = hg.OpenALPlayStereo(state.sounds[math.random(1, #state.sounds)], hg.OpenALStereoSourceState(1, hg.OALSR_Once))

    -- next photo
    state.noise_intensity = 1.0
    state.tex_photo0 = state.next_tex
    state.index_photo0 = state.current_photo
    state.next_tex = nil
    coroutine.yield()
    
    -- ramp down the noise intensity
    start_clock = hg.GetClock()
    while true do
        clock = hg.GetClock() - start_clock
        clock_s = hg.time_to_sec_f(clock)
        state.noise_intensity = clock_s + 2.0 * clamp(map(clock_s, 0.8, 1.0, 0.0, 1.0), 0.0, 1.0)
        state.noise_intensity = (2.0 - state.noise_intensity) / 2.0
        if clock_s >= 1.0 then
            break
        end
        coroutine.yield()
    end

    state.noise_intensity = 0.0
    coroutine.yield()
end

function config_gui(default_res_x, default_res_y, open_vr_enabled)
    default_res_x = default_res_x or 960
    default_res_y = default_res_y or 720
    open_vr_enabled = open_vr_enabled or false
    -- resolution selection
    local res_list = {{640, 360}, {768, 432}, {896, 504}, {960, 720}, {1024, 576}, {1152, 648}, {1280, 720}, {1920, 1080}, {1920, 1200}, {2560, 1440}, {3840, 2160}, {5120, 2880}}
    local res_list_str = {}
    local res_x, res_y = 600, 250
    local mode_list = {hg.WV_Windowed, hg.WV_Fullscreen, hg.WV_Undecorated, hg.WV_FullscreenMonitor1, hg.WV_FullscreenMonitor2, hg.WV_FullscreenMonitor3}
    local mode_list_str = {"Windowed", "Fullscreen", "Undecorated", "Fullscreen Monitor #1", "Fullscreen Monitor #2", "Fullscreen Monitor #3"}

    local res_modified
    local res_preset = 3
    local fullscreen_modified
    local fullscreen_preset = 2
    local default_fullscreen = hg.WV_Undecorated

    -- local open_vr_enabled = false
    -- local pressed_low_aaa = false
    -- local pressed_no_aaa = false

    -- local full_aaa = true
    -- local low_aaa = false
    -- local no_aaa = false

    local run_mode = "stay"

    local win = hg.NewWindow("Display configuration", res_x, res_y, 32)
    hg.RenderInit(win) -- , hg.RT_OpenGL)

    local imgui_prg = hg.LoadProgramFromAssets('core/shader/imgui')
    local imgui_img_prg = hg.LoadProgramFromAssets('core/shader/imgui_image')

    hg.ImGuiInit(10, imgui_prg, imgui_img_prg)

    -- prepare list of resolutions
    local i
    for i = 1, #res_list do
        table.insert(res_list_str, res_list[i][1] .. "x" .. res_list[i][2])
    end

    -- main loop
    while run_mode == "stay" do
        hg.ImGuiBeginFrame(res_x, res_y, hg.TickClock(), hg.ReadMouse(), hg.ReadKeyboard())

        -- main window
        local screen_config_tex = "CRT Display Output"
        if hg.ImGuiBegin(screen_config_tex, true, hg.ImGuiWindowFlags_NoMove | hg.ImGuiWindowFlags_NoResize) then
            hg.ImGuiSetWindowPos(screen_config_tex, hg.Vec2(0, 0), hg.ImGuiCond_Once)
            hg.ImGuiSetWindowSize(screen_config_tex, hg.Vec2(res_x, res_y), hg.ImGuiCond_Once)

            hg.ImGuiText("Screen")

            res_modified, res_preset = hg.ImGuiCombo("Resolution", res_preset, res_list_str)

            -- apply preset if a combo entry was selected
            if res_modified then
                default_res_x = res_list[res_preset + 1][1]
                default_res_y = res_list[res_preset + 1][2]
            end

            -- fullscreen_modified, default_fullscreen = hg.ImGuiCheckBox("Fullscreen", default_fullscreen)
            fullscreen_modified, fullscreen_preset = hg.ImGuiCombo("Mode", fullscreen_preset, mode_list_str)

            -- apply preset if a combo entry was selected
            if fullscreen_modified then
                default_fullscreen = mode_list[fullscreen_preset + 1]
            end

            -- Rendering settings
            hg.ImGuiSpacing()
            hg.ImGuiSeparator()
            hg.ImGuiSpacing()
            hg.ImGuiText("Setup")

            -- pressed_open_vr_enabled = hg.ImGuiRadioButton("Enable VR", open_vr_enabled)
            -- hg.ImGuiSameLine()
            -- pressed_low_aaa = hg.ImGuiRadioButton("Low AAA", low_aaa)
            -- hg.ImGuiSameLine()
            -- pressed_no_aaa = hg.ImGuiRadioButton("Classic", no_aaa)
            -- hg.ImGuiSameLine()

            -- if open_vr_enabled then
            --     full_aaa = true
            --     low_aaa = false
            --     no_aaa = false
            -- elseif pressed_low_aaa then
            --     full_aaa = false
            --     low_aaa = true
            --     no_aaa = false
            -- elseif pressed_no_aaa then
            --     full_aaa = false
            --     low_aaa = false
            --     no_aaa = true
            -- end

            -- start demo
            hg.ImGuiSpacing()
            hg.ImGuiSeparator()
            hg.ImGuiSpacing()

            hg.ImGuiPushStyleColor(hg.ImGuiCol_Button, hg.Color(1.0, 0.5, 0.0, 1.0))
            press_play = hg.ImGuiButton("Play <3")
            hg.ImGuiPopStyleColor()
            hg.ImGuiSameLine()
            hg.ImGuiSpacing()
            hg.ImGuiSameLine()
            hg.ImGuiPushStyleColor(hg.ImGuiCol_Button, hg.Color(0.5, 0.2, 0.3, 1.0))
            press_cancel = hg.ImGuiButton("Exit :(")
            hg.ImGuiPopStyleColor()

            if hg.ReadKeyboard():Key(hg.K_Escape) then
                run_mode = "cancel"
            elseif press_play then
                run_mode = "play"
            elseif press_cancel then
                run_mode = "cancel"
            end
        end

        hg.ImGuiEnd()

        hg.ImGuiEnd()

        hg.SetView2D(0, 0, 0, res_x, res_y, -1, 1, hg.CF_Color | hg.CF_Depth, hg.Color.Black, 1, 0)
        hg.ImGuiEndFrame(0)

        hg.Frame()
        hg.UpdateWindow(win)
    end

    hg.RenderShutdown()
	hg.DestroyWindow(win)

    return run_mode, default_res_x, default_res_y, default_fullscreen, open_vr_enabled
end
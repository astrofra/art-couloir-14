function LoadPhotoFromTable(_photo_table, _photo_idx, _photo_folder, res)
	-- hg.LoadTextureFromAssets(slide_data[_idx].bitmap, hg.TF_UClamp | hg.TF_VClamp, res)
	local texture_ref = hg.LoadTextureFromAssets('photos/' .. _photo_folder .. "/" .. _photo_table[_photo_idx] .. '.png', hg.TF_UClamp | hg.TF_VClamp, res)
	local texture = res:GetTexture(texture_ref)

	local slide_texture_ref = hg.LoadTextureFromAssets('photos/' .. _photo_folder .. "/slides/" .. _photo_table[_photo_idx] .. '_slide.png', hg.TF_UClamp | hg.TF_VClamp, res)
	local slide_texture = res:GetTexture(slide_texture_ref)

	return {texture_ref = texture_ref, texture = texture, slide_texture_ref = slide_texture_ref, slide_texture = slide_texture}
end

function ChangePhoto(state, folder_table, photo_tables, res)
    state.current_photo = state.current_photo + 1
    if state.current_photo > #state.photo_table then
        state.current_photo = 1
        state.current_folder = state.current_folder + 1
        if state.current_folder > #folder_table then
            state.current_folder = 1
        end
        state.photo_table = photo_tables[folder_table[state.current_folder]]
    end

    state.tex_photo0 = LoadPhotoFromTable(state.photo_table, state.current_photo, folder_table[state.current_folder], res)
	state.tex_title0 = hg.LoadTextureFromAssets('titles/' .. folder_table[state.current_folder] .. '.png', hg.TF_UClamp | hg.TF_VClamp, res)
    return state
end

hg = require("harfang")
require("utils")
require("arguments")
slides_colors = require("slides_colors")

hg.InputInit()
hg.WindowSystemInit()
hg.OpenALInit()

SLIDE_SHOW_SPEED = 1.0
VR_DEBUG_DISPLAY = false
-- local res_x, res_y = 768, 576
-- local res_x, res_y = 800, 600
local res_x, res_y = 960, 720
local default_window_mode = hg.WV_Windowed

local options = parseArgs(arg)
local screen_modes = {
	Windowed = hg.WV_Windowed,
    Undecorated = hg.WV_Undecorated,
    Fullscreen = hg.WV_Fullscreen,
    Hidden = hg.WV_Hidden,
    FullscreenMonitor1 = hg.WV_FullscreenMonitor1,
    FullscreenMonitor2 = hg.WV_FullscreenMonitor2,
    FullscreenMonitor3 = hg.WV_FullscreenMonitor3
}
if options.output then
	default_window_mode = screen_modes[options.output]
end
if options.width then
	res_x = options.width
end
if options.height then
	res_y = options.height
end

local win = hg.NewWindow('COULOIR 14', res_x, res_y, 32, default_window_mode) --, hg.WV_Fullscreen)
hg.RenderInit(win)
hg.RenderReset(res_x, res_y, hg.RF_VSync | hg.RF_MSAA4X | hg.RF_MaxAnisotropy)

hg.AddAssetsFolder("assets_compiled")

local pipeline = hg.CreateForwardPipeline(2048, false)
local res = hg.PipelineResources()

-- VR Stuff

local render_data = hg.SceneForwardPipelineRenderData()  -- this object is used by the low-level scene rendering API to share view-independent data with both eyes

-- OpenVR initialization
local open_vr_enabled = false

if hg.OpenVRInit() then
	open_vr_enabled = true
end

local vr_left_fb, vr_right_fb
if open_vr_enabled then
	vr_left_fb = hg.OpenVRCreateEyeFrameBuffer(hg.OVRAA_MSAA4x)
	vr_right_fb = hg.OpenVRCreateEyeFrameBuffer(hg.OVRAA_MSAA4x)
end

-- Create scene
local scene = hg.Scene()
hg.LoadSceneFromAssets("main.scn", scene, res, hg.GetForwardPipelineInfo())

local crt_scene = hg.Scene()
hg.LoadSceneFromAssets("crt.scn", crt_scene, res, hg.GetForwardPipelineInfo())

-- CRT Stuff

-- text rendering
-- load font and shader program
local font_size = math.floor(60 * (res_x / 960.0))
local font_osd = hg.LoadFontFromAssets("fonts/" .. "VCR_OSD_MONO.ttf", font_size)

local font_program = hg.LoadProgramFromAssets('core/shader/font')

-- text uniforms and render state
local text_uniform_values = {hg.MakeUniformSetValue('u_color', hg.Vec4(1, 1, 0, 1))}
local text_render_state = hg.ComputeRenderState(hg.BM_Alpha, hg.DT_Always, hg.FC_Disabled)

-- VHS fx shader
local screen_prg = hg.LoadProgramFromAssets('shaders/vhs_fx.vsb', 'shaders/vhs_fx.fsb')

-- create a plane model for the final rendering stage
local vtx_layout = hg.VertexLayoutPosFloatNormUInt8TexCoord0UInt8()

local screen_zoom = 1
local screen_mdl = hg.CreatePlaneModel(vtx_layout, screen_zoom, screen_zoom * (res_y / res_x), 1, 1)
local screen_ref = res:AddModel('screen', screen_mdl)

-- CRT photos data

-- state context
local photo_state = {
	state = "display_photo",
	start_clock = nil,
    current_photo = nil,
    photo_table = nil,
    tex_photo0 = nil,
	tex_title0 = nil,
    noise_intensity = nil,
	update_pipeline = true,
	sounds = {}
}

-- photo
local idx

local photo_tables = {}
local folder_table = {"arzamas_16", "fantomy", "hazmat", "netzwerk", "radiograf"}
local folder_short = {"_ARZM/", "_FNTM/", "_HZMT/", "_NETW/", "_RDGF/"}

for idx = 1, 5 do
	photo_tables[folder_table[idx]] = {}
end

photo_tables.arzamas_16 = {}
photo_tables.fantomy = {}
photo_tables.hazmat = {}
photo_tables.netzwerk = {}
photo_tables.radiograf = {}

for idx = 0, 22 do
	table.insert(photo_tables.arzamas_16, string.format("%03d", idx))
end
for idx = 0, 23 do
	table.insert(photo_tables.fantomy, string.format("%03d", idx))
end
for idx = 0, 15 do
	table.insert(photo_tables.hazmat, string.format("%03d", idx))
end
for idx = 0, 17 do
	table.insert(photo_tables.netzwerk, string.format("%03d", idx))
end
for idx = 0, 22 do
	table.insert(photo_tables.radiograf, string.format("%03d", idx))
end

photo_state.current_folder = 1
photo_state.photo_table = photo_tables[folder_table[photo_state.current_folder]]

-- audio
-- background noise
local bg_snd_ref = hg.OpenALLoadWAVSoundAsset('sfx/static.wav')
local bg_src_ref = hg.OpenALPlayStereo(bg_snd_ref, hg.OpenALStereoSourceState(1, hg.OALSR_Loop))

-- photo change fx
for snd_idx = 0, 4 do
	photo_state.sounds[snd_idx + 1] = hg.OpenALLoadWAVSoundAsset('sfx/change' .. snd_idx .. '.wav') 
end

photo_state.current_photo = 1
photo_state.tex_photo0 = LoadPhotoFromTable(photo_state.photo_table, photo_state.current_photo, folder_table[photo_state.current_folder], res)
photo_state.tex_title0 = hg.LoadTextureFromAssets('titles/' .. folder_table[photo_state.current_folder] .. '.png', hg.TF_UClamp | hg.TF_VClamp, res)

photo_state.noise_intensity = 0.0
local chroma_distortion = 0.0

local zoom_level = 1.0 / 1.125

-- 3D scene stuff

-- Setup 2D rendering to display eyes textures
local quad_layout = hg.VertexLayout()
quad_layout:Begin():Add(hg.A_Position, 3, hg.AT_Float):Add(hg.A_TexCoord0, 3, hg.AT_Float):End()

local quad_model = hg.CreatePlaneModel(quad_layout, 1, 1, 1, 1)
local quad_render_state = hg.ComputeRenderState(hg.BM_Alpha, hg.DT_Disabled, hg.FC_Disabled)

local eye_t_size = res_x / 2.5
local eye_t_x = (res_x - 2 * eye_t_size) / 6 + eye_t_size / 2
local quad_matrix = hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(hg.Deg(90), hg.Deg(0), hg.Deg(0)), hg.Vec3(eye_t_size, 1, eye_t_size))

local tex0_program = hg.LoadProgramFromAssets("shaders/sprite")

local quad_uniform_set_value_list = hg.UniformSetValueList()
quad_uniform_set_value_list:clear()
quad_uniform_set_value_list:push_back(hg.MakeUniformSetValue("color", hg.Vec4(1, 1, 1, 1)))

local quad_uniform_set_texture_list = hg.UniformSetTextureList()

local initial_head_pos = scene:GetNode("FPSCamera"):GetTransform():GetPos()
initial_head_pos.y = 0.0

local keyboard = hg.Keyboard('raw')
local switch_clock = hg.GetClock()

-- Fetch scene's nodes
local crt_screen_node = scene:GetNode("crt_screen")
local crt_screen_material = crt_screen_node:GetObject():GetMaterial(0)

-- local photo_material_texture = hg.GetMaterialTexture(crt_screen_material, "uDiffuseMap")
-- local video_fx_material_texture = hg.GetMaterialTexture(crt_screen_material, "uSelfMap")

local slide_screen_node = scene:GetNode("slide_screen")
local slide_screen_material = slide_screen_node:GetObject():GetMaterial(0)

-- fullscreen crt scene

local crt_scene_screen_node = crt_scene:GetNode("crt_screen")
local crt_scene_screen_material = crt_scene_screen_node:GetObject():GetMaterial(0)

-- local crt_scene_photo_material_texture = hg.GetMaterialTexture(crt_scene_screen_material, "uDiffuseMap")
-- local crt_scene_video_fx_material_texture = hg.GetMaterialTexture(crt_scene_screen_material, "uSelfMap")

-- HomeComputer (terminal to display the title of each folder)
local home_computer_screen = scene:GetNode("SM_HomeComputer_screen")
local home_computer_screen_material = home_computer_screen:GetObject():GetMaterial(0)

local screen_lights = {}

for idx = 0, 3 do
	table.insert(screen_lights, scene:GetNode("ScreenLight" .. idx))
end

if not open_vr_enabled then
	local _cam = scene:GetNode("FPSCamera")
	local _rot = _cam:GetTransform():GetRot()
	_rot.y = _rot.y + math.pi / 8.0
	_rot.x = _rot.x + math.pi / 16.0
	_cam:GetTransform():SetRot(_rot)
	_cam:GetCamera():SetFov(math.pi / 2.0)
	scene:SetCurrentCamera(_cam)
end

-- Main loop
local frame_count = 0
local DISPLAY_DURATION = hg.time_from_sec_f(8.0)
local RAMP_UP_DURATION = hg.time_from_sec_f(1.0)
local RAMP_DOWN_DURATION = hg.time_from_sec_f(1.0)
photo_state.start_clock = hg.GetClock()

while not keyboard:Pressed(hg.K_Escape) and hg.IsWindowOpen(win) do
	keyboard:Update()
	dt = hg.TickClock()

	-- photo_state.lock = false

	if photo_state.state == "display_photo" then -- Display the photo & wait for the end of exposure time
		-- next state ?
		if hg.GetClock() - photo_state.start_clock > DISPLAY_DURATION then
			photo_state.start_clock = hg.GetClock()
			photo_state.state = "ramp_up"
		end
	elseif photo_state.state == "ramp_up" then -- increase the static noise to the max
		local clock = hg.GetClock() - photo_state.start_clock
		local clock_s = hg.time_to_sec_f(clock)
		photo_state.noise_intensity = clock_s + 2.0 * clamp(map(clock_s, hg.time_to_sec_f(RAMP_UP_DURATION) * 0.8, hg.time_to_sec_f(RAMP_UP_DURATION), 0.0, 1.0), 0.0, 1.0)
		local chroma_distortion = clamp(map(photo_state.noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)

		hg.SetMaterialValue(crt_screen_material, 'uControl', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))
		hg.SetMaterialValue(crt_scene_screen_material, 'uControl', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))
		
		-- slide screen
		local slide_transition = clamp(map(clock_s, hg.time_to_sec_f(RAMP_UP_DURATION) * 0.925, hg.time_to_sec_f(RAMP_UP_DURATION), 0.0, 1.0), 0.0, 1.0)
		-- slide_transition = slide_transition^2.0
		local slide_exposure = hg.Lerp(2.0, 0.5, slide_transition)
		local slide_gamma = hg.Lerp(0.35, 10.0, slide_transition)

		hg.SetMaterialValue(slide_screen_material, 'uCustom', hg.Vec4(slide_exposure, slide_gamma, 0.0, 0.0))

		-- light rig
		for idx = 1, 4 do
			local rgb_color = slides_colors[folder_table[photo_state.current_folder]][string.format("%03d", photo_state.current_photo - 1)][idx]
			rgb_color = increase_saturation(rgb_color, 5.0)
			local diffuse_color = LerpColor(hg.Color(rgb_color[1], rgb_color[2], rgb_color[3], 255.0) * (1.0 / 255.0), hg.Color.White * 0.8, slide_transition)
			local spec_color = diffuse_color
			screen_lights[idx]:GetLight():SetDiffuseColor(diffuse_color * 2.0)
			screen_lights[idx]:GetLight():SetSpecularColor(spec_color * 2.0)
		end

		-- next state ?
		if hg.GetClock() - photo_state.start_clock > RAMP_UP_DURATION then
			photo_state.state = "change_photo"
		end
	elseif photo_state.state == "change_photo" then -- now that the noise is set to the max, let's swap the photo (trick!)
		photo_state = ChangePhoto(photo_state, folder_table, photo_tables, res)
		
		-- textures
		if hg.IsValid(photo_state.tex_photo0.texture) and hg.IsValid(photo_state.tex_photo0.slide_texture) then
			print("Update photos !")

			hg.SetMaterialTexture(crt_screen_material, "uDiffuseMap", photo_state.tex_photo0.texture_ref, 0)
			hg.SetMaterialTexture(slide_screen_material, "uSelfMap", photo_state.tex_photo0.slide_texture_ref, 4)

			hg.SetMaterialTexture(crt_scene_screen_material, "uDiffuseMap", photo_state.tex_photo0.texture_ref, 0)

			hg.SetMaterialTexture(home_computer_screen_material, "uSelfMap", photo_state.tex_title0, 4)
		else
			print("Texture not valid !")
		end

		-- next state
		photo_state.start_clock = hg.GetClock()
		photo_state.state = "ramp_down"
	elseif photo_state.state == "ramp_down" then -- ramp down the noise
		local clock = hg.GetClock() - photo_state.start_clock
        local clock_s = hg.time_to_sec_f(clock)
        photo_state.noise_intensity = clock_s + 2.0 * clamp(map(clock_s, hg.time_to_sec_f(RAMP_DOWN_DURATION) * 0.8, hg.time_to_sec_f(RAMP_DOWN_DURATION), 0.0, 1.0), 0.0, 1.0)
        photo_state.noise_intensity = (2.0 - photo_state.noise_intensity) / 2.0
		photo_state.noise_intensity = photo_state.noise_intensity * ((1.0 - clock_s)^0.15)
		local chroma_distortion = clamp(map(photo_state.noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)

		hg.SetMaterialValue(crt_screen_material, 'uControl', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))
		hg.SetMaterialValue(crt_scene_screen_material, 'uControl', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))

		-- slide screen
		local slide_transition = 1.0 - clamp(map(clock_s, 0.0, hg.time_to_sec_f(RAMP_UP_DURATION) * 0.25, 0.0, 1.0), 0.0, 1.0)
		-- slide_transition = slide_transition^2.0
		local slide_exposure = hg.Lerp(2.0, 0.5, slide_transition)
		local slide_gamma = hg.Lerp(0.35, 10.0, slide_transition)

		hg.SetMaterialValue(slide_screen_material, 'uCustom', hg.Vec4(slide_exposure, slide_gamma, 0.0, 0.0))

		-- light rig
		for idx = 1, 4 do
			local rgb_color = slides_colors[folder_table[photo_state.current_folder]][string.format("%03d", photo_state.current_photo - 1)][idx]
			rgb_color = increase_saturation(rgb_color, 5.0)
			local diffuse_color = LerpColor(hg.Color(rgb_color[1], rgb_color[2], rgb_color[3], 255.0) * (1.0 / 255.0), hg.Color.White * 0.8, slide_transition)
			local spec_color = diffuse_color
			screen_lights[idx]:GetLight():SetDiffuseColor(diffuse_color * 2.0)
			screen_lights[idx]:GetLight():SetSpecularColor(spec_color * 2.0)
		end

		-- next state ?
		if hg.GetClock() - photo_state.start_clock > RAMP_DOWN_DURATION then
			hg.SetMaterialValue(crt_screen_material, 'uControl', hg.Vec4(0.015, 0.0, 0.0, 0.0))

			hg.SetMaterialValue(crt_scene_screen_material, 'uControl', hg.Vec4(0.015, 0.0, 0.0, 0.0))

			-- light rig
			for idx = 1, 4 do
				local rgb_color = slides_colors[folder_table[photo_state.current_folder]][string.format("%03d", photo_state.current_photo - 1)][idx]
				rgb_color = increase_saturation(rgb_color, 5.0)
				local diffuse_color = hg.Color(rgb_color[1], rgb_color[2], rgb_color[3], 255.0) * (1.0 / 255.0)
				local spec_color = diffuse_color
				screen_lights[idx]:GetLight():SetDiffuseColor(diffuse_color * 2.0)
				screen_lights[idx]:GetLight():SetSpecularColor(spec_color * 2.0)
			end

			photo_state.start_clock = hg.GetClock()
			photo_state.state = "display_photo"
		end
	end

	scene:Update(dt)
	crt_scene:Update(dt)

	-- rendering
	view_id = 0  -- keep track of the next free view id

	-- vr
	if open_vr_enabled then
			actor_body_mtx = hg.TransformationMat4(initial_head_pos, hg.Vec3(0, 0, 0))

			vr_state = hg.OpenVRGetState(actor_body_mtx, 0.05, 1000)
			left, right = hg.OpenVRStateToViewState(vr_state)

			passId = hg.SceneForwardPipelinePassViewId()

			-- Prepare view-independent render data once
			view_id, passId = hg.PrepareSceneForwardPipelineCommonRenderData(view_id, scene, render_data, pipeline, res, passId)
			vr_eye_rect = hg.IntRect(0, 0, vr_state.width, vr_state.height)

			-- Prepare the left eye render data then draw to its framebuffer
			view_id, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(view_id, left, scene, render_data, pipeline, res, passId)
			view_id, passId = hg.SubmitSceneToForwardPipeline(view_id, scene, vr_eye_rect, left, pipeline, render_data, res, vr_left_fb:GetHandle())

			-- Prepare the right eye render data then draw to its framebuffer
			view_id, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(view_id, right, scene, render_data, pipeline, res, passId)
			view_id, passId = hg.SubmitSceneToForwardPipeline(view_id, scene, vr_eye_rect, right, pipeline, render_data, res, vr_right_fb:GetHandle())
	else
		view_id, passId = hg.SubmitSceneToPipeline(view_id, scene, hg.IntRect(0, 0, res_x, res_y), true, pipeline, res)
	end

	view_id = view_id + 1

	-- -- CRT display rendering
	if open_vr_enabled then

		view_id, passId = hg.SubmitSceneToPipeline(view_id, crt_scene, hg.IntRect(0, 0, res_x, res_y), true, pipeline, res)

		local chroma_distortion = clamp(map(photo_state.noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)
		local clamped_noise = clamp(photo_state.noise_intensity, 0.01, 1.0)

		-- text OSD
		local osd_text = folder_short[photo_state.current_folder] .. (photo_state.current_photo - 1)
		-- osd_text = ghostWorldAssociations[photo_state.index_photo0]
		view_id = view_id + 1

		hg.SetView2D(view_id, 0, 0, res_x, res_y, -1, 1, hg.CF_None, hg.Color.Black, 1, 0)

		local text_pos = hg.Vec3(res_x * 0.05, res_y * 0.05, -0.5)
		local _osd_colors = {hg.Vec4(1.0, 0.0, 0.0, 0.8), hg.Vec4(0.0, 1.0, 0.0, 0.8), hg.Vec4(1.0, 1.0, 1.0, 1.0)}
		local _osd_offsets = {-2.0, 1.0, 0.0}

		for _text_loop = 1, 3 do
			local _text_offset = hg.Vec3(res_x * 0.001 * _osd_offsets[_text_loop] * clamped_noise, 0.0, 0.0)
			hg.DrawText(view_id, font_osd, osd_text, font_program, 'u_tex', 0, 
					hg.Mat4.Identity, text_pos + _text_offset, hg.DTHA_Left, hg.DTVA_Bottom, 
					{hg.MakeUniformSetValue('u_color', _osd_colors[_text_loop])}, 
					{}, text_render_state)
		end
	end

	-- Display the VR eyes texture to the backbuffer
	if VR_DEBUG_DISPLAY and open_vr_enabled then
		hg.SetViewRect(view_id, 0, 0, res_x, res_y)
		vs = hg.ComputeOrthographicViewState(hg.TranslationMat4(hg.Vec3(0, 0, 0)), res_y, 0.1, 100, hg.ComputeAspectRatioX(res_x, res_y))
		hg.SetViewTransform(view_id, vs.view, vs.proj)

		quad_uniform_set_texture_list:clear()
		quad_uniform_set_texture_list:push_back(hg.MakeUniformSetTexture("s_tex", hg.OpenVRGetColorTexture(vr_left_fb), 0))
		hg.SetT(quad_matrix, hg.Vec3(eye_t_x, 0, 1))
		hg.DrawModel(view_id, quad_model, tex0_program, quad_uniform_set_value_list, quad_uniform_set_texture_list, quad_matrix, quad_render_state)

		quad_uniform_set_texture_list:clear()
		quad_uniform_set_texture_list:push_back(hg.MakeUniformSetTexture("s_tex", hg.OpenVRGetColorTexture(vr_right_fb), 0))
		hg.SetT(quad_matrix, hg.Vec3(-eye_t_x, 0, 1))
		hg.DrawModel(view_id, quad_model, tex0_program, quad_uniform_set_value_list, quad_uniform_set_texture_list, quad_matrix, quad_render_state)
	end

	hg.Frame()

	if open_vr_enabled then
		hg.OpenVRSubmitFrame(vr_left_fb, vr_right_fb)
	end

	hg.UpdateWindow(win)

	-- scene:GarbageCollect()
	-- collectgarbage()
end

hg.DestroyForwardPipeline(pipeline)
hg.RenderShutdown()
hg.DestroyWindow(win)

-- Display a scene in VR

function LoadPhotoFromTable(_photo_table, _photo_idx, _photo_folder)
	return hg.LoadTextureFromAssets('photos/' .. _photo_folder .. "/" .. _photo_table[_photo_idx] .. '.png', hg.TF_UClamp)
end

hg = require("harfang")
require("utils")
require("arguments")
require("coroutines")

hg.InputInit()
hg.WindowSystemInit()
hg.OpenALInit()

SLIDE_SHOW_SPEED = 1.0
VR_DEBUG_DISPLAY = false
-- local res_x, res_y = 768, 576
-- local res_x, res_y = 800, 600
local res_x, res_y = 960, 720
-- local res_x, res_y = math.floor(1080 * (4/3)), 1080
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

imgui_prg = hg.LoadProgramFromAssets('core/shader/imgui')
imgui_img_prg = hg.LoadProgramFromAssets('core/shader/imgui_image')

local imgui_vid = 255
hg.ImGuiInit(imgui_vid, imgui_prg, imgui_img_prg)

pipeline = hg.CreateForwardPipeline(2048, false)
res = hg.PipelineResources()

-- VR Stuff

render_data = hg.SceneForwardPipelineRenderData()  -- this object is used by the low-level scene rendering API to share view-independent data with both eyes

-- OpenVR initialization
if not hg.OpenVRInit() then
	os.exit()
end

vr_left_fb = hg.OpenVRCreateEyeFrameBuffer(hg.OVRAA_MSAA4x)
vr_right_fb = hg.OpenVRCreateEyeFrameBuffer(hg.OVRAA_MSAA4x)

-- Create models
vtx_layout = hg.VertexLayoutPosFloatNormUInt8()

cube_mdl = hg.CreateCubeModel(vtx_layout, 1, 1, 1)
cube_ref = res:AddModel('cube', cube_mdl)
ground_mdl = hg.CreateCubeModel(vtx_layout, 50, 0.01, 50)
ground_ref = res:AddModel('ground', ground_mdl)

-- Load shader
prg_ref = hg.LoadPipelineProgramRefFromAssets('core/shader/pbr.hps', res, hg.GetForwardPipelineInfo())

-- Create materials
function create_material(ubc, orm)
	mat = hg.Material()
	hg.SetMaterialProgram(mat, prg_ref)
	hg.SetMaterialValue(mat, "uBaseOpacityColor", ubc)
	hg.SetMaterialValue(mat, "uOcclusionRoughnessMetalnessColor", orm)
	return mat
end

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
screen_prg = hg.LoadProgramFromAssets('shaders/vhs_fx.vsb', 'shaders/vhs_fx.fsb')

-- create a plane model for the final rendering stage
local vtx_layout = hg.VertexLayoutPosFloatNormUInt8TexCoord0UInt8()

local screen_zoom = 1
local screen_mdl = hg.CreatePlaneModel(vtx_layout, screen_zoom, screen_zoom * (res_y / res_x), 1, 1)
local screen_ref = res:AddModel('screen', screen_mdl)

-- video stream
local tex_video = hg.CreateTexture(res_x, res_y, "Video texture", 0)
local size = hg.iVec2(res_x, res_y)
local fmt = hg.TF_RGB8

local streamer = hg.MakeVideoStreamer('hg_ffmpeg.dll')
streamer:Startup()
local handle = streamer:Open('assets_compiled/videos/glitches.mp4')
streamer:Play(handle)
local video_start_clock = hg.GetClock()

-- CRT photos data

-- state context
local photo_state = {
    current_photo = nil,
    photo_table = nil,
    next_tex = nil,
    tex_photo0 = nil,
	index_photo0 = nil,
    noise_intensity = nil,
    coroutine = nil,
	sounds = {}
}

-- photo
local idx

photo_tables = {}
folder_table = {"arzamas_16", "fantomy", "hazmat", "netzwerk", "radiograf"}
folder_short = {"_ARZM/", "_FNTM/", "_HZMT/", "_NETW/", "_RDIO/"}

for idx = 1, 5 do
	photo_tables[folder_table[idx]] = {}
end

photo_tables.arzamas_16 = {}
photo_tables.fantomy = {}
photo_tables.hazmat = {}
photo_tables.netzwerk = {}
photo_tables.radiograf = {}

for idx = 0, 23 do
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
photo_state.next_tex = nil
photo_state.tex_photo0 = LoadPhotoFromTable(photo_state.photo_table, photo_state.current_photo, folder_table[photo_state.current_folder])
photo_state.index_photo0 = photo_state.current_photo

photo_state.noise_intensity = 0.0
chroma_distortion = 0.0

local zoom_level = 1.125
zoom_level = 1.0 / zoom_level

-- 3D scene stuff

-- Create scene
scene = hg.Scene()
hg.LoadSceneFromAssets("main.scn", scene, res, hg.GetForwardPipelineInfo())

-- Setup 2D rendering to display eyes textures
quad_layout = hg.VertexLayout()
quad_layout:Begin():Add(hg.A_Position, 3, hg.AT_Float):Add(hg.A_TexCoord0, 3, hg.AT_Float):End()

quad_model = hg.CreatePlaneModel(quad_layout, 1, 1, 1, 1)
quad_render_state = hg.ComputeRenderState(hg.BM_Alpha, hg.DT_Disabled, hg.FC_Disabled)

eye_t_size = res_x / 2.5
eye_t_x = (res_x - 2 * eye_t_size) / 6 + eye_t_size / 2
quad_matrix = hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(hg.Deg(90), hg.Deg(0), hg.Deg(0)), hg.Vec3(eye_t_size, 1, eye_t_size))

tex0_program = hg.LoadProgramFromAssets("shaders/sprite")

quad_uniform_set_value_list = hg.UniformSetValueList()
quad_uniform_set_value_list:clear()
quad_uniform_set_value_list:push_back(hg.MakeUniformSetValue("color", hg.Vec4(1, 1, 1, 1)))

quad_uniform_set_texture_list = hg.UniformSetTextureList()

local initial_head_pos = scene:GetNode("FPSCamera"):GetTransform():GetPos()
initial_head_pos.y = 0.0

local keyboard = hg.Keyboard('raw')
local switch_clock = hg.GetClock()

-- Main loop
while not keyboard:Pressed(hg.K_Escape) and hg.IsWindowOpen(win) do
	keyboard:Update()
	dt = hg.TickClock()

	if photo_state.coroutine == nil and (keyboard:Released(hg.K_Space) or (hg.GetClock() - switch_clock > hg.time_from_sec_f(10.0 / SLIDE_SHOW_SPEED))) then
		photo_state.coroutine = coroutine.create(PhotoChangeCoroutine)
		switch_clock = hg.GetClock()
	elseif photo_state.coroutine and coroutine.status(photo_state.coroutine) ~= 'dead' then
		coroutine.resume(photo_state.coroutine, photo_state)
	else
		photo_state.coroutine = nil
	end

	-- CRT display

	-- slideshow main logic
	if photo_state.coroutine == nil and (keyboard:Released(hg.K_Space) or (hg.GetClock() - switch_clock > hg.time_from_sec_f(10.0 / SLIDE_SHOW_SPEED))) then
		photo_state.coroutine = coroutine.create(PhotoChangeCoroutine)
		switch_clock = hg.GetClock()
	elseif photo_state.coroutine and coroutine.status(photo_state.coroutine) ~= 'dead' then
		coroutine.resume(photo_state.coroutine, photo_state)
	else
		photo_state.coroutine = nil
	end

	-- prepare slideshow display
	chroma_distortion = clamp(map(photo_state.noise_intensity, 0.1, 0.5, 0.0, 1.0), 0.0, 1.0)
	val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(photo_state.noise_intensity, chroma_distortion, 0.0, 0.0))}
	-- val_uniforms = {hg.MakeUniformSetValue('control', hg.Vec4(1.0, 1.0, 0.0, 0.0))} -- test only
	_, tex_video, size, fmt = hg.UpdateTexture(streamer, handle, tex_video, size, fmt)

	tex_uniforms = {
		hg.MakeUniformSetTexture('u_video', tex_video, 0),
		hg.MakeUniformSetTexture('u_photo0', photo_state.tex_photo0, 1)
	}

	-- loop noise video (ffmpeg)
	if hg.GetClock() - video_start_clock > hg.time_from_sec_f(7.0) then
		video_start_clock = hg.GetClock()
		print("Restart glitch tape!")
		streamer:Seek(handle, 0)
		streamer:Play(handle)
	end

	scene:Update(dt)

	-- vr
	actor_body_mtx = hg.TransformationMat4(initial_head_pos, hg.Vec3(0, 0, 0))

	vr_state = hg.OpenVRGetState(actor_body_mtx, 0.05, 1000)
	left, right = hg.OpenVRStateToViewState(vr_state)

	view_id = 0  -- keep track of the next free view id
	passId = hg.SceneForwardPipelinePassViewId()

	-- CRT display rendering

	hg.SetViewPerspective(view_id, 0, 0, res_x, res_y, hg.TranslationMat4(hg.Vec3(0, 0, -0.68 * zoom_level)))

	hg.DrawModel(view_id, screen_mdl, screen_prg, val_uniforms, tex_uniforms, hg.TransformationMat4(hg.Vec3(0, 0, 0), hg.Vec3(math.pi / 2, math.pi, 0)))

	-- text OSD
	local osd_text = folder_short[photo_state.current_folder] .. (photo_state.index_photo0 - 1)
	-- osd_text = ghostWorldAssociations[photo_state.index_photo0]
	view_id = view_id + 1

	hg.SetView2D(view_id, 0, 0, res_x, res_y, -1, 1, hg.CF_None, hg.Color.Black, 1, 0)

	local text_pos = hg.Vec3(res_x * 0.05, res_y * 0.05, -0.5)
	local _osd_colors = {hg.Vec4(1.0, 0.0, 0.0, 0.8), hg.Vec4(0.0, 1.0, 0.0, 0.8), hg.Vec4(1.0, 1.0, 1.0, 1.0)}
	local _osd_offsets = {-2.0, 1.0, 0.0}

	for _text_loop = 1, 3 do
		local _text_offset = hg.Vec3(res_x * 0.001 * _osd_offsets[_text_loop] * photo_state.noise_intensity, 0.0, 0.0)
		hg.DrawText(view_id, font_osd, osd_text, font_program, 'u_tex', 0, 
				hg.Mat4.Identity, text_pos + _text_offset, hg.DTHA_Left, hg.DTVA_Bottom, 
				{hg.MakeUniformSetValue('u_color', _osd_colors[_text_loop])}, 
				{}, text_render_state)
	end

	-- Prepare view-independent render data once
	view_id, passId = hg.PrepareSceneForwardPipelineCommonRenderData(view_id, scene, render_data, pipeline, res, passId)
	vr_eye_rect = hg.IntRect(0, 0, vr_state.width, vr_state.height)

	-- Prepare the left eye render data then draw to its framebuffer
	view_id, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(view_id, left, scene, render_data, pipeline, res, passId)
	view_id, passId = hg.SubmitSceneToForwardPipeline(view_id, scene, vr_eye_rect, left, pipeline, render_data, res, vr_left_fb:GetHandle())

	-- Prepare the right eye render data then draw to its framebuffer
	view_id, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(view_id, right, scene, render_data, pipeline, res, passId)
	view_id, passId = hg.SubmitSceneToForwardPipeline(view_id, scene, vr_eye_rect, right, pipeline, render_data, res, vr_right_fb:GetHandle())

	view_id = view_id + 1

	-- Display the VR eyes texture to the backbuffer
	if VR_DEBUG_DISPLAY then
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

	-- ImGUI
	hg.ImGuiBeginFrame(res_x, res_y, hg.TickClock(), hg.ReadMouse(), hg.ReadKeyboard())

	if hg.ImGuiBegin('Debug') then
		hg.ImGuiText('Actor:')
		hg.ImGuiInputVec3("Pos", hg.GetTranslation(vr_state.head))
	end
	hg.ImGuiEnd()

	hg.SetView2D(imgui_vid, 0, 0, res_x, res_y, -1, 1, 0, hg.Color.Black, 1, 0)
	hg.ImGuiEndFrame(imgui_vid)

	hg.Frame()
	hg.OpenVRSubmitFrame(vr_left_fb, vr_right_fb)

	hg.UpdateWindow(win)
end

hg.DestroyForwardPipeline(pipeline)
hg.RenderShutdown()
hg.DestroyWindow(win)

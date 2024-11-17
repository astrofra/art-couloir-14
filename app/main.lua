-- Display a scene in VR

hg = require("harfang")

hg.InputInit()
hg.WindowSystemInit()

res_x, res_y = 1280, 720
win = hg.RenderInit("Couloir 14", res_x, res_y, hg.RF_VSync) -- | hg.RF_MSAA4X)

hg.AddAssetsFolder("assets_compiled")

imgui_prg = hg.LoadProgramFromAssets('core/shader/imgui')
imgui_img_prg = hg.LoadProgramFromAssets('core/shader/imgui_image')

local imgui_vid = 255
hg.ImGuiInit(imgui_vid, imgui_prg, imgui_img_prg)

pipeline = hg.CreateForwardPipeline(2048, false)
res = hg.PipelineResources()

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

-- Main loop
while not hg.ReadKeyboard():Key(hg.K_Escape) and hg.IsWindowOpen(win) do
	dt = hg.TickClock()

	scene:Update(dt)

	actor_body_mtx = hg.TransformationMat4(initial_head_pos, hg.Vec3(0, 0, 0))

	vr_state = hg.OpenVRGetState(actor_body_mtx, 0.05, 1000)
	left, right = hg.OpenVRStateToViewState(vr_state)

	vid = 0  -- keep track of the next free view id
	passId = hg.SceneForwardPipelinePassViewId()

	-- Prepare view-independent render data once
	vid, passId = hg.PrepareSceneForwardPipelineCommonRenderData(vid, scene, render_data, pipeline, res, passId)
	vr_eye_rect = hg.IntRect(0, 0, vr_state.width, vr_state.height)

	-- Prepare the left eye render data then draw to its framebuffer
	vid, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(vid, left, scene, render_data, pipeline, res, passId)
	vid, passId = hg.SubmitSceneToForwardPipeline(vid, scene, vr_eye_rect, left, pipeline, render_data, res, vr_left_fb:GetHandle())

	-- Prepare the right eye render data then draw to its framebuffer
	vid, passId = hg.PrepareSceneForwardPipelineViewDependentRenderData(vid, right, scene, render_data, pipeline, res, passId)
	vid, passId = hg.SubmitSceneToForwardPipeline(vid, scene, vr_eye_rect, right, pipeline, render_data, res, vr_right_fb:GetHandle())

	-- Display the VR eyes texture to the backbuffer
	hg.SetViewRect(vid, 0, 0, res_x, res_y)
	vs = hg.ComputeOrthographicViewState(hg.TranslationMat4(hg.Vec3(0, 0, 0)), res_y, 0.1, 100, hg.ComputeAspectRatioX(res_x, res_y))
	hg.SetViewTransform(vid, vs.view, vs.proj)

	quad_uniform_set_texture_list:clear()
	quad_uniform_set_texture_list:push_back(hg.MakeUniformSetTexture("s_tex", hg.OpenVRGetColorTexture(vr_left_fb), 0))
	hg.SetT(quad_matrix, hg.Vec3(eye_t_x, 0, 1))
	hg.DrawModel(vid, quad_model, tex0_program, quad_uniform_set_value_list, quad_uniform_set_texture_list, quad_matrix, quad_render_state)

	quad_uniform_set_texture_list:clear()
	quad_uniform_set_texture_list:push_back(hg.MakeUniformSetTexture("s_tex", hg.OpenVRGetColorTexture(vr_right_fb), 0))
	hg.SetT(quad_matrix, hg.Vec3(-eye_t_x, 0, 1))
	hg.DrawModel(vid, quad_model, tex0_program, quad_uniform_set_value_list, quad_uniform_set_texture_list, quad_matrix, quad_render_state)

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

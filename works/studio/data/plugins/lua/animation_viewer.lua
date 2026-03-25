plugin_type = "EditorPlugin"

states = {}

function GetState(key)
	local state = states[key]

	if state == nil then
		state = {
			selected_take = 0
		}
		states[key] = state
	end

	return state
end

show_ui = false

function OnLoad()
	ed.RegisterShortcut('Window.AnimationViewer')
	return true
end

function ExtendWindowMenu()
	local current_document_can_animate = GetCurrentSceneDocument() ~= nil
	res, show_ui = ed.MenuCheckWithShortcut(ed.tr('Animation Viewer'), 'Window.AnimationViewer', show_ui, current_document_can_animate)
end

function DrawKeyframe(draw_list, key)
	hg.ImGuiButton('', hg.Vector2(8, 12))
	if hg.ImGuiIsItemHovered() then
		hg.ImGuiSetTooltip('t: '..key.t)
	end
end

function DrawAnimationTrack(doc, track, t_min, t_max)
	local target = track:GetTarget()
	hg.ImGuiText(target) -- TODO push clip rect

	-- tracks
	local tracks_header_width = 256

	hg.ImGuiIndent(tracks_header_width)
	local old_cursor_pos = hg.ImGuiGetCursorPos()

	local track_len = hg.ImGuiGetContentRegionAvailWidth()
	local track_t_len = t_max - t_min

	local draw_list = hg.ImGuiGetWindowDrawList()
	local key_count = track:GetKeyCount()

	for i=1,key_count,1 do
		local key = track:GetKey(i-1)

		local key_pos_x = (key.t * track_len) / track_t_len -- pos in track
		hg.ImGuiSameLine(tracks_header_width + key_pos_x)

		DrawKeyframe(draw_list, key)

		hg.ImGuiSetCursorPos(old_cursor_pos) -- restore cursor to start of track
	end

	hg.ImGuiUnindent(tracks_header_width)
end

function DrawAnimation(doc, anim)
	hg.ImGuiPushItemWidth(200)

	-- header
	local target = anim:GetTarget()
	local r, v = hg.ImGuiInputText(ed.tr('Target'), target, 256)
	if r then
		doc:TakeSnapshot('AnimSetTarget')
		anim:SetTarget(v)
	end

	hg.ImGuiSameLine()
	if hg.ImGuiButton('+') then
		-- TODO
	end
	if hg.ImGuiIsItemHovered() then hg.ImGuiSetTooltip(ed.tr('Add animation track')) end

	-- tracks
	hg.ImGuiIndent()
	local track_count = anim:GetTrackCount()
	for i = 1,track_count,1 do
		DrawAnimationTrack(doc, anim:GetTrack(i-1), hg.time_from_sec(0), hg.time_from_sec(5))
	end
	hg.ImGuiUnindent()
end

function DrawAnimationTake(doc, take)
	hg.ImGuiColumns(4, 'TakeHeader', false)

	-- header
	local r, v = hg.ImGuiInputText(ed.tr('Name'), take:GetName(), 256)
	if r then
		doc:TakeSnapshot('AnimTakeSetName')
		take:SetName(v)
	end

	hg.ImGuiNextColumn()
	if hg.ImGuiButton(ed.tr('Add animation...')) then
		-- TODO
	end

	local t_start, t_end = take:GetRange()

	hg.ImGuiNextColumn()
	r, v = hg.ImGuiInput_time_ns("T start", t_start)
	if r then t_start = v end

	hg.ImGuiNextColumn()
	local r2, v2 = hg.ImGuiInput_time_ns("T end", t_end)
	if r2 then t_end = v2 end

	if r or r2 then
		doc:TakeSnapshot('AnimTakeSetRange')
		take:SetRange(t_start, t_end)
	end

	hg.ImGuiColumns()

	-- animations
	if hg.ImGuiBeginChild('AnimationsView', hg.Vector2(0, 0), true) then
		local anim_count = take:GetAnimCount()

		for i = 1,anim_count,1 do
			hg.ImGuiPushID(i)
			DrawAnimation(doc, take:GetAnim(i-1))
			hg.ImGuiPopID()

			hg.ImGuiSeparator()
		end

		hg.ImGuiEndChild()
	end
end

function DrawSceneAnimationTakes(doc, scene, state)
	if ed.IsShortcutDown('Window.AnimationViewer') then show_ui = not show_ui end

	if show_ui == false then return end

	res, show_ui = hg.ImGuiBegin('Animation', 0)

	if res then
		local take_names = {}

		local take_count = scene:GetAnimTakeCount()

		if take_count == 0 then
			if hg.ImGuiButton(ed.tr('Add')) then
				doc:TakeSnapshot("AddAnimTake")
				scene:AddAnimTake(hg.AnimTake('New take'))
			end
		else
			for i = 1,take_count,1 do
				take_names[i] = tostring(i-1)..': '..scene:GetAnimTake(i-1):GetName()
			end

			if state.selected_take >= take_count then state.selected_take = take_count - 1 end

			hg.ImGuiPushItemWidth(128)
			res, state.selected_take = hg.ImGuiCombo(ed.tr('Takes'), state.selected_take, hg.StringList(take_names))

			hg.ImGuiSameLine()
			if hg.ImGuiButton(ed.tr('Add')) then
				doc:TakeSnapshot("AddAnimTake")
				scene:AddAnimTake(hg.AnimTake('Take #'..take_count))
			end

			hg.ImGuiSameLine()
			if hg.ImGuiButton(ed.tr('Delete')) then
				doc:TakeSnapshot("DeleteAnimTake")
				scene:RemoveAnimTake(state.selected_take)
			end

			hg.ImGuiSeparator()
			DrawAnimationTake(doc, scene:GetAnimTake(state.selected_take))
		end
	end
	hg.ImGuiEnd()
end

function GetCurrentSceneDocument()
	local doc = ed.GetDocumentInFocus()
	if doc ~= nil then if doc:GetType() == 'Scene' then return doc end end
	return nil
end

function DrawUI() -- UI thread
	local doc = GetCurrentSceneDocument()

	if doc ~= nil then
		local doc_state = GetState(doc:GetPath())
		DrawSceneAnimationTakes(doc, doc:GetScene(), doc_state)
	end
end

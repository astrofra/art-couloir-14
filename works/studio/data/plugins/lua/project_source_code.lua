-- Assemble plugin implementing Project source code support
--
-- Features:
--
-- * Lua based project support.
-- * Describe source code configuration for the Project.
-- * Provide a way to run the project source code and monitor and control the runing process.

plugin_type = 'EditorPlugin'

--
config_path = '@project-meta:source_code.json'

function LoadConfig()
	local doc = hg.CreateJSONDocumentReader()
	if doc:Load(config_path) == false then return end

	local res, v
	res, v = doc:ReadString('startup_directory')
	if res then startup_directory = v end
	res, v = doc:ReadString('lua_startup_script')
	if res then lua_startup_script = v end
end

function SaveConfig()
	local doc = hg.CreateJSONDocumentWriter()
	doc:WriteString('startup_directory', startup_directory)
	doc:WriteString('lua_startup_script', lua_startup_script)
	return doc:Save(config_path)
end

--
function OnProjectOpened()
	startup_directory = ed.GetProjectDir()
	LoadConfig()
end

function OnCloseProject()
	if IsProjectRunning() then StopProcess() end
	SaveConfig()
	return true
end

--
function IsProjectRunning()
	if process == nil then return false end
	local finished, exit_status = process:try_get_exit_status()
	if finished then process = nil end
	local res = process ~= nil
	return res
end

function RunLuaProject()
	local command_line = ed.GetDataDir()..'/runtime/lua/lua.exe '..lua_startup_script
	print('Starting project {project_dir: '..startup_directory..' command_line: '..command_line..'}')
	process = ed.Process(command_line, startup_directory)
end

--
function RunProject()
	if IsProjectRunning() == false then
		RunLuaProject()
	end
	SaveConfig()
end

function StopProject()
	if IsProjectRunning() then
		process:kill()
	end
end

--
startup_directory = ''

lua_startup_script = 'main.lua'

function ExtendProjectProperties()
	if hg.ImGuiCollapsingHeader(ed.tr('Source Code')) then
		local res

		hg.ImGuiColumns(2, 'source', false)
		hg.ImGuiSetColumnWidth(0, hg.ImGuiGetWindowContentRegionWidth() * 0.8)

		res, startup_directory = hg.ImGuiInputText(ed.tr('Startup Directory'), startup_directory, 512)
		hg.ImGuiNextColumn()
		if hg.ImGuiButton(ed.tr('Browse...')) then
			res, startup_directory = hg.OpenFolderDialog(ed.tr('Select Startup Directory'), startup_directory, startup_directory)
		end
		hg.ImGuiNextColumn()

		res, lua_startup_script = hg.ImGuiInputText(ed.tr('Startup Script'), lua_startup_script, 512)
		hg.ImGuiNextColumn()
		if hg.ImGuiButton(ed.tr('Browse...')) then
			-- TODO support for std::function<> in Fabgen
		end
		hg.ImGuiNextColumn()

		hg.ImGuiColumns()
	end
end

function ExtendProjectMenu()
	hg.ImGuiSeparator()

	if ed.MenuItemWithShortcut(ed.tr('Run Project...'), 'Project.Run', IsProjectRunning() == false) then
		RunProject()
	end

	if ed.MenuItemWithShortcut(ed.tr('Stop Project'), 'Project.Stop', IsProjectRunning()) then
		StopProject()
	end
end

function ExtendStatusBar()
	if (IsProjectRunning()) then
		hg.ImGuiSameLine()
		hg.ImGuiText(ed.tr('Project Running'))
	end
end

--
function DrawUI()
	if ed.IsShortcutDown('Project.Run') then RunProject() end
	if ed.IsShortcutDown('Project.Stop') then StopProject() end
end

--
function OnLoad()
	ed.RegisterShortcut('Project.Run', 'Ctrl+F5')
	ed.RegisterShortcut('Project.Stop', 'Shift+F5')
	return true
end

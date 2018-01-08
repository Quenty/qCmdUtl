local PROJECT_NAME = "qCmdUtl"
local VERSION = "5.1.4"

if _G.RegisterPlugin and not _G.RegisterPlugin(PROJECT_NAME) then return end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CoreGui              = game:GetService("CoreGui")

local gloo = require(script.Parent.Gloo)

local Plugin              = PluginManager():CreatePlugin()
local PluginActive        = false
local Toolbar             = Plugin:CreateToolbar(PROJECT_NAME)
local ActivateGUIButton   = Toolbar:CreateButton("", ""..PROJECT_NAME.."", "http://www.roblox.com/asset/?id=172761963")

local NewCFrame           = CFrame.new
local Vector3FromNormalId = Vector3.FromNormalId
local Vector3FromAxis     = Vector3.FromAxis

local LegacyMode = false -- Just for you asimo3089...  https://xkcd.com/1172/

local ceil  = math.ceil
local floor = math.floor


--[[

This code is very old, and therefore, I do not recommend you consider its structure or content of very high quality.

~ Quenty
5.1.4

5.1.3 Changelog
 - Remove output spam from keys
 - Fixed FormFactor to reflect ROBLOX's new policy (resize tool)
 - Cleaned up legacy code
 - Started change log
 - Duplicate [NM] should no longer crash when cloning folders

]]

------------------------ qGUI.lua ------------------------

local function PointInBounds(Frame, X, Y)
	local TopBound    = Frame.AbsolutePosition.Y
	local BottomBound = Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
	local LeftBound   = Frame.AbsolutePosition.X
	local RightBound  = Frame.AbsolutePosition.X + Frame.AbsoluteSize.X

	if Y > TopBound and Y < BottomBound and X > LeftBound and X < RightBound then
		return true
	else
		return false
	end
end

------------------------ Signal.lua ------------------------

local Signal = {}

function Signal.new()
	local sig = {}

	local mSignaler = Instance.new('BindableEvent')

	local mArgData = nil
	local mArgDataCount = nil

	function sig:fire(...)
		mArgData = {...}
		mArgDataCount = select('#', ...)
		mSignaler:Fire()
	end

	function sig:connect(f)
		if not f then error("connect(nil)", 2) end
		return mSignaler.Event:connect(function()
			f(unpack(mArgData, 1, mArgDataCount))
		end)
	end

	function sig:wait()
		mSignaler.Event:wait()
		assert(mArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
		return unpack(mArgData, 1, mArgDataCount)
	end

	function sig:Destroy()
		mSignaler:Destroy()
		mArgData      = nil
		mArgDataCount = nil
		mSignaler     = nil
	end

	return sig
end


------------------------ qSystems.lua ------------------------

local function RoundNumber(Number, Divider)
	-- Rounds a Number, with 1.5 rounding up to 2, and so forth, by default. 
	-- @param Number the Number to round
	-- @param [Divider] optional Number of which to "round" to. If nothing is given, it will default to 1. 

	Divider = Divider or 1

	return (math.floor((Number/Divider)+0.5)*Divider)
end


------------------------ ORIGINAL CODE ------------------------

local function Snap(number,by)
	if by == 0 then
		return number
	else
		return floor(number/by + 0.5)*by
	end
end

local function NumNormal(n)
	return n == 0 and 0 or n/math.abs(n)
end

local function StrFix(str,size,pad)
	local str_size = #str
	if size > str_size then
		return string.rep(pad or "0",size-str_size) .. str
	elseif size < str_size then
		return str:sub(str_size-size+1)
	else
		return str
	end
end

local function IsPosInt(n)
	return type(n) == "number" and n > 0 and floor(n) == n
end

function IsArray(array)
	local max,n = 0,0
	for k,v in pairs(array) do
		if not IsPosInt(k) then
			return false
		end
		max = math.max(max,k)
		n = n + 1
	end
	return n == max
end

local function GetIndex(table,value)
	for i,v in pairs(table) do
		if v == value then
			return i
		end
	end
end

local function class(name)
	local def = {}
	getfenv(0)[name] = def
	return function(ctor, static)
		local nctor = function(...)
			local this = {}
			if ctor then
				ctor(this, ...)
			end
			return this
		end
		getfenv(0)['Create'..name] = nctor
		if static then static(def) end
	end
end

local function Create(ty)
	return function(data)
		local obj = Instance.new(ty)
		for k, v in pairs(data) do
			if type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		return obj
	end
end

local function Modify(obj)
	return function(data)
		for k, v in pairs(data) do
			if type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		return obj
	end
end

--[[----------------------------------------------------------------------------
EventGroup
	Manages event connections. Added events will remain until removal. Removed events are automatically disconnected.
	Subgroups, which are EventGroups, can also be added.

	Adding an event*:
		EventGroup.EventName = (event)
	Removing (and disconnecting) an event:
		EventGroup.EventName = nil

	Adding a new subgroup (and adding event to that group)**:
		EventGroup.NewGroup.EventName = (event)
	Removing a subgroup (and removing all of the group's events):
		EventGroup.NewGroup = nil

	Getting all events:
		EventGroup("GetEvents")
	Getting all subgroups:
		EventGroup("GetGroups")
	Removing all events and subgroups:
		EventGroup("Clear")

	*If an event or group already exists with the same name, it will first be removed.
	**The group does not have to be created beforehand.
]]

class'EventGroup'(function(def)
	local eventContainer = {}
	local groupContainer = {}

	local methods = {
		GetEvents = function(self)
			local copy = {}
			for name,event in pairs(eventContainer) do
				copy[name] = event
			end
			return copy
		end;
		GetGroups = function(self)
			local copy = {}
			for name,group in pairs(groupContainer) do
				copy[name] = group
			end
			return copy
		end;
		Clear = function(self)
			for k in pairs(eventContainer) do
				self[k] = nil
			end
			for k in pairs(groupContainer) do
				self[k] = nil
			end
		end;
	}

	setmetatable(def,{
		__index = function(t,k)
			local event = eventContainer[k]
			if event then
				return event
			else
				local group = groupContainer[k]
				if group == nil then
					group = CreateEventGroup()
					groupContainer[k] = group
				end
				return group
			end
		end;
		__newindex = function(t,k,v)
			local event = eventContainer[k]
			if event ~= nil then
				if event.disconnect then
					event:disconnect()
				end
				eventContainer[k] = nil
			else
				local group = groupContainer[k]
				if group ~= nil then
					group("Clear")
					groupContainer[k] = nil
				end
			end
			if v ~= nil then
				eventContainer[k] = v
			end
		end;
		__call = function(self,name,...)
			if methods[name] then
				return methods[name](self,...)
			else
				error("EventGroup: "..tostring(name).." is not a valid method",2)
			end
		end;
	})
end)

local CreateEventGroup = CreateEventGroup -- kill errors.
local Event = CreateEventGroup()

-- go-to for outputting info
function Log(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG:",out)
end

function LogWarning(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG_WARNING:",out)
end

function LogError(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG_ERROR:",out)
end

local function TransformModel(objects, center, new, recurse)
	for _,object in pairs(objects) do
		if object:IsA("BasePart") then
			object.CFrame = new:toWorldSpace(center:toObjectSpace(object.CFrame))
		end
		if recurse then
			TransformModel(object:GetChildren(), center, new, true)
		end
	end
end

local function RecurseFilter(object,class,out)
	if object:IsA(class) then
		table.insert(out,object)
	end
	for _,child in pairs(object:GetChildren()) do
		RecurseFilter(child,class,out)
	end
end

local function GetFiltered(class,objects)
	local out = {}
	for _,object in pairs(objects) do
		RecurseFilter(object,class,out)
	end
	return out
end;

local bb_points = {
	Vector3.new(-1,-1,-1);
	Vector3.new( 1,-1,-1);
	Vector3.new(-1, 1,-1);
	Vector3.new( 1, 1,-1);
	Vector3.new(-1,-1, 1);
	Vector3.new( 1,-1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new( 1, 1, 1);
}

-- recursive for GetBoundingBox
local function RecurseGetBoundingBox(object,sides,parts)
	if object:IsA"BasePart" then
		local mod = object.Size/2
		local rot = object.CFrame
		for i = 1,#bb_points do
			local point = rot*NewCFrame(mod*bb_points[i]).p
			if point.x > sides[1] then sides[1] = point.x end
			if point.x < sides[2] then sides[2] = point.x end
			if point.y > sides[3] then sides[3] = point.y end
			if point.y < sides[4] then sides[4] = point.y end
			if point.z > sides[5] then sides[5] = point.z end
			if point.z < sides[6] then sides[6] = point.z end
		end
		if parts then parts[#parts + 1] = object end
	end
	local children = object:GetChildren()
	for i = 1,#children do
		RecurseGetBoundingBox(children[i],sides,parts)
	end
end

local function GetBoundingBox(objects,return_parts)
	local sides = {-math.huge;math.huge;-math.huge;math.huge;-math.huge;math.huge}
	local parts
	if return_parts then
		parts = {}
	end
	for i = 1,#objects do
		RecurseGetBoundingBox(objects[i],sides,parts)
	end
	return
		Vector3.new(sides[1]-sides[2],sides[3]-sides[4],sides[5]-sides[6]),
		Vector3.new((sides[1]+sides[2])/2,(sides[3]+sides[4])/2,(sides[5]+sides[6])/2),
		parts
end

local anchor_lookup = {}
local function Anchor(part,reset)
	if reset then
		local anchored = anchor_lookup[part]
		if anchored ~= nil then
			part.Anchored = anchored
			anchor_lookup[part] = nil
		end
	else
		if anchor_lookup[part] == nil then
			anchor_lookup[part] = part.Anchored
			part.Anchored = true
		end
	end
end


local DisplayInfoGUI
local DisplayInfo do
	local function NumFix(num,idp)
		local mult = 10^(idp or 0)
		return math.floor(num*mult + 0.5)/mult
	end

	function DisplayInfo(DoSetWaypoint, ...)
		if DisplayInfoGUI then
			local NewText = ""
			for i,v in pairs{...} do
				if type(v) == "number" then
					NewText = NewText .. tostring(NumFix(math.abs(v),5)) .. " "
				else
					NewText = NewText .. tostring(v) .. " "
				end
			end

			if DisplayInfoGUI.Text ~= NewText then
				DisplayInfoGUI.Text = NewText

				if DoSetWaypoint then
					ChangeHistoryService:SetWaypoint("qCmdUtl: "..NewText .. tostring(tick())) -- Adding the tick() because our waypoints are SMART. None of this text-based filtering.
				end
			end
		end
	end
end

local Camera = workspace.CurrentCamera
local function CameraLookAt(cf)
	Camera.Focus = cf
	Camera.CoordinateFrame = CFrame.new(Camera.CoordinateFrame.p,cf.p)
end

local SettingsData = {
	Layout = {};
	Options = {};
	Style = {};
}

-- SettingsButton

local Overlay = Create 'Part' {
	Name			= "SelectionOverlay";
	Anchored		= true;
	CanCollide		= false;
	Locked			= true;
	-- FormFactor		= "Custom";
	TopSurface		= 0;
	BottomSurface	= 0;
	Transparency	= 1;
	Archivable		= false;
}

local OverlayHandles = Create 'Handles' {
	Name		= "OverlayHandles";
	Adornee		= Overlay;
	Visible		= false;
	Archivable	= false;
}
local OverlayArcHandles = Create 'ArcHandles' {
	Name		= "OverlayArcHandles";
	Adornee		= Overlay;
	Visible		= false;
	Archivable	= false;
}
local OverlaySelectionBox = Create 'SelectionBox' {
	Name		= "OverlaySelectionBox";
	Adornee		= Overlay;
	Visible		= false;
	Archivable	= false;
}
local OverlaySurfaceSelection = Create 'SurfaceSelection' {
	Name		= "OverlaySurfaceSelection";
	Adornee		= Overlay;
	Visible		= false;
	Archivable	= false;
}
--[[
local OverlayGUI = Create 'ScreenGui' {	-- TODO: find object that doesn't spam output
	Name		= "OverlayGUI";
	Archivable	= false;
	OverlayHandles;
	OverlayArcHandles;
	OverlaySelectionBox;
	OverlaySurfaceSelection;
}
--]]

local function OverlayGUIParent(parent)
	OverlayHandles.Parent = parent
	OverlayArcHandles.Parent = parent
	OverlaySelectionBox.Parent = parent
	OverlaySurfaceSelection.Parent = parent
end

local function WrapOverlay(object,isbb,min_size)
	OverlayHandles.Faces = Faces.new(
		Enum.NormalId.Right,
		Enum.NormalId.Left,
		Enum.NormalId.Top,
		Enum.NormalId.Bottom,
		Enum.NormalId.Front,
		Enum.NormalId.Back
	)

	if type(object) == "table" then
		if #object > 0 then
			local size,pos,parts = GetBoundingBox(object,true)
			if min_size and size.magnitude < min_size.magnitude then
				Overlay.Size = min_size
			else
				Overlay.Size = size
			end
			Overlay.CFrame = CFrame.new(pos)
			OverlayGUIParent(CoreGui)

			if #object == 1 and object[1]:IsA("BasePart") then
				OverlayHandles.Faces = object[1].ResizeableFaces;
			end

			return size,pos,parts
		else
			OverlayGUIParent(nil)
		end
	elseif object and object:IsA("BasePart") then
		if isbb then
			local size,pos,parts = GetBoundingBox({object},true)
			pos = CFrame.new(pos)
			if min_size and size.magnitude < min_size.magnitude then
				Overlay.Size = min_size
			else
				Overlay.Size = size
			end
			Overlay.CFrame = pos
			OverlayGUIParent(CoreGui)
			return size,pos,parts
		else
			local size,pos = object.Size,object.CFrame
			if min_size and size.magnitude < min_size.magnitude then
				Overlay.Size = min_size
			else
				Overlay.Size = size
			end
			Overlay.CFrame = pos
			OverlayGUIParent(CoreGui)

			return size,pos
		end
	else
		OverlayGUIParent(nil)
	end
end

local function SetOverlaySize(size)
	local cf       = Overlay.CFrame
	Overlay.Size   = size
	Overlay.CFrame = cf
end

local function SetOverlay(size,cf)
	Overlay.Size = size
	Overlay.CFrame = cf
end

local Selection = game:GetService("Selection")

local function SelectionAdd(object)
		local objects = Selection:Get()
		objects[#objects+1] = object
		Selection:Set(objects)
end

local function SelectionRemove(object)
	local objects = Selection:Get()
	for i,v in pairs(objects) do
		if v == object then
			table.remove(objects,i)
			break
		end
	end
	Selection:Set(objects)
end

local function SelectionSet(objects)
	Selection:Set(objects)
end

local function InSelection(object)
	local objects = Selection:Get()
	for i,v in pairs(objects) do
		if v == object then
			return true
		end
	end
	return false
end

local function GetFilteredSelection(class)
	local out = {}
	for _,object in pairs(Selection:Get()) do
		RecurseFilter(object,class,out)
	end
	return out
end

local ALT_KEYS = {
	["\51"] = true;
	["\52"] = true;
}
local Mouse_Alt_Active = false

local CTRL_KEYS = {
	["\47"] = true;
	["\48"] = true;
	["\49"] = true;
	["\50"] = true;
}
local Mouse_Ctrl_Active = false

local ModelScope = workspace

local function GetTop(object,scope)
	if not object then return nil end
	if object.Locked then return nil end
	if not object:IsDescendantOf(scope) then return nil end
	local top = object
	repeat
		top = top.Parent
		if top == nil then return object end
	until top.Parent == scope
	return top
end

local function DoubleClick(Mouse)
	local Target = GetTop(Mouse.Target,ModelScope)
	if Target then
		if Target:IsA"Model" then
			SelectionSet{}
			ModelScope = Target
			DisplayInfo(false, "Scope into:",ModelScope:GetFullName())
		end
	elseif ModelScope:IsDescendantOf(workspace) then
		SelectionSet{ModelScope}
		ModelScope = ModelScope.Parent
		DisplayInfo(false, "Scope out to:",ModelScope:GetFullName())
	end
end

local LastTarget = nil
local function Click(Mouse,first,remove)
	--print("Click")
	local Target = GetTop(Mouse.Target,ModelScope)
	if first then
		LastTarget = Target
		if Target then
			if Mouse_Ctrl_Active then
				if InSelection(Target) then
					SelectionRemove(Target)
					return true
				else
					SelectionAdd(Target)
					return false
				end
			else
				SelectionSet{Target}
			end
		else
			SelectionSet{}
		end
	else
		if Target ~= LastTarget then
			LastTarget = Target
			if Mouse_Ctrl_Active then
				if Target then
					if remove then
						SelectionRemove(Target)
					else
						SelectionAdd(Target)
					end
				end
			else
				SelectionSet{Target}
			end
		end
	end
end

-- local Mouse_Active = false

local PreviousTool             = nil
local SelectedTool             = nil

local ToolSelection            = {}

local MenuList                 = {}
local Menus                    = {}
local Variables                = {}

local OnToolSelect             = {}
local OnSelectionChanged       = {}
local OnToolDeselect           = {}

local ToolSelectCallback       = {}
local SelectionChangedCallback = {}
local ToolDeselectCallback     = {}
local ToolHints                = {} -- ["ToolName"] = "Hint here"

Selection.SelectionChanged:connect(function()
	if SelectedTool then
		local callback = SelectionChangedCallback[SelectedTool]
		if callback then callback() end
		local func = OnSelectionChanged[SelectedTool]
		if func then func(SelectedTool,Variables[SelectedTool]) end
	end
end)

local function DeselectTool(tool)
	--print("Request DeselectTool "..tostring(tool))
	if tool then
		--print("Fulfilling request DeselectTool")
		if ToolDeselectCallback[tool] then 
			ToolDeselectCallback[tool]()
		else
			--print("No callback")
		end

		local func = OnToolDeselect[tool]
		if func then 
			func(tool,Variables[tool])
		end
		if tool ~= "Duplicate [NM]" and tool ~= "Duplicate" then
			PreviousTool = tool;
		end
		SelectedTool = nil
	end
end

-- local ActivateMouse

local SelectedToolSignal = Signal.new()

local function SelectTool(tool)
	if tool then
		SelectedToolSignal:fire(tool)
		if SelectedTool then
			if SelectedTool == tool then -- We're selecting ourselves, can't do that...
				DeselectTool(SelectedTool)
				return nil;
			else 
				DeselectTool(SelectedTool) -- Otherwise, just diselect the tool.
			end
		end

		SelectedTool = tool

		if ToolSelectCallback[tool] then 
			ToolSelectCallback[tool]()
		end
		if SelectionChangedCallback[tool] then 
			SelectionChangedCallback[tool]()
		end
		OnToolSelect[tool](tool,Variables[tool])

		local func = OnSelectionChanged[tool]
		if func then 
			func(tool, Variables[tool])
		end
	end
end

local function SelectPreviousTool()
	if PreviousTool ~= "Duplicate [NM]" and PreviousTool ~= "Duplicate" then
		SelectTool(PreviousTool)
	end
end

local Reactivate, Deactivate -- GUI

do
	local Mouse = Plugin:GetMouse()

	ModelScope = workspace

	local Down = false

	local select_hold = true
	local click_stamp = 0

	Event.Mouse.Down = Mouse.Button1Down:connect(function()
		Down = true
		if not Mouse_Alt_Active then
			local stamp = tick()
			if stamp-click_stamp < 0.3 then
				--print("Double click")
				DoubleClick(Mouse)
			else
				local remove = Click(Mouse,true)
				if select_hold then
					Event.Mouse.SelectHold = Mouse.Move:connect(function()
						Click(Mouse,false,remove)
					end)
				end
			end
			click_stamp = stamp
		end
	end)

	Event.Mouse.Up = Mouse.Button1Up:connect(function()
		--print("Up")
		Down = false
		Event.Mouse.SelectHold = nil
	end)

	Event.Mouse.Move = Mouse.Move:connect(function()
		click_stamp = 0
	end)


	Event.Mouse.KeyDown = Mouse.KeyDown:connect(function(key)
		if CTRL_KEYS[key] then
			Mouse_Ctrl_Active = true
		elseif ALT_KEYS[key] then
			Mouse_Alt_Active = true
		end
	end)

	Event.Mouse.KeyUp = Mouse.KeyUp:connect(function(key)
		--print("Key up: "..string.byte(key:lower()));

		if CTRL_KEYS[key] then
			Mouse_Ctrl_Active = false
		elseif ALT_KEYS[key] then
			Mouse_Alt_Active = false
		end
	end)
end

--[[
local function DeactivateMouse()
	ActivateMouseButton:SetActive(false)
	Mouse_Active = false
	if SelectedTool then
		DeselectTool(SelectedTool)
	end
end--]]

do local Menu = "Move"
	table.insert(MenuList, Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			Increment = 1;
		};
		VariableList = {
			{"Increment","Move Increment (In Studs)"};
		};
		Color = Color3.new(0.854902, 0.521569, 0.254902);
	}

	do local Tool = "MoveAxis"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [H] - Moves by world axis"

		OnToolSelect[Tool] = function(tool,vars)
			OverlayHandles.Color = BrickColor.new("Bright orange")
			OverlayHandles.Style = "Resize" --"Movement"
			OverlayHandles.Visible = true

			local origin = {}
			local ocf = Overlay.CFrame
			local inc = vars.Increment
			Event[tool].Down = OverlayHandles.MouseButton1Down:connect(function(face)
				inc = vars.Increment
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = part.CFrame
				end
				ocf = Overlay.CFrame
				DisplayInfo(true, "Move:",0)
			end)
			local rdis
			Event[tool].Drag = OverlayHandles.MouseDrag:connect(function(face,distance)
				rdis = Snap(distance,inc)
				local pos = Vector3FromNormalId(face)*rdis
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = cframe + pos
					Anchor(part,true)
				end
				Overlay.CFrame = ocf+pos
				DisplayInfo(false, "Move:",rdis)
			end)

			-- Handle Undo
			Event[tool].Up = OverlayHandles.MouseButton1Up:connect(function()
				DisplayInfo(true, "Moved:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection,true)
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayHandles.Visible = false
		end
	end

	do local Tool = "MoveFirst"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [G] - Moves by first selection."

		OnToolSelect[Tool] = function(tool,vars)
			OverlayHandles.Color = BrickColor.new("Bright orange")
			OverlayHandles.Style = "Resize"
			OverlayHandles.Visible = true

			local origin = {}
			local corigin
			local ocf = Overlay.CFrame
			local inc = vars.Increment
			Event[tool].Down = OverlayHandles.MouseButton1Down:connect(function(face)
				inc = vars.Increment
				corigin = ToolSelection[1].CFrame
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				ocf = corigin:toObjectSpace(Overlay.CFrame)
				DisplayInfo(true, "Move:",0)
			end)
			local rdis
			Event[tool].Drag = OverlayHandles.MouseDrag:connect(function(face,distance)
				rdis = Snap(distance,inc)
				local cf = corigin * CFrame.new(Vector3FromNormalId(face)*rdis)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = cf:toWorldSpace(cframe)
					Anchor(part,true)
				end
				Overlay.CFrame = cf:toWorldSpace(ocf)
				DisplayInfo(false, "Move:",rdis)
			end)

			-- Handle Undo
			Event[tool].Up = OverlayHandles.MouseButton1Up:connect(function()
				DisplayInfo(true, "Moved:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection[1])
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayHandles.Visible = false
		end
	end

	do
		local Tool = "MoveObject"

		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [J] - Moves by objects axis."

		OnToolSelect[Tool] = function(tool,vars)
			OverlayHandles.Color = BrickColor.new("Bright orange")
			OverlayHandles.Style = "Resize"
			OverlayHandles.Visible = true

			local origin = {}
			local ocf = Overlay.CFrame
			local inc = vars.Increment
			Event[tool].Down = OverlayHandles.MouseButton1Down:connect(function(face)
				inc = vars.Increment
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = part.CFrame
				end
				ocf = Overlay.CFrame
				DisplayInfo(true, "Move:",0)
			end)
			local rdis
			Event[tool].Drag = OverlayHandles.MouseDrag:connect(function(face,distance)
				rdis = Snap(distance,inc)
				local cf = CFrame.new(Vector3FromNormalId(face)*rdis)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = cframe * cf
					Anchor(part,true)
				end
				Overlay.CFrame = ocf*cf
				DisplayInfo(false, "Move:",rdis)
			end)

			-- Handle Undo
			Event[tool].Up = OverlayHandles.MouseButton1Up:connect(function()
				DisplayInfo(true, "Moved:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection[1])
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayHandles.Visible = false
		end
	end
end

do local Menu = "Rotate"
	table.insert(MenuList, Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			Increment = 5;
		};
		VariableList = {
			{"Increment","Rotation Increment (In Degrees)"};
		};
		Color = Color3.new(0.643137, 0.741176, 0.278431);
	}

	do local Tool = "RotatePivot"

		table.insert(Menus["Rotate"].Tools,Tool)
		Variables[Tool] = Menus["Rotate"].Variables
		ToolHints[Tool] = "Hotkey [X] - Rotates around first selection's axis."

		local min_size = Vector3.new(4,4,4)

		OnToolSelect[Tool] = function(tool,vars)
			OverlayArcHandles.Color = BrickColor.new("Br. yellowish green")
			OverlayArcHandles.Visible = true

			local origin = {}
			local corigin
			local ocf
			local inc = vars.Increment
			local rdis

			Event[tool].Down = OverlayArcHandles.MouseButton1Down:connect(function(axis)
				inc = vars.Increment
				corigin = ToolSelection[1].CFrame
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				ocf = corigin:toObjectSpace(Overlay.CFrame)
				DisplayInfo(true, "Rotate:",0)
			end)
			Event[tool].Drag = OverlayArcHandles.MouseDrag:connect(function(axis,angle)
				rdis = Snap(math.deg(angle),inc)
				local a = Vector3FromAxis(axis)*math.rad(rdis)
				local new = corigin * CFrame.Angles(a.x,a.y,a.z)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = new:toWorldSpace(cframe)
					Anchor(part,true)
				end
				Overlay.CFrame = new:toWorldSpace(ocf)
				DisplayInfo(false, "Rotate:",rdis)
			end)
			Event[tool].Up = OverlayArcHandles.MouseButton1Up:connect(function(axis)
				DisplayInfo(true, "Rotate:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection[1],false,min_size)
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayArcHandles.Visible = false
		end
	end

	do local Tool = "RotateGroup"
		table.insert(Menus["Rotate"].Tools,Tool)
		Variables[Tool] = Menus["Rotate"].Variables
		ToolHints[Tool] = "Hotkey [Z] - Rotates by world axis."

		local min_size = Vector3.new(4,4,4)

		OnToolSelect[Tool] = function(tool,vars)
			OverlayArcHandles.Color = BrickColor.new("Br. yellowish green")
			OverlayArcHandles.Visible = true

			local origin = {}
			local corigin = Overlay.CFrame
			local inc = vars.Increment
			local rdis

			Event[tool].Down = OverlayArcHandles.MouseButton1Down:connect(function(axis)
				inc = vars.Increment
				corigin = Overlay.CFrame
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				DisplayInfo(true, "Rotate:",0)
			end)
			Event[tool].Drag = OverlayArcHandles.MouseDrag:connect(function(axis,angle)
				rdis = Snap(math.deg(angle),inc)
				local a = Vector3FromAxis(axis)*math.rad(rdis)
				local new = corigin * CFrame.Angles(a.x,a.y,a.z)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = new:toWorldSpace(cframe)
					Anchor(part,true)
				end
				Overlay.CFrame = new
				DisplayInfo(false, "Rotate:",rdis)
			end)
			Event[tool].Up = OverlayArcHandles.MouseButton1Up:connect(function(axis)
				DisplayInfo(true, "Rotated:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(ToolSelection,true,min_size)
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayArcHandles.Visible = false
		end
	end

	do local Tool = "RotateObject"

		table.insert(Menus["Rotate"].Tools,Tool)
		Variables[Tool] = Menus["Rotate"].Variables
		ToolHints[Tool] = "Hotkey [C] - Rotates by individual object axis."

		local min_size = Vector3.new(4,4,4)

		OnToolSelect[Tool] = function(tool,vars)
			OverlayArcHandles.Color = BrickColor.new("Br. yellowish green")
			OverlayArcHandles.Visible = true

			local origin = {}
			local ocf = Overlay.CFrame
			local inc = vars.Increment
			local rdis

			Event[tool].Down = OverlayArcHandles.MouseButton1Down:connect(function(axis)
				inc = vars.Increment
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					origin[part] = part.CFrame
				end
				ocf = Overlay.CFrame
				DisplayInfo(true, "Rotate:",0)
			end)
			Event[tool].Drag = OverlayArcHandles.MouseDrag:connect(function(axis,angle)
				rdis = Snap(math.deg(angle),inc)
				local a = Vector3FromAxis(axis)*math.rad(rdis)
				local new = CFrame.Angles(a.x,a.y,a.z)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = cframe * new
					Anchor(part,true)
				end
				Overlay.CFrame = ocf * new
				DisplayInfo(false, "Rotate:",rdis)
			end)
			Event[tool].Up = OverlayArcHandles.MouseButton1Up:connect(function(axis)
				DisplayInfo(true, "Rotated:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection[1],false,min_size)
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayArcHandles.Visible = false
		end
	end
end

do local Menu = "Resize"
	table.insert(MenuList,Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			Increment = 1;
		};
		VariableList = {
			{"Increment","Resize Increment (In Studs)"};
		};
		Color = Color3.new(0.0156863, 0.686275, 0.92549);
	}

	local FF_CUSTOM = Enum.FormFactor.Custom

	-- fixes the resizing direction for a face
	local FACE_MULTIPLIER = {
		[Enum.NormalId.Back]	=  1;
		[Enum.NormalId.Bottom]	= -1;
		[Enum.NormalId.Front]	= -1;
		[Enum.NormalId.Left]	= -1;
		[Enum.NormalId.Right]	=  1;
		[Enum.NormalId.Top]		=  1;
	}


	-- selects a component from face vector
	local FACE_COMPONENT = {
		[Enum.NormalId.Back]	= "z";
		[Enum.NormalId.Bottom]	= "y";
		[Enum.NormalId.Front]	= "z";
		[Enum.NormalId.Left]	= "x";
		[Enum.NormalId.Right]	= "x";
		[Enum.NormalId.Top]		= "y";
	}


	do local Tool = "ResizeObject"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [R] - Resizes objects by object axis"

		OnToolSelect[Tool] = function(tool,vars)
			OverlayHandles.Color = BrickColor.new("Cyan")
			OverlayHandles.Style = "Resize"
			OverlayHandles.Visible = true

			local origin = {}
			local first
			local face_mult,face_size,face_vec
			local cinc
			local inc
			local rdis
			Event[tool].Down = OverlayHandles.MouseButton1Down:connect(function(face)
				face_mult,face_size,face_vec = FACE_MULTIPLIER[face],FACE_COMPONENT[face],Vector3FromNormalId(face)
				first = ToolSelection[1]
				for k in pairs(origin) do
					origin[k] = nil
				end
				for _,part in pairs(ToolSelection) do
					--local ff = GetFormFactor(part)
					origin[part] = {part.CFrame,part.Size--[[,ff,FORMFACTOR_MULTIPLIER[face][ff]--]]}
				end
				cinc = vars.Increment
				inc = Snap(cinc,1)
				if inc == 0 then
					inc = 1
				end
				DisplayInfo(true, "Resize:",0)
				rdis = 0
			end)
			Event[tool].Drag = OverlayHandles.MouseDrag:connect(function(face,distance)
				local dis = distance*face_mult
				for part,info in pairs(origin) do
					local sz--[[,ff,ffm--]] = info[2]--[[,info[3],info[4]--]]
					local mult
					--if ff == FF_CUSTOM then
						mult = Snap(dis,cinc)
					--[[else
						mult = Snap(dis,inc*ffm)
					end--]]
					local mod   = face_vec*mult
					local fsize = sz[face_size]
					local ffm = math.min(cinc, 0.2)
					mod         = fsize + mult*face_mult < ffm and face_vec*((ffm-fsize)*face_mult) or mod
					Anchor(part)
					part.Size = sz + mod
					part.CFrame = info[1] * CFrame.new(mod*face_mult/2)
					Anchor(part,true)
					if part == first then
						DisplayInfo(false, "Resize:",mod.magnitude)
						rdis = mod.magnitude
					end
				end
				SetOverlay(first.Size,first.CFrame)

				-- Correct handles
				if #ToolSelection == 1 then
					OverlayHandles.Faces = ToolSelection[1].ResizeableFaces
				else
					OverlayHandles.Faces = Faces.new(
						Enum.NormalId.Right,
						Enum.NormalId.Left,
						Enum.NormalId.Top,
						Enum.NormalId.Bottom,
						Enum.NormalId.Front,
						Enum.NormalId.Back
					)
				end
			end)

			-- Handle Undo
			Event[tool].Up = OverlayHandles.MouseButton1Up:connect(function()
				DisplayInfo(true, "Resized:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection = selection
			WrapOverlay(selection[1],false)

			if #selection == 1 then
				OverlayHandles.Faces = selection[1].ResizeableFaces
			end
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayHandles.Visible = false
		end
	end

	do local Tool = "ResizeCenter"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [T] - Resizes objects by object axis from center"

		OnToolSelect[Tool] = function(tool,vars)
			OverlayHandles.Color = BrickColor.new("Cyan")
			OverlayHandles.Style = "Resize"
			OverlayHandles.Visible = true

			local origin = {}
			local first
			local face_mult,face_size,face_vec
			local cinc
			local inc

			local rdis = 0

			Event[tool].Down = OverlayHandles.MouseButton1Down:connect(function(face)
				face_mult,face_size,face_vec = FACE_MULTIPLIER[face],FACE_COMPONENT[face],Vector3FromNormalId(face)
				first = ToolSelection[1]
				for k in pairs(origin) do
					origin[k] = nil
				end

				for _,part in pairs(ToolSelection) do
					--local ff = GetFormFactor(part)
					origin[part] = {part.CFrame,part.Size--[[,ff,FORMFACTOR_MULTIPLIER[face][ff]--]]}
				end

				cinc = vars.Increment
				inc = Snap(cinc,1)
				if inc == 0 then
					inc = 1
				end
				DisplayInfo(true, "Resize:",0)
				rdis = 0
			end)

			Event[tool].Drag = OverlayHandles.MouseDrag:connect(function(face,distance)
				if face_mult then
					local dis = distance*2*face_mult
					for part,info in pairs(origin) do
						local sz--[[,ff,ffm--]] = info[2]--[[,info[3],info[4]--]]
						local mult
						--if ff == FF_CUSTOM then
							mult = Snap(dis,cinc)
						--else
						--	mult = Snap(dis,inc*ffm)
						--end
						local mod = face_vec*mult
						local fsize = sz[face_size]
						local ffm = math.min(cinc, 0.2)
						mod = fsize + mult*face_mult < ffm and face_vec*((ffm-fsize)*face_mult) or mod
						Anchor(part)
						part.Size = sz + mod
						part.CFrame = info[1]
						Anchor(part, true)
						if part == first then
							DisplayInfo(false, "Resize:", mod.magnitude)
							rdis = mod.magnitude
						end
					end
					SetOverlay(first.Size,first.CFrame)

					-- Correct handles
					if #ToolSelection == 1 then
						OverlayHandles.Faces = ToolSelection[1].ResizeableFaces
					else
						OverlayHandles.Faces = Faces.new(
							Enum.NormalId.Right,
							Enum.NormalId.Left,
							Enum.NormalId.Top,
							Enum.NormalId.Bottom,
							Enum.NormalId.Front,
							Enum.NormalId.Back
						)
					end
				end
			end)

			-- Handle Undo
			Event[tool].Up = OverlayHandles.MouseButton1Up:connect(function()
				DisplayInfo(true, "Resized:", rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			local selection = GetFilteredSelection("BasePart")
			ToolSelection   = selection
			WrapOverlay(selection[1],false)

			if #selection == 1 then
				OverlayHandles.Faces = selection[1].ResizeableFaces
			end
		end

		OnToolDeselect[Tool] = function(tool,vars)
			Event[tool] = nil
			OverlayHandles.Visible = false
		end
	end
end

do local Menu = "Clipboard"
	table.insert(MenuList,Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
		};
		VariableList = {
		};
		Color = Color3.new(1,1,1);
	}

	local ClipboardContents = {}
	local ClipboardContentParent = {}

	do local Tool = "Cut"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables

		OnToolSelect[Tool] = function(tool)
			local selection = Selection:Get()
			if #selection == 0 then
				DisplayInfo(true, "Selection was empty")
				SelectPreviousTool()
				return
			end

			for i in pairs(ClipboardContents) do
				ClipboardContents[i] = nil
			end
			for k in pairs(ClipboardContentParent) do
				ClipboardContentParent[k] = nil
			end
			for i = 1,#selection do
				local object = selection[i]:Clone()
				ClipboardContents[#ClipboardContents + 1] = object
				ClipboardContentParent[object] = object.Parent
				selection[i]:Destroy()
			end
			Selection:Set{}
			DisplayInfo(true, "Cut selection to clipboard")
			SelectPreviousTool()
		end
	end

	do local Tool = "Copy"

		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables

		OnToolSelect[Tool] = function(tool)
			local selection = Selection:Get()
			if #selection == 0 then
				DisplayInfo(false, "Selection was empty")
				SelectPreviousTool()
				return
			end

			for i in pairs(ClipboardContents) do
				ClipboardContents[i] = nil
			end
			for k in pairs(ClipboardContentParent) do
				ClipboardContentParent[k] = nil
			end
			for i = 1,#selection do
				local object = selection[i]:Clone()
				ClipboardContents[#ClipboardContents + 1] = object
				ClipboardContentParent[object] = object.Parent
			end
			DisplayInfo(false, "Copied selection to clipboard")
			SelectPreviousTool()
		end
	end

	do local Tool = "Paste"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables

		OnToolSelect[Tool] = function(tool)
			if #ClipboardContents == 0 then
				DisplayInfo(false, "Clipboard was empty")
				SelectPreviousTool()
				return
			end
			local copy = {}
			local copy_parent = {}
			for i,v in pairs(ClipboardContents) do
				local o = v:Clone()
				copy[i] = o
				copy_parent[o] = ClipboardContentParent[v]
			end

			local cSize,cPos,cParts = GetBoundingBox(copy,true)

			local selection = Selection:Get()
			local sSize,sPos
			if #selection > 0 then
				sSize,sPos = GetBoundingBox(selection)
			else
				sSize,sPos = cSize,cPos
			end

			local center = CFrame.new(cPos)
			local new = CFrame.new(sPos + Vector3.new(0,sSize.y/2 + cSize.y/2,0))

			for i,part in pairs(cParts) do
				part.CFrame = new:toWorldSpace(center:toObjectSpace(part.CFrame))
			end

			for i,v in pairs(copy) do
				v.Parent = copy_parent[v] or ModelScope
			end

			CameraLookAt(new)

			Selection:Set(copy)

			DisplayInfo(false, "Pasted from clipboard")
			SelectPreviousTool()
		end
	end
end

------------------------------------------------------------
do local Menu = "qModifications"
	table.insert(MenuList,Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			Scale = 0.5;
		};
		VariableList = {
			{"Scale","Scale Factor"};
		};
		Color = BrickColor.new("Bright violet").Color --Color3.new(1,1,1);
	}

	do local Tool = "Duplicate [NM]"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey Hold both [SHIFT] and [C] - Clones the current selection in place.\nSame behavior as [CTRL][D] (with collisions off)."

		OnToolSelect[Tool] = function(tool)
			--[[local copy = {}
			local copy_parent = {}
			local selection = Selection:Get()
			if #selection == 0 then
				DisplayInfo(false, "Selection was empty")
				SelectPreviousTool()
				return
			end

			for i = 1, #selection do
				local object = selection[i]:Clone()
				copy[#copy + 1] = object
				copy_parent[object] = object.Parent
			end

			local cSize,cPos,cParts = GetBoundingBox(copy,true)

			-- local selection = Selection:Get()
			local sSize,sPos
			if #selection > 0 then
				sSize,sPos = GetBoundingBox(selection)
			else
				sSize,sPos = cSize,cPos
			end

			local center = CFrame.new(cPos)
			local new = CFrame.new(sPos + Vector3.new(0,0,0))

			for i,part in pairs(cParts) do
				part.CFrame = new:toWorldSpace(center:toObjectSpace(part.CFrame))
			end

			for i,v in pairs(copy) do
				v.Parent = copy_parent[v] or ModelScope
			end

			--CameraLookAt(new)--]]

			local SelectionList = Selection:Get()
			if #SelectionList == 0 then
				DisplayInfo(false, "Selection was empty")
				SelectPreviousTool()
				return
			end

			local ToClone = {}
			for _, Item in pairs(SelectionList) do
				ToClone[Item] = true
			end

			-- Filter out descendants
			for _, Item in pairs(SelectionList) do
				for _, OtherItem in pairs(SelectionList) do
					if Item:IsDescendantOf(OtherItem) then
						ToClone[Item] = nil
					end
				end
			end

			local Clones = {}
			for Item, _ in pairs(ToClone) do
				local Clone = Item:Clone()
				Clones[#Clones+1] = Clone

				Clone.Parent = workspace
				if Item:IsA("BasePart") then
					Clone.CFrame = Item.CFrame
				end
			end

			Selection:Set(Clones)

			DisplayInfo(true, "Duplicated selection (No Move)")
		end
	end

	do local Tool = "Scale"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables

		local function findObjectHelper(model, objectName, className, listOfFoundObjects)
			if not model then return end
			local findStart, findEnd = string.find(model.Name, objectName)
			if findStart == 1 and findEnd == #(model.Name) then  -- must match entire name
				if not className or model.className == className or (pcall(model.IsA, model, className) and model:IsA(className)) then
					table.insert(listOfFoundObjects, model)
				end
			end
			if pcall(model.GetChildren, model) then
				local modelChildren = model:GetChildren()
				for i = 1, #modelChildren do
					findObjectHelper(modelChildren[i], objectName, className, listOfFoundObjects)
				end
			end
		end

		local function resizeModelInternal(model, resizeFactor)
			local modelCFrame = model:GetModelCFrame()
			local modelSize = model:GetModelSize()
			local baseParts = {}
			local basePartCFrames = {}
			local joints = {}
			local jointParents = {}
			local meshes = {}

			findObjectHelper(model, ".*", "BasePart", baseParts)
			findObjectHelper(model, ".*", "JointInstance", joints)

			-- meshes don't inherit from anything accessible?
			findObjectHelper(model, ".*", "FileMesh", meshes)                    -- base class for SpecialMesh and FileMesh
			findObjectHelper(model, ".*", "CylinderMesh", meshes)
			findObjectHelper(model, ".*", "BlockMesh", meshes)

			-- store the CFrames, so our other changes don't rearrange stuff
			for _, basePart in pairs(baseParts) do
				basePartCFrames[basePart] = basePart.CFrame
			end

			-- scale joints
			for _, joint in pairs(joints) do
				joint.C0 = joint.C0 + (joint.C0.p) * (resizeFactor - 1)
				joint.C1 = joint.C1 + (joint.C1.p) * (resizeFactor - 1)
				jointParents[joint] = joint.Parent
			end

			-- scale parts and reposition them within the model
			for _, basePart in pairs(baseParts) do
				-- if pcall(function() basePart.FormFactor = "Custom" end) then basePart.FormFactor = "Custom" end
				basePart.Size = basePart.Size * resizeFactor
				local oldCFrame = basePartCFrames[basePart]
				local oldPositionInModel = modelCFrame:pointToObjectSpace(oldCFrame.p)
				local distanceFromCorner = oldPositionInModel + modelSize/2
				distanceFromCorner = distanceFromCorner * resizeFactor

				local newPositionInSpace = modelCFrame:pointToWorldSpace(distanceFromCorner - modelSize/2)
				basePart.CFrame = oldCFrame - oldCFrame.p + newPositionInSpace
			end

			-- scale meshes
			for _,mesh in pairs(meshes) do
				mesh.Scale = mesh.Scale * resizeFactor
			end

			-- pop the joints back, because they prolly got borked
			for _, joint in pairs(joints) do
				joint.Parent = jointParents[joint]
			end

			return model
		end

		local function resizeImplementation(modelList, resizeFactor)
			if not resizeFactor then
				resizeFactor = modelList
				modelList = game.Selection:Get()
			end
			if type(modelList) ~= "table" then modelList = {modelList} end

			for _, model in pairs(modelList) do
				resizeModelInternal(model, resizeFactor)
			end

			return modelList
		end


		OnToolSelect[Tool] = function(tool, vars)
			local copy = {}
			local copy_parent = {}
			local selection = Selection:Get()
			if #selection == 0 then
				DisplayInfo(false, "Selection was empty")
				SelectPreviousTool()
				return
			end

			for i = 1,#selection do
				local object = selection[i]:Clone()
				copy[#copy + 1] = object
				copy_parent[object] = object.Parent
			end

			local cSize,cPos,cParts = GetBoundingBox(copy,true)

			local selection = Selection:Get()
			local sSize,sPos
			if #selection > 0 then
				sSize,sPos = GetBoundingBox(selection)
			else
				sSize,sPos = cSize,cPos
			end

			local center = CFrame.new(cPos)
			local new = CFrame.new(sPos + Vector3.new(0,0,0))

			for i,part in pairs(cParts) do
				part.CFrame = new:toWorldSpace(center:toObjectSpace(part.CFrame))
			end

			local NewModel = Instance.new("Model", workspace)
			NewModel.Name = "ScaledModel";

			for i,v in pairs(copy) do
				v.Parent = copy_parent[v] or NewModel--ModelScope
			end

			resizeImplementation(NewModel, vars.Scale)

			Selection:Set({NewModel})

			DisplayInfo(true, "Scaled selection by a factor by "..vars.Scale)
			SelectPreviousTool()
		end
	end
end

----------------------------------------------------------------

do local Menu = "Convert"
	table.insert(MenuList,Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			ClassName = "WedgePart";
		};
		VariableList = {
			{"ClassName","Class name to convert to"};
		};
		Color = Color3.new(1, 107/255, 107/255);
	}

	do local Tool = "Convert"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey Hold [SHIFT] and [X] - Cheap and fast conversion between certain classes."

		OnToolSelect[Tool] = function(tool, vars)
			local copy = {}
			local copy_parent = {}
			local selection = Selection:Get()
			if #selection == 0 then
				DisplayInfo(false, "Selection was empty")
				SelectPreviousTool()
				return
			end

			local converted = false

			for i = 1,#selection do
				if selection[i]:IsA("BasePart") then
					local object

					if vars.ClassName == "Part" or vars.ClassName == "WedgePart" or vars.ClassName == "CornerWedgePart" or vars.ClassName == "TrussPart" or vars.ClassName == "MeshPart" then
						object = Instance.new(vars.ClassName)
						for _, Property in pairs({"BrickColor"; "Material"; "Reflectance"; "Transparency"; "Name"; "Parent"; "Anchored"; "Archivable"; "CanCollide"; "Locked"; "Elasticity"; "Friction"; "BackParamA"; "BackParamB"; "BackSurfaceInput"; "BottomParamA"; "BottomParamB"; "BottomSurfaceInput"; "FrontParamA"; "FrontParamB"; "FrontSurfaceInput"; "LeftParamA"; "LeftParamB"; "LeftSurfaceInput"; "RightParamA"; "RightParamB"; "RightSurfaceInput"; "TopParamA"; "TopParamB"; "TopSurfaceInput"; "BackSurface"; "BottomSurface"; "FrontSurface"; "LeftSurface"; "RightSurface"; "TopSurface";}) do
							object[Property] = selection[i][Property]
						end
						--[[
						if selection[i].ClassName == "CornerWedgePart" and vars.ClassName ~= "CornerWedgePart" then
							object.FormFactor = "Custom"
						end

						if (selection[i].ClassName == "Part" or selection[i].ClassName == "WedgePart") and (vars.ClassName == "Part" or vars.ClassName == "WedgePart") then
							object.FormFactor = selection[i].FormFactor
						end--]]

						copy[#copy + 1] = object
						copy_parent[object] = selection[i].Parent

						object.Size = selection[i].Size
						object.CFrame = selection[i].CFrame

						selection[i].Parent = nil
						converted = true
					else
						DisplayInfo(false, "Could not convert into ClassName '" .. vars.ClassName .. "', because it was an invalid ClassName.")
					end
				else
					DisplayInfo(false, "Could not convert a '" .. selection[i].ClassName .. "'")
				end
			end

			for i,v in pairs(copy) do
				v.Parent = copy_parent[v] or ModelScope
			end

			--CameraLookAt(new)

			Selection:Set(copy)

			if converted then
				DisplayInfo(true, "Conversion done.")
			end
			SelectPreviousTool()
		end
	end

	--[[
	do local Tool = "ReactivateMouse"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables

		OnToolSelect[Tool] = function(tool, vars)
			ActivateMouse()
		end
	end--]]
end

do local Menu = "SelectEdge"
	table.insert(MenuList,Menu)
	Menus[Menu] = {
		Tools = {};
		Variables = {
			EdgeSnap = 0.5;
			RotIncrement = 5;
		};
		VariableList = {
			{"RotIncrement","Rotation Increment (In Degrees)"};
			{"EdgeSnap","Edge Snap (In Studs)"};
		};
		Color = Color3.new(0.960784, 0.803922, 0.188235);
	}

	local function GetRelativeEdge(p,s,inc)
		local ax,ay,az = math.abs(p.x/s.x),math.abs(p.y/s.y),math.abs(p.z/s.z)
		return Vector3.new(NumNormal(p.x),NumNormal(p.y),NumNormal(p.z)) * Vector3.new(
			(ax>ay or ax>az) and s.x or Snap(math.abs(p.x),inc),
			(ay>ax or ay>az) and s.y or Snap(math.abs(p.y),inc),
			(az>ax or az>ay) and s.z or Snap(math.abs(p.z),inc)
		)
	end

	local function FilterTarget(target)
		if target then
			if not target.Locked then
				return target
			end
		end
		return nil
	end

	do local Tool = "SelectEdge"
		table.insert(Menus[Menu].Tools,Tool)
		Variables[Tool] = Menus[Menu].Variables
		ToolHints[Tool] = "Hotkey [V] - Rotate around a selected edge. \n To select an edge: hold down [ALT] and [LEFT MOUSE BUTTON]"

		local function SelectEdgeUpdateOverlay()
			local Size, Position = GetBoundingBox(ToolSelection)

			local PositionNumber = (Overlay.Position - Position).magnitude
			local SizeNumber = math.max(Size.X, Size.Y, Size.Z)/2

			if PositionNumber > SizeNumber then
				SizeNumber = PositionNumber
			end

			SizeNumber = math.min(25, math.max(2, SizeNumber))

			Overlay.Size = Vector3.new(SizeNumber, SizeNumber, SizeNumber)
		end


		OnToolSelect[Tool] = function(tool,vars)
			if LegacyMode then
				Plugin:Activate(true)
			end
			local Mouse = Plugin:GetMouse()

			--[[if not Mouse_Active then
				ActivateMouse()
			end--]]
			--[[Event.SelectEdge.Deactivate = Plugin.Deactivation:connect(function()
				DeselectTool(tool)
			end)--]]

			local Down = false
			local SelectEdgeVisible = false

			local select_hold = true
			local click_stamp = 0

			OverlayGUIParent(nil)
			OverlayArcHandles.Color   = BrickColor.new("Bright yellow")
			OverlaySelectionBox.Color = BrickColor.new("Bright yellow")

			DisplayInfo(false, "Select Edge Activated. Hold down [ALT] and [LEFT MOUSE BUTTON] to select the edge you want")

			local function select_edge()
				OverlayArcHandles.Visible = false
				OverlaySelectionBox.Visible = true
				Overlay.Size = Vector3.new(1,1,1)
				local Target = FilterTarget(Mouse.Target)
				if Target then
					OverlayGUIParent(CoreGui)
					local pos = Target.CFrame:toObjectSpace(Mouse.Hit).p
					local JointCenter = CFrame.new(GetRelativeEdge(pos,Target.Size/2,vars.EdgeSnap))
					Overlay.CFrame = Target.CFrame * JointCenter
					SelectEdgeVisible = true
				else
					SelectEdgeVisible = false
					OverlayArcHandles.Visible = false
					OverlayGUIParent(nil)
				end
			end

			Event.SelectEdge.Down = Mouse.Button1Down:connect(function()
				Down = true
				if Mouse_Alt_Active then
					select_edge()
				end
			end)
			Event.SelectEdge.Up = Mouse.Button1Up:connect(function()
				OverlayArcHandles.Visible = true
				OverlaySelectionBox.Visible = false
				-- Overlay.Size = Vector3.new(4, 4, 4)
				SelectEdgeUpdateOverlay()
				Down = false

				Event.SelectEdge.SelectHold = nil
			end)
			Event.SelectEdge.Move = Mouse.Move:connect(function()
				click_stamp = 0
				if Down then
					if Mouse_Alt_Active then
						select_edge()
					else
						OverlayArcHandles.Visible = true
						OverlaySelectionBox.Visible = false
						-- Overlay.Size = Vector3.new(4, 4, 4)
						SelectEdgeUpdateOverlay()
					end
				end
			end)

			local inc = 0
			local ocf = CFrame.new()
			local origin = {}
			local corigin = CFrame.new()
			local rdis

			Event.SelectEdge.Arc.Down = OverlayArcHandles.MouseButton1Down:connect(function(axis)
				if SelectEdgeVisible then
					inc = vars.RotIncrement
					corigin = Overlay.CFrame
					for k in pairs(origin) do
						origin[k] = nil
					end
					for _,part in pairs(ToolSelection) do
						origin[part] = corigin:toObjectSpace(part.CFrame)
					end
					ocf = corigin:toObjectSpace(Overlay.CFrame)
					DisplayInfo(true, "Rotate:",0)
				end
			end)
			Event.SelectEdge.Arc.Drag = OverlayArcHandles.MouseDrag:connect(function(axis,angle)
				rdis = Snap(math.deg(angle),inc)
				local a = Vector3FromAxis(axis)*math.rad(rdis)
				local new = corigin * CFrame.Angles(a.x,a.y,a.z)
				for part,cframe in pairs(origin) do
					Anchor(part)
					part.CFrame = new:toWorldSpace(cframe)
					Anchor(part,true)
				end
				Overlay.CFrame = new:toWorldSpace(ocf)
				DisplayInfo(false, "Rotate:",rdis)
			end)

			Event.SelectEdge.Arc.Up = OverlayArcHandles.MouseButton1Up:connect(function(axis,angle)
				DisplayInfo(true, "Rotated:",rdis)
			end)
		end

		OnSelectionChanged[Tool] = function(tool,vars)
			ToolSelection = GetFilteredSelection("BasePart")
			SelectEdgeUpdateOverlay()
		end

		OnToolDeselect[Tool] = function(tool,vars)
			--SelectEdgeVisible = false
			Event.SelectEdge = nil
			OverlayGUIParent(nil)
			OverlaySelectionBox.Visible = false
			OverlayArcHandles.Visible = false
		end
	end
end





--- GUI Generation here? 


local Screen

local GUI_Initialized = false
-- local GUI_Active = false

local ExpandPanel
local CollapsePanel

local function InitializeGUI()
	if GUI_Initialized then
		print("GUI_Initialized is true")
	end

	if not gloo then
		error(PROJECT_NAME.." needs the gloo library to load the GUI.",0)
	end

	local draggingMenu = false
	local infoRight = false
	local hoverEnabled = true
	local panelPosition
	local collapseAxis = "x"
	local collapseDirection = -1

	local MenuInputBoxes = {}
	local MouseOverLabelEvent = Signal.new() -- Event whenever the mouse enters and makes a label visible.

	local function ApplyMouseOverLabelEvent(GuiLabel)
		-- Applies the event firing to the label
		-- @author Quenty

		MouseOverLabelEvent:connect(function(LabelVisible)
			if LabelVisible ~= GuiLabel then
				GuiLabel.Visible = false
			end
		end)

		GuiLabel.Changed:connect(function(Property)
			if Property == "Visible" then
				if GuiLabel.Visible then
					MouseOverLabelEvent:fire(GuiLabel)
				end
			end
		end)
	end

	local GlobalStylist = gloo.Stylist{
		Font = "ArialBold";
		FontSize = "Size14";
		TextColor3 = Color3.new(1,1,1);
	}

	local MenuStylist = gloo.Stylist{
		BackgroundTransparency = 0.5;
		BackgroundColor3 = Color3.new(0,0,0);
		BorderColor3 = Color3.new(1,1,1);
	}

	local ButtonStylist = gloo.Stylist{
		BackgroundTransparency = 0.5;
		BackgroundColor3 = Color3.new(0,0,0);
		BorderColor3 = Color3.new(1,1,1);
		Size = UDim2.new(0,100,0,20);
		Style = "RobloxButton";
		Selected = false;
	}
	GlobalStylist.AddStylist(ButtonStylist)

	local SelectedButtonStylist = gloo.Stylist{
		BackgroundTransparency = 0.5;
		BackgroundColor3 = Color3.new(0,0,0);
		BorderColor3 = Color3.new(1,1,1);
		Size = UDim2.new(0,100,0,20);
		Style = "RobloxButton";
		Selected = true;
	}
	GlobalStylist.AddStylist(SelectedButtonStylist)

	local MenuNodeStylist = gloo.Stylist{
		BackgroundTransparency = 0.5;
		BorderSizePixel = 0;
		Size = UDim2.new(0,100,0,8);
	}

	local HoverNameStylist = gloo.Stylist{
		AutoButtonColor = false;
		BackgroundTransparency = 1;
		TextStrokeColor3 = Color3.new(0,0,0);
		TextStrokeTransparency = 0;
	}
	GlobalStylist.AddStylist(HoverNameStylist)

	local DockClass = gloo.DockContainer()
	Screen = DockClass.GUI
	Screen.Name = PROJECT_NAME.."GUI"

	DisplayInfoGUI = Create'TextButton'{
		Name = "DisplayInfoGUI";
		Text = "";
		Parent = Screen;
	}
	HoverNameStylist.AddObject(DisplayInfoGUI)

	local InfoClass = gloo.AutoSizeLabel(DisplayInfoGUI)
	InfoClass.LockAxis(nil,24)
	InfoClass.SetPadding(4)

	local MenuContainerClass, MenuContainerFrame = gloo.StackingFrame(Instance.new("ImageButton"))
	MenuContainerClass.SetPadding(4,8)
	Modify(MenuContainerFrame){
		AutoButtonColor        = false;
		Name                   = "MenuContainer";
		BorderSizePixel        = 0;
		BackgroundColor3       = Color3.new(0,0,0);
		BackgroundTransparency = 0.3;
		Position               = UDim2.new(0,0,0,24);
		Parent                 = Screen;
	}
	panelPosition = MenuContainerFrame.Position

	-------

	Reactivate = Create 'TextButton'{
		Name                   = "Reactivate_Container";
		Text                   = "\n\n\n\n\n\n\n\n\n\nROBLOX deactivated mouse input from qCmdUtl. \n\nq_q\n\n\n\n\n\n\n\n\n\n\n\nLegacy mode prevents this overlay from showing up again. \n\nPlugin shortcuts and other functions not guaranteed to work. \n\nUSE WITH CAUTION. (Will reset upon file load)";
		Parent                 = MenuContainerFrame;
		BackgroundColor3       = Color3.new(0, 0, 0);
		BorderSizePixel        = 0;
		Visible                = false;
		Size                   = UDim2.new(1, 0, 1, 0);
		ZIndex                 = 20;
		TextColor3             = Color3.new(1, 1, 1);
		Active                 = true;
		BackgroundTransparency = 0.1;
		TextWrapped            = true;
		Font                   = "SourceSans";
		FontSize               = "Size14";
		TextYAlignment         = "Top"
	}

	ReactivateTwo = Create 'TextButton'{
		Parent   = Reactivate;
		Style    = "RobloxRoundDefaultButton";
		ZIndex   = 20;
		Text     = "Reactivate";
		FontSize = "Size14";
		Font     = "SourceSans";
		Size     = UDim2.new(0, 100, 0, 50);
		Position = UDim2.new(0.5, -50, 0.5, -25);
		Name     = "Reactivate_Two";
		Visible  = true;
	}

	Deactivate = Create 'TextButton' {
		Parent   = Reactivate;
		Style    = "RobloxRoundDropdownButton";
		ZIndex   = 20;
		Text     = "Hide";
		FontSize = "Size14";
		Font     = "SourceSans";
		Size     = UDim2.new(0, 100, 0, 50);
		Position = UDim2.new(0.5, -50, 0.5, 25);
		Name     = "Deactivate";
		Visible  = true;
	}

	AlwaysActiveCheckmark = Create 'TextButton' {
		Parent   = Reactivate;
		Style    = "RobloxRoundDropdownButton";
		ZIndex   = 20;
		Text     = "";
		FontSize = "Size14";
		Font     = "ArialBold";
		Size     = UDim2.new(0, 20, 0, 20);
		Position = UDim2.new(0, 10, 0.5, 75);
		Name     = "AlwaysActiveCheckmark";
		Visible  = true;
		Create 'TextLabel' {
			FontSize               = "Size14";
			Font                   = "SourceSans";
			FontSize               = "Size14";
			Text                   = "Legacy mode";
			TextXAlignment         = "Left";
			Visible                = true;
			Size                   = UDim2.new(0, 70, 0, 40);
			BackgroundTransparency = 1;
			TextColor3             = Color3.new(1, 1, 1);
			ZIndex                 = 20;
			Position               = UDim2.new(1, 10, 0, -5);
			TextWrapped            = true;
			TextYAlignment         = "Top"
		}
	}


	-- Dang it Anaminus... this is horrible. Your global states are killing me!s

	Event.ReactivateChangedZIndex = Reactivate.Changed:connect(function(Property)
		if Property == "ZIndex" and Reactivate.ZIndex ~= 20 then
			Reactivate.ZIndex    = 20
			wait()
			ReactivateTwo.ZIndex = 20
			Deactivate.ZIndex    = 20
			AlwaysActiveCheckmark.ZIndex = 20
		end
	end)


	local Placeholder = Create'Frame'{
		Name = "Placeholder";
		BackgroundTransparency = 1;
	}

	local MouseDrag = Create'ImageButton'{
		Active                 = false;
		Size                   = UDim2.new(1.5, 0, 1.5, 0);
		AutoButtonColor        = false;
		BackgroundTransparency = 1;
		Name                   = "MouseDrag";
		Position               = UDim2.new(-0.25, 0, -0.25, 0);
		ZIndex                 = 10;
	}

	local MouseOverFrame = Create'Frame'{
		Name = "MouseOver";
		BackgroundTransparency = 1;
		Parent = Screen;
	}

	--[[
	local math_env = {
		abs = math.abs; acos = math.acos; asin = math.asin; atan = math.atan; atan2 = math.atan2;
		ceil = math.ceil; cos = math.cos; cosh = math.cosh; deg = math.deg;
		exp = math.exp; floor = math.floor; fmod = math.fmod; frexp = math.frexp;
		huge = math.huge; ldexp = math.ldexp; log = math.log; log10 = math.log10;
		max = math.max; min = math.min; modf = math.modf; pi = math.pi;
		pow = math.pow; rad = math.rad; random = math.random; sin = math.sin;
		sinh = math.sinh; sqrt = math.sqrt; tan = math.tan; tanh = math.tanh;
	}--]]

	local function eval(str,prev)
		--[[local env = {}
		for k,v in pairs(math_env) do
			env[k] = v
		end
		env.x = prev
		env.n = prev

		local result

		pcall(function()
			local f = loadstring("return "..str)
			if f then
				setfenv(f,env)
				local s,o = pcall(f)
				if s then
					result = o
				end
			end
		end)


		return result or--]] return tonumber(str)
	end

	local function GetPosIndex(list,pos,size)
		list = MenuContainerClass.List
		if #list > 1 then
			local yMax = pos.y
			local index

			for i = 1,#list do
				local menu = list[i]
				if menu.AbsolutePosition.y + menu.AbsoluteSize.y/2 > yMax - size.y
				and menu.AbsolutePosition.y + size.y > yMax - size.y then
					index = i
					break
				end
			end
			return index
		else
			return 1
		end
	end

	local function InvokeMenuDrag(MenuFrame,offset,fToggle)
		draggingMenu = true

		local orderSet = {}
		do
			local list = MenuContainerClass.List
			for i = 1,#list do
				orderSet[i] = list[i].AbsolutePosition + list[i].AbsoluteSize/2
			end
		end

		local mouse_pos = offset + MenuFrame.AbsolutePosition
		Placeholder.Size = MenuFrame.Size
		local index = MenuContainerClass.GetIndex(MenuFrame)
		MenuContainerClass.RemoveObject(MenuFrame)
		MenuContainerClass.AddObject(Placeholder,index)
		MenuFrame.Parent = Screen

		local drag_con
		local up_con

		local doToggle = true
		local zIndex = MenuFrame.ZIndex
		local function mouse_up()
			MouseDrag.Parent = nil
			drag_con:disconnect(); drag_con = nil
			up_con:disconnect(); --drag = nil
			gloo.SetZIndex(MenuFrame, zIndex)
			MenuContainerClass.RemoveObject(Placeholder)
			MenuContainerClass.AddObject(MenuFrame,index)
			draggingMenu = false
			if doToggle then
				fToggle()
			end
		end

		local function mouse_drag(x,y)
			local pos = Vector2.new(x,y) - offset
			local x,y = pos.x,pos.y
			local cPos = MenuContainerFrame.AbsolutePosition + Vector2.new(8,8)
			local max = cPos + MenuContainerFrame.AbsoluteSize - Vector2.new(16,16)

			if y > max.y then
				y = max.y
			elseif y < cPos.y then
				y = cPos.y
			end

			MenuFrame.Position = UDim2.new(0,cPos.x,0,y)
			index = GetPosIndex(orderSet,MenuFrame.AbsolutePosition + MenuFrame.AbsoluteSize/2,MenuFrame.AbsoluteSize/2) or index
			MenuContainerClass.MoveObject(Placeholder,index)
		end

		drag_con = MouseDrag.MouseMoved:connect(function(...)
			doToggle = false
			mouse_drag(...)
		end)
		up_con = MouseDrag.MouseButton1Up:connect(mouse_up)
		gloo.SetZIndex(MenuFrame,zIndex + 1)
		MouseDrag.Parent = Screen
		mouse_drag(mouse_pos.x,mouse_pos.y)
	end


	for i,menu_name in pairs(MenuList) do
		local menu = Menus[menu_name]
		local MenuClass,MenuFrame = gloo.StackingFrame()
		MenuClass.SetPadding()
		MenuStylist.AddObject(MenuFrame)
		MenuContainerClass.AddObject(MenuFrame)

		do
			local Node = Instance.new("ImageButton")
			if menu.Color then
				Node.BackgroundColor3 = menu.Color
			else
				Node.BackgroundColor3 = Color3.new(1,1,1)
			end
			MenuNodeStylist.AddObject(Node)
			MenuClass.AddObject(Node)

			local label      = Instance.new('TextLabel')
			local labelClass = gloo.AutoSizeLabel(label)
			labelClass.LockAxis(nil,8)
			labelClass.SetPadding(4)
			HoverNameStylist.AddObject(label)
			label.Visible    = false
			label.Text       = menu_name .. " Menu"
			label.Parent     = Node
			Node.MouseEnter:connect(function()
				if Node.AbsolutePosition.x + Node.AbsoluteSize.x + label.AbsoluteSize.x > Screen.AbsoluteSize.x then
					label.Position = UDim2.new(0,-label.AbsoluteSize.x,0,0)
				else
					label.Position = UDim2.new(1,0,0,0)
				end
				label.Visible = true
			end)
			Node.MouseLeave:connect(function() label.Visible = false end)
			ApplyMouseOverLabelEvent(label)

			local visible = true
			local function toggle_menu()
				visible = not visible
				for i,button in pairs(MenuClass.List) do
					if button ~= Node then
						button.Visible = visible
					end
				end
			end

			Node.MouseButton1Down:connect(function(x,y)
				label.Visible = false
				InvokeMenuDrag(MenuFrame,Vector2.new(x,y) - MenuFrame.AbsolutePosition,toggle_menu)
			end)
		end
		local vars = menu.Variables
		for i,var in pairs(menu.VariableList) do
			local name = var[1]
			local field
			if type(vars[name]) == 'number' then
				vars[name] = Plugin:GetSetting("Menus/".. menu_name .."/Variables/" .. name) or vars[name]
				vars[name] = RoundNumber(vars[name], 0.0001)


				field = Instance.new("TextBox")
				ButtonStylist.AddObject(field)
				MenuClass.AddObject(field)
				field.Text = vars[name]


				field.FocusLost:connect(function(enter)
					local num = tonumber(eval(field.Text,vars[name]))
					if num then
						vars[name] = num
						Plugin:SetSetting("Menus/".. menu_name .. "/Variables/" ..name, num)
						field.Text = num
					else
						field.Text = vars[name]
					end
				end)
			elseif type(vars[name]) == 'string' then
				field = Instance.new("TextBox")
				ButtonStylist.AddObject(field)
				MenuClass.AddObject(field)
				field.Text = vars[name]
				field.FocusLost:connect(function(enter)
					if field.Text ~= "" then
						vars[name] = field.Text
					else
						field.Text = vars[name]
					end
				end)
			end

			if field then
				field.Name = name

				local label = Instance.new('TextLabel', field)
				local labelClass = gloo.AutoSizeLabel(label)
				labelClass.LockAxis(nil,20)
				labelClass.SetPadding(4)
				HoverNameStylist.AddObject(label)
				label.Visible = false
				label.Text = var[2]

				field.MouseEnter:connect(function()
					if field.AbsolutePosition.x + field.AbsoluteSize.x + label.AbsoluteSize.x > Screen.AbsoluteSize.x then
						label.Position = UDim2.new(0,-label.AbsoluteSize.x,0,0)
					else
						label.Position = UDim2.new(1,0,0,0)
					end
					label.Visible = true
				end)

				field.MouseLeave:connect(function() 
					label.Visible = false 
				end)
				ApplyMouseOverLabelEvent(label)

				-- Record textbox's. 
				MenuInputBoxes[#MenuInputBoxes+1] = field
			end
		end



		for i,tool in pairs(menu.Tools) do
			local button = Instance.new("TextButton")
			ButtonStylist.AddObject(button)
			button.Name  = tool .. "Button"
			button.Text  = tool
			MenuClass.AddObject(button)
			ToolSelectCallback[tool] = function()
				--button.Selected = true;
				ButtonStylist.RemoveObject(button)
				SelectedButtonStylist.AddObject(button)
			end
			ToolDeselectCallback[tool] = function()
				--print("Set self Selected to false")
				--button.Selected = false;
				SelectedButtonStylist.RemoveObject(button)
				ButtonStylist.AddObject(button)
			end
			button.MouseButton1Click:connect(function()
				SelectTool(tool)
			end)

			if ToolHints[tool] then
				-- Do mouse over label
				local label      = Instance.new('TextLabel')
				local labelClass = gloo.AutoSizeLabel(label)
				labelClass.LockAxis(nil,8)
				labelClass.SetPadding(4)
				HoverNameStylist.AddObject(label)

				label.Visible    = false
				label.Text       = ToolHints[tool]
				label.Parent     = button

				button.MouseEnter:connect(function()
					if button.AbsolutePosition.x + button.AbsoluteSize.x + label.AbsoluteSize.x > Screen.AbsoluteSize.x then
						label.Position = UDim2.new(0,-label.AbsoluteSize.x,0,0)
					else
						label.Position = UDim2.new(1,0,0,0)
					end
					label.Visible = true
				end)
				button.MouseLeave:connect(function() label.Visible = false end)
				ApplyMouseOverLabelEvent(label)
			end

		end
	end

	local function tweenPanel(position,dir,notween)
		if notween == true then
			MenuContainerFrame.Position = position
		else
			MenuContainerFrame:TweenPosition(position,dir,"Quad",0.25,true)
		end
	end

	function ExpandPanel(notween)
		if hoverEnabled and collapseDirection ~= 0 then
			DisplayInfoGUI.Visible = true
			if collapseAxis == "y" then
				if collapseDirection == 1 then
					tweenPanel(panelPosition,"Out",notween)
				else
					tweenPanel(UDim2.new(panelPosition.X.Scale,panelPosition.X.Offset,0,0),"Out",notween)
				end
			else
				if collapseDirection == 1 then
					tweenPanel(panelPosition,"Out",notween)
				else
					tweenPanel(UDim2.new(0,0,panelPosition.Y.Scale,panelPosition.Y.Offset),"Out",notween)
				end
			end
		end
	end


	function CollapsePanel(notween)
		if hoverEnabled and collapseDirection ~= 0 and not SelectedTool and not draggingMenu then
			DisplayInfoGUI.Visible = false
			if collapseAxis == "y" then
				if collapseDirection == 1 then
					tweenPanel(UDim2.new(panelPosition.X.Scale,panelPosition.X.Offset,1,0),"In",notween)
				else
					tweenPanel(UDim2.new(panelPosition.X.Scale,panelPosition.X.Offset,0,-MenuContainerFrame.AbsoluteSize.y),"In",notween)
				end
			else
				if collapseDirection == 1 then
					tweenPanel(UDim2.new(1,0,panelPosition.Y.Scale,panelPosition.Y.Offset),"In",notween)
				else
					tweenPanel(UDim2.new(0,-MenuContainerFrame.AbsoluteSize.x,panelPosition.Y.Scale,panelPosition.Y.Offset),"In",notween)
				end
			end
		end
	end

	MouseOverFrame.MouseEnter:connect(ExpandPanel)
	MouseOverFrame.MouseLeave:connect(CollapsePanel)

	MenuContainerFrame.Changed:connect(function(p)
		if hoverEnabled and p == "AbsoluteSize" then
			MouseOverFrame.Size = MenuContainerFrame.Size
		end
	end)
	MouseOverFrame.Size = MenuContainerFrame.Size
	MouseOverFrame.Position = MenuContainerFrame.Position

	DisplayInfoGUI.Changed:connect(function(p)
		if infoRight and p == "AbsoluteSize" then
			local pos = DisplayInfoGUI.Position
			DisplayInfoGUI.Position = UDim2.new(1,-DisplayInfoGUI.AbsoluteSize.x,pos.Y.Scale,pos.Y.Offset)
		end
	end)


	DockClass.DragBeginCallback = function(dragged, MouseOffset)
		if dragged == MenuContainerFrame then
			hoverEnabled = false
		end

		local RealMouseOffset = dragged.AbsolutePosition + MouseOffset

		-- print("Dragged began on", dragged:GetFullName())
		-- FIX NOT BEING ABLE TO ENTER VALUES
		for _, TextBox in pairs(MenuInputBoxes) do
			-- print(TextBox, TextBox.AbsolutePosition, MouseOffset, TextBox.AbsolutePosition + TextBox.AbsoluteSize)

			if PointInBounds(TextBox, RealMouseOffset.X, RealMouseOffset.Y) then
				-- print("Point in bounds", TextBox:GetFullName())

				TextBox:CaptureFocus()
				return false
			end
		end
	end

	DockClass.DragCallback = function(dragged)
		if dragged == MenuContainerFrame then
			collapseAxis = "x"
			collapseDirection = 0
		elseif dragged == DisplayInfoGUI then
			infoRight = false
		end
	end

	DockClass.DockCallback = function(dragged,docked,axis,side)
		if dragged == MenuContainerFrame then
			collapseAxis = axis
			collapseDirection = side*2-1
		elseif dragged == DisplayInfoGUI then
			if docked == Screen and axis == "x" and side == 1 then
				infoRight = true
			end
		end
	end

	DockClass.DragStopCallback = function(dragged)
		if dragged == MenuContainerFrame then
			panelPosition = MenuContainerFrame.Position
			MouseOverFrame.Position = panelPosition
			hoverEnabled = true
		end
	end

	---- Roblox HUD docking
	local RobloxGui = CoreGui:FindFirstChild("RobloxGui")
	if RobloxGui then
		local function makeDockFrame(object)
			local frame = Create'Frame'{
				Name = object.Name;
				BackgroundTransparency = 1;
				Size = UDim2.new(0,object.AbsoluteSize.x,0,object.AbsoluteSize.y);
				Position = UDim2.new(0,object.AbsolutePosition.x,0,object.AbsolutePosition.y);
			}
			object.Changed:connect(function(p)
				if p == "AbsoluteSize" then
					frame.Size = UDim2.new(0,object.AbsoluteSize.x,0,object.AbsoluteSize.y)
				elseif p == "AbsolutePosition" then
					frame.Position = UDim2.new(0,object.AbsolutePosition.x,0,object.AbsolutePosition.y)
				elseif p == "Visible" then
					frame.Visible = object.Visible
				end
			end)
			frame.Parent = Screen
		end

		local findObjects = {
			MouseLockLabel = function(object)
				return object.Active
			end;
			SettingsButton = true;
			CameraTiltDown = true;
			CameraTiltUp = true;
			CameraZoomIn = true;
			CameraZoomOut = true;
			BackpackButton = true;
		}

		RobloxGui.DescendantAdded:connect(function(object)
			local find = findObjects[object.Name]
			if find then
				if type(find) == "function" then
					if find(object) then
						makeDockFrame(object)
					end
				else
					makeDockFrame(object)
				end
			end
		end)

		for name,f in pairs(findObjects) do
			if type(f) == "function" then
				local object = RobloxGui:FindFirstChild(name,true)
				if object and f(object) then
					makeDockFrame(object)
				end
			else
				local object = RobloxGui:FindFirstChild(name,true)
				if object then
					makeDockFrame(object)
				end
			end
		end

	end

	GUI_Initialized = true
end

do
	local Mouse = Plugin:GetMouse()

	local Is_Plugin_Enabled = false
	local Disable


	local function Enable()
		Is_Plugin_Enabled = true
		Plugin:Activate(true)
		ActivateGUIButton:SetActive(true)

		if not GUI_Initialized then
			InitializeGUI()

			Event.ReactivateClick = Reactivate.MouseButton1Click:connect(function()
				SelectPreviousTool()
				Enable()
		   	end)

		   	Event.ReactivateClickTwo = ReactivateTwo.MouseButton1Click:connect(function()
				SelectPreviousTool()
				Enable()
		   	end)

		   	Event.DeactivateClick = Deactivate.MouseButton1Click:connect(function()
		   		--- Deactivates it 100%.
				Disable()
		   	end)

		   	Event.AlwaysActiveCheckmarkClick = AlwaysActiveCheckmark.MouseButton1Click:connect(function()
		   		LegacyMode = not LegacyMode

		   		if LegacyMode then
		   			AlwaysActiveCheckmark.Text = "X"
		   		else
		   			AlwaysActiveCheckmark.Text = ""
		   		end
		   	end)
		end

		ExpandPanel(true)
		Screen.Parent = CoreGui
		Reactivate.Visible = false
	end

	function Disable()
		Is_Plugin_Enabled = false
		Plugin:Activate(false)
		ActivateGUIButton:SetActive(false)

		Screen.Parent = nil

		if SelectedTool then
			DeselectTool(SelectedTool)
		end

		CollapsePanel(true)
	end

	ActivateGUIButton.Click:connect(function()
		if not Is_Plugin_Enabled then
			Enable()
		else
			Disable()
		end
	end)

	Plugin.Deactivation:connect(function()
		if GUI_Initialized and not LegacyMode then
			Reactivate.Visible = true

			if SelectedTool then
				DeselectTool(SelectedTool)
			end

			-- Firing on activation is weird, and this may fix it....
			if Screen.Parent == nil or not Is_Plugin_Enabled then
				CollapsePanel(Screen.Parent == nil and true)
			end
		end
	end)


	local KeysDown = {}

	local function KeyUp(key)
		local function Check(Key)
			return KeysDown[string.byte(Key:lower())]
		end

		local function SCheck(Key)
			return KeysDown[Key]
		end

		local function SpecialSelectTool(Tool)
			SelectTool(Tool);
			-- Activate()
			if SelectedTool then
				ExpandPanel(true);
			end
		end

		if (Is_Plugin_Enabled or LegacyMode) then -- 50 is ctrl
			-- SHORTCUT KEYS --

			if SCheck(48) then
				if Check("c") then
					--print("Activate copy");
					SelectTool(Menus.qModifications.Tools[1])
				elseif Check("x") then
					SpecialSelectTool(Menus.Convert.Tools[1]) -- Convert
				end
			else
				if Check("r") then
					SpecialSelectTool(Menus.Resize.Tools[1]) -- ResizeObject
				elseif Check("t") then
					SpecialSelectTool(Menus.Resize.Tools[2]) -- ResizeCenter
				elseif Check("g") then
					SpecialSelectTool(Menus.Move.Tools[2]) -- MoveFirst
				elseif Check("h") then
					SpecialSelectTool(Menus.Move.Tools[1]) -- MoveAxial
				elseif Check("j") then
					SpecialSelectTool(Menus.Move.Tools[3]) -- MoveObject
				elseif Check("z") then
					SpecialSelectTool(Menus.Rotate.Tools[2]) -- RotateGroup
				elseif Check("x") then
					SpecialSelectTool(Menus.Rotate.Tools[1]) -- RotatePivot
				elseif Check("c") then
					SpecialSelectTool(Menus.Rotate.Tools[3]) -- RotateObject
				elseif Check("v") then
					SpecialSelectTool(Menus.SelectEdge.Tools[1]) -- SelectEdge
				end
			end
		end

		KeysDown[string.byte(key:lower())] = false;
	end

	local function KeyDown(key)
		-- print("Key down");
		KeysDown[string.byte(key:lower())] = true;
	end

	Mouse.KeyDown:connect(KeyDown)
	Mouse.KeyUp:connect(KeyUp)
	SelectedToolSignal:connect(function()
		KeysDown[48] = false
	end)
end

PluginActive = true
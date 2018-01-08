--[==[
gloo Change Log

v0.11:
	- started Change Log
	- GetScreen now returns object if it is a ScreenGui
	- added DockContainer
	- added Sprite
	- added TruncatingLabel
	- changed arguments of AutoSizeLabel
	- documentation now uses "GuiText" type (see Remarks in gloo.Help('Help') for details)
	- changed StackingFrame;
		- SetPadding now accepts a `border` argument
		- added GetIndex function
v0.10:
	- changed documentation scheme;
		- arguments and returns divided into sections
		- more simple scheme for function arguments
	- also fixed some documentation inconsitencies
	- changed Stylist;
		- separated objects and stylists
		- made function names more descriptive
		- added overrides
	- some ScrollBar class functions are aliased instead of switching names
	- StackingFrame class now has "List" value
	- changed arguments to ScrollingContainer
	- Help function now accepts a function itself as an argument (just in case)
v0.9:
	- added SetZIndexOnChanged function
	- changed implimentation of SetZIndex
	- added option to Graphic to divide polygon coordinates
	- added proper documentation for ScrollBar
	- added proper documentation for ScrollingList
	- added proper documentation for ScrollingContainer
	- Help function argument is now case-insensitive
v0.8:
	- added GetScreen function
	- changed `handle` back to `class` in documentation
	- changed Graphic;
		- added Destroy function
		- added "vgrip" polygon
	- added ScrollBar, derived from ScrollingList and DetailedList
	- changed ScrollingList and DetailedList to use ScrollBar
	- added ScrollingContainer
	- added Documentation Remarks section to gloo.Help('Help')
v0.7:
	- gloo does not load if gloo already exists
	- SetZIndex now works recursively
	- added `ignore_list` argument to SetZIndex
	- changed `class` to `handle` in documentation
	- expanded Stylists;
		- Stylists can be added to Stylists
		- added "Alias Maps"
		- other functions and whatnots
	- changed MakeGraphic;
		- renamed MakeGraphic to Graphic
		- removed SetGraphicStyle in favor of Stylists
		- added "wrench" and "cross" polygons
	- added "GUI" value to AutoSizeLabel class
	- StackingFrame now considers Style padding
	- changed TabContainer;
		- fixed some transparency with default appearance
		- changed default font to ArialBold
	- changed DetailedList;
		- added documentation
		- added gloo.SORT for sorting (useless)
		- removed `config` argument in favor of Stylists
		- fixed some ZIndexing issues
		- changed check-box graphic implimentation
		- moved scroll functions to own table in class
		- changed how scrolling works a bit
		- Destroy destroys things better
v0.6:
	- started versioning
	- added Version function
< v0.6:
	- started gloo library
	- added SetZIndex function
	- added GetPadding function
	- added Stylist
	- added MakeGraphic
	- added SetGraphicStyle
	- added AutoSizeLabel
	- added ScrollingList
	- added StackingFrame
	- added TabContainer
	- added DetailedList
	- added Help function
]==]
--[[
local PROJECT_NAME = "gloo"

if _G[PROJECT_NAME] then return end
--]]
---- SETTINGS
local ENTRY_SIZE	= 17	-- default size of rows, scrollbars, etc
local WEAK_TABLES	= false	-- whether weak tables are enabled (causes problems under certain circumstances)
----/SETTINGS

local lib = {}
local doc = {}
local version = "0.11"

doc["Version"] = [==[
Version ( )
	returns: string `version`

Returns the current version of the library (currently ]==]..version..[==[).
]==]

function lib.Version()
	return version
end

local SORT = {
	NONE = 0;
	ASCENDING = 1;
	DESCENDING = 2;
}
lib.SORT = SORT

local WEAK_MODE = {
	K = {__mode="k"};
	V = {__mode="v"};
	KV = {__mode="kv"};
}

local function GetIndex(table,value)
	for i,v in pairs(table) do
		if v == value then
			return i
		end
	end
end

local function ClampIndex(table,index)
	local max = #table
	index = math.floor(index)
	return index < 1 and 1 or index > max and max or index
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

--[[DEPEND:]]

doc["SetZIndex"] = [==[
SetZIndex ( Instance `object`, number `zindex` )
	returns: (nothing)

Sets the ZIndex of `object`, then calls SetZIndex on every child of `object`.

Arguments:
	`object`
		The instance to set the ZIndex of.
	`zindex`
		The ZIndex to set the object to.
]==]

doc["SetZIndexOnChanged"] = [==[
SetZIndexOnChanged ( Instance `object` )
	returns: RBXScriptConnection `connection`

Sets an object to call SetZIndex whenever its ZIndex changes.

Arguments:
	`object`
		The instance to set.

Returns:
	`connection`
		The resulting event connection.
]==]

local ZIndexLock = {}
local function SetZIndex(object,z)
	if not ZIndexLock[object] then
		ZIndexLock[object] = true
		object.ZIndex = z
		for _,child in pairs(object:GetChildren()) do
			SetZIndex(child,z)
		end
		ZIndexLock[object] = nil
	end
end

local function SetZIndexOnChanged(object)
	return object.Changed:connect(function(p)
		if p == "ZIndex" then
			SetZIndex(object,object.ZIndex)
		end
	end)
end

lib.SetZIndex = SetZIndex
lib.SetZIndexOnChanged = SetZIndexOnChanged

--[[DEPEND:]]

doc["GetScreen"] = [==[
GetScreen ( Instance `object` )
	returns ScreenGui `screen`

Gets the nearest ascending ScreenGui of `object`.
Returns `object` if it is a ScreenGui.
Returns nil if `object` isn't the descendant of a ScreenGui.

Arguments:
	`object`
		The instance to get the ascending ScreenGui from.

Returns:
	`screen`
		The ascending screen.
		Will be nil if `object` isn't the descendant of a ScreenGui.
]==]

local function GetScreen(object)
	local screen = object
	while not screen:IsA("ScreenGui") do
		screen = screen.Parent
		if screen == nil then return nil end
	end
	return screen
end

lib.GetScreen = GetScreen

--[[DEPEND:]]

doc["GetPadding"] = [==[
GetPadding ( GuiObject `object` )
	returns: number `padding`

Gets the padding amount for a Frame or GuiButton that has its Style property set.

Arguments:
	`object`
		The Frame or GuiButton to get he padding from.

Returns:
	`padding`
		The padding amount of `object`
]==]

local function GetPadding(object)
	local base_size = 0
	local base_pad = 0
	if object:IsA"Frame" then
		if object.Style == Enum.FrameStyle.ChatBlue
		or object.Style == Enum.FrameStyle.ChatGreen
		or object.Style == Enum.FrameStyle.ChatRed then
			base_size = 60
			base_pad = 17
		elseif object.Style == Enum.FrameStyle.RobloxSquare
		or object.Style == Enum.FrameStyle.RobloxRound then
			base_size = 21
			base_pad = 8
		else
			return 0
		end
	elseif object:IsA"GuiButton" then
		if object.Style == Enum.ButtonStyle.RobloxButtonDefault
		or object.Style == Enum.ButtonStyle.RobloxButton then
			base_size = 36
			base_pad = 12
		else
			return 0
		end
	else
		return 0
	end
	local size = math.min(object.AbsoluteSize.x,object.AbsoluteSize.y)
	if size < base_size then
		return size/base_size*base_pad
	else
		return base_pad
	end
end

lib.GetPadding = GetPadding

--[[DEPENDS:]]

doc["Sprite"] = [==[
Sprite ( Content `sprite_map`, GuiObject `sprite_frame`, Vector2, `sprite_size`, Vector2 `sprite_map_size`, bool `fix_blur` )
	returns: table `class`, GuiObject `sprite_frame`

Creates a sprite from a sprite map (an image that holds smaller "sub-images").

Arguments:
	`sprite_map`
		The image to use as the sprite map.
	`frame`
		The object that will contain the sprite image.
		Optional; defaults to a new Frame
	`sprite_size`
		The dimensions of one sprite on the sprite map.
		Optional; defaults to [32, 32]
	`sprite_map_size`
		The dimensions of the sprite map.
		Optional; defaults to [256, 256]
	`fix_blur`
		Indicates whether image blurriness should be fixed.
		Blurriness occurs because GUIs are offset by half a pixel, causing images to render "in-between" pixels.
		This can be fixed by using Scaled position to offset the image by 0.5 pixels.
		Optional; defaults to true

Returns:
	`class`
		Contains the following values:
		GUI
			The sprite itself.

		SetOffset ( number `row`, number `column` )
			Sets the offset of the sprite on the sprite map.
			`row` and `column` represent the row and column on the sprite map, starting from 0.
			For example, an offset of [0, 2] would select the third sprite in the first row.

		GetOffset ( )
			Returns the current offset of the sprite.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`sprite_frame`
		The sprite itself.
]==]

local function CreateSprite(sprite_map,SpriteFrame,sprite_size,map_size,fix_blur)
	sprite_size = sprite_size or Vector2.new(32,32)
	map_size = map_size or Vector2.new(256,256)
	if fix_blur == nil then fix_blur = true end

	if not SpriteFrame then
		SpriteFrame = Create'Frame'{
			Name = "Sprite";
			BackgroundTransparency = 1;
		}
	end
	SpriteFrame.ClipsDescendants = true;
	local MapFrame = Create'ImageLabel'{
		Name = "SpriteMap";
		Active = false;
		BackgroundTransparency = 1;
		Image = sprite_map;
		Size = UDim2.new(map_size.x/sprite_size.x,0,map_size.y/sprite_size.y,0);
		Parent = SpriteFrame;
	};

	local off_row,off_col = 0,0

	local SetOffset = fix_blur
	and function(row,col)
		local size = SpriteFrame.AbsoluteSize
		MapFrame.Position = UDim2.new(-col - 0.5/size.x,0,-row - 0.5/size.y,0)
		off_row,off_col = row,col
	end
	or function(row,col)
		MapFrame.Position = UDim2.new(-col,0,-row,0)
		off_row,off_col = row,col
	end;

	if fix_blur then
		SpriteFrame.Changed:connect(function(p)
			if p == "AbsoluteSize" then
				SetOffset(off_row,off_col)
			end
		end)
	end

	local Class = {
		GUI = SpriteFrame;
		SetOffset = SetOffset;
		GetOffset = function()
			return off_row,off_col
		end;
	}

	function Class.Destroy()
		for k in pairs(Class) do
			Class[k] = nil
		end
		SpriteFrame:Destroy()
	end

	return Class,SpriteFrame
end

lib.Sprite = CreateSprite

--[[DEPEND:]]

doc["Stylist"] = [==[
Stylist ( table `style` )
	returns: table `class`, table `style`

Creates a new stylist, which manages the properties of an entire group of objects.

Arguments:
	`style`
		A table of property/value pairs.
		Optional; defaults to an empty table.

Returns:
	`class`
		Contains the following values:
		Style
			The `style` table.

		AddObject ( Instance `object`, table `alias_map` )
			Adds `object` to the stylist and updates its properties.
			If `alias_map` is specified, then for this object, properties in the style will first be mapped though this table (see Alias Maps).

		RemoveObject ( Instance `object` )
			Removes `object` from the stylist.

		GetObjects ( )
			Returns a list of objects added to this stylist.
			Items in the list have no defined order.

		SetProperty ( string `property`, * `value`, bool `update`, bool `no_overrides` )
			Sets `property` in each object to `value`.
			Also sets the value in the `style` table.
			If `update` is true, objects will be updated even if `property` in `style` doesn't change.
			If `no_override` is true, then overrides will not be updated (see Overrides).

		SetGroup ( table `properties`, bool `update, bool `no_overrides` )
			Similar to SetProperty, but allows you to set multiple properties at once.
			`properties` is a table of propert/value pairs.
			If `update` is true, objects will be updated even if a property in `style` doesn't change.
			If `no_override` is true, then overrides will not be updated (see Overrides).

		Update ( bool `no_override` )
			Updates every objects' properties to reflect values in the `style` table.
			If `no_override` is true, then overrides will not be updated (see Overrides).

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

		AddStylist ( Stylist `stylist`, table `alias_map` )
			Adds `stylist` to this stylist and updates its properties.
			If `alias_map` is specified, then for this object, properties in the style will first be mapped though this table (see Alias Maps).
			Adding two stylists to each other is not recommended.
			(See Adding Stylists)

		RemoveStylist ( Stylist `stylist` )
			Removes `stylist` for this stylist.

		GetStylists ( )
			Returns a list of stylists added to this stylist.
			Items in the list have no defined order.

		AddOverride ( Stylist `override`, number `index` )
			Adds `override` to the stylist.
			If `index` is specified, then `override` will be added at that index.

		RemoveOverride ( Stylist `override` )
			Removes `override` from the stylist.
			`override` may also be a number, which indicates the index of the override to remove.
			Returns the removed override.


Alias Maps:
	These let you set the property of an object as if it were another.
	For example, if an alias map contains ["TextColor3"] = "BackgroundColor3", then
	the object will have its BackgroundColor3 property set using the TextColor3 value in the style.
	This implies that both properties should have the same type, or at least be convertible.


Adding Stylists:
	Other stylists can be added to a stylist as a "sub-stylist".
	When a property in the stylist is updated, the same property in sub-stylists also gets updated.


Overrides:
	When this stylist is updated, any "overrides" that have been added to it will also be updated.
	Because objects can be apart of more than one stylist, conflicts can arise.
	When updating a stylist of lower precedence, one would also have to update stylists of higher precedence.
	Overrides simply automate this process.
]==]

local function CreateStylist(StyleTable)
	StyleTable = StyleTable or {}
	local ObjectLookup = WEAK_TABLES and setmetatable({},WEAK_MODE.K) or {}
	local AliasObjectLookup = WEAK_TABLES and setmetatable({},WEAK_MODE.K) or {}
									-- ISSUE: objects are getting dropped when they obviously haven't been collected 
	local StylistLookup = WEAK_TABLES and setmetatable({},WEAK_MODE.K) or {}
	local AliasStylistLookup = WEAK_TABLES and setmetatable({},WEAK_MODE.K) or {}

	local Overrides = WEAK_TABLES and setmetatable({},WEAK_MODE.V) or {}

	local function pset(t,k,v)
		t[k] = v
	end

	local function SetProperty(property,value,update,no_override)
		local old = StyleTable[property]
		if value ~= old or update then
			StyleTable[property] = value
			for object in pairs(ObjectLookup) do
				pcall(pset,object,property,value)
			end
			for stylist in pairs(StylistLookup) do
			--	if stylist.Style[property] ~= nil then
					stylist.SetProperty(property,value,update)
			--	end
			end
			for object,alias_map in pairs(AliasObjectLookup) do
				local alias = alias_map[property]
				if alias then
					pcall(pset,object,alias,value)
				else
					pcall(pset,object,property,value)
				end
			end
			for stylist,alias_map in pairs(AliasStylistLookup) do
			--	if stylist.Style[property] ~= nil then
					local alias = alias_map[property]
					if alias then
						stylist.SetProperty(alias,value,update)
					else
						stylist.SetProperty(property,value,update)
					end
			--	end
			end
			if not no_override then
				for i,override in pairs(Overrides) do
					override.Update()
				end
			end
		end
	end

	local function SetGroup(new_style,update,no_override)
		for property,value in pairs(new_style) do
			local old = StyleTable[property]
			if value ~= old or update then
				StyleTable[property] = value
				for object in pairs(ObjectLookup) do
					pcall(pset,object,property,value)
				end
				for stylist in pairs(StylistLookup) do
				--	if stylist.Style[property] ~= nil then
						stylist.SetProperty(property,value,update)
				--	end
				end
				for object,alias_map in pairs(AliasObjectLookup) do
					local alias = alias_map[property]
					if alias then
						pcall(pset,object,alias,value)
					else
						pcall(pset,object,property,value)
					end
				end
				for stylist,alias_map in pairs(AliasStylistLookup) do
				--	if stylist.Style[property] ~= nil then
						local alias = alias_map[property]
						if alias then
							stylist.SetProperty(alias,value,update)
						else
							stylist.SetProperty(property,value,update)
						end
				--	end
				end
			end
		end
		if not no_override then
			for i,override in pairs(Overrides) do
				override.Update()
			end
		end
	end

	local function Update(no_override)
		for property,value in pairs(StyleTable) do
			for object in pairs(ObjectLookup) do
				pcall(pset,object,property,value)
			end
			for stylist in pairs(StylistLookup) do
			--	if stylist.Style[property] ~= nil then
					stylist.SetProperty(property,value)
			--	end
			end
			for object,alias_map in pairs(AliasObjectLookup) do
				local alias = alias_map[property]
				if alias then
					pcall(pset,object,alias,value)
				else
					pcall(pset,object,property,value)
				end
			end
			for stylist,alias_map in pairs(AliasStylistLookup) do
			--	if stylist.Style[property] ~= nil then
					local alias = alias_map[property]
					if alias then
						stylist.SetProperty(alias,value)
					else
						stylist.SetProperty(property,value)
					end
			--	end
			end
		end
		if not no_override then
			for i,override in pairs(Overrides) do
				override.Update()
			end
		end
	end

	local function AddObject(object,alias_map)
		if alias_map and type(alias_map) == "table" then
			AliasObjectLookup[object] = alias_map
			for property,value in pairs(StyleTable) do
				local alias = alias_map[property]
				if alias then
					pcall(pset,object,alias,value)
				else
					pcall(pset,object,property,value)
				end
			end
		else
			ObjectLookup[object] = true
			for property,value in pairs(StyleTable) do
				pcall(pset,object,property,value)
			end
		end
	end

	local function RemoveObject(object)
		ObjectLookup[object] = nil
		AliasObjectLookup[object] = nil
	end

	local function GetObjects()
		local list = {}
		for object in pairs(ObjectLookup) do
			list[#list+1] = object
		end
		for object in pairs(AliasObjectLookup) do
			list[#list+1] = object
		end
		return list
	end

	local function AddStylist(stylist,alias_map)
		if alias_map and type(alias_map) == "table" then
			AliasStylistLookup[stylist] = alias_map
			local in_style = stylist.Style
			for property,value in pairs(StyleTable) do
			--	if in_style[property] ~= nil then
					local alias = alias_map[property]
					if alias then
						stylist.SetProperty(alias,value)
					else
						stylist.SetProperty(property,value)
					end
			--	end
			end
		else
			StylistLookup[stylist] = true
			local in_style = stylist.Style
			for property,value in pairs(StyleTable) do
			--	if in_style[property] ~= nil then
					stylist.SetProperty(property,value)
			--	end
			end
		end
	end

	local function RemoveStylist(stylist)
		StylistLookup[stylist] = nil
		AliasStylistLookup[stylist] = nil
	end

	local function GetStylists()
		local list = {}
		for stylist in pairs(StylistLookup) do
			list[#list+1] = stylist
		end
		for stylist in pairs(AliasStylistLookup) do
			list[#list+1] = stylist
		end
		return list
	end

	local function AddOverride(override,index)
		for i,v in pairs(Overrides) do
			if v == override then
				return
			end
		end
		if index then
			table.insert(Overrides,index,override)
		else
			table.insert(Overrides,override)
		end
	end

	local function RemoveOverride(index)
		if type(index) == "number" then
			index = ClampIndex(Overrides,index)
		else
			if index == nil then
				index = #Overrides
			else
				index = GetIndex(Overrides,index)
			end
		end
		if index then
			local object = table.remove(Overrides,index)
			return object
		end
	end

	local Class = {
		Style = StyleTable;
		SetProperty = SetProperty;
		SetGroup = SetGroup;
		GetObjects = GetObjects;
		Update = Update;
		AddObject = AddObject;
		RemoveObject = RemoveObject;
		AddStylist = AddStylist;
		RemoveStylist = RemoveStylist;
		GetStylists = GetStylists;
		AddOverride = AddOverride;
		RemoveOverride = RemoveOverride;
	}
	local function Destroy()
		for k in pairs(Class) do
			Class[k] = nil
		end
		for k in pairs(ObjectLookup) do
			ObjectLookup[k] = nil
		end
		for k in pairs(AliasObjectLookup) do
			AliasObjectLookup[k] = nil
		end
		for k in pairs(StylistLookup) do
			StylistLookup[k] = nil
		end
		for k in pairs(AliasStylistLookup) do
			AliasStylistLookup[k] = nil
		end
		for k in pairs(Overrides) do
			Overrides[k] = nil
		end
	end
	Class.Destroy = Destroy

	return Class,StyleTable
end

lib.Stylist = CreateStylist

--[[DEPEND:]]

doc["AutoSizeLabel"] = [==[
AutoSizeLabel ( GuiText `label` )
	returns: table `class`, GuiText `label`

Creates a text GUI that automatically resizes to its text.
Note that this is dependant on the TextBounds property.

Arguments:
	`label`
		An object to turn into an auto-sizing label.
		Optional; defaults to a new TextLabel

Returns:
	`class`
		Contains the following values:
		GUI
			The auto-sizing label itself.

		LockAxis ( number `x`, number `y` )
			Locks the size of the label on an axis to a specific amount.
			`x` sets the amount, in pixels, to lock to on the x axis.
			`y` sets the amount, in pixels, to lock to on the y axis.
			Passing either value as nil will unlock that respective axis.

		SetPadding ( number `pt`, number `pr`, number `pb`, number `pl` )
			Sets the padding for each side of the label.

			Passing four values specifies the top, right, bottom, and left, in that order.
			Passing three values specifies the top (`pt`), right/left (`pr`), and bottom (`pb`).
			Passing two values specifies the top/bottom (`pt`), and right/left (`pr`).
			Passing one value specifies that all sides have that value.
			Passing no values sets all sides to 0.

			If the text is aligned to a certain side, the padding on that side will be ignored.

		Update ( )
			Updates the label.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`label`
		The auto-sizing label itself.
]==]

local function CreateAutoSizeLabel(Label)
	if not Label then
		Label = Create'TextLabel'{
			Name = "AutoSizeLabel";
			BackgroundColor3 = Color3.new(0,0,0);
			BorderColor3 = Color3.new(1,1,1);
			TextColor3 = Color3.new(1,1,1);
			FontSize = "Size14";
			Font = "ArialBold";
		}
	end

	local pt,pr,pb,pl = 0,0,0,0
	local t,r,b,l = 0,0,0,0
	local lx,ly
	local function Update()
		local bounds = Label.TextBounds
		local x = lx or bounds.x+l+r
		local y = ly or bounds.y+t+b
		Label.Size = UDim2.new(0,x,0,y)
	end

	local function ReflectPadding()
		t,r,b,l = pt,pr,pb,pl
		if Label.TextXAlignment == Enum.TextXAlignment.Left then
			l = 0
		elseif Label.TextXAlignment == Enum.TextXAlignment.Right then
			r = 0
		end
		if Label.TextYAlignment == Enum.TextYAlignment.Top then
			t = 0
		elseif Label.TextYAlignment == Enum.TextYAlignment.Bottom then
			b = 0
		end
		Update()
	end

	local function SetPadding(nt,nr,nb,nl)
		if nl then
			pt,pr,pb,pl = nt,nr,nb,nl
		elseif nb then
			pt,pr,pb,pl = nt,nr,nb,nr
		elseif nr then
			pt,pr,pb,pl = nt,nr,nt,nr
		elseif nt then
			pt,pr,pb,pl = nt,nt,nt,nt
		else
			pt,pr,pb,pl = 0,0,0,0
		end
		ReflectPadding()
	end

	local function LockAxis(x,y)
		lx,ly = x,y
		Update()
	end

	local con = Label.Changed:connect(function(p)
		if p == "TextBounds" then
			Update()
		elseif p == "TextXAlignment" or p == "TextYAlignment" then
			ReflectPadding()
		end
	end)

	local Class = {
		GUI = Label;
		Update = Update;
		LockAxis = LockAxis;
		SetPadding = SetPadding;
	}
	local function Destroy()
		for k in pairs(Class) do
			Class[k] = nil
		end
		con:disconnect()
	end
	Class.Destroy = Destroy

	Update()

	return Class,Label
end

lib.AutoSizeLabel = CreateAutoSizeLabel

--[[DEPEND:]]

doc["TruncatingLabel"] = [==[
TruncatingLabel ( GuiText `label` )
	returns: GuiText `label`

Creates a label that displays truncated text.
When the label is hovered over, the full text is displayed.

Arguments:
	`label`
		An object that will be turned into a truncating label.
		Optional; defaults to a new GuiText

Returns:
	`label`
		The label itself.
]==]

local function CreateTruncatingLabel(Label)
	if not Label then
		Label = Create'TextLabel'{
			BackgroundColor3 = Color3.new(0,0,0);
			BorderColor3 = Color3.new(1,1,1);
			TextColor3 = Color3.new(1,1,1);
			FontSize = "Size14";
			Font = "ArialBold";
			Text = "";
		}
	end
	Label.ClipsDescendants = true;

	local FullTextLabel = Create'TextLabel'{
		Name = "FullTextLabel";
		BackgroundColor3 = Label.BackgroundColor3;
		BorderColor3 = Label.BorderColor3;
		TextColor3 = Label.TextColor3;
		FontSize = Label.FontSize;
		Font = Label.Font;
		Text = Label.Text;
		Visible = false;
		ZIndex = 9;
		Parent = Label;
	}

	local ex = {
		Name = true;
		Parent = true;
		Position = true;
		Size = true;
		ClipsDescendants = true;
		ZIndex = true;
		Visible = true;
	}

	local function pset(t,k,v)
		t[k] = v
	end

	Label.Changed:connect(function(p)
		if not ex[p] then
			pcall(pset,FullTextLabel,p,Label[p])
		end
	end)

	Label.MouseEnter:connect(function()
		local align = Label.TextXAlignment
		local bound = math.max(Label.TextBounds.x+4,Label.AbsoluteSize.x)
		if align == Enum.TextXAlignment.Center then
			FullTextLabel.Size = UDim2.new(0,bound,1,0)
			FullTextLabel.Position = UDim2.new(0.5,-bound/2,0,0)
		elseif align == Enum.TextXAlignment.Right then
			FullTextLabel.Size = UDim2.new(0,bound,1,0)
			FullTextLabel.Position = UDim2.new(1,-bound,0,0)
		else
			FullTextLabel.Size = UDim2.new(0,bound,1,0)
			FullTextLabel.Position = UDim2.new(0,0,0,0)
		end
		Label.ClipsDescendants = false
		SetZIndex(FullTextLabel,9)
		FullTextLabel.Visible = true
	end)

	FullTextLabel.MouseLeave:connect(function()
		FullTextLabel.Visible = false
		Label.ClipsDescendants = true
	end)

	return Label
end

lib.TruncatingLabel = CreateTruncatingLabel

--[[DEPEND:]]

doc["DockContainer"] = [==[
DockContainer ( GuiBase `container` )
	returns: table `class`, GuiBase `container`

Creates a container whose children can snap to each others' edges when dragged (referred to as "dockables").
Only children that are GuiButtons will be made draggable.
However, they will still dock to any sibling that is a GuiObject.

Arguments:
	`container`
		An object that becomes the dock container.
		Optional; defaults to a new ScreenGui

Returns:
	`class`
		Contains the following values:
		GUI
			The container itself.

		SnapWidth
			A number indicating the space (in pixels) required between the edges of two dockables before one snaps to the other.
			Initially, this value is 16.

		ConstrainToContainer
			A bool indicating whether dockables can't be dragged outside the container.
			Initially, this value is false.

		SnapToContainerEdge
			A bool indicating whether dockables can snap to the edge of the container.
			Only applies if ConstrainToContainer is false.
			Initially, this value is true.

		PositionScaled
			A bool indicating whether the position of dockables are set as a Scale or an Offset.
			Initially, this value is true.

		DragZIndex
			A number indicating the amount to increase the ZIndex of a dockable by when it is dragged.
			Initially, this value is 1.

		InvokeDrag ( GuiObject `dragged`, Vector2 `mouse_offset` )
			Starts dragging `dragged` as if it were clicked.
			`mouse_offset` is the position of the mouse when it "clicked" the object, in relation to the object.

		StopDrag ( )
			Stops the dragging of an object, if there is an object being dragged.

		DragCallback ( GuiObject `dragged`, Vector2 `mouse_offset` )
			A function called when an object is dragged, before the object updates.
			`dragged` is the object being dragged.
			`mouse_offset` is the location of the mouse when it started dragging, in relation to the object.
			If the function returns false, then the object's position will not be updated.

		DragBeginCallback ( GuiObject `dragged`, Vector2 `mouse_offset` )
			A function called before an object starts being dragged.
			`dragged` is the object being dragged.
			`mouse_offset` is the position of the mouse, in relation to the object.
			If the function returns false, then the drag will be canceled.

		DragStopCallback ( GuiObject `dragged`, Vector2 `mouse_pos` )
			A function called after an object stops being dragged.
			`dragged` is the object that was dragged.
			`mouse_offset` is the position of the mouse when it started dragging, in relation to the object.

		DockCallback ( GuiObject `dragged`, GuiObject `docked`, string `axis`, number `side` )
			A function called before the currently dragged object snaps to another dockable.
			`dragged` is the current object being dragged.
			`docked` is the dockable that `dragged` snapped to (if available).
			`axis` is the axis the dockable snapped on ("x"or "y")
			`side` is the side of the dockable that was snapped on (0 or 1).
			Note that `docked` can be the container, if objects are allowed to snap to it.
			If the function returns false, then the snap to the dockable will be canceled.

	`container`
		The container itself

]==]

local function CreateDockContainer(Container)
	if not Container then
		Container = Instance.new("ScreenGui")
		Container.Name = "DockContainer"
	end

	local Class = {
		GUI = Container;
		SnapWidth = 16;
		SnapToEdge = true;
		ConstrainToContainer = false;
		PositionScaled = true;
		DragZIndex = 1;
	}

	local DragEvent = {}
	local MouseDrag = Create'ImageButton'{
		Active = false;
		Size = UDim2.new(1.5, 0, 1.5, 0);
		AutoButtonColor = false;
		BackgroundTransparency = 1;
		Name = "MouseDrag";
		Position = UDim2.new(-0.25, 0, -0.25, 0);
		ZIndex = 10;
	}

	local function stopDragDefault()
		return false,"no object is being dragged"
	end

	local function InvokeDrag(dockable,mouse_offset)
		if Class.DragBeginCallback then
			if Class.DragBeginCallback(dockable,mouse_offset)
			== false then return end
		end

		local drag_con
		local up_con

		drag_con = MouseDrag.MouseMoved:connect(function(x,y)
			if Class.DragCallback then
				if Class.DragCallback(dockable,mouse_offset)
				== false then return end
			end

			local snapWidth = Class.SnapWidth

			local cApos = Container.AbsolutePosition
			local Apos = Vector2.new(x,y) - mouse_offset

			local cAsize = Container.AbsoluteSize
			local Asize = dockable.AbsoluteSize

			local APX,APY = Apos.x,Apos.y
			local ASX,ASY = Asize.x,Asize.y

			x = Apos.x - cApos.x
			y = Apos.y - cApos.y

			local docked_x,docked_y
			local side_x,side_y

			if Class.DockCallback then
				for i,sibling in pairs(Container:GetChildren()) do
					if sibling:IsA"GuiObject" and sibling ~= dockable and sibling.Visible then
						local sApos = sibling.AbsolutePosition
						local sAsize = sibling.AbsoluteSize

						if Apos.x + Asize.x >= sApos.x and Apos.x <= sApos.x + sAsize.x then
							if math.abs((Apos.y + Asize.y) - sApos.y) <= snapWidth then
								if Class.DockCallback(dockable,sibling,"y",0) ~= false then
									y = sApos.y - cApos.y - Asize.y
								end
							elseif math.abs(Apos.y - (sApos.y + sAsize.y)) <= snapWidth then
								if Class.DockCallback(dockable,sibling,"y",1) ~= false then
									y = sApos.y - cApos.y + sAsize.y
								end
							end
						end
						if Apos.y + Asize.y >= sApos.y and Apos.y <= sApos.y + sAsize.y then
							if math.abs((Apos.x + Asize.x) - sApos.x) <= snapWidth then
								if Class.DockCallback(dockable,sibling,"x",0) ~= false then
									x = sApos.x - cApos.x - Asize.x
								end
							elseif math.abs(Apos.x - (sApos.x + sAsize.x)) <= snapWidth then
								if Class.DockCallback(dockable,sibling,"x",1) ~= false then
									x = sApos.x - cApos.x + sAsize.x
								end
							end
						end
					end
				end
				if Class.ConstrainToContainer then
					if APY < cApos.y then
						if Class.DockCallback(dockable,Container,"y",0) ~= false then
							y = 0
						end
					elseif APY + ASY > cApos.y + cAsize.y then
						if Class.DockCallback(dockable,Container,"y",1) ~= false then
							y = cAsize.y - ASY
						end
					end
					if APX < cApos.x then
						if Class.DockCallback(dockable,Container,"x",0) ~= false then
							x = 0
						end
					elseif APX + ASX > cApos.x + cAsize.x then
						if Class.DockCallback(dockable,Container,"x",1) ~= false then
							x = cAsize.x - ASX
						end
					end
				elseif Class.SnapToEdge then
					if math.abs(APY - cApos.y) <= snapWidth then
						if Class.DockCallback(dockable,Container,"y",0) ~= false then
							y = 0
						end
					elseif math.abs((APY+ASY) - (cApos.y+cAsize.y)) <= snapWidth then
						if Class.DockCallback(dockable,Container,"y",1) ~= false then
							y = cAsize.y - ASY
						end
					end
					if math.abs(APX - cApos.x) <= snapWidth then
						if Class.DockCallback(dockable,Container,"x",0) ~= false then
							x = 0
						end
					elseif math.abs((APX+ASX) - (cApos.x+cAsize.x)) <= snapWidth then
						if Class.DockCallback(dockable,Container,"x",1) ~= false then
							x = cAsize.x - ASX
						end
					end
				end
			else
				for i,sibling in pairs(Container:GetChildren()) do
					if sibling:IsA"GuiObject" and sibling ~= dockable and sibling.Visible then
						local sApos = sibling.AbsolutePosition
						local sAsize = sibling.AbsoluteSize

						if Apos.x + Asize.x >= sApos.x and Apos.x <= sApos.x + sAsize.x then
							if math.abs((Apos.y + Asize.y) - sApos.y) <= snapWidth then
								y = sApos.y - cApos.y - Asize.y
							elseif math.abs(Apos.y - (sApos.y + sAsize.y)) <= snapWidth then
								y = sApos.y - cApos.y + sAsize.y
							end
						end
						if Apos.y + Asize.y >= sApos.y and Apos.y <= sApos.y + sAsize.y then
							if math.abs((Apos.x + Asize.x) - sApos.x) <= snapWidth then
								x = sApos.x - cApos.x - Asize.x
							elseif math.abs(Apos.x - (sApos.x + sAsize.x)) <= snapWidth then
								x = sApos.x - cApos.x + sAsize.x
							end
						end
					end
				end
				if Class.ConstrainToContainer then
					if APY < cApos.y then
						y = 0
					elseif APY + ASY > cApos.y + cAsize.y then
						y = cAsize.y - ASY
					end
					if APX < cApos.x then
						x = 0
					elseif APX + ASX > cApos.x + cAsize.x then
						x = cAsize.x - ASX
					end
				elseif Class.SnapToEdge then
					if math.abs(APY - cApos.y) <= snapWidth then
						y = 0
					elseif math.abs((APY+ASY) - (cApos.y+cAsize.y)) <= snapWidth then
						y = cAsize.y - ASY
					end
					if math.abs(APX - cApos.x) <= snapWidth then
						x = 0
					elseif math.abs((APX+ASX) - (cApos.x+cAsize.x)) <= snapWidth then
						x = cAsize.x - ASX
					end
				end
			end

			local sx,sy = 0,0
			if Class.PositionScaled then
				sx = x/cAsize.x
				sy = y/cAsize.y
				x = 0
				y = 0
			end
			dockable.Position = UDim2.new(sx,x,sy,y)
		end)
		local zIndex = dockable.ZIndex
		local function mouse_up()
			Class.StopDrag = stopDragDefault
			MouseDrag.Parent = nil
			drag_con:disconnect(); drag_con = nil
			up_con:disconnect(); drag = nil
			SetZIndex(dockable,zIndex)
			if Class.DragStopCallback then
				Class.DragStopCallback(dockable,mouse_offset)
			end
			return true
		end
		up_con = MouseDrag.MouseButton1Up:connect(mouse_up)
		SetZIndex(dockable,zIndex + Class.DragZIndex)
		MouseDrag.Parent = GetScreen(dockable)
		Class.StopDrag = mouse_up
	end
	Class.InvokeDrag = InvokeDrag

	local function ChildAdded(child)
		if child:IsA"GuiButton" then
			DragEvent[child] = child.MouseButton1Down:connect(function(x,y)
				InvokeDrag(child,Vector2.new(x,y) - child.AbsolutePosition)
			end)
		end
	end

	local function ChildRemoved(child)
		if DragEvent[child] then
			DragEvent[child]:disconnect()
			DragEvent[child] = nil
		end
	end

	Container.ChildAdded:connect(ChildAdded)
	Container.ChildRemoved:connect(ChildRemoved)

	for i,dockable in pairs(Container:GetChildren()) do
		ChildAdded(dockable)
	end

	return Class,Container
end

lib.DockContainer = CreateDockContainer

--[[DEPEND:
Stylist.lua;
]]

doc["Graphic"] = [==[
Graphic ( string `polygon`, Vector2 `size`, table `style`, table `config` )
	returns table `class`, Frame `graphic`

Creates a basic GUI graphic from a polygon or specified preset.

Arguments:
	`polygon`
		May be a string, referencing a preset (see Presets).
		May also be a table that contains two tables, which represent the x and y coordinates (respectively) of each point in the polygon.
		If coordinates are not between 0 and 1, a 3rd entry may be specified, which is the number to divide each coordinate by.
	`size`
		The size, in pixels, of the graphic.
		May also be a table that contains the x and y size of the graphic.
	`style`
		A table that will be used with the graphic's Stylist, which controls the appearance of the graphic.
		Optional; defaults to an empty table.
		Note that the graphic essentially shares the same properties as a Frame object.
		So, if ["BackgroundColor3"] = Color3.new(1,1,1) were in the table, the graphic's color would be set to white.
	`config`
		A table that alters how the graphic will be drawn.
		It can contain the following possible values:
			method
				May be "scaled" or "static".
				Determines if pixels will be scaled to the parent or static.
			round
				May be "half", "ceil", or "floor".
				If static method is chosen, this determines how to round each pixel.
			offset
				A Vector2. This offsets the polygon on the final image.

Returns:
	`class`
	Contains the following values:
	GUI
		The Frame object which makes up the graphic.

	Style
		The Stylist object used to class the appearance of the graphic.

	Destroy ( )
		Releases the resources used by this object.
		Run this if you're no longer using this object.


Presets:
	arrow-up
	arrow-down
	arrow-left
	arrow-right
	check-mark
	pin
	wrench
	cross
	grip
	vgrip
]==]

--[[
	polygon:
		string:									a reference to a predefined polygon
		table: {Vector2, ...}					a list of Vector2 points
		table: {{number, ...},{number, ...}}	two lists of x and y axes
	size
		table: {number, number}
		Vector2
	style
	config
		method	= scaled|static			Whether pixels will be scaled to the parent or static
		round	= ceil|floor|half		If static method is chosen, this determines how to round each pixel
		offset	= Vector2				Offsets the polygon on the final image. The polygon will be clipped so that it doesn't render outside the image region
]]

--[[
local polyX = {3,8,9,13,13,10,8,6,2}
local polyY = {2,6,2,9,13,10,15,2,10}
local polyCorners = 9
]]

local internal_polygon = {
	["arrow-up"] = {
		{2,4,6};
		{5,3,5};
		8;
	};
	["arrow-down"] = {
		{2,4,6};
		{3,5,3};
		8;
	};
	["arrow-left"] = {
		{5,3,5};
		{2,4,6};
		8;
	};
	["arrow-right"] = {
		{3,5,3};
		{2,4,6};
		8;
	};
	["check-mark"] = {
		{1,3,7,7,3,1};
		{3,5,1,3,7,5};
		8;
	};
	["pin"] = {
		{4,11,11,12,12,8,8,7,7,3,3,4, 4,5,7,7,5,5};
		{2,2,9,9,10,10,14,14,10,10,9,9, 2,3,3,9,9,3};
		16;
	};
	["wrench"] = {
		{	2;	8;	18;	25;	29;	29;	24;	20;	17;	17;	22;	16;	12;	12};
		{	24;	30;	20;	20;	16;	10;	15;	15;	12;	8;	3;	3;	7;	14};
		32,
	};
	["cross"] = {
		{1;	2;	4;	6;	7;	7;	5;	7;	7;	6;	4;	2;	1;	1;	3;	1};
		{1;	1;	3;	1;	1;	2;	4;	6;	7;	7;	5;	7;	7;	6;	4;	2};
		8;
	};
	["grip"] = function(size,class,config)
		local GraphicFrame = class.GUI
		GraphicFrame.Size = UDim2.new(0,size.x*(size.y == 0 and 2 or size.y),0,size.x*2)
		for i=1,size.x do
			local p = Instance.new("Frame",GraphicFrame)
			p.BackgroundColor3 = Color3.new(0,0,0)
			p.BorderSizePixel = 0
			p.Size = UDim2.new(1,0,0,1)
			p.Position = UDim2.new(0,0,0,(i-1)*(size.y == 0 and 2 or size.y))
			class.Stylist.AddObject(p)
		end

		return class,GraphicFrame
	end;
	["vgrip"] = function(size,class,config)
		local GraphicFrame = class.GUI
		GraphicFrame.Size = UDim2.new(0,size.x*2,0,size.x*(size.y == 0 and 2 or size.y))
		for i=1,size.x do
			local p = Instance.new("Frame",GraphicFrame)
			p.BackgroundColor3 = Color3.new(0,0,0)
			p.BorderSizePixel = 0
			p.Size = UDim2.new(0,1,1,0)
			p.Position = UDim2.new(0,(i-1)*(size.y == 0 and 2 or size.y),0,0)
			class.Stylist.AddObject(p)
		end

		return class,GraphicFrame
	end;
}

local function CreateGraphic(polygon,size,style,config)
--[[	local function round(d)
		local i = floor(d)
		d = d - i
		if d < 0.5 then
			return i
		elseif d > 0.5 then
			return i + 1
		elseif i%2==0 then
			return i
		else
			return i + 1
		end
	end
]]
	local function round(n)
		if n < 0 then
			return math.ceil(n - 0.5)
		else
			return math.floor(n + 0.5)
		end
	end

	local GraphicFrame = Instance.new("Frame")
	GraphicFrame.Name = "Graphic"
	GraphicFrame.BackgroundTransparency = 1

	local GraphicStylist = CreateStylist(style)

	local Class = {
		GUI = GraphicFrame;
		Stylist = GraphicStylist;
	}

	function Class.Destroy()
		for k in pairs(Class) do
			Class[k] = nil
		end
		GraphicStylist.Destroy()
		GraphicFrame:Destroy()
	end

	local polygonX,polygonY = {},{}
	if type(polygon) == "table" then
		polygonX = polygon[1]
		polygonY = polygon[2]
		local div = polygon[3]
		if div then
			for i=1,#polygonX do
				polygonX[i] = (polygonX[i])/div
			end
			for i=1,#polygonY do
				polygonY[i] = (polygonY[i])/div
			end
		end
	elseif type(polygon) == "string" then
		local in_poly = internal_polygon[polygon]
		if type(in_poly) == "table" then
			local div = in_poly[3] or 1
			for i=1,#in_poly[1] do
				polygonX[i] = (in_poly[1][i])/div
			end
			for i=1,#in_poly[2] do
				polygonY[i] = (in_poly[2][i])/div
			end
		elseif type(in_poly) == "function" then
			return in_poly(size,Class,config)
		else
			error("\'"..tostring(polygon).."\' is not a valid internal polygon",2)
		end
	else
		error("invalid polygon",2)
	end
	local posX,posY,sizeX,sizeY = 0,0,0,0
	config = config or {}
	local method = config.method or "scaled"
	local round = round
	if config.round == "ceil" then
		round = math.ceil
	elseif config.round == "floor" then
		round = math.floor
	elseif config.round == "half" then
		round = round
	end
	if config.offset then
		posX,posY = -config.offset.x,-config.offset.y
	end
	if type(size) == "userdata" then
		sizeX = size.x
		sizeY = size.y
	elseif type(size) == "table" then
		sizeX = size[1] or size.x
		sizeY = size[2] or size.y
	else
		error("invalid size",2)
	end

	local polygonN = #polygonX
	for i=1,polygonN do
		polygonX[i] = polygonX[i]*sizeX
	end
	for i=1,polygonN do
		polygonY[i] = polygonY[i]*sizeY
	end

	GraphicFrame.Size = UDim2.new(0,sizeX,0,sizeY)

	local p = Instance.new("Frame")
	p.BorderSizePixel = 0
	p.BackgroundColor3 = Color3.new()
	p.Size = UDim2.new(0,1,0,1)

	local fillLine
	if method == "scaled" then
		fillLine = function(x1,x2,y)
			x2 = x2-x1
			if x2 ~= 0 then
				local c = p:Clone()
				GraphicStylist.AddObject(c)
				c.Position = UDim2.new(x1/sizeX,0,y/sizeY,0)
				c.Size = UDim2.new(x2/sizeX,0,1/sizeY,0)
				c.Parent = GraphicFrame
			end
		end
	elseif method == "static" then
		fillLine = function(x1,x2,y)
			x1 = round(x1,1)
			x2 = round(x2,1)-x1
			if x2 ~= 0 then
				local c = p:Clone()
				GraphicStylist.AddObject(c)
				c.Position = UDim2.new(0,x1,0,y)
				c.Size = UDim2.new(0,x2,0,1)
				c.Parent = GraphicFrame
			end
		end
	else
		error("invalid method",2)
	end

	for pixelY = posY,sizeY+posY-1 do
		local nodes = 0
		local nodeX = {}
		local j = polygonN;
		for i=1,polygonN do
			if polygonY[i] < pixelY and polygonY[j] >= pixelY or polygonY[j] < pixelY and polygonY[i] >= pixelY then
				nodeX[nodes] = (polygonX[i] + (pixelY - polygonY[i])/(polygonY[j] - polygonY[i])*(polygonX[j] - polygonX[i]))
				nodes = nodes + 1
			end
			j = i
		end

		local i = 0
		while i < nodes - 1 do
			if nodeX[i] > nodeX[i+1] then
				nodeX[i],nodeX[i+1] = nodeX[i+1],nodeX[i]
				if i ~= 0 then i = i - 1 end
			else
				i = i + 1
			end
		end

		local modX,modY = posX + sizeX, posY + sizeY

		local i = 0
		while i < nodes - 1 do
			if nodeX[i] >= modX then
				break
			end
			if nodeX[i+1] > posX then
				if nodeX[i] < posX then
					nodeX[i] = posX
				end
				if nodeX[i+1] > modX then
					nodeX[i+1] = modX
				end
				fillLine(nodeX[i]-posX,nodeX[i+1]-posX,pixelY-posY)
			end
			i = i + 2
		end
	end

	return Class,GraphicFrame
end

lib.Graphic = CreateGraphic

--[[DEPEND:
SetZIndex.lua;
GetScreen.lua;
Graphic.lua;
]]

doc["ScrollBar"] = [==[
ScrollBar ( bool `horizontal`, number `size` )
	returns: table `class`, Frame `scroll_bar`

Creates a primative scroll bar.
This scroll bar features a draggable thumb, paging buttons at either end, and a clickable track.

Arguments:
	`horizontal`
		If true, the scroll bar will appear horizontally instead of vertically.
		Optional; defaults to false.
	`size`
		Sets the width or height of the scroll bar.
		Optional; defaults to ]==]..ENTRY_SIZE..[==[

Returns:
	`class`
		Contains the following values:
		GUI
			The scroll bar itself.

		ScrollIndex
			A number indicating the current position of the scroll bar.

		TotalSpace
			A number indicating the total span of the scrollable space.

		VisibleSpace
			A number indicating the visible span of the scrollable space.

		PageIncrement
			The amount to increase or decrease the ScrollIndex when ScrollDown or ScrollUp is called.

		Update ( )
			Updates the scroll bar to reflect any changes.

		UpdateCallback ( table `class` )
			A function called first when `class`.Update is called.

		CanScrollDown ( )
			Returns whether the scroll bar can scroll down (or right if `horizontal` is true).

		CanScrollRight ( )
			Alias of CanScrollDown.

		CanScrollUp ( )
			Returns whether the scroll bar can scroll up (or left if `horizontal` is true).

		CanScrollLeft ( )
			Alias of CanScrollUp.

		ScrollDown ( )
			Scrolls down (or right) by the current PageIncrement.

		ScrollRight( )
			Alias of ScrollDown.

		ScrollUp ( )
			Scrolls up (or left) by the current PageIncrement.

		ScrollLeft ( )
			Alias of ScrollUp.

		ScrollTo ( number `index` )
			Scrolls to a specific place, specified by `index`.
			This may be any number; it will be clamped between 0 and TotalSpace.

		GetScrollPercent ( )
			Returns the scroll index as a percentage between 0 and 1.

		SetScrollPercent ( number `percent` )
			Sets the ScrollIndex as a percentage between 0 and 1.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`scroll_bar`
		The scroll bar itself.
]==]

local function CreateScrollBar(horizontal,size)
	size = size or ENTRY_SIZE

	-- create row scroll bar
	local ScrollFrame = Create'Frame'{
		Size = horizontal and UDim2.new(1,0,0,size) or UDim2.new(0,size,1,0);
		Position = horizontal and UDim2.new(0,0,1,-size) or UDim2.new(1,-size,0,0);
		BackgroundTransparency = 1;
		Name = "ScrollFrame";
		Create'ImageButton'{
			BackgroundColor3 = Color3.new(1,1,1);
			BackgroundTransparency = 0.7;
			BorderSizePixel = 0;
			Size = UDim2.new(0, size, 0, size);
			Name = "ScrollDown";
			Position = horizontal and UDim2.new(1,-size,0,0) or UDim2.new(0,0,1,-size);
		};
		Create'ImageButton'{
			BackgroundColor3 = Color3.new(1,1,1);
			BackgroundTransparency = 0.7;
			BorderSizePixel = 0;
			Size = UDim2.new(0, size, 0, size);
			Name = "ScrollUp";
		};
		Create'ImageButton'{
			AutoButtonColor = false;
			Size = horizontal and UDim2.new(1,-size*2,1,0) or UDim2.new(1,0,1,-size*2);
			BackgroundColor3 = Color3.new(0,0,0);
			BorderSizePixel = 0;
			BackgroundTransparency = 0.7;
			Position = horizontal and UDim2.new(0,size,0,0) or UDim2.new(0,0,0,size);
			Name = "ScrollBar";
			Create'ImageButton'{
				BorderSizePixel = 0;
				BackgroundColor3 = Color3.new(1,1,1);
				Size = UDim2.new(0, size, 0, size);
				BackgroundTransparency = 0.5;
				Name = "ScrollThumb";
			};
		};
	}

	local ScrollDownFrame = ScrollFrame.ScrollDown
		local ScrollDownGraphic = CreateGraphic(horizontal and "arrow-right" or "arrow-down",Vector2.new(size,size))
		ScrollDownGraphic.GUI.Parent = ScrollDownFrame
	local ScrollUpFrame = ScrollFrame.ScrollUp
		local ScrollUpGraphic = CreateGraphic(horizontal and "arrow-left" or "arrow-up",Vector2.new(size,size))
		ScrollUpGraphic.GUI.Parent = ScrollUpFrame
	local ScrollBarFrame = ScrollFrame.ScrollBar
	local ScrollThumbFrame = ScrollBarFrame.ScrollThumb
		local Decal = CreateGraphic(horizontal and "vgrip" or "grip",Vector2.new(4),{BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.5})
		Decal.GUI.Position = UDim2.new(0.5,-4,0.5,-4)
		Decal.GUI.Parent = ScrollThumbFrame

	local MouseDrag = Create'ImageButton'{
		Active = false;
		Size = UDim2.new(1.5, 0, 1.5, 0);
		AutoButtonColor = false;
		BackgroundTransparency = 1;
		Name = "MouseDrag";
		Position = UDim2.new(-0.25, 0, -0.25, 0);
		ZIndex = 10;
	}

	local Class = {
		GUI = ScrollFrame;
		ScrollIndex = 0;
		VisibleSpace = 0;
		TotalSpace = 0;
		PageIncrement = 1;
		UpdateCallback = function()end;
	}

	local function GetScrollPercent()
		return Class.ScrollIndex/(Class.TotalSpace-Class.VisibleSpace)
	end
	Class.GetScrollPercent = GetScrollPercent

	local function CanScrollDown()
		return Class.ScrollIndex + Class.VisibleSpace < Class.TotalSpace
	end
	Class.CanScrollDown = CanScrollDown
	Class.CanScrollRight = CanScrollDown

	local function CanScrollUp()
		return Class.ScrollIndex > 0
	end
	Class.CanScrollUp = CanScrollUp
	Class.CanScrollLeft = CanScrollUp

	local ScrollStyle = {BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0}
	local ScrollStyle_ds = {BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.7}

	local last_down
	local last_up
	local UpdateScrollThumb = horizontal
	and function()
		ScrollThumbFrame.Size = UDim2.new(Class.VisibleSpace/Class.TotalSpace,0,0,size)
		if ScrollThumbFrame.AbsoluteSize.x < size then
			ScrollThumbFrame.Size = UDim2.new(0,size,0,size)
		end
		local bar_size = ScrollBarFrame.AbsoluteSize.x
		ScrollThumbFrame.Position = UDim2.new(GetScrollPercent()*(bar_size - ScrollThumbFrame.AbsoluteSize.x)/bar_size,0,0,0)
	end
	or function()
		ScrollThumbFrame.Size = UDim2.new(0,size,Class.VisibleSpace/Class.TotalSpace,0)
		if ScrollThumbFrame.AbsoluteSize.y < size then
			ScrollThumbFrame.Size = UDim2.new(0,size,0,size)
		end
		local bar_size = ScrollBarFrame.AbsoluteSize.y
		ScrollThumbFrame.Position = UDim2.new(0,0,GetScrollPercent()*(bar_size - ScrollThumbFrame.AbsoluteSize.y)/bar_size,0)
	end

	local function Update()
		local t = Class.TotalSpace
		local v = Class.VisibleSpace
		local s = Class.ScrollIndex
		if v <= t then
			if s > 0 then
				if s + v > t then
					Class.ScrollIndex = t - v
				end
			else
				Class.ScrollIndex = 0
			end
		else
			Class.ScrollIndex = 0
		end

		Class.UpdateCallback()

		local down = CanScrollDown()
		local up = CanScrollUp()
		if down ~= last_down then
			last_down = down
			ScrollDownFrame.Active = down
			ScrollDownFrame.AutoButtonColor = down
			ScrollDownGraphic.Stylist.SetGroup(down and ScrollStyle or ScrollStyle_ds)
			ScrollDownFrame.BackgroundTransparency = down and 0.5 or 0.7
		end
		if up ~= last_up then
			last_up = up
			ScrollUpFrame.Active = up
			ScrollUpFrame.AutoButtonColor = up
			ScrollUpGraphic.Stylist.SetGroup(up and ScrollStyle or ScrollStyle_ds)
			ScrollUpFrame.BackgroundTransparency = up and 0.5 or 0.7
		end
		ScrollThumbFrame.Visible = down or up
		UpdateScrollThumb()
	end
	Class.Update = Update

	local function ScrollDown()
		Class.ScrollIndex = Class.ScrollIndex + Class.PageIncrement
		Update()
	end
	Class.ScrollDown = ScrollDown
	Class.ScrollRight = ScrollDown

	local function ScrollUp()
		Class.ScrollIndex = Class.ScrollIndex - Class.PageIncrement
		Update()
	end
	Class.ScrollUp = ScrollUp
	Class.ScrollLeft = ScrollUp

	local function ScrollTo(index)
		Class.ScrollIndex = index
		Update()
	end
	Class.ScrollTo = ScrollTo

	local function SetScrollPercent(percent)
		Class.ScrollIndex = math.floor((Class.TotalSpace - Class.VisibleSpace)*percent + 0.5)
		Update()
	end
	Class.SetScrollPercent = SetScrollPercent

	-- fixes AutoButtonColor
	local function ResetButtonColor(button)
		local active = button.Active
		button.Active = not active
		button.Active = active
	end

	SetZIndexOnChanged(ScrollFrame)

	local scroll_event_id = 0
	ScrollDownFrame.MouseButton1Down:connect(function()
		scroll_event_id = tick()
		local current = scroll_event_id
		local up_con
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollDownFrame)
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
		ScrollDown()
		wait(0.2) -- delay before auto scroll
		while scroll_event_id == current do
			ScrollDown()
			if not CanScrollDown() then break end
			wait()
		end
	end)

	ScrollDownFrame.MouseButton1Up:connect(function()
		scroll_event_id = tick()
	end)

	ScrollUpFrame.MouseButton1Down:connect(function()
		scroll_event_id = tick()
		local current = scroll_event_id
		local up_con
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollUpFrame)
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
		ScrollUp()
		wait(0.2)
		while scroll_event_id == current do
			ScrollUp()
			if not CanScrollUp() then break end
			wait()
		end
	end)

	ScrollUpFrame.MouseButton1Up:connect(function()
		scroll_event_id = tick()
	end)

	ScrollBarFrame.MouseButton1Down:connect(horizontal
	and function(x,y)
		scroll_event_id = tick()
		local current = scroll_event_id
		local up_con
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollUpFrame)
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
		if x > ScrollThumbFrame.AbsolutePosition.x then
			ScrollTo(Class.ScrollIndex + Class.VisibleSpace)
			wait(0.2)
			while scroll_event_id == current do
				if x < ScrollThumbFrame.AbsolutePosition.x + ScrollThumbFrame.AbsoluteSize.x then break end
				ScrollTo(Class.ScrollIndex + Class.VisibleSpace)
				wait()
			end
		else
			ScrollTo(Class.ScrollIndex - Class.VisibleSpace)
			wait(0.2)
			while scroll_event_id == current do
				if x > ScrollThumbFrame.AbsolutePosition.x then break end
				ScrollTo(Class.ScrollIndex - Class.VisibleSpace)
				wait()
			end
		end
	end
	or function(x,y)
		scroll_event_id = tick()
		local current = scroll_event_id
		local up_con
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollUpFrame)
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
		if y > ScrollThumbFrame.AbsolutePosition.y then
			ScrollTo(Class.ScrollIndex + Class.VisibleSpace)
			wait(0.2)
			while scroll_event_id == current do
				if y < ScrollThumbFrame.AbsolutePosition.y + ScrollThumbFrame.AbsoluteSize.y then break end
				ScrollTo(Class.ScrollIndex + Class.VisibleSpace)
				wait()
			end
		else
			ScrollTo(Class.ScrollIndex - Class.VisibleSpace)
			wait(0.2)
			while scroll_event_id == current do
				if y > ScrollThumbFrame.AbsolutePosition.y then break end
				ScrollTo(Class.ScrollIndex - Class.VisibleSpace)
				wait()
			end
		end
	end)

	ScrollThumbFrame.MouseButton1Down:connect(horizontal
	and function(x,y)
		scroll_event_id = tick()
		local mouse_offset = x - ScrollThumbFrame.AbsolutePosition.x
		local drag_con
		local up_con
		drag_con = MouseDrag.MouseMoved:connect(function(x,y)
			local bar_abs_pos = ScrollBarFrame.AbsolutePosition.x
			local bar_drag = ScrollBarFrame.AbsoluteSize.x - ScrollThumbFrame.AbsoluteSize.x
			local bar_abs_one = bar_abs_pos + bar_drag
			x = x - mouse_offset
			x = x < bar_abs_pos and bar_abs_pos or x > bar_abs_one and bar_abs_one or x
			x = x - bar_abs_pos
			SetScrollPercent(x/(bar_drag))
		end)
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollThumbFrame)
			drag_con:disconnect(); drag_con = nil
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
	end
	or function(x,y)
		scroll_event_id = tick()
		local mouse_offset = y - ScrollThumbFrame.AbsolutePosition.y
		local drag_con
		local up_con
		drag_con = MouseDrag.MouseMoved:connect(function(x,y)
			local bar_abs_pos = ScrollBarFrame.AbsolutePosition.y
			local bar_drag = ScrollBarFrame.AbsoluteSize.y - ScrollThumbFrame.AbsoluteSize.y
			local bar_abs_one = bar_abs_pos + bar_drag
			y = y - mouse_offset
			y = y < bar_abs_pos and bar_abs_pos or y > bar_abs_one and bar_abs_one or y
			y = y - bar_abs_pos
			SetScrollPercent(y/(bar_drag))
		end)
		up_con = MouseDrag.MouseButton1Up:connect(function()
			scroll_event_id = tick()
			MouseDrag.Parent = nil
			ResetButtonColor(ScrollThumbFrame)
			drag_con:disconnect(); drag_con = nil
			up_con:disconnect(); drag = nil
		end)
		MouseDrag.Parent = GetScreen(ScrollFrame)
	end)

	Update()

	return Class,ScrollFrame
end

lib.ScrollBar = CreateScrollBar

--[[DEPEND:
GetPadding.lua;
]]

doc["StackingFrame"] = [==[
StackingFrame ( GuiObject `frame`, bool `horizontal`, bool `alignment` )
	returns: table `class`, Frame `stacking_frame`

Creates a frame that automatically resizes based on the objects it contains.
These objects are automatically positioned to stack next to each other.
Objects that have their Visible property set to false become ignored.

Arguments:
	`frame`
		If specified, then it will be used as the StackingFrame.
		Children that exist in this object beforehand will be added to the StackingFrame automatically. 
		Use the AddObject function to add children afterwards.
		Optional; defaults to a new Frame.
	`horizontal`
		If true, objects will be positioned horizontally instead of vertically.
		Optional; defaults to false
	`alignment`
		If true, objects will be aligned to the right if vertical (else left), or the bottom if horizontal (else top).
		Optional; defaults to false

Returns:
	`class`
		Contains the following values:
		GUI
			The stacking frame itself.

		List
			The table containing the objects in the stacking frame.
			Should only be used for ordering items! Use AddObject and RemoveObject accordingly!

		AddObject ( GuiObject `object`, number `index` )
			Adds `object` to the list.
			If `index` is specified, the object is added at that position in the list.
			Otherwise, it is added to the end.

		RemoveObject ( number `index` )
			Removes the object at `index` in the list.
			If `index` is not specified, then the last object is removed.
			`index` can also be an object in the list.

		MoveObject ( number `index`, number `to` )
			Moves the object at `index` to the new index `to`.
			`index` and `to` can also be objects in the list.

		GetIndex ( Instance `object` )
			Returns the index of `object` in the stacking frame, if it exists there.

		SetPadding ( number `padding`, number `border` )
			Sets the amount of space between and around children, in pixels.
			`padding` is the amount of space between each child.
			`border` is the amount of space around all children.
		Update ( )
			Updates the object.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`stacking_frame`
		The stacking frame itself.
]==]

local function CreateStackingFrame(Frame,horizontal,alignment)
	Frame = Frame or Instance.new("Frame")
	local children = {}
	local connections = {}
	local border = 0
	local padding = 0
	local style_pad = 0
	local event_id = 0
	local Update

	if horizontal then
		if alignment then
			Update = function()
				event_id = event_id + 1; local eid = event_id
				local height = 0
				local length = 0
				for i,child in pairs(children) do
					if event_id ~= eid then return end
					if child.Visible then
						local abs = child.AbsoluteSize
						child.Position = UDim2.new(0,length + border,1,-abs.y - border)
						height = abs.y > height and abs.y or height
						length = length + abs.x + padding
					end
				end
				if event_id ~= eid then return end
				if #children > 0 then
					Frame.Size = UDim2.new(0,length - padding + border*2 + style_pad,0,height + border*2 + style_pad)
				else
					Frame.Size = UDim2.new(0,border*2 + style_pad,0,border*2 + style_pad)
				end
			end
		else
			Update = function()
				event_id = event_id + 1; local eid = event_id
				local height = 0
				local length = 0
				for i,child in pairs(children) do
					if event_id ~= eid then return end
					if child.Visible then
						local abs = child.AbsoluteSize
						child.Position = UDim2.new(0,length + border,0,border)
						height = abs.y > height and abs.y or height
						length = length + abs.x + padding
					end
				end
				if event_id ~= eid then return end
				if #children > 0 then
					Frame.Size = UDim2.new(0,length - padding + border*2 + style_pad,0,height + border*2 + style_pad)
				else
					Frame.Size = UDim2.new(0,border*2 + style_pad,0,border*2 + style_pad)
				end
			end
		end
	else
		if alignment then
			Update = function()
				event_id = event_id + 1; local eid = event_id
				local width = 0
				local length = 0
				for i,child in pairs(children) do
					if event_id ~= eid then return end
					if child.Visible then
						local abs = child.AbsoluteSize
						child.Position = UDim2.new(1,-abs.x - border,0,length + border)
						width = abs.x > width and abs.x or width
						length = length + abs.y + padding
					end
				end
				if event_id ~= eid then return end
				if #children > 0 then
					Frame.Size = UDim2.new(0,width + border*2 + style_pad,0,length - padding + border*2 + style_pad)
				else
					Frame.Size = UDim2.new(0,border*2 + style_pad,0,border*2 + style_pad)
				end
			end
		else
			Update = function()
				event_id = event_id + 1; local eid = event_id
				local width = 0
				local length = 0
				for i,child in pairs(children) do
					if event_id ~= eid then return end
					if child.Visible then
						local abs = child.AbsoluteSize
						child.Position = UDim2.new(0,border,0,length + border)
						width = abs.x > width and abs.x or width
						length = length + abs.y + padding
					end
				end
				if event_id ~= eid then return end
				if #children > 0 then
					Frame.Size = UDim2.new(0,width + border*2 + style_pad,0,length - padding + border*2 + style_pad)
				else
					Frame.Size = UDim2.new(0,border*2 + style_pad,0,border*2 + style_pad)
				end
			end
		end
	end

	local function SetPadding(pad,bor)
		padding = pad or padding
		border = bor or border
		Update()
	end

	local function AddObject(object,index)
		if object:IsA"GuiObject" then
			if index then
				table.insert(children,index,object)
			else
				table.insert(children,object)
			end
			connections[object] = object.Changed:connect(function(p)
				if p == "AbsoluteSize" or p == "Visible" then
					Update()
				end
			end)
			object.Parent = Frame
			Update()
		end
	end

	local function RemoveObject(index)
		if type(index) == "number" then
			index = ClampIndex(children,index)
		else
			if index == nil then
				index = #children
			else
				index = GetIndex(children,index)
			end
		end
		if index then
			local object = table.remove(children,index)
			if connections[object] then
				connections[object]:disconnect()
				connections[object] = nil
			end
			object.Parent = nil
			Update()
			return object
		end
	end

	local function MoveObject(index,to)
		if type(index) ~= "number" then
			index = GetIndex(children,index)
		end
		if type(to) ~= "number" then
			to = GetIndex(children,to)
		end
		if index and to then
			index = ClampIndex(children,index)
			to = ClampIndex(children,to)
			local child = table.remove(children,index)
			table.insert(children,to,child)
			Update()
		end
	end

	local Class = {
		GUI = Frame;
		List = children;
		Update = Update;
		SetPadding = SetPadding;
		AddObject = AddObject;
		RemoveObject = RemoveObject;
		MoveObject = MoveObject;
		GetIndex = function(object)
			return GetIndex(children,object)
		end;
	}

	local function Destroy()
		for i,v in pairs(children) do
			if connections[v] then
				connections[v]:disconnect()
				connections[v] = nil
			end
			v.Parent = nil
			children[i] = nil
		end
		for i,con in pairs(connections) do
			con:disconnect()
			connections[i] = nil
		end
		for k in pairs(Class) do
			Class[k] = nil
		end
		Frame:Destroy()
	end
	Class.Destroy = Destroy

	for i,child in pairs(Frame:GetChildren()) do
		AddObject(child,i)
	end

	Update()

	Frame.Changed:connect(function(p)
		if p == "AbsoluteSize" or p == "Style" then
			local old = style_pad
			style_pad = GetPadding(Frame)*2
			if style_pad ~= old then
				Update()
			end
		end
	end)

	return Class,Frame
end

lib.StackingFrame = CreateStackingFrame

--[[DEPEND:
ScrollBar.lua;
]]

doc["ScrollingList"] = [==[
ScrollingList ( table `list`, number `entry_height` )
	returns: table `class`, Frame `scrolling_frame`

Creates a scrollable list designed to display a large number of items.

Arguments:
	`list`
		Contains the items to display in the list.
		Items will be converted to a string before being displayed, so this may contain any type of value.
		Optional; defaults to an empty table
	`entry_height`
		Specifies the height, in pixels, of each displayed entry.
		Optional; defaults to ]==]..ENTRY_SIZE..[==[

Returns:
	`class`
		Contains the following values:
		List
			The `list` table.

		GUI
			The scrolling list itself.

		Scroll
			A class for the list's scroll bar.

		EntryStylist
			A stylist containing every displayed entry.

		AddEntry ( * `item`, number `index` )
			Add an entry to the list and updates automatically.
			`item` is the value to add to the list.
			If `index` is specified, `item` will be added to the list at `index`.
			Otherwise, it will be added to the end.

		AddEntries ( table `items`, number `index` )
			Adds a group of entries to the list.
			`items` is a table of values that will be added to the list.
			If `index` is specified, the items will be inserted into the list starting at `index.
			Otherwise, they will be added to the end.

		RemoveEntry ( * `item` )
			Removes the first occurance of `item` in the list.
			If `item` is a number, the item at that index in the list will be removed.
			If `item` is not specified, then the list item in the list will be removed.

		Update ( )
			Updates the display to reflect the list.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`scrolling_frame`
		The scrolling list itself.
]==]

local function CreateScrollingList(List,entryHeight)
	List = List or {}
	entryHeight = entryHeight or ENTRY_SIZE

	local ScrollingListFrame = Instance.new("Frame")
	ScrollingListFrame.Size = UDim2.new(0,300,0,200)
	ScrollingListFrame.Style = Enum.FrameStyle.RobloxRound
	ScrollingListFrame.Active = true
	ScrollingListFrame.Name = "ScrollingListFrame"

	local ListViewFrame = Instance.new("Frame",ScrollingListFrame)
	ListViewFrame.Name = "ListViewFrame"
	ListViewFrame.BackgroundTransparency = 1
	ListViewFrame.Size = UDim2.new(1,-entryHeight,1,0)

	local EntryStylist = CreateStylist{
		Name = "ListEntry";
		Font = "ArialBold";
		FontSize = "Size14";
		TextColor3 = Color3.new(1,1,1);
		BackgroundTransparency = 1;
		TextXAlignment = "Left";
	}
	local EntryTemplate = Instance.new("TextLabel")

	local EntryFrames = {}

	local Scroll,ScrollBarFrame = CreateScrollBar(false,entryHeight)
	ScrollBarFrame.Size = UDim2.new(0,entryHeight,1,0)
	ScrollBarFrame.Position = UDim2.new(1,-entryHeight,0,0)
	ScrollBarFrame.Parent = ScrollingListFrame

	local Update = Scroll.Update

	local Class = {
		List = List;
		GUI = ScrollingListFrame;
		Scroll = Scroll;
		Update = Update;
		EntryStylist = EntryStylist;
	}

	Scroll.UpdateCallback = function()
		local visible_space = Scroll.VisibleSpace
		-- update current entries
		for i = 1,visible_space do
			local item = List[i + Scroll.ScrollIndex]
			if item then
				local entry = EntryFrames[i]
				if not entry then
					entry = EntryTemplate:Clone()
					EntryStylist.AddObject(entry)
					EntryFrames[i] = entry
					entry.Parent = ListViewFrame
					entry.ZIndex = ScrollingListFrame.ZIndex
				end
				entry.Text = tostring(item)
				entry.Position = UDim2.new(0,0,0,(i-1)*entryHeight)
				entry.Size = UDim2.new(1,0,0,entryHeight)
			else
				local entry = EntryFrames[i]
				if entry then
					EntryStylist.RemoveObject(entry)
					entry:Destroy()
					EntryFrames[i] = nil
				end
			end
		end
		-- remove extra entries (occurs only when #EntryFrames > VisibleSpace)
		for i = Scroll.VisibleSpace+1,#EntryFrames do
			local entry = EntryFrames[i]
			if entry then
				EntryStylist.RemoveObject(entry)
				entry:Destroy()
			end
			EntryFrames[i] = nil
		end
	end

	-- add an item to the list; optional list index
	local function AddEntry(item,index)
		if index then
			table.insert(List,index,item)
		else
			table.insert(List,item)
		end
		Scroll.TotalSpace = #List
		Update()
	end
	Class.AddEntry = AddEntry

	-- add multiple items to list
	local function AddEntries(items,index)
		if index then
			for i = 1,#items do
				table.insert(List,index+i-1,items[i])
			end
		else
			for i = 1,#items do
				table.insert(List,items[i])
			end
		end
		Scroll.TotalSpace = #List
		Update()
	end
	Class.AddEntries = AddEntries

	-- remove entry from list; may be a list index or an item in the list
	local function RemoveEntry(item)
		if type(item) == "number" or type(item) == "nil" then
			table.remove(List,item)
		else
			for i,v in pairs(List) do
				if v == item then
					table.remove(List,i)
					break
				end
			end
		end
		Scroll.TotalSpace = #List
		Update()
	end
	Class.RemoveEntry = RemoveEntry

	SetZIndexOnChanged(ScrollingListFrame)

	ListViewFrame.Changed:connect(function(p)
		if p == "AbsoluteSize" then
			Scroll.VisibleSpace = math.floor(ListViewFrame.AbsoluteSize.y/entryHeight)
			Update()
		end
	end)

	function Class.Destroy()
		for i in pairs(Class) do
			Class[i] = nil
		end
		for i,v in pairs(EntryFrames) do
			v:Destroy()
			EntryFrames[i] = nil
		end
		EntryStylist.Destroy()
		Scroll.Destroy()
		ScrollingListFrame:Destroy()
	end

	return Class,ScrollingListFrame
end

lib.ScrollingList = CreateScrollingList

--[[DEPEND:
ScrollBar.lua;
]]

doc["ScrollingContainer"] = [==[
ScrollingContainer ( bool `v_scroll_bar`, bool `h_scroll_bar`, number `scroll_width` )
	returns: table `class`, Frame `scrolling_container`

Creates a container that can be scrolled with one or more scroll bars.
The scroll bars update dynamically based on the size of the boundary and container.
Objects in the container are automatically clipped to display only within the boundary.

Arguments:
	`v_scroll_bar`
		Indicates whether the container should have a vertical scroll bar.
		Optional; defaults to true
	`h_scroll_bar`
		Indicates whether the container should have a horizontal scroll bar.
		Optional; defaults to false
	`scroll_width`
		Indicates the width the scrollbar(s).
		Optional; defaults to ]==]..ENTRY_SIZE..[==[

Returns:
	`class`
		Contains the following values:
		Boundary
			A Frame that represents the visible area, clipping off any overflowing content.

		Container
			A Frame that will contain other items to be displayed in the scrolling container.

		GUI
			The scrolling container itself.

		HScroll
			The horizontal scroll bar class (if available).

		VScroll
			The vertical scroll bar class (if available).

		Update ( )
			Updates the scroll bar (or both, if present).

	`scrolling_container`
		The scrolling container itself.
]==]

local function CreateScrollingContainer(v_scroll,h_scroll,scroll_width)
	if v_scroll == nil then v_scroll = true end
	scroll_width = scroll_width or ENTRY_SIZE

	local ParentFrame = Create'Frame'{
		Name = "ScrollingContainer";
		Size = UDim2.new(0,300,0,200);
		BackgroundTransparency = 1;
	}

	local Boundary = Create'Frame'{
		Name = "Boundary";
		BackgroundColor3 = Color3.new(0,0,0);
		BorderColor3 = Color3.new(1,1,1);
		ClipsDescendants = true;
		Parent = ParentFrame;
	}

	local Container = Create'Frame'{
		Name = "Container";
		BackgroundTransparency = 1;
		Parent = Boundary;
	}

	local Class = {
		GUI = ParentFrame;
		Boundary = Boundary;
		Container = Container;
	}

	if v_scroll and h_scroll then
		local VScroll = CreateScrollBar(false,scroll_width)
		VScroll.PageIncrement = scroll_width
		VScroll.GUI.Position = UDim2.new(1,-scroll_width,0,0)
		VScroll.GUI.Size = UDim2.new(0,scroll_width,1,-scroll_width)
		VScroll.GUI.Parent = ParentFrame
		local VUpdate = VScroll.Update
		VScroll.UpdateCallback = function()
			Container.Position = UDim2.new(0,Container.Position.X.Offset,0,-VScroll.ScrollIndex)
		end

		local HScroll = CreateScrollBar(true,scroll_width)
		HScroll.PageIncrement = scroll_width
		HScroll.GUI.Position = UDim2.new(0,0,1,-scroll_width)
		HScroll.GUI.Size = UDim2.new(1,-scroll_width,0,scroll_width)
		HScroll.GUI.Parent = ParentFrame
		local HUpdate = HScroll.Update
		HScroll.UpdateCallback = function()
			Container.Position = UDim2.new(0,-HScroll.ScrollIndex,0,Container.Position.Y.Offset)
		end

		Boundary.Size = UDim2.new(1,-scroll_width,1,-scroll_width)

		local function Update()
			VUpdate()
			HUpdate()
		end

		local function SizeChanged(p)
			if p == "AbsoluteSize" then
				VScroll.TotalSpace = Container.AbsoluteSize.y
				VScroll.VisibleSpace = Boundary.AbsoluteSize.y
				HScroll.TotalSpace = Container.AbsoluteSize.x
				HScroll.VisibleSpace = Boundary.AbsoluteSize.x
				Update()
			end
		end
		Boundary.Changed:connect(SizeChanged)
		Container.Changed:connect(SizeChanged)
		Class.VScroll = VScroll
		Class.HScroll = HScroll
		Class.Update = Update
		SizeChanged("AbsoluteSize")
		Update()
	elseif v_scroll then
		local Scroll = CreateScrollBar(false,scroll_width)
		Scroll.PageIncrement = scroll_width
		Scroll.GUI.Position = UDim2.new(1,-scroll_width,0,0)
		Scroll.GUI.Size = UDim2.new(0,scroll_width,1,0)
		Scroll.GUI.Parent = ParentFrame
		local Update = Scroll.Update
		Scroll.UpdateCallback = function()
			Container.Position = UDim2.new(0,Container.Position.X.Offset,0,-Scroll.ScrollIndex)
		end
		local function SizeChanged(p)
			if p == "AbsoluteSize" then
				Scroll.TotalSpace = Container.AbsoluteSize.y
				Scroll.VisibleSpace = Boundary.AbsoluteSize.y
				Update()
			end
		end
		Boundary.Changed:connect(SizeChanged)
		Container.Changed:connect(SizeChanged)
		Class.VScroll = Scroll
		Class.Update = Update
		SizeChanged("AbsoluteSize")
		Update()
	elseif h_scroll then
		local Scroll = CreateScrollBar(true,scroll_width)
		Scroll.PageIncrement = scroll_width
		Scroll.GUI.Position = UDim2.new(0,0,1,-scroll_width)
		Scroll.GUI.Size = UDim2.new(1,0,0,scroll_width)
		Scroll.GUI.Parent = ParentFrame
		local Update = Scroll.Update
		Scroll.UpdateCallback = function()
			Container.Position = UDim2.new(0,-Scroll.ScrollIndex,0,Container.Position.Y.Offset)
		end
		local function SizeChanged(p)
			if p == "AbsoluteSize" then
				Scroll.TotalSpace = Container.AbsoluteSize.x
				Scroll.VisibleSpace = Boundary.AbsoluteSize.x
				Update()
			end
		end
		Boundary.Changed:connect(SizeChanged)
		Container.Changed:connect(SizeChanged)
		Class.HScroll = Scroll
		Class.Update = Update
		SizeChanged("AbsoluteSize")
		Update()
	end

	return Class,ParentFrame
end

lib.ScrollingContainer = CreateScrollingContainer

--[[DEPEND:
SetZIndex.lua;
Stylist.lua;
Graphic.lua;
ScrollBar.lua;
]]

doc["DetailedList"] = [==[
DetailedList ( table `row_data_list`, table `column_scheme`, number `row_height` )
	returns: table `class`, Frame `list_frame`

Creates a customizable list for displaying data.

Arguments:
	`row_data_list`
		Holds all the data to be displayed.
		It contains tables that hold data for each row in the list (see Row Data).
		Optional; defaults to an empty table.
	`column_scheme`
		Contains information for how each column will be displayed (see Column Scheme).
	`row_height`
		Sets the height of each row, in pixels.
		Optional; defaults to ]==]..ENTRY_SIZE..[==[

Returns:
	`class`
		Contains the following values:
		GUI
			The DetailedList itself.
		Data
			The `row_data_list` table.
		Scroll
			A class for the list's scroll bar.

		AddRow ( table `row_data`, number `index`, table `style` )
			Adds a new row to the list.
			`row_data` is the data to display in the row.
			If `index` is specified, then the row will be added to that place in the list, instead of the end.
			If `style` is specified, then the row's Stylist will be created with it.
			Returns the row's data table.

		RemoveRow ( number `index` )
			Removes a row from the list.
			`index` may be a numerical index in the list, or a row data table in the list.
			Returns the removed row's data table.

		UpdateRow ( number `index` )
			Updates the specified row to reflect the data in `row_data_list`
			`index` may be a numerical index in the list, or a row data table in the list.

		Stylist
			A table that contains Stylist classes for controlling the appearance of the DetailedList.
			It contains the following values:
				Global: Every object in the DetailedList
				Cell: Every cell in list
				Header: Each cell the top (header) row of the list.
				RowSpan: Each cell container of each row.
				Rows: A table that contains Stylists for each row in the list, referenced by the row's data table.
				Columns: A table that contains Stylists for each column in the list.

		Update ( )
			Updates the display.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`list_frame`
		The DetailedList itself.


Column Scheme:
	The column scheme is a list of tables, each representing a column that will appear in the DetailedList.
	Each of these tables contain the following entries:
		["type"] = (string)
			Indicates the data type of the column.
			More entries may be required depending on the type (see Column Scheme Types).
		["name"] = (string)
			The name of the column. This will appear in the header at the top.
		["width"] = (UDim)
			The width of the column.
		["style"] = (table)
			Optional. Defines a custom style for the column.
			If defined, then it will become the corresponding stylist in `class`.Stylist.Columns.


Row Data:
	A row data table holds the data for each cell of a row.
	Each entry corresponds to each cell in the row.
	Their types should match up with the column scheme (see Column Scheme Types).

	Example (for scheme {"check-box", "image", "text"}):
		row_data_list = {
			{true, "flower.png", "Flowers"};
			{false, "beehive.png", "Bees"};
		}


Column Scheme Types:
	Here are the possible data types, and their extra entries:
		text
			Row Data: string
				The text to display in the cell.
			Entries: none
		image
			Row Data: string
				The Content string of the image to display in the cell.
			Entries: none
		text-button
			Row Data: string
				The text to display in the cell.
			Entries:
				["callback"] = function (table `row_data`, table `class`)
					Called when the button is clicked.
					`row_data` is the button's row data.
					`class` is the DetailedList class.
		image-button
			Row Data: string
				The Content string of the image to display in the cell.
			Entries:
				["callback"] = function (table `row_data`, table `class`)
					Called when the button is clicked.
					`row_data` is the button's row data.
					`class` is the DetailedList class.
		text-field (BUGGY)
			Row Data: string
				The value displayed in the text field.
			Entries:
				["callback"] = function (string `text`, table `row_data`, table `class`)
					Called when the field's text changes.
					`text` is the field's current text.
					`row_data` is the field's row data.
					`class` is the DetailedList class.
					This function should return a string (usually `text`).
					If nil or false is returned, then the field will be reverted to the text before the change.
		check-box
			Row Data: bool
				The state of the check box.
			Entries:
				["checked"] = string, table
					The image (Content string) to display when the box is checked.
					If a table, its entries are the arguments to make a new Graphic.
				["unchecked"] = string, table
					The image (Content string) to display when the box is unchecked.
					If a table, its entries are the arguments to make a new Graphic.
				["callback"] = function (table `row_data`, table `class`)
					Called when the check box is clicked.
					`row_data` is the button's row data.
					`class` is the DetailedList class.
					This function should return a bool, indicating if the check box should toggle its state.
		drop-list (NOT IMPLEMENTED)
			Row Data: string
				The value displayed in the drop list.
			Entries:
				["items"] = table
					A list of items to appear in the drop list.


Stylists:
	These stylists will let you easily control the appearance of the DetailedList.
	Because many objects are apart of multiple stylists, certain stylists will override others when updated.
	The following tree shows the precedence of each stylist:

	Global
		Header
		Cell
			Columns
				Header
			Rows
		RowSpan

	For example, if the Column stylist is updated, then the Header and Cell stylists will automatically update afterwards.
]==]

--[==[EXCLUDE:
detailed list notes

	updating will take much more processing, due to amount of info per row
	there aren't going to be millions of rows
	so, go back to having frames for each row
	but, still use row indexing
	on update, stop displaying displayed rows, query new rows, display them

	row frames in the RowFramesList table are referenced by data rows in the RowDataList table

	PANIC: columns have a fixed width
	when updating, resize each cell width using one of the following options:
	->	basic: columns have fixed, perminent width, defined by column scheme, calculated once on row addition
		detailed view-like: columns have fixed width regardless of row content, recalculated when column tab is resized
		table-like: each column width is recalculated based on its content, when a row is added/removed (expensive)

	entry scheme:
		a table that describes an entry to the list
		keys are sequential, describing a part of the entry

		Entry Data:
			For a cell type, the acceptable entry data type is defined below.
			If the entry is a table instead, the first value in that table is the original data,
			while other keys defined will set the corresponding property of the cell.
			Example:
				As Data Type:	"A string"
				As Table:		{"A string", TextColor3 = Color3.new(1,0,0)}
		Types:
		Column Scheme Definition:											Entry Data:
		{"text"};															string
		{"image"};															string
		{"text-button", callback = function};								string
		{"image-button", callback = function};								string
		{"text-field", callback = function};								string
		{"check-box", checked = string, unchecked = string, callback};		bool
		{"drop-list", items = table};										string

		Each scheme has a 'name' key (string) and a 'width' key (UDim), which define he name and width of the column
		Each scheme can also have a 'style' key, who's value is a table that defines properties for each cell as columns
]==]

local function CreateDetailedList(RowDataList,ColumnScheme,rowHeight)
	RowDataList = RowDataList or {}
	rowHeight = rowHeight or ENTRY_SIZE
	local viewHeight = 0
	local numRows = math.floor(viewHeight/rowHeight)
	local scrollIndex = 0

	local RowFramesList = {}	-- holds a list of frames associated with RowDataList entries. This list is independent of RowDataList, and may be resorted
	local RowFrameLookup = {}	-- [data]=frame references
	local RowDataLookup = {}	-- [frame]=data references; it would be nice if this didn't have to exist
	local DisplayedRows = {}	-- a list of currently displayed row frames
	local CellMetadata = {}		-- extra data associated with a cell

	local DetailedListFrame = Create'Frame'{
		Size = UDim2.new(0,300,0,200);
		BackgroundTransparency = 1;
		Create'Frame'{
			Name = "ListViewFrame";
			BackgroundTransparency = 1;
			Size = UDim2.new(1,-rowHeight,1,-rowHeight);
			Position = UDim2.new(0,0,0,rowHeight);
		};
		Create'Frame'{
			Name = "ColumnHeaderFrame";
			BackgroundTransparency = 1;
			Size = UDim2.new(1,-rowHeight,0,rowHeight);
			Position = UDim2.new(0,0,0,0);
		};
	}

	local ListViewFrame = DetailedListFrame.ListViewFrame
	local ColumnHeaderFrame = DetailedListFrame.ColumnHeaderFrame

---- Stylists
	local GlobalStylist = CreateStylist{		-- for all objects
		TextColor3			= Color3.new(1,1,1);
		TextXAlignment		= Enum.TextXAlignment.Center;
		TextYAlignment		= Enum.TextYAlignment.Center;
		TextTransparency	= 0;
		Font				= Enum.Font.ArialBold;
		FontSize			= Enum.FontSize.Size14;
	}
	local CellStylist = CreateStylist{		-- for all cells
		BackgroundColor3		= Color3.new(0,0,0);
		BorderColor3			= Color3.new(1,1,1);
		BorderSizePixel			= 1;
		BackgroundTransparency	= 0.7;
	}
	local HeaderStylist = CreateStylist{		-- for all column headers
		TextColor3				= Color3.new(1,1,1);
		TextTransparency		= 0;
		BackgroundColor3		= Color3.new(1,1,1);
		BorderColor3			= Color3.new(1,1,1);
		BorderSizePixel			= 1;
		BackgroundTransparency	= 0.8;
	}
	local RowSpanStylist = CreateStylist{		-- for cell container of each row
		BackgroundTransparency	= 1;
	}
	local RowStylists = {}				-- list of stylists for each row
	local ColumnStylists = {}			-- list of stylists for each column

	GlobalStylist.AddOverride(HeaderStylist)
	GlobalStylist.AddOverride(RowSpanStylist)

	local Scroll,ScrollBarFrame = CreateScrollBar(false,rowHeight)
	Modify(ScrollBarFrame){
		Size = UDim2.new(0,rowHeight,1,-rowHeight);
		Position = UDim2.new(1,-rowHeight,0,rowHeight);
		Parent = DetailedListFrame;
	}

	local Update = Scroll.Update

---- DetailedList Class
	local Class = {
		Data = RowDataList;
		GUI = DetailedListFrame;
		Stylist = {
			Global = GlobalStylist;
			Cell = CellStylist;
			Header = HeaderStylist;
			RowSpan = RowSpanStylist;
			Rows = RowStylists;
			Columns = ColumnStylists;
		};
		Update = Update;
	}

	-- update row display
	local event_id = 0
	Scroll.UpdateCallback = function()
		event_id = event_id + 1
		local current_id = event_id
		-- stop displaying previous rows
		for i,row in pairs(DisplayedRows) do
			if event_id ~= current_id then return end
			row.Visible = false
			DisplayedRows[i] = nil
		end
		-- query and display current rows
		for i = 1,Scroll.VisibleSpace do
			if event_id ~= current_id then return end
			local row = RowFramesList[i + Scroll.ScrollIndex]
			if row then
				DisplayedRows[#DisplayedRows+1] = row
				row.Position = UDim2.new(0,0,0,(i-1)*rowHeight)
				row.Size = UDim2.new(1,0,0,rowHeight)
				row.Visible = true
			end
		end
	end

	ListViewFrame.Changed:connect(function(p)
		if p == "AbsoluteSize" then
			Scroll.VisibleSpace = math.floor(ListViewFrame.AbsoluteSize.y/rowHeight)
			Update()
		end
	end)

---- Row Sorting
	local SortGraphic = Create'Frame'{
		Name = "SortGraphic";
		BackgroundTransparency = 1;
		Size = UDim2.new(0,rowHeight,0,rowHeight);
		Position = UDim2.new(1,-rowHeight*0.75,0.5,-rowHeight/8);
	}
	local GraphicTextAlias = {["TextColor3"]="BackgroundColor3";["TextTransparency"]="BackgroundTransparency"}

	local SortUpG,SortUp = CreateGraphic("arrow-up",Vector2.new(rowHeight,rowHeight))
	GlobalStylist.AddStylist(SortUpG.Stylist,GraphicTextAlias)
	SortUp.Visible = false
	SortUp.Parent = SortGraphic

	local SortDownG,SortDown = CreateGraphic("arrow-down",Vector2.new(rowHeight,rowHeight))
	GlobalStylist.AddStylist(SortDownG.Stylist,GraphicTextAlias)
	SortDown.Visible = false
	SortDown.Parent = SortGraphic

	-- sets the direction (up or down) and parent (column header)
	local function SetSortGraphic(direction,parent)
		if parent then
			if parent.TextXAlignment == Enum.TextXAlignment.Right then
				SortGraphic.Position = UDim2.new(0,0,0,0)
			else
				SortGraphic.Position = UDim2.new(1,-rowHeight,0,0)
			end
		end
		if direction > 0 then
			SortUp.Visible = true
			SortDown.Visible = false
			if SortGraphic.ZIndex ~= parent.ZIndex then
				SetZIndex(SortGraphic,parent.ZIndex)
			end
			SortGraphic.Parent = parent
		elseif direction < 0 then
			SortUp.Visible = false
			SortDown.Visible = true
			if SortGraphic.ZIndex ~= parent.ZIndex then
				SetZIndex(SortGraphic,parent.ZIndex)
			end
			SortGraphic.Parent = parent
		else
			SortUp.Visible = false
			SortDown.Visible = false
			SortGraphic.Parent = nil
		end
	end

	-- sorts a column (at index) by a sort type (ascending/descending/none)
	-- will eventually be added to class
	local function SortColumn(index,sort_type)
		-- re-sort to original sorting
		for i,data in pairs(RowDataList) do
			RowFramesList[i] = RowFrameLookup[data]
		end
		local header = ColumnHeaderFrame:GetChildren()[index] -- eww
		SetSortGraphic(0)
		-- sort depending on type, if provided
		if sort_type == SORT.ASCENDING then
			table.sort(RowFramesList,function(a,b)
				local adata,bdata = RowDataLookup[a][index],RowDataLookup[b][index]
				-- a and b should always have the same type
				local t = type(adata)
				if t == "table" then
					adata,bdata = adata[1],bdata[1]
					t = type(adata)
				end
				if t == "boolean" then
					return tostring(adata) > tostring(bdata)
				elseif t == "number" or t == "string" then
					return adata < bdata
				else
					return tostring(adata) < tostring(bdata)
				end
			end)
			SetSortGraphic(1,header)
		elseif sort_type == SORT.DESCENDING then
			table.sort(RowFramesList,function(a,b)
				local adata,bdata = RowDataLookup[a][index],RowDataLookup[b][index]
				-- a and b should always have the same type
				local t = type(adata)
				if t == "table" then
					adata,bdata = adata[1],bdata[1]
					t = type(adata)
				end
				if t == "boolean" then
					return tostring(adata) < tostring(bdata)
				elseif t == "number" or t == "string" then
					return adata > bdata
				else
					return tostring(adata) > tostring(bdata)
				end
			end)
			local header = ColumnHeaderFrame:GetChildren()[index]
			SetSortGraphic(-1,header)
		end
		Update()
	end

---- Initialize column scheme
	local RowTemplate = Create'Frame'{
		Name = "Row";
		Visible = false;
	}

	-- appends a space character to aligned text as cheap padding
	local function SetText(frame,text)
		if text == nil then
			frame.Text = "";
		else
			text = tostring(text)
			if #text > 0 and frame.TextXAlignment ~= Enum.TextXAlignment.Center then
				if frame.TextXAlignment == Enum.TextXAlignment.Left then
					frame.Text = " " .. text
				elseif frame.TextXAlignment == Enum.TextXAlignment.Right then
					frame.Text = text .. " "
				end
			else
				frame.Text = text
			end
		end
	end

	-- used by check-box, which uses either an image or a Graphic.
	local function SetImageOrGraphic(cell,active)
		local md = CellMetadata[cell]
		local checked,unchecked = md.Checked,md.Unchecked
		if type(unchecked) == "string" then
			cell.Image = active and "" or unchecked
		elseif type(unchecked) == "table" then
			if active then
				unchecked.GUI.Parent = nil
			else
				if unchecked.GUI.ZIndex ~= cell.ZIndex then
					SetZIndex(unchecked.GUI,cell.ZIndex)
				end
				unchecked.GUI.Parent = cell
			end
		end
		if type(checked) == "string" then
			cell.Image = active and checked or ""
		elseif type(checked) == "table" then
			if active then
				if checked.GUI.ZIndex ~= cell.ZIndex then
					SetZIndex(checked.GUI,cell.ZIndex)
				end
				checked.GUI.Parent = cell
			else
				checked.GUI.Parent = nil
			end
		end
	end

	local current_sort_header = nil
	local current_sort_type = SORT.NONE

	-- generate a template for rows
	local ColumnHeaderPos = UDim.new()
	for i,cell_scheme in pairs(ColumnScheme) do
		ColumnStylists[i] = CreateStylist(cell_scheme.style or {})
		GlobalStylist.AddOverride(ColumnStylists[i])
		ColumnStylists[i].AddOverride(HeaderStylist)
		ColumnStylists[i].AddOverride(CellStylist)
		local cell_type = cell_scheme.type
		local template
		if cell_type == "text" then
			template = Instance.new("TextLabel",RowTemplate)
			template.Name = "Text"
		elseif cell_type == "image" then
			template = Instance.new("ImageLabel",RowTemplate)
			template.Name = "Image"
		elseif cell_type == "text-button" then
			template = Instance.new("TextButton",RowTemplate)
			template.Name = "TextButton"
		elseif cell_type == "image-button" then
			template = Instance.new("ImageButton",RowTemplate)
			template.Name = "ImageButton"
		elseif cell_type == "text-field" then
			template = Instance.new("TextBox",RowTemplate)
			template.Name = "TextField"
			template.ClearTextOnFocus = false
		elseif cell_type == "check-box" then
			template = Instance.new("ImageButton",RowTemplate)
			template.Name = "CheckBox"
		end

		-- create the header row
		local ColumnHeader = Create'TextButton'{
			Name = "ColumnHeader";
			Parent = ColumnHeaderFrame;
		}
		GlobalStylist.AddObject(ColumnHeader)
		ColumnStylists[i].AddObject(ColumnHeader)
		HeaderStylist.AddObject(ColumnHeader)
		SetText(ColumnHeader,cell_scheme.name)
		-- sort on click
		ColumnHeader.MouseButton1Click:connect(function()
			if current_sort_header == ColumnHeader then
				-- cycle between ascending, descending, and none
				if current_sort_type == SORT.ASCENDING then
					current_sort_type = SORT.DESCENDING
				elseif current_sort_type == SORT.DESCENDING then
					current_sort_type = SORT.NONE
				else
					current_sort_type = SORT.ASCENDING
				end
			else
				current_sort_type = SORT.ASCENDING
			end
			current_sort_header = ColumnHeader
			SortColumn(i,current_sort_type)
		end)
		local Width = cell_scheme.width
		ColumnHeader.Size = UDim2.new(Width.Scale,Width.Offset,1,0)
		ColumnHeader.Position = UDim2.new(ColumnHeaderPos.Scale,ColumnHeaderPos.Offset,0,0)
		ColumnHeaderPos = ColumnHeaderPos + Width
	end
	ColumnHeaderPos = nil

---- Class functions

	-- update the row frame to reflect the row data
	function Class.UpdateRow(index)
		local RowData
		if type(index) == "number" then
			RowData = RowDataList[index]
		else
			RowData = index
		end

		local Row = RowFrameLookup[RowData]
		local Cells = Row:GetChildren() -- eww
		local CellColPos = UDim.new()
		for i,cell_scheme in pairs(ColumnScheme) do
			local cell_type = cell_scheme.type
			local Cell = Cells[i]
			local CellData = RowData[i]
			local Width = cell_scheme.width
			if cell_type == "text" then
				SetText(Cell,CellData)
			elseif cell_type == "image" then
				Cell.Image = CellData
			elseif cell_type == "text-button" then
				SetText(Cell,CellData)
			elseif cell_type == "image-button" then
				Cell.Image = CellData
			elseif cell_type == "text-field" then
				SetText(Cell,CellData)
			elseif cell_type == "check-box" then
				SetImageOrGraphic(Cell,CellData)
			end
			Cell.Size = UDim2.new(Width.Scale,Width.Offset,1,0) -- this would be a lot easier if UDim2.new accepts UDims
			Cell.Position = UDim2.new(CellColPos.Scale,CellColPos.Offset,0,0)
			CellColPos = CellColPos + Width
		end
	end

	-- add a new row to the list; optional list index
	function Class.AddRow(RowData,index,style)
		-- TODO: verify that data matches column scheme
		local NewRow = RowTemplate:Clone()
		if index then
			index = index > #RowDataList+1 and #RowDataList+1 or index < 1 and 1 or index
			table.insert(RowDataList,index,RowData)
			table.insert(RowFramesList,index,NewRow)
		else
			table.insert(RowDataList,RowData)
			table.insert(RowFramesList,NewRow)
		end
		Scroll.TotalSpace = #RowDataList
		RowSpanStylist.AddObject(NewRow)
		NewRow.Size = UDim2.new(1,0,0,rowHeight)
		NewRow.ZIndex = DetailedListFrame.ZIndex
		NewRow.Parent = ListViewFrame
		local Cells = NewRow:GetChildren()
		local CellColPos = UDim.new()
		RowStylists[RowData] = CreateStylist(style or {})
		GlobalStylist.AddOverride(RowStylists[RowData])
		CellStylist.AddOverride(RowStylists[RowData])
		for i,cell_scheme in pairs(ColumnScheme) do
			local cell_type = cell_scheme.type
			local Cell = Cells[i]
			Cell.ZIndex = DetailedListFrame.ZIndex
			GlobalStylist.AddObject(Cell)
			ColumnStylists[i].AddObject(Cell)
			RowStylists[RowData].AddObject(Cell)
			CellStylist.AddObject(Cell)
			local CellData = RowData[i]
			local Width = cell_scheme.width
			if cell_type == "text" then
				SetText(Cell,CellData)
			elseif cell_type == "image" then
				Cell.Image = CellData
			elseif cell_type == "text-button" then
				SetText(Cell,CellData)
				Cell.MouseButton1Click:connect(function()
					cell_scheme.callback(RowData,Class)
				end)
			elseif cell_type == "image-button" then
				Cell.Image = CellData
				Cell.MouseButton1Click:connect(function()
					cell_scheme.callback(RowData,Class)
				end)
			elseif cell_type == "text-field" then
				SetText(Cell,CellData)
				local last_text = CellData
				local e = false
				Cell.Changed:connect(function(p)
					if e then return end
					if p == "Text" then
						e = true
						local text = cell_scheme.callback(Cell.Text,RowData,Class)
						if text then
							RowData[i] = text
							SetText(Cell,text)
							last_text = text
						else
							SetText(Cell,last_text)
						end
						e = false
					end
				end)
			elseif cell_type == "check-box" then
				CellMetadata[Cell] = {}
				if type(cell_scheme.checked) == "table" then
					local graphic = CreateGraphic(cell_scheme.checked[1],cell_scheme.checked[2])
					SetZIndex(graphic.GUI,DetailedListFrame.ZIndex)
					GlobalStylist.AddStylist(graphic.Stylist,GraphicTextAlias)
					CellMetadata[Cell].Checked = graphic
				else
					CellMetadata[Cell].Checked = cell_scheme.checked
				end
				if type(cell_scheme.unchecked) == "table" then
					local graphic = CreateGraphic(cell_scheme.unchecked[1],cell_scheme.unchecked[2])
					SetZIndex(graphic.GUI,DetailedListFrame.ZIndex)
					GlobalStylist.AddStylist(graphic.Stylist,GraphicTextAlias)
					CellMetadata[Cell].Unchecked = graphic
				else
					CellMetadata[Cell].Unchecked = cell_scheme.unchecked
				end
				SetImageOrGraphic(Cell,CellData)
				Cell.MouseButton1Click:connect(function()
					local continue = true
					if cell_scheme.callback then
						continue = cell_scheme.callback(RowData,Class)
					end
					if continue then
						RowData[i] = not RowData[i]
						SetImageOrGraphic(Cell,RowData[i])
					end
				end)
			end
			Cell.Size = UDim2.new(Width.Scale,Width.Offset,1,0) -- this would be a lot easier if UDim2.new accepts UDims
			Cell.Position = UDim2.new(CellColPos.Scale,CellColPos.Offset,0,0)
			CellColPos = CellColPos + Width
		end
		RowFrameLookup[RowData] = NewRow
		RowDataLookup[NewRow] = RowData
		Update()
		return RowData
	end

	-- remove entry from the list; may be a list index or an item in the list
	function Class.RemoveRow(index)
		local RowData
		if type(index) == "number" or type(index) == "nil" then
			RowData = table.remove(RowDataList,index)
		else
			for i,v in pairs(RowDataList) do
				if v == index then
					RowData = table.remove(RowDataList,i)
					break
				end
			end
		end
		if RowData then
			local stylist = RowStylists[RowData]
			GlobalStylist.RemoveOverride(stylist)
			stylist.Destroy()
			RowStylists[RowData] = nil

			local frame = RowFrameLookup[RowData]
			RowDataLookup[frame] = nil
			RowFrameLookup[RowData] = nil
			for i,rowframe in pairs(RowFramesList) do
				if rowframe == frame then
					for i,cell in pairs(rowframe:GetChildren()) do
						GlobalStylist.RemoveObject(cell)
						ColumnStylists[i].RemoveObject(cell)
						CellStylist.RemoveObject(cell)
					end
					table.remove(RowFramesList,i)
					break
				end
			end
			Scroll.TotalSpace = #RowDataList
			for i,rowframe in pairs(DisplayedRows) do
				if rowframe == frame then
					table.remove(DisplayedRows,i)
					break
				end
			end
			frame:Destroy()
		end
		Update()
		return RowData
	end

---- Finish

	-- when the list's Zindex changes, update the ZIndex of everything
	SetZIndexOnChanged(DetailedListFrame)

	-- attempts to free resources
	function Class.Destroy()
		local function empty_table(t)
			for k in pairs(t) do t[k] = nil end
		end
		empty_table(Class.Stylist)
		empty_table(Class)
		empty_table(RowFramesList)
		empty_table(RowFrameLookup)
		empty_table(RowDataLookup)
		empty_table(DisplayedRows)
		empty_table(CellMetadata)
		GlobalStylist.Destroy()
		CellStylist.Destroy()
		HeaderStylist.Destroy()
		RowSpanStylist.Destroy()
		for k,v in pairs(RowStylists) do
			v.Destroy()
			RowStylists[k] = nil
		end
		for k,v in pairs(ColumnStylists) do
			v.Destroy()
			ColumnStylists[k] = nil
		end
		Scroll.Destroy()
		RowTemplate:Destroy()
		DetailedListFrame:Destroy()
	end

	Class.Update()

	return Class,DetailedListFrame
end

lib.DetailedList = CreateDetailedList

--[[DEPEND:
SetZIndex.lua;
Stylist.lua;
AutoSizeLabel.lua;
StackingFrame.lua;
]]

doc["TabContainer"] = [==[
TabContainer ( table `content_list`, number `selected_height`, number `tab_height` )
	returns: table `class`, Frame `tab_container`

Creates a container that can hold multiple GuiObjects in a single space by using tabs.
A GuiObject added to the container gets its own tab, which shows the GuiObject's Name, and displays the GuiObject when clicked.

Arguments:
	`content_list`
		A list of GuiObjects to be initially added to the container.
		Optional; defaults to an empty table
	`selected_height`
		The height of a selected tab.
		Optional; defaults to 24
	`tab_height`
		The height, in pixels, of a tab that is not selected.
		Optional; defaults to 20

Returns:
	`class`
		Contains the following values:
		GUI
			The container itself.

		AddTab ( GuiObject `content`, number `index` )
			Adds `content` to the container at `index`.
			if `index` is not specified, then it will be added to the end.

		RemoveTab ( number `index` )
			Removes the tab at `index`, and returns the content of that tab.
			`index` can also be a GUI in the container.

		MoveTab ( number `index`, number `to` )
			Moves the object at `index` to the index of `to`.
			`index` and `to` can also be GUIs in the container.

		SelectTab ( number `index` )
			Selects the tab at `index`.
			`index` can also be a GUI in the container.

		GetIndex ( GuiObject `content` )
			Returns the index of `content`.
			If `content` isn't in the container, this returns nil.

		GetSelectedIndex ( )
			Returns the index of the selected tab, and its GUI.

		TabStylist
			A Stylist object that controls the appearance of unselected tabs.
			Also controls the appearance of the content border.

		SelectedTabStylist
			A Stylist object that controls the appearance of the selected tab.

		Destroy ( )
			Releases the resources used by this object.
			Run this if you're no longer using this object.

	`tab_container`
		The container itself.
]==]

local function CreateTabContainer(ContentList,SelectedTabHeight,TabHeight)
	SelectedTabHeight = SelectedTabHeight or 24
	TabHeight = TabHeight or 20

	local selected_index = 0
	local content_list = {}
	local tab_lookup = {}
	local con = {}

	local TabContainerFrame = Create'Frame'{
		Name = "TabContainer";
		Size = UDim2.new(0,300,0,200);
		BackgroundTransparency = 1;
		Create'Frame'{
			Name = "Content";
			Size = UDim2.new(1,0,1,-SelectedTabHeight);
			Position = UDim2.new(0,0,0,SelectedTabHeight);
			BackgroundColor3 = Color3.new();
			BorderColor3 = Color3.new(1,1,1);
		};
		Create'Frame'{
			Parent = TabContainerFrame;
			Name = "Tabs";
			BackgroundTransparency = 1;
		};
	}

	local TabContentFrame = TabContainerFrame.Content
	local TabHeaderFrame = TabContainerFrame.Tabs
	local TabHeaderClass = CreateStackingFrame(TabHeaderFrame,true,true)

	local TabStyle = {
		BackgroundColor3 = Color3.new();
		BackgroundTransparency = 0.5;
		BorderColor3 = Color3.new(1,1,1);
		TextColor3 = Color3.new(1,1,1);
		Font = "ArialBold";
		FontSize = "Size14";
	}
	local TabStylist = CreateStylist(TabStyle)
	TabStylist.AddObject(TabContentFrame)

	local SelectedTabStyle = {
		BackgroundColor3 = Color3.new();
		BackgroundTransparency = 0.5;
		BorderColor3 = Color3.new(1,1,1);
		TextColor3 = Color3.new(1,1,1);
		Font = "ArialBold";
		FontSize = "Size14";
	}
	local SelectedTabStylist = CreateStylist(SelectedTabStyle)

	local function GetIndex(content)
		for index,c in pairs(content_list) do
			if c == content then
				return index
			end
		end
	end

	local function GetSelectedIndex()
		return selected_index,content_list[selected_index]
	end

	local function ClampIndex(index,i)
		local max = #content_list + (i or 0)
		index = math.floor(index)
		return index < 1 and 1 or index > max and max or index
	end

	local function SelectTab(index)
		if #content_list > 0 then
			if type(index) ~= "number" then
				index = GetIndex(index)
			end
			if index then
				index = ClampIndex(index)
				if selected_index > 0 then
					local content = content_list[selected_index]
					content.Visible = false
					local Tab = tab_lookup[content]
					Tab.LockAxis(nil,TabHeight)
					SelectedTabStylist.RemoveObject(Tab, GUI)
					TabStylist.AddObject(Tab.GUI)
				end
				local content = content_list[index]
				content.Visible = true
				local Tab = tab_lookup[content]
				Tab.LockAxis(nil,SelectedTabHeight)
				TabStylist.RemoveObject(Tab.GUI)
				SelectedTabStylist.AddObject(Tab.GUI)
				selected_index = index
			end
		else
			selected_index = 0
		end
	end

	local function AddTab(content,index)
		if index then
			index = ClampIndex(index,1)
			table.insert(content_list,index,content)
		else
			table.insert(content_list,content)
			index = #content_list
		end
		content.Visible = false
		content.Parent = TabContentFrame

		local TabFrame = Create'TextButton'{
			Name = "Tab";
			Text = content.Name;
		}
		local Tab = CreateAutoSizeLabel(TabFrame)
		tab_lookup[content] = Tab
		Tab.SetPadding(0,4)
		Tab.LockAxis(nil,TabHeight)
		TabStylist.AddObject(TabFrame)
		TabHeaderClass.AddObject(TabFrame,index)
		TabFrame.MouseButton1Click:connect(function()
			SelectTab(content)
		end)
		con[content] = content.Changed:connect(function(p)
			if p == "Name" then
				TabFrame.Text = content.Name
			end
		end)
		if selected_index == 0 then
			SelectTab(index)
		elseif index <= selected_index then
			selected_index = selected_index + 1
		end
	end

	local function RemoveTab(index)
		if #content_list > 0 then
			if type(index) ~= "number" then
				if index == nil then
					index = #content_list
				else
					index = GetIndex(index)
				end
			end
			if index then
				index = ClampIndex(index)
				local content = table.remove(content_list,index)
				content.Parent = nil
				con[content]:disconnect()
				con[content] = nil
				local tab = tab_lookup[content]
				TabHeaderClass.RemoveObject(index)
				tab_lookup[content] = nil
				tab.Destroy()
				if index == selected_index then
					SelectTab(index)
				elseif index < selected_index then
					selected_index = selected_index - 1
				end
				return content
			end
		end
	end

	local function MoveTab(index,to)
		if #content_list > 0 then
			if type(index) ~= "number" then
				index = GetIndex(index)
			end
			if type(to) ~= "number" then
				to = GetIndex(to)
			end
			if index and to then
				index = ClampIndex(index)
				to = ClampIndex(to)
				local content = table.remove(content_list,index)
				table.insert(content_list,to,content)
				TabHeaderClass.MoveObject(index,to)
				if index == selected_index then
					selected_index = to
				elseif index > selected_index and to <= selected_index then
					selected_index = selected_index + 1
				elseif index < selected_index and to >= selected_index then
					selected_index = selected_index - 1
				end
			end
		end
	end

	local Class = {
		GUI = TabContainerFrame;
		GetIndex = GetIndex;
		GetSelectedIndex = GetSelectedIndex;
		SelectTab = SelectTab;
		AddTab = AddTab;
		RemoveTab = RemoveTab;
		MoveTab = MoveTab;
		TabStylist = TabStylist;
		SelectedTabStylist = SelectedTabStylist;
	}

	SetZIndexOnChanged(TabContainerFrame)

	local function Destroy()
		for k in pairs(Class) do
			Class[k] = nil
		end
		SelectedTabStylist.Destroy()
		TabStylist.Destroy()
		TabHeaderClass.Destroy()
		for k,v in pairs(con) do
			v:disconnect()
			con[k] = nil
		end
		for i,content in pairs(content_list) do
			content.Parent = nil
			content_list[i] = nil
		end
		for k,tab in pairs(tab_lookup) do
			tab_lookup[k] = nil
			tab.Destroy()
		end
		TabContainerFrame:Destroy()
	end
	Class.Destroy = Destroy

	if ContentList then
		for i,content in pairs(ContentList) do
			AddTab(content,i)
		end
	end

	return Class,TabContainerFrame
end

lib.TabContainer = CreateTabContainer

--[[DEPEND:]]

doc["Help"] = [==[
Help ( string `query`, bool `no_print` )
	returns: string `message`

Returns help information for the library.

Arguments:
	`query`
		The name of the function to display help for (case-insensitive).
		If unspecified, a list of functions will be displayed.
	`no_print`
		If set to true, the returned message will NOT also be printed.
		Note than when printed this way, the message is automatically formatted to maintain readability. 

Returns:
	`message`
		The resulting message.


Documentation Remarks:
	Function values follow this format:
		type `reference`

	"type" is the argument's value type (string, bool, table, etc).
	An asterisk (*) as the type indicates that the argument may be any type.

	In the documentation, a word enclosed in grave accents (i.e. `example`) refers to the indicated value.

	The type "GuiText" refers to TextLabels, TextButtons, and TextBoxes.
	This type doesn't actually exist, but it is used here to indicate that the above types are acceptable.

	A "Callback" refers to a function that can be overridden by the user, in order to run his/her own code at a specific time.

]==]

local default_help = [==[
Use ]==].."gloo"..[==[.Help("FunctionName") for more information about a specific function.

Functions:
]==]

do
	local sorted = {}
	for name,ref in pairs(doc) do
		if type(name) == "string" then
			table.insert(sorted,name)
		end
	end
	table.sort(sorted)
	for i,name in pairs(sorted) do
		default_help = default_help .. "\t" .. name .. "\n"
	end
end

doc["FunctionName"] = [==[
That was an example, silly.

]==]..default_help


local DocumentationLookup = {}
DocumentationLookup[false] = default_help

function lib.Help(query,no_print)
	if type(query) == "string" then
		query = query:lower()
	end
	local output = DocumentationLookup[query] or DocumentationLookup[false]
	if not no_print then
		print(string.rep("_",80))
		for c in output:gsub("\r\n?","\n"):gmatch("(.-)\n") do
			c = c:gsub(" ","\160")
			c = c:gsub("\t",string.rep("\160",8))
			print(#c == 0 and "\160" or c)
		end
		print("\160")
	end
	return output
end

for name,ref in pairs(doc) do
	if type(name) == "string" then
		DocumentationLookup[name:lower()] = ref
		local f = lib[name]
		if type(f) == "function" then
			DocumentationLookup[f] = ref
		end
	end
end

setmetatable(lib,{
	__tostring = function()
		return ("%s GUI Library [v%s] (use %s.Help() for help)"):format("gloo", version, "gloo")
	end;
})

--_G.gloo = lib
--print(("Loaded %s library. Type _G.%s.Help() for help."):format(PROJECT_NAME, PROJECT_NAME))

return lib
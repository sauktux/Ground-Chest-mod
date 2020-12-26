local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"
local searchFunction = require "searchFunction"

local screen_x, screen_y,half_x,half_y,w,h

local update_time = 0

local min_seen = 8 --How much of the widget can minimally be seen when it's moved out of your screen at x or y coordinates?
--I think 8 is around the size where you might not be able to drag it out.
local items_page = 50--10x wide and 5x tall seems balanced to both see the item and its number. And it leaves space up top for the additional controls.
--Additional controls like: Switch views, Switch pages, etc.

local on_button_press_fn

local function LoadConfig(name)
    local mod = "Ground Chest"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end



local ui_button = LoadConfig("ui_button")



local function InGame()
	return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

--Some features:
--Clicking on an item tile: Will queue up for the item to be picked up, several tiles can be clicked at once and they will be picked up based on clicking order.
--There are several variants for the background of the item tile.

local GroundChestUI = Class(Widget,function(self,owner)
        Widget._ctor(self,"GroundChestUI")
		
		self.GenerateItemList = searchFunction.GenerateItemList
		
        screen_x,screen_y = TheSim:GetScreenSize()
        half_x = screen_x/2
        half_y = screen_y/2
		
		on_button_press_fn = function() self:Toggle() end
		
        self.owner = owner
		self.tiles = {} --Track all tiles that currently exist and aren't deleted.
		self.ent_list = {}
		self.page = 1
		self.total_pages = 1
		
		self.pos_x = half_x--Centered
		self.pos_y = half_y*1.5--At a 0.75/1 position from below.
		self.offset_x = 0
		self.offset_y = 0
		
		self.size_x = 1/10*half_x+64*7 --Not sure why I use 1/10 of screen size and then add 64's, but it seems like a relatively good size.
		self.size_y = 1/10*half_y+64*5
		
		self.bg = self:AddChild(Image("images/plantregistry.xml", "backdrop.tex"))
		self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
		self.bg:SetSize(self.size_x,self.size_y)
		self.itembg = {atlas = "images/quagmire_recipebook.xml", tex = "cookbook_known.tex", scale = 0.4}
		
		self.refreshbutton = self.bg:AddChild(ImageButton("images/button_icons.xml","refresh.tex"))
		self.refreshbutton:SetPosition(self.size_x*2.9/7,self.size_y*7/20)
		self.refreshbutton:SetNormalScale(0.2)
		self.refreshbutton:SetFocusScale(0.2*1.1)
		self.refreshbutton_fn = function() self:UpdateList() self:UpdateTiles() end
		self.refreshbutton:SetOnClick(self.refreshbutton_fn)
		
		self.refreshbutton_text = self.refreshbutton:AddChild(Text(BUTTONFONT,32))
		self.refreshbutton_text:SetPosition(0,24)
		self.refreshbutton_text:SetString("Refresh")
		self.refreshbutton_text:Hide()
		
		self.on_refreshbutton_gainfocus_fn = function() self.refreshbutton_text:Show() end
		self.on_refreshbutton_losefocus_fn = function() self.refreshbutton_text:Hide() end
		self.refreshbutton:SetOnGainFocus(self.on_refreshbutton_gainfocus_fn)
		self.refreshbutton:SetOnLoseFocus(self.on_refreshbutton_losefocus_fn)
		--[[
		self.textbox = self.bg:AddChild(Image("images/textboxes.xml", "textbox3_gold_normal.tex"))
		self.textbox:SetSize(self.size_x/3,self.size_y/8)
		self.textbox:SetPosition(-self.size_x*2/7,7*self.size_y/20)
		self.textbox:Show()
		--]]--Use a screen for text input.
		
		--Just gonna grab the texture names from Klei's plantspage.lua
		local left_textures = {
			normal = "arrow2_left.tex",
			over = "arrow2_left_over.tex",
			disabled = "arrow_left_disabled.tex",
			down = "arrow2_left_down.tex",
		}
		local right_textures = {
			normal = "arrow2_right.tex",
			over = "arrow2_right_over.tex",
			disabled = "arrow_right_disabled.tex",
			down = "arrow2_right_down.tex",
		}
		
		self.arrow_left = self.bg:AddChild(ImageButton("images/plantregistry.xml",left_textures.normal,left_textures.over,left_textures.disabled,left_textures.down))
		self.arrow_left:SetPosition(self.size_x*-1/7,self.size_y*7/20)
		self.arrow_left:SetNormalScale(0.5)
		self.arrow_left:SetFocusScale(0.5)
		
		self.arrow_left_fn = function () self:RetreatPage() end
		self.arrow_left:SetOnClick(self.arrow_left_fn)
		
		self.arrow_left_text = self.arrow_left:AddChild(Text(BUTTONFONT,32))
		self.arrow_left_text:SetPosition(0,24)
		self.arrow_left_text:SetString("Previous Page")
		self.arrow_left_text:Hide()
		
		self.on_arrow_left_gainfocus_fn = function() self.arrow_left_text:Show() end
		self.on_arrow_left_losefocus_fn = function() self.arrow_left_text:Hide() end
		self.arrow_left:SetOnGainFocus(self.on_arrow_left_gainfocus_fn)
		self.arrow_left:SetOnLoseFocus(self.on_arrow_left_losefocus_fn)
		
		
		self.arrow_right = self.bg:AddChild(ImageButton("images/plantregistry.xml",right_textures.normal,right_textures.over,right_textures.disabled,right_textures.down))
		self.arrow_right:SetPosition(self.size_x*1/7,self.size_y*7/20)
		self.arrow_right:SetNormalScale(0.5)
		self.arrow_right:SetFocusScale(0.5)
		
		self.arrow_right_fn = function() self:AdvancePage() end
		self.arrow_right:SetOnClick(self.arrow_right_fn)
		
		self.arrow_right_text = self.arrow_right:AddChild(Text(BUTTONFONT,32))
		self.arrow_right_text:SetPosition(0,24)
		self.arrow_right_text:SetString("Next Page")
		self.arrow_right_text:Hide()
		
		self.on_arrow_right_gainfocus_fn = function() self.arrow_right_text:Show() end
		self.on_arrow_right_losefocus_fn = function() self.arrow_right_text:Hide() end
		self.arrow_right:SetOnGainFocus(self.on_arrow_right_gainfocus_fn)
		self.arrow_right:SetOnLoseFocus(self.on_arrow_right_losefocus_fn)
		
		self.page_text = self.bg:AddChild(Text(BUTTONFONT,32))
		self.page_text:SetPosition(0,self.size_y*7/20)
		self.page_text:SetColour(1,201/255,14/255,1)--Gold coloured.
		self.page_text:SetString("Page 1")
		
		
		
		local x_range = 10
		local y_range = 5
		for x = 1,x_range do
			for y = 1,y_range do
				local tile = self.bg:AddChild(GroundChestItemTiles(nil,self.itembg))
				self.tiles[x_range*(y-1)+x] = tile

				local min_vx = -8 -- Min distance it has to be from the vertical edges
				local u_x = self.size_x-2*min_vx
				local d_x = u_x/(x_range+1)
				
				local min_ty = 40 -- Min top
				local min_by = 16 -- Min bot
				local u_y = self.size_y-min_ty-min_by
				local d_y = u_y/(y_range+1)
				tile:SetPosition((-0.5)*u_x+d_x*x,(0.5)*u_y-min_ty-d_y*y)
			end
		end
		
		local ongainfocus_fn = function() self.focused = true end
		local onlosefocus_fn = function() self.focused = false end
		self.bg:SetOnGainFocus(ongainfocus_fn)
		self.bg:SetOnLoseFocus(onlosefocus_fn)
		
		self.shown = false
		self:Hide()
		
		
        self:StartUpdating()
    end)

function GroundChestUI:FillBoard(scale)--Function for testing, use as reference, do not use for anything other than testing.
		self.bgitem = self.bg:AddChild(ImageButton("images/quagmire_recipebook.xml","cookbook_known.tex"))
		self.bgitem:SetPosition(0,0)
		self.bgitem:SetOnClick(function() print("Clickity Click") end)
		self.bgitem:Hide()
		w,h = self.bgitem:GetSize()
		w = w*scale
		h = h*scale
		for x = 1,math.floor(self.size_x/w) do
			for y = 1,math.floor(self.size_y/h)-2 do
			self.bgitem = self.bg:AddChild(ImageButton("images/quagmire_recipebook.xml","recipe_known.tex"))
			self.bgitem:SetScale(scale)
			
			local min_vx = -8 -- Min distance it has to be from the vertical edges
            local u_x = self.size_x-2*min_vx
            local d_x = u_x/(math.floor(self.size_x/w+1))
			
            local min_tz = 32 -- Min top
            local min_bz = 8 -- Min bot
            local u_z = self.size_y-min_tz-min_bz
            local d_z = u_z/(math.floor(self.size_y/h-2)+1)
            self.bgitem:SetPosition((-0.5)*u_x+d_x*x,(0.5)*u_z-min_tz-d_z*y)
			
			self.bgitem:SetOnClick(function() print("Clickity Click") end)
			self.bgitem:Show()
		
			self.testitem = self.bgitem:AddChild(ImageButton(GetInventoryItemAtlas("cane_ancient.tex"),"cane_ancient.tex"))
			self.testitem:SetScale(2)
			self.testitem:Show()
			self.testitemcount = self.bgitem:AddChild(Text(NUMBERFONT,72))
			self.testitemcount:SetPosition(0,-30)
			self.testitemcount:SetString(tostring(math.random(1,40)))
			self.testitemcount:MoveToFront()
			self.testitemcount:Show()
			self.bgitem:SetOnGainFocus(function() self.testitemcount:SetSize(72*1.2) self.testitemcount:SetPosition(0,-30*1.2) end)
			self.bgitem:SetOnLoseFocus(function() self.testitemcount:SetSize(72) self.testitemcount:SetPosition(0,-30) end)
			end
		end
end

function GroundChestUI:Toggle()
	if self.shown then
		self.shown = false
		self:Hide()
	else
		self.shown = true
		self:UpdateList()--Opening up the UI should give you new info without the need to press the "Refresh" button.
		self:UpdateTiles()
		self:Show()
	end
end
 
function GroundChestUI:UpdatePosition()
	self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
end

function GroundChestUI:HandleMouseMovement()
	if TheInput:IsControlPressed(CONTROL_PRIMARY) and self.focused then
		local pos = TheInput:GetScreenPosition()
		self.start_pos = self.start_pos or pos
		self.offset_x = pos.x-self.start_pos.x
		self.offset_y = pos.y-self.start_pos.y
		self:UpdatePosition()
	else
		local new_x = self.pos_x+self.offset_x
		local new_y = self.pos_y+self.offset_y
		
		local neg_out_x = -self.size_x/2+min_seen
		local neg_out_y = -self.size_y/2+min_seen
		local out_x = screen_x+self.size_x/2-min_seen
		local out_y = screen_y+self.size_y/2-min_seen
		self.pos_x = new_x > neg_out_x and new_x < out_x and new_x or (new_x < 0 and neg_out_x or out_x)
		self.pos_y = new_y > neg_out_y and new_y < out_y and new_y or (new_y < 0 and neg_out_y or out_y)
		self.offset_x = 0
		self.offset_y = 0
		self.start_pos = nil
		self:UpdatePosition()
	end	
end

function GroundChestUI:UpdateTiles()
	for num,tile in pairs(self.tiles) do
		local entity = self.ent_list[num+50*(self.page-1)] or {}-- 50 is the current number of items supported per page.
		local prefab = entity.prefab
		local name = entity.name
		local amount = entity.amount
		local stackable = entity.stackable
		
		local tex = prefab and prefab..".tex" or nil
		local atlas = tex and GetInventoryItemAtlas(tex) or nil
		if prefab then
			tile:SetItem(prefab,atlas,tex)
		else
			tile:RemoveItem()
		end
		tile:SetStackText(stackable and amount or nil)
	end
end

function GroundChestUI:UpdateList()
	local x,y,z = ThePlayer.Transform:GetWorldPosition()
	self.ent_list = self.GenerateItemList({x = x, y = y, z = z},30)
	self:UpdatePages()
	self:UpdatePageText()
end

function GroundChestUI:AdvancePage()
	local page = self.page
	if page+1 > self.total_pages then --Loop or do nothing.
		
	else
		self.page = self.page+1
	end
	
	self:UpdateTiles()
	self:UpdatePageText()
end

function GroundChestUI:RetreatPage()
	local page = self.page
	if page-1 < 1 then --Loop or do nothing.
		
	else
		self.page = self.page-1
	end
	
	self:UpdateTiles()
	self:UpdatePageText()
end

function GroundChestUI:UpdatePageText()
	self.page_text:SetString("Page "..self.page)
	--Also update the widgets to be clickable/non-clickable:
	if self.page == 1 then
		self.arrow_left:Disable()
	else
		self.arrow_left:Enable()
	end
	if self.page == self.total_pages then
		self.arrow_right:Disable()
	else
		self.arrow_right:Enable()
	end
end


function GroundChestUI:UpdatePages()
	self.total_pages = math.ceil(#self.ent_list/50)
	if self.page > self.total_pages then --Don't move them from their current page unless it doesn't have anything left.
		self.page = self.total_pages
		self:UpdateTiles()
		self:UpdatePageText()
	end
end

function GroundChestUI:OnUpdate(dt)
	self:HandleMouseMovement()
end

if ui_button and ui_button ~= 0 then
	TheInput:AddKeyDownHandler(ui_button,function() if not InGame() then return else on_button_press_fn() end end)
end

return GroundChestUI

    
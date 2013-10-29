
function SearchBoxTemplate_OnLoad(self)
	self:SetText(SEARCH);
	self:SetFontObject("GameFontDisable");
	self.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
	self:SetTextInsets(16, 20, 0, 0);
end

function SearchBoxTemplate_OnEditFocusLost(self)
	self:HighlightText(0, 0);
	self:SetFontObject("GameFontDisable");
	self.searchIcon:SetVertexColor(0.6, 0.6, 0.6);
	if ( self:GetText() == "" or self:GetText() == SEARCH ) then
		self:SetText(SEARCH);
		self.clearButton:Hide();
	end
end

function SerachBoxTemplate_OnEditFocusGained(self)
	self:HighlightText();
	self:SetFontObject("ChatFontSmall");
	self.searchIcon:SetVertexColor(1.0, 1.0, 1.0);
	if ( self:GetText() == SEARCH ) then
		self:SetText("")
	end
	self.clearButton:Show();
end

ITEM_SEARCHBAR_LIST = {
	"BagItemSearchBox",
	"GuildItemSearchBox",
	"VoidItemSearchBox",
	"BankItemSearchBox",
};

function BagSearch_OnHide(self)
	local allClosed = true;
	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self and bar:IsVisible() then
			allClosed = false;
		end
	end
	if ( allClosed ) then
		self.clearButton:Click();
		BagSearch_OnTextChanged(self);
	end
end

function BagSearch_OnTextChanged(self, userChanged)
	local text = self:GetText();
	if ( text == SEARCH ) then
		text = "";
	end
	SetItemSearch(text);
	if (text ~= "") then
		self.clearButton:Show();
	else
		self.clearButton:Hide();
	end
end

function BagSearch_OnChar(self, text)
	-- clear focus if the player is repeating keys (ie - trying to move)
	-- TODO: move into base editbox code?
	local MIN_REPEAT_CHARACTERS = 3
	local searchString = self:GetText();
	if (string.len(searchString) > MIN_REPEAT_CHARACTERS) then
		local repeatChar = true;
		for i=1, MIN_REPEAT_CHARACTERS, 1 do 
			if ( string.sub(searchString,(0-i), (0-i)) ~= string.sub(searchString,(-1-i),(-1-i)) ) then
				repeatChar = false;
				break;
			end
		end
		if ( repeatChar ) then
			self:ClearFocus();
		end
	end
end

function BagSearch_OnEditFocusGained(self)
	SerachBoxTemplate_OnEditFocusGained(self);

	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self then
			bar:SetText(SEARCH);
		end
	end
end

function BagSearch_OnEditFocusLost(self)
	SerachBoxTemplate_OnEditFocusGained(self);

	local search = self:GetText();
	for _,barName in pairs(ITEM_SEARCHBAR_LIST) do
		local bar = _G[barName];
		if bar and bar ~= self then
			bar:SetText(search);
		end
	end
end

-- functions to manage tab interfaces where only one tab of a group may be selected
function PanelTemplates_Tab_OnClick(self, frame)
	PanelTemplates_SetTab(frame, self:GetID())
end

function PanelTemplates_SetTab(frame, id)
	frame.selectedTab = id;
	PanelTemplates_UpdateTabs(frame);
end

function PanelTemplates_GetSelectedTab(frame)
	return frame.selectedTab;
end

function PanelTemplates_UpdateTabs(frame)
	if ( frame.selectedTab ) then
		local tab;
		for i=1, frame.numTabs, 1 do
			tab = _G[frame:GetName().."Tab"..i];
			if ( tab.isDisabled ) then
				PanelTemplates_SetDisabledTabState(tab);
			elseif ( i == frame.selectedTab ) then
				PanelTemplates_SelectTab(tab);
			else
				PanelTemplates_DeselectTab(tab);
			end
		end
	end
end

function PanelTemplates_GetTabWidth(tab)
	local tabName = tab:GetName();

	local sideWidths = 2 * _G[tabName.."Left"]:GetWidth();
	return tab:GetTextWidth() + sideWidths;
end

function PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
	local tabName = tab:GetName();
	
	local buttonMiddle = _G[tabName.."Middle"];
	local buttonMiddleDisabled = _G[tabName.."MiddleDisabled"];
	local sideWidths = 2 * _G[tabName.."Left"]:GetWidth();
	local tabText = _G[tab:GetName().."Text"];
	local width, tabWidth;
	local textWidth;
	if ( absoluteTextSize ) then
		textWidth = absoluteTextSize;
	else
		tabText:SetWidth(0);
		textWidth = tabText:GetWidth();
	end
	-- If there's an absolute size specified then use it
	if ( absoluteSize ) then
		if ( absoluteSize < sideWidths) then
			width = 1;
			tabWidth = sideWidths
		else
			width = absoluteSize - sideWidths;
			tabWidth = absoluteSize
		end
		tabText:SetWidth(width);
	else
		-- Otherwise try to use padding
		if ( padding ) then
			width = textWidth + padding;
		else
			width = textWidth + 24;
		end
		-- If greater than the maxWidth then cap it
		if ( maxWidth and width > maxWidth ) then
			if ( padding ) then
				width = maxWidth + padding;
			else
				width = maxWidth + 24;
			end
			tabText:SetWidth(width);
		else
			tabText:SetWidth(0);
		end
		if (minWidth and width < minWidth) then
			width = minWidth;
		end
		tabWidth = width + sideWidths;
	end
	
	if ( buttonMiddle ) then
		buttonMiddle:SetWidth(width);
	end
	if ( buttonMiddleDisabled ) then
		buttonMiddleDisabled:SetWidth(width);
	end
	
	tab:SetWidth(tabWidth);
	local highlightTexture = _G[tabName.."HighlightTexture"];
	if ( highlightTexture ) then
		highlightTexture:SetWidth(tabWidth);
	end
end

function PanelTemplates_SetNumTabs(frame, numTabs)
	frame.numTabs = numTabs;
end

function PanelTemplates_DisableTab(frame, index)
	_G[frame:GetName().."Tab"..index].isDisabled = 1;
	PanelTemplates_UpdateTabs(frame);
end

function PanelTemplates_EnableTab(frame, index)
	local tab = _G[frame:GetName().."Tab"..index];
	tab.isDisabled = nil;
	-- Reset text color
	tab:SetDisabledFontObject(GameFontHighlightSmall);
	PanelTemplates_UpdateTabs(frame);
end

function PanelTemplates_DeselectTab(tab)
	local name = tab:GetName();
	_G[name.."Left"]:Show();
	_G[name.."Middle"]:Show();
	_G[name.."Right"]:Show();
	--tab:UnlockHighlight();
	tab:Enable();
	_G[name.."Text"]:SetPoint("CENTER", tab, "CENTER", (tab.deselectedTextX or 0), (tab.deselectedTextY or 2));
		
	_G[name.."LeftDisabled"]:Hide();
	_G[name.."MiddleDisabled"]:Hide();
	_G[name.."RightDisabled"]:Hide();
end

function PanelTemplates_SelectTab(tab)
	local name = tab:GetName();
	_G[name.."Left"]:Hide();
	_G[name.."Middle"]:Hide();
	_G[name.."Right"]:Hide();
	--tab:LockHighlight();
	tab:Disable();
	tab:SetDisabledFontObject(GameFontHighlightSmall);
	_G[name.."Text"]:SetPoint("CENTER", tab, "CENTER", (tab.selectedTextX or 0), (tab.selectedTextY or -3));
	
	_G[name.."LeftDisabled"]:Show();
	_G[name.."MiddleDisabled"]:Show();
	_G[name.."RightDisabled"]:Show();
	
	if ( GameTooltip:IsOwned(tab) ) then
		GameTooltip:Hide();
	end
end

function PanelTemplates_SetDisabledTabState(tab)
	local name = tab:GetName();
	_G[name.."Left"]:Show();
	_G[name.."Middle"]:Show();
	_G[name.."Right"]:Show();
	--tab:UnlockHighlight();
	tab:Disable();
	tab.text = tab:GetText();
	-- Gray out text
	tab:SetDisabledFontObject(GameFontDisableSmall);
	_G[name.."LeftDisabled"]:Hide();
	_G[name.."MiddleDisabled"]:Hide();
	_G[name.."RightDisabled"]:Hide();
end

function ScrollFrameTemplate_OnMouseWheel(self, value, scrollBar)
	scrollBar = scrollBar or _G[self:GetName() .. "ScrollBar"];
	local scrollStep = scrollBar.scrollStep or scrollBar:GetHeight() / 2
	if ( value > 0 ) then
		scrollBar:SetValue(scrollBar:GetValue() - scrollStep);
	else
		scrollBar:SetValue(scrollBar:GetValue() + scrollStep);
	end
end

-- Function to handle the update of manually calculated scrollframes.  Used mostly for listings with an indeterminate number of items
function FauxScrollFrame_Update(frame, numItems, numToDisplay, buttonHeight, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth, alwaysShowScrollBar )
	-- If more than one screen full of skills then show the scrollbar
	local frameName = frame:GetName();
	local scrollBar = _G[ frameName.."ScrollBar" ];
	local showScrollBar;
	if ( numItems > numToDisplay or alwaysShowScrollBar ) then
		frame:Show();
		showScrollBar = 1;
	else
		scrollBar:SetValue(0);
		frame:Hide();
	end
	if ( frame:IsShown() ) then
		local scrollChildFrame = _G[ frameName.."ScrollChildFrame" ];
		local scrollUpButton = _G[ frameName.."ScrollBarScrollUpButton" ];
		local scrollDownButton = _G[ frameName.."ScrollBarScrollDownButton" ];
		local scrollFrameHeight = 0;
		local scrollChildHeight = 0;

		if ( numItems > 0 ) then
			scrollFrameHeight = (numItems - numToDisplay) * buttonHeight;
			scrollChildHeight = numItems * buttonHeight;
			if ( scrollFrameHeight < 0 ) then
				scrollFrameHeight = 0;
			end
			scrollChildFrame:Show();
		else
			scrollChildFrame:Hide();
		end
		local maxRange = (numItems - numToDisplay) * buttonHeight;
		if (maxRange < 0) then
			maxRange = 0;
		end
		scrollBar:SetMinMaxValues(0, maxRange); 
		scrollBar:SetValueStep(buttonHeight);
		scrollBar:SetStepsPerPage(numToDisplay-1);
		scrollChildFrame:SetHeight(scrollChildHeight);
		
		-- Arrow button handling
		if ( scrollBar:GetValue() == 0 ) then
			scrollUpButton:Disable();
		else
			scrollUpButton:Enable();
		end
		if ((scrollBar:GetValue() - scrollFrameHeight) == 0) then
			scrollDownButton:Disable();
		else
			scrollDownButton:Enable();
		end
		
		-- Shrink because scrollbar is shown
		if ( highlightFrame ) then
			highlightFrame:SetWidth(smallHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(smallWidth);
			end
		end
	else
		-- Widen because scrollbar is hidden
		if ( highlightFrame ) then
			highlightFrame:SetWidth(bigHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(bigWidth);
			end
		end
	end
	return showScrollBar;
end

function FauxScrollFrame_OnVerticalScroll(self, value, itemHeight, updateFunction)
	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetValue(value);
	self.offset = floor((value / itemHeight) + 0.5);
	if ( updateFunction ) then
		updateFunction(self);
	end
end

function FauxScrollFrame_GetOffset(frame)
	return frame.offset;
end

function FauxScrollFrame_SetOffset(frame, offset)
	frame.offset = offset;
end

-- Scrollframe functions
function ScrollFrame_OnLoad(self)
	_G[self:GetName().."ScrollBarScrollDownButton"]:Disable();
	_G[self:GetName().."ScrollBarScrollUpButton"]:Disable();

	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetMinMaxValues(0, 0);
	scrollbar:SetValue(0);
	self.offset = 0;
	
	if ( self.scrollBarHideable ) then
		_G[self:GetName().."ScrollBar"]:Hide();
		_G[scrollbar:GetName().."ScrollDownButton"]:Hide();
		_G[scrollbar:GetName().."ScrollUpButton"]:Hide();
	else
		_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
		_G[scrollbar:GetName().."ScrollUpButton"]:Disable();
		_G[scrollbar:GetName().."ScrollDownButton"]:Show();
		_G[scrollbar:GetName().."ScrollUpButton"]:Show();
	end
	if ( self.noScrollThumb ) then
		_G[scrollbar:GetName().."ThumbTexture"]:Hide();
	end
end

function ScrollFrame_OnScrollRangeChanged(self, xrange, yrange)
	local scrollbar = self.ScrollBar or _G[self:GetName().."ScrollBar"];
	if ( not yrange ) then
		yrange = self:GetVerticalScrollRange();
	end
	local value = scrollbar:GetValue();
	if ( value > yrange ) then
		value = yrange;
	end
	scrollbar:SetMinMaxValues(0, yrange);
	scrollbar:SetValue(value);
	if ( floor(yrange) == 0 ) then
		if ( self.scrollBarHideable ) then
			_G[self:GetName().."ScrollBar"]:Hide();
			_G[scrollbar:GetName().."ScrollDownButton"]:Hide();
			_G[scrollbar:GetName().."ScrollUpButton"]:Hide();
			_G[scrollbar:GetName().."ThumbTexture"]:Hide();
		else
			_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
			_G[scrollbar:GetName().."ScrollUpButton"]:Disable();
			_G[scrollbar:GetName().."ScrollDownButton"]:Show();
			_G[scrollbar:GetName().."ScrollUpButton"]:Show();
			if ( not self.noScrollThumb ) then
				_G[scrollbar:GetName().."ThumbTexture"]:Show();
			end
		end
	else
		_G[scrollbar:GetName().."ScrollDownButton"]:Show();
		_G[scrollbar:GetName().."ScrollUpButton"]:Show();
		_G[self:GetName().."ScrollBar"]:Show();
		if ( not self.noScrollThumb ) then
			_G[scrollbar:GetName().."ThumbTexture"]:Show();
		end
		-- The 0.005 is to account for precision errors
		if ( yrange - value > 0.005 ) then
			_G[scrollbar:GetName().."ScrollDownButton"]:Enable();
		else
			_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
		end
	end
	
	-- Hide/show scrollframe borders
	local top = _G[self:GetName().."Top"];
	local bottom = _G[self:GetName().."Bottom"];
	local middle = _G[self:GetName().."Middle"];
	if ( top and bottom and self.scrollBarHideable ) then
		if ( self:GetVerticalScrollRange() == 0 ) then
			top:Hide();
			bottom:Hide();
		else
			top:Show();
			bottom:Show();
		end
	end
	if ( middle and self.scrollBarHideable ) then
		if ( self:GetVerticalScrollRange() == 0 ) then
			middle:Hide();
		else
			middle:Show();
		end
	end
end

function ScrollBar_AdjustAnchors(scrollBar, topAdj, bottomAdj, xAdj)
	-- assumes default anchoring of topleft-topright, bottomleft-bottomright
	local topY = 0;
	local bottomY = 0;
	local point, parent, refPoint, x, y;
	for i = 1, 2 do
		point, parent, refPoint, x, y = scrollBar:GetPoint(i);
		if ( point == "TOPLEFT" ) then
			topY = y;
		elseif ( point == "BOTTOMLEFT" ) then
			bottomY = y;
		end
	end
	xAdj = xAdj or 0;
	topAdj = topAdj or 0;
	bottomAdj = bottomAdj or 0;
	scrollBar:SetPoint("TOPLEFT", parent, "TOPRIGHT", x + xAdj, topY + topAdj);
	scrollBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", x + xAdj, bottomY + bottomAdj);
end

function ScrollingEdit_OnTextChanged(self, scrollFrame)
	-- force an update when the text changes
	self.handleCursorChange = true;
	ScrollingEdit_OnUpdate(self, 0, scrollFrame);
end

function ScrollingEdit_OnCursorChanged(self, x, y, w, h)
	self.cursorOffset = y;
	self.cursorHeight = h;
	self.handleCursorChange = true;
end

-- NOTE: If your edit box never shows partial lines of text, then this function will not work when you use
-- your mouse to move the edit cursor. You need the edit box to cut lines of text so that you can use your
-- mouse to highlight those partially-seen lines; otherwise you won't be able to use the mouse to move the
-- cursor above or below the current scroll area of the edit box.
function ScrollingEdit_OnUpdate(self, elapsed, scrollFrame)
local height, range, scroll, size, cursorOffset;
	if ( self.handleCursorChange ) then
		if ( not scrollFrame ) then
			scrollFrame = self:GetParent();
		end
		height = scrollFrame:GetHeight();
		range = scrollFrame:GetVerticalScrollRange();
		scroll = scrollFrame:GetVerticalScroll();
		size = height + range;
		cursorOffset = -self.cursorOffset;
		
		if ( math.floor(height) <= 0 or math.floor(range) <= 0 ) then
			--Frame has no area, nothing to calculate.
			return;
		end
		
		while ( cursorOffset < scroll ) do
			scroll = (scroll - (height / 2));
			if ( scroll < 0 ) then
				scroll = 0;
			end
			scrollFrame:SetVerticalScroll(scroll);
		end

		while ( (cursorOffset + self.cursorHeight) > (scroll + height) and scroll < range ) do
			scroll = (scroll + (height / 2));
			if ( scroll > range ) then
				scroll = range;
			end
			scrollFrame:SetVerticalScroll(scroll);
		end
		
		self.handleCursorChange = false;
	end
end

function EditBox_HandleTabbing(self, tabList)
	local editboxName = self:GetName();
	local index;
	for i=1, #tabList do
		if ( editboxName == tabList[i] ) then
			index = i;
			break;
		end
	end
	if ( IsShiftKeyDown() ) then
		index = index - 1;
	else
		index = index + 1;
	end

	if ( index == 0 ) then
		index = #tabList;
	elseif ( index > #tabList ) then
		index = 1;
	end

	local target = tabList[index];
	_G[target]:SetFocus();
end

function EditBox_ClearFocus (self)
	self:ClearFocus();
end

function EditBox_SetFocus (self)
	self:SetFocus();
end

function EditBox_HighlightText (self)
	self:HighlightText();
end

function EditBox_ClearHighlight (self)
	self:HighlightText(0, 0);
end

UIFrameCache = CreateFrame("FRAME");
local caches = {};
function UIFrameCache:New (frameType, baseName, parent, template)
	if ( self ~= UIFrameCache ) then
		error("Attempt to run factory method on class member");
	end
	
	local frameCache = {};

	setmetatable(frameCache, self);
	self.__index = self;
	
	frameCache.frameType = frameType;
	frameCache.baseName = baseName;
	frameCache.parent = parent;
	frameCache.template = template;
	frameCache.frames = {};
	frameCache.usedFrames = {};
	frameCache.numFrames = 0;

	tinsert(caches, frameCache);
	
	return frameCache;
end

function UIFrameCache:GetFrame ()
	local frame = self.frames[1];
	if ( frame ) then
		tremove(self.frames, 1);
		tinsert(self.usedFrames, frame);
		return frame;
	end
	
	frame = CreateFrame(self.frameType, self.baseName .. self.numFrames + 1, self.parent, self.template);
	frame.frameCache = self;
	self.numFrames = self.numFrames + 1;
	tinsert(self.usedFrames, frame);
	return frame;
end

function UIFrameCache:ReleaseFrame (frame)
	for k, v in next, self.frames do
		if ( v == frame ) then
			return;
		end
	end
	
	for k, v in next, self.usedFrames do
		if ( v == frame ) then
			tinsert(self.frames, frame);
			tremove(self.usedFrames, k);
			break;
		end
	end	
end

-- Truncated Button code

function TruncatedButton_OnEnter(self)
	local text = _G[self:GetName().."Text"];
	if ( text:IsTruncated() ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(text:GetText());
		GameTooltip:Show();
	end
end

function TruncatedButton_OnLeave(self)
	if ( GameTooltip:GetOwner() == self ) then
		GameTooltip:Hide();
	end
end

-- Magic Button code
function MagicButton_OnLoad(self)
	local leftHandled = false;
	local rightHandled = false;
	
	-- Find out where this button is anchored and adjust positions/separators as necessary
	for i=1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint(i);
		
		if (relativeTo:GetObjectType() == "Button" and (point == "TOPLEFT" or point == "LEFT")) then
			
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 1, 0);
			end	
			
			if (relativeTo.RightSeparator) then
				-- Modify separator to make it a Middle
				self.LeftSeparator = relativeTo.RightSeparator;
			else
				-- Add a Middle separator
				self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER");
				relativeTo.RightSeparator = self.LeftSeparator;
			end
			
			self.LeftSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
			self.LeftSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500);
			self.LeftSeparator:SetWidth(13);
			self.LeftSeparator:SetHeight(25);
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 5, 1);
			
			leftHandled = true;	
			
		elseif (relativeTo:GetObjectType() == "Button" and (point == "TOPRIGHT" or point == "RIGHT")) then
		
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -1, 0);
			end	
			
			if (relativeTo.LeftSeparator) then
				-- Modify separator to make it a Middle
				self.RightSeparator = relativeTo.LeftSeparator;
			else
				-- Add a Middle separator
				self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER");
				relativeTo.LeftSeparator = self.RightSeparator;
			end
			
			self.RightSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
			self.RightSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500);
			self.RightSeparator:SetWidth(13);
			self.RightSeparator:SetHeight(25);
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -5, 1);
			
			rightHandled = true;
			
		elseif (point == "BOTTOMLEFT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 4, 4);
			end	
			leftHandled = true;
		elseif (point == "BOTTOMRIGHT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -6, 4);
			end
			rightHandled = true;
		elseif (point == "BOTTOM") then
			if (offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 0, 4);
			end
		end	
	end	
	
	-- If this button didn't have a left anchor, add the left border texture
	if (not leftHandled) then
		if (not self.LeftSeparator) then
			-- Add a Left border
			self.LeftSeparator = self:CreateTexture(self:GetName().."_LeftSeparator", "BORDER");
			self.LeftSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
			self.LeftSeparator:SetTexCoord(0.24218750, 0.32812500, 0.63281250, 0.82812500);
			self.LeftSeparator:SetWidth(11);
			self.LeftSeparator:SetHeight(25);
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 6, 1);
		end
	end
	
	-- If this button didn't have a right anchor, add the right border texture
	if (not rightHandled) then
		if (not self.RightSeparator) then
			-- Add a Right border
			self.RightSeparator = self:CreateTexture(self:GetName().."_RightSeparator", "BORDER");
			self.RightSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame");
			self.RightSeparator:SetTexCoord(0.90625000, 0.99218750, 0.00781250, 0.20312500);
			self.RightSeparator:SetWidth(11);
			self.RightSeparator:SetHeight(25);
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -6, 1);
		end
	end
end

-- ButtonFrameTemplate code
function ButtonFrameTemplate_HideButtonBar(self)
	if self.bottomInset then 
		self.bottomInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET);
	else
		_G[self:GetName() .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET);
	end
	_G[self:GetName() .. "BtnCornerLeft"]:Hide();
	_G[self:GetName() .. "BtnCornerRight"]:Hide();
	_G[self:GetName() .. "ButtonBottomBorder"]:Hide();
end

function ButtonFrameTemplate_ShowButtonBar(self)
	if self.topInset then 
		self.topInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET);
	else
		_G[self:GetName() .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET);
	end
	_G[self:GetName() .. "BtnCornerLeft"]:Show();
	_G[self:GetName() .. "BtnCornerRight"]:Show();
	_G[self:GetName() .. "ButtonBottomBorder"]:Show();
end

function ButtonFrameTemplate_HideAttic(self)
	if self.topInset then 
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET);
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET);
	end
	self.TopTileStreaks:Hide();
end

function ButtonFrameTemplate_ShowAttic(self)
	if self.topInset then 
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET);
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET);
	end
	self.TopTileStreaks:Show();
end


function ButtonFrameTemplate_HidePortrait(self)
	self.portrait:Hide();
	self.portraitFrame:Hide();
	self.topLeftCorner:Show();
	self.topBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "TOPRIGHT",  0, 0);
	self.leftBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "BOTTOMLEFT",  0, 0);
end


function ButtonFrameTemplate_ShowPortrait(self)
	self.portrait:Show();
	self.portraitFrame:Show();
	self.topLeftCorner:Hide();
	self.topBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "TOPRIGHT",  0, -10);
	self.leftBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT",  8, 0);
end

-- A bit ugly, we want the talent frame to display a dialog box in certain conditions.
function PortraitFrameCloseButton_OnClick(self)
	if ( self:GetParent().onCloseCallback) then
		self:GetParent().onCloseCallback(self);
	else
		HideParentPanel(self);
	end	
end

-- SquareButton template code
SQUARE_BUTTON_TEXCOORDS = {
	["UP"] = {     0.45312500,    0.64062500,     0.01562500,     0.20312500};
	["DOWN"] = {   0.45312500,    0.64062500,     0.20312500,     0.01562500};
	["LEFT"] = {   0.23437500,    0.42187500,     0.01562500,     0.20312500};
	["RIGHT"] = {  0.42187500,    0.23437500,     0.01562500,     0.20312500};
	["DELETE"] = { 0.01562500,    0.20312500,     0.01562500,     0.20312500};
};

function SquareButton_SetIcon(self, name)
	local coords = SQUARE_BUTTON_TEXCOORDS[strupper(name)];
	if (coords) then
		self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]);
	end
end


-- Cap progress bar
function CapProgressBar_SetNotches(capBar, count)
	local barWidth = capBar:GetWidth();
	local barName = capBar:GetName();
	
	if ( capBar.notchCount and capBar.notchCount > count ) then
		for i = count + 1, capBar.notchCount do
			_G[barName.."Divider"..i]:Hide();
		end
	end
	
	local notchWidth = barWidth / count;
	
	for i=1, count - 1 do
		local notch = _G[barName.."Divider"..i];
		if ( not notch ) then
			notch = capBar:CreateTexture(barName.."Divider"..i, "BORDER", "CapProgressBarDividerTemplate", -1);
		end
		notch:ClearAllPoints();
		notch:SetPoint("LEFT", capBar, "LEFT", notchWidth * i - 2, 0);
	end
	capBar.notchCount = count;
end

function CapProgressBar_Update(capBar, cap1Quantity, cap1Limit, cap2Quantity, cap2Limit, totalQuantity, totalLimit, hasNoSharedStats)
	if ( totalLimit == 0) then
		return;
	end
	
	local barWidth = capBar:GetWidth();
	local sizePerPoint = barWidth / totalLimit;
	local progressWidth = totalQuantity * sizePerPoint;
	
	local cap1Width, cap2Width;
	if ( cap2Quantity and cap2Limit ) then
		cap1Width = min(cap1Limit - cap1Quantity, cap2Limit - cap2Quantity) * sizePerPoint;	--cap1 can't go past the cap2 LFG limit either.
		cap2Width = (cap2Limit - cap2Quantity) * sizePerPoint - cap1Width;
	else
		cap1Width = (cap1Limit - cap1Quantity) * sizePerPoint;
		cap2Width = 0;
	end
	
	--Don't let it go past the end.
	progressWidth = min(progressWidth, barWidth);
	cap1Width = min(cap1Width, barWidth - progressWidth);
	cap2Width = min(cap2Width, barWidth - progressWidth - cap1Width);
	capBar.progress:SetWidth(progressWidth);
	
	capBar.cap1:SetWidth(cap1Width);
	capBar.cap2:SetWidth(cap2Width);
	
	local lastFrame, lastRelativePoint = capBar, "LEFT";
	
	if ( progressWidth > 0 ) then
		capBar.progress:Show();
		capBar.progress:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.progress, "RIGHT";
	else
		capBar.progress:Hide();
	end
	
	if ( cap1Width > 0 and not hasNoSharedStats) then
		capBar.cap1:Show();
		capBar.cap1Marker:Show();
		capBar.cap1:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.cap1, "RIGHT";
	else
		capBar.cap1:Hide();
		capBar.cap1Marker:Hide();
	end
	
	if ( cap2Width > 0 and not hasNoSharedStats) then
		capBar.cap2:Show();
		capBar.cap2Marker:Show();
		capBar.cap2:SetPoint("LEFT", lastFrame, lastRelativePoint, 0, 0);
		lastFrame, lastRelativePoint = capBar.cap2, "RIGHT";
	else
		capBar.cap2:Hide();
		capBar.cap2Marker:Hide();
	end
end

function InputScrollFrame_OnLoad(self)
	local scrollBar = self.ScrollBar;
	scrollBar:SetFrameLevel(self.FocusButton:GetFrameLevel() + 2);
	scrollBar:ClearAllPoints();
	scrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", -13, -11);
	scrollBar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", -13, 9);
	-- reposition the up and down buttons
	_G[self:GetName().."ScrollBarScrollDownButton"]:SetPoint("TOP", scrollBar, "BOTTOM", 0, 4);
	_G[self:GetName().."ScrollBarScrollUpButton"]:SetPoint("BOTTOM", scrollBar, "TOP", 0, -4);
	-- make the scroll bar hideable and force it to start off hidden so positioning calculations can be done
	-- as soon as it needs to be shown
	self.scrollBarHideable = 1;
	scrollBar:Hide();
	self.EditBox:SetWidth(self:GetWidth() - 18);
end
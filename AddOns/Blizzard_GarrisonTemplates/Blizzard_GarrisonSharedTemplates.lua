GARRISON_FOLLOWER_BUSY_COLOR = { 0, 0.06, 0.22, 0.44 };
GARRISON_FOLLOWER_INACTIVE_COLOR = { 0.22, 0.06, 0, 0.44 };

---------------------------------------------------------------------------------
--- Static Popup Dialogs                                                             ---
---------------------------------------------------------------------------------

StaticPopupDialogs["CONFIRM_FOLLOWER_UPGRADE"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		C_Garrison.CastSpellOnFollower(self.data);
	end,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["CONFIRM_FOLLOWER_ABILITY_UPGRADE"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		C_Garrison.CastSpellOnFollowerAbility(self.data.followerID, self.data.abilityID);
	end,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["CONFIRM_FOLLOWER_TEMPORARY_ABILITY"] = {
	text = CONFIRM_GARRISON_FOLLOWER_TEMPORARY_ABILITY,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		C_Garrison.CastSpellOnFollower(self.data);
	end,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

StaticPopupDialogs["CONFIRM_FOLLOWER_EQUIPMENT"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		if (self.data.source == "spell") then
			C_Garrison.CastSpellOnFollowerAbility(self.data.followerID, self.data.abilityID);
		elseif (self.data.source == "item") then
			C_Garrison.CastItemSpellOnFollowerAbility(self.data.followerID, self.data.abilityID);
		end
	end,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

---------------------------------------------------------------------------------
--- Follower List                                                             ---
---------------------------------------------------------------------------------

local FOLLOWER_BUTTON_HEIGHT = 56;
local CATEGORY_BUTTON_HEIGHT = 20;
local FOLLOWER_LIST_BUTTON_OFFSET = -6;
local FOLLOWER_LIST_BUTTON_INITIAL_OFFSET = -7;
local GARRISON_FOLLOWER_LIST_BUTTON_FULL_XP_WIDTH = 205;

GarrisonFollowerList = {};

function GarrisonFollowerList:Initialize(followerType)
	self.followerTab = self:GetParent().FollowerTab;
	if (self.followerTab) then
		self.followerTab.followerList = self;
	end
	self:Setup(self:GetParent(), followerType);
end

function GarrisonFollowerList:Setup(mainFrame, followerType, followerTemplate, initialOffsetX)
	self.followers = { };
	self.followersList = { };
	self:DirtyList();
	self.followerType = followerType;

	self.listScroll.update = function() self:UpdateData(); end;
	self.listScroll.dynamic = function(offset) return GarrisonFollowerList_GetTopButton(self, offset); end;

	if (not followerTemplate) then
		followerTemplate = "GarrisonMissionFollowerOrCategoryListButtonTemplate";
	end
	if (not initialOffsetX) then
		initialOffsetX = 7;
	end
	HybridScrollFrame_CreateButtons(self.listScroll, followerTemplate, initialOffsetX, FOLLOWER_LIST_BUTTON_INITIAL_OFFSET, nil, nil, nil, FOLLOWER_LIST_BUTTON_OFFSET);
	self.listScroll.followerFrame = mainFrame;
	
	self:UpdateFollowers();
end

function GarrisonFollowerList:OnShow()
	if (self.followerTab) then
		self.followerTab.lastUpdate = GetTime();
	end
	self:StopAnimations();

	self:DirtyList();
	self:UpdateFollowers();
	-- if there's no follower displayed in the tab, select the first one
	if (self.followerTab) then
		if (not self.followerTab.followerID or not self:HasFollower(self.followerTab.followerID)) then
			local index = self:FindFirstFollower();
			if (index and index ~= 0) then
				self:ShowFollower(self.followers[index].followerID);
			else
				-- empty page
				self:ShowFollower(0);
			end
		else
			-- refresh the shown follower
			self:ShowFollower(self.followerTab.followerID);
		end
	end
	if (C_Garrison.GetNumFollowers(self.followerType) >= GarrisonFollowerOptions[self.followerType].minFollowersForThreatCountersFrame) then
		self:ShowThreatCountersFrame();
	end

	self:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE");
	self:RegisterEvent("GARRISON_FOLLOWER_REMOVED");
	self:RegisterEvent("GARRISON_FOLLOWER_XP_CHANGED");
	self:RegisterEvent("GARRISON_FOLLOWER_UPGRADED");
	self:RegisterEvent("GARRISON_FOLLOWER_DURABILITY_CHANGED");
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:RegisterEvent("CURSOR_UPDATE");
end

function GarrisonFollowerList:ShowThreatCountersFrame()
	GarrisonThreatCountersFrame:Show();
end

function GarrisonFollowerList:StopAnimations()
	if (self.followerTab) then
		local abilities = self.followerTab.AbilitiesFrame.Abilities;
		if (abilities) then
		    for i, abilityFrame in ipairs(abilities) do
			    GarrisonFollowerPageAbility_StopAnimations(abilityFrame);
		    end
		end
	end
end

function GarrisonFollowerList:OnHide()
	self.followers = nil;

	self:UnregisterEvent("GARRISON_FOLLOWER_LIST_UPDATE");
	self:UnregisterEvent("GARRISON_FOLLOWER_REMOVED");
	self:UnregisterEvent("GARRISON_FOLLOWER_XP_CHANGED");
	self:UnregisterEvent("GARRISON_FOLLOWER_UPGRADED");
	self:UnregisterEvent("GARRISON_FOLLOWER_DURABILITY_CHANGED");
	self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:UnregisterEvent("CURSOR_UPDATE");
end

function GarrisonFollowerList:FindFirstFollower(ignoreDBID)
	for i, index in ipairs(self.followersList) do
		if index ~= 0 and self.followers[self.followersList[i]].followerID ~= ignoreDBID then
			return index;
		end
	end
	return nil;
end

function GarrisonFollowerList:HasFollower(followerID)
	for i, index in ipairs(self.followersList) do
		if (index ~= 0 and (self.followers[index].followerID == followerID)) then
			return true;
		end
	end
	return false;
end

function GarrisonFollowerList:OnEvent(event, ...)
	if (event == "GARRISON_FOLLOWER_LIST_UPDATE" or event == "GARRISON_FOLLOWER_XP_CHANGED" or event == "GARRISON_FOLLOWER_DURABILITY_CHANGED") then
		local followerTypeID = ...;
		if (followerTypeID == self.followerType) then
			if (self.followerTab and self.followerTab.followerID and self.followerTab:IsVisible()) then
				self:ShowFollower(self.followerTab.followerID);
			end
			
			if (self:IsVisible()) then
				self:DirtyList();
				self:UpdateFollowers();
			end
			
			if (self.followerTab and self.followerTab.followerID and self.followerTab:IsVisible()) then
				if (C_Garrison.GetNumFollowers(self.followerType) >= GarrisonFollowerOptions[self.followerType].minFollowersForThreatCountersFrame) then
					self:ShowThreatCountersFrame();
				end
			end
		end
		return true;
	elseif (event == "GARRISON_FOLLOWER_REMOVED") then
		local followerTypeID = ...;
		if (followerTypeID == self.followerType) then
			if (self.followerTab and self.followerTab.followerID and self.followerTab:IsVisible() and not C_Garrison.GetFollowerInfo(self.followerTab.followerID) and self.followers) then
				-- viewed follower got removed, pick someone else
				local ignoreFollowerDBID = self.followerTab.followerID;
				local index = self:FindFirstFollower(ignoreFollowerDBID);
				if (index and index ~= 0) then
					self:ShowFollower(self.followers[index].followerID);
				else
					self:ShowFollower(0);
				end
			end
			if (self:IsVisible()) then
				self:DirtyList();
				self:UpdateFollowers();
			end
		end
		return true;
	elseif (event == "GARRISON_FOLLOWER_UPGRADED") then
		if ( self.followerTab and self.followerTab.followerID and self.followerTab:IsVisible() ) then
			local followerID = ...;
			if ( followerID == self.followerTab.followerID ) then
				self.followerTab.ModelCluster.Child.Model[1]:SetSpellVisualKit(6375);	-- level up visual;
				PlaySound("UI_Garrison_CommandTable_Follower_LevelUp");
			end
		end
	elseif (event == "CURRENT_SPELL_CAST_CHANGED" or event == "CURSOR_UPDATE") then
		if (self.followerTab and self.followerTab.followerID and self:IsVisible()) then
			local followerID = self.followerTab.followerID;
			local followerInfo = C_Garrison.GetFollowerInfo(followerID);
			if (followerInfo) then
				followerInfo.abilities = C_Garrison.GetFollowerAbilities(followerID);
				self:UpdateValidSpellHighlight(followerID, followerInfo);
			end
		end
	end

	return false;
end


GarrisonMissionFollowerDurabilityMixin = { }

function GarrisonMissionFollowerDurabilityMixin:SetDurability(durability, maxDurability, durabilityLoss)
	local heartWidth = 13;
	local spacing = 2;

	self.durabilityVal = durability;
	self.maxDurabilityVal = maxDurability;
	self.durabilityLossVal = durabilityLoss;

	durability = Clamp(durability, 0, maxDurability);
	durabilityLoss = Clamp(durabilityLoss or 0, 0, durability);
	durability = durability - durabilityLoss;
	while ((self.durability and #self.durability or 0) < maxDurability) do
		local durabilityTexture = self:CreateTexture(nil, "ARTWORK", "GarrisonMissionFollowerButtonDurabilityTemplate");
		durabilityTexture:ClearAllPoints();
		if (#self.durability == 1) then
			durabilityTexture:SetPoint("TOPLEFT");
		else
			durabilityTexture:SetPoint("TOPLEFT", self.durability[#self.durability - 1], "TOPRIGHT", spacing, 0);
		end
	end

	for i = 1, durability do
		self.durability[i]:Show();
		self.durability[i]:SetAtlas("GarrisonTroops-Health");
		self.durability[i]:SetDesaturated(false);
	end
	for i = durability + 1, durability + durabilityLoss do
		self.durability[i]:Show();
		self.durability[i]:SetAtlas("GarrisonTroops-Health-Consume");
		self.durability[i]:SetDesaturated(false);
	end
	for i = durability + durabilityLoss + 1, maxDurability do
		self.durability[i]:Show();
		self.durability[i]:SetAtlas("GarrisonTroops-Health");
		self.durability[i]:SetDesaturated(true);
	end
	for i = maxDurability + 1, (self.durability and #self.durability or 0) do
		self.durability[i]:Hide();
	end

	local width = max(1, maxDurability * (heartWidth + spacing));
	self:SetWidth(width);
end

function GarrisonMissionFollowerDurabilityMixin:GetDurability()
	return self.durabilityVal, self.maxDurabilityVal, self.durabilityLossVal;
end

GarrisonFollowerListButton = { };

function GarrisonFollowerListButton:GetFollowerList()
	return self:GetParent():GetParent():GetParent();
end

GarrisonMissionFollowerOrCategoryListButtonMixin = { }

function GarrisonMissionFollowerOrCategoryListButtonMixin:GetFollowerList()
	return self:GetParent():GetParent():GetParent():GetParent();
end

function GarrisonFollowListEditBox_OnTextChanged(self)
	SearchBoxTemplate_OnTextChanged(self);
	self:GetParent():UpdateFollowers();
end

function GarrisonFollowerList:DoesFollowerMatchFilters(follower, searchString)
	if (not follower.isCollected and not self.showUncollected) then
		return false;
	end
	if (searchString ~= "" and not C_Garrison.SearchForFollower(follower.followerID, searchString)) then
		return false;
	end
	if (self.filter and not self.filter(follower)) then
		return false;
	end

	return true;
end

function GarrisonFollowerList:UpdateFollowers()

	if ( self.dirtyList ) then
		self.followers = C_Garrison.GetFollowers(self.followerType) or {};
		self.dirtyList = nil;
	end

	if ( not self.followers ) then
		return;
	end

	self.followersList = { };
	self.followersLabels = { };

	local searchString = "";
	if ( self.SearchBox ) then
		searchString = self.SearchBox:GetText();
	end
	
	local numActive = 0;
	local numTroops = 0;
	local numInactive = 0;
	local numUncollected = 0;
	for i = 1, #self.followers do
		if self:DoesFollowerMatchFilters(self.followers[i], searchString) then
			tinsert(self.followersList, i);
			if (not self.followers[i].isCollected) then
				numUncollected = numUncollected + 1;
			elseif (self.followers[i].isTroop) then
				numTroops = numTroops + 1;
			elseif (self.followers[i].status == GARRISON_FOLLOWER_INACTIVE) then
				numInactive = numInactive + 1;
			else
				numActive = numActive + 1;
			end
		end
	end

	if ( self.followerTab ) then
		local maxFollowers = C_Garrison.GetFollowerSoftCap(self.followerType);
		local numActiveFollowers = C_Garrison.GetNumActiveFollowers(self.followerType) or 0;
		if ( self.isLandingPage ) then
			local countColor = HIGHLIGHT_FONT_COLOR_CODE;
			if ( numActiveFollowers > maxFollowers ) then
				countColor = RED_FONT_COLOR_CODE;
			end
			self.followerTab.NumFollowers:SetText(countColor..numActiveFollowers.."/"..maxFollowers..FONT_COLOR_CODE_CLOSE);
			self.followerTab.FollowerText:SetText(GarrisonFollowerOptions[self.followerType].strings.FOLLOWER_COUNT_LABEL);
		else
			local countColor = NORMAL_FONT_COLOR_CODE;
			if ( numActiveFollowers > maxFollowers ) then
				countColor = RED_FONT_COLOR_CODE;
			end
			self.followerTab.NumFollowers:SetText(format(GarrisonFollowerOptions[self.followerType].strings.FOLLOWER_COUNT_STRING, countColor, numActiveFollowers, maxFollowers, FONT_COLOR_CODE_CLOSE));
		end
	end

	GarrisonFollowerList_SortFollowers(self);

	if (GarrisonFollowerOptions[self.followerType].showCategoriesInFollowerList) then
		-- The sort above will yield the following sort order: Active followers, troops, inactive followers. Insert new entries for the appropriate
		-- category labels at the correct locations. Category labels will have "followerID" set to 0.

	    local additionalOffset = 0;

		additionalOffset = additionalOffset + 1;
		tinsert(self.followersList, 0 + additionalOffset, 0);
		self.followersLabels[0 + additionalOffset] = FOLLOWERLIST_LABEL_CHAMPIONS;

		additionalOffset = additionalOffset + 1;
		tinsert(self.followersList, numActive + additionalOffset, 0);
		self.followersLabels[numActive + additionalOffset] = FOLLOWERLIST_LABEL_TROOPS;

	    if ( numInactive > 0 ) then
		    additionalOffset = additionalOffset + 1;
		    tinsert(self.followersList, numActive + numTroops + additionalOffset, 0);
		    self.followersLabels[numActive + numTroops + additionalOffset] = FOLLOWERLIST_LABEL_INACTIVE;
	    end
		if ( numUncollected > 0 ) then
		    additionalOffset = additionalOffset + 1;
			tinsert(self.followersList, numActive + numTroops + numInactive + additionalOffset, 0)
		    self.followersLabels[numActive + numTroops + numInactive + additionalOffset] = FOLLOWERLIST_LABEL_UNCOLLECTED;
		end
	end
	self:UpdateData();
end

function GarrisonFollowerList_GetTopButton(self, offset)
	local followerFrame = self;
	local buttonHeight = followerFrame.listScroll.buttonHeight;
	local expandedFollower = followerFrame.expandedFollower;
	local followers = followerFrame.followers;
	local sortedList = followerFrame.followersList;
	local totalHeight = 0;
	for i = 1, #sortedList do
		local height;
		if ( sortedList[i] == 0 ) then
			height = CATEGORY_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
		elseif ( followers[sortedList[i]].followerID == expandedFollower ) then
			height = followerFrame.expandedFollowerHeight;
		else
			height = FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
		end
		totalHeight = totalHeight + height;
		if ( totalHeight > offset ) then
			return i - 1, height + offset - totalHeight;
		end
	end

	--We're scrolled completely off the bottom
	return #followers, 0;
end

function GarrisonFollowerList_SetButtonMode(followerList, button, mode)
	if (mode == "CATEGORY") then
		followerList:CollapseButton(button.Follower);
		button:SetHeight(CATEGORY_BUTTON_HEIGHT);
	else
		button:SetHeight(FOLLOWER_BUTTON_HEIGHT);
	end

	button.mode = mode;
	button.Follower:SetShown(mode == "FOLLOWER");
	button.Category:SetShown(mode == "CATEGORY");
end

function GarrisonFollowerList:UpdateData()
	local followerFrame = self:GetParent();
	local followers = self.followers;
	local followersList = self.followersList;
	local categoryLabels = self.followersLabels;
	local numFollowers = #followersList;
	local scrollFrame = self.listScroll;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	local showCounters = self.showCounters;
	local canExpand = self.canExpand;
	local totalHeight = -FOLLOWER_LIST_BUTTON_INITIAL_OFFSET;

	for i = 1, numButtons do
		local button = buttons[i];
		local index = offset + i; -- adjust index
		if ( index <= numFollowers and followersList[index] == 0 ) then
			GarrisonFollowerList_SetButtonMode(self, button, "CATEGORY");
			button.Category:SetText(categoryLabels[index]);
			button:Show();
		elseif ( index <= numFollowers ) then
			local follower = followers[followersList[index]];

			GarrisonFollowerList_SetButtonMode(self, button, "FOLLOWER");
			button.Follower.DurabilityFrame:SetShown(follower.isTroop);

			button.Follower.id = follower.followerID;
			button.Follower.info = follower;
			button.Follower.Name:SetText(follower.name);
			button.Follower.Class:SetAtlas(follower.classAtlas);
			button.Follower.Status:SetText(follower.status);
			if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then
				button.Follower.Status:SetTextColor(1, 0.1, 0.1);
			else
				button.Follower.Status:SetTextColor(0.698, 0.941, 1);
			end
			button.Follower.PortraitFrame:SetupPortrait(follower);

			local countersAreaWidth = GarrisonFollowerButton_UpdateCounters(self:GetParent(), button.Follower, follower, showCounters, followerFrame.lastUpdate);

			if ( follower.isCollected ) then
				-- have this follower
				button.Follower.isCollected = true;
				button.Follower.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				button.Follower.Class:SetDesaturated(false);
				button.Follower.Class:SetAlpha(0.2);
				button.Follower.PortraitFrame.PortraitRingQuality:Show();
				button.Follower.PortraitFrame.Portrait:SetDesaturated(false);
				if ( follower.status == GARRISON_FOLLOWER_INACTIVE ) then
					button.Follower.PortraitFrame.PortraitRingCover:Show();
					button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.5);
					button.Follower.BusyFrame:Show();
					button.Follower.BusyFrame.Texture:SetColorTexture(unpack(GARRISON_FOLLOWER_INACTIVE_COLOR));
				elseif ( follower.status ) then
					button.Follower.PortraitFrame.PortraitRingCover:Show();
					button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.5);
					button.Follower.BusyFrame:Show();
					button.Follower.BusyFrame.Texture:SetColorTexture(unpack(GARRISON_FOLLOWER_BUSY_COLOR));
					-- get time remaining for follower
					if ( follower.status == GARRISON_FOLLOWER_ON_MISSION ) then
						if (follower.isMaxLevel) then
							button.Follower.Status:SetText(C_Garrison.GetFollowerMissionTimeLeft(follower.followerID));
						else
							button.Follower.Status:SetFormattedText(GARRISON_FOLLOWER_ON_MISSION_WITH_DURATION, C_Garrison.GetFollowerMissionTimeLeft(follower.followerID));
						end
					end
				else
					button.Follower.PortraitFrame.PortraitRingCover:Hide();
					button.Follower.BusyFrame:Hide();
				end
				if ( canExpand ) then
					button.Follower.DownArrow:SetAlpha(1);
				else
					button.Follower.DownArrow:SetAlpha(0);
				end
				-- adjust text position if we have additional text to show below name
				if (follower.isMaxLevel or follower.status or follower.isTroop) then
					button.Follower.Name:SetPoint("LEFT", button.Follower.PortraitFrame, "LEFT", 66, 8);
				else
					button.Follower.Name:SetPoint("LEFT", button.Follower.PortraitFrame, "LEFT", 66, 0);
				end
				-- show iLevel for max level followers	
				if (ShouldShowILevelInFollowerList(follower)) then
					button.Follower.ILevel:SetText(ITEM_LEVEL_ABBR.." "..follower.iLevel);
					button.Follower.ILevel:Show();
					if (button.Follower.DurabilityFrame:IsShown()) then
						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.DurabilityFrame, "TOPRIGHT", 4, 0);
					else
						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "TOPRIGHT", 4, 0);
					end
				else
					button.Follower.ILevel:SetText(nil);
					button.Follower.ILevel:Hide();
					if (button.Follower.DurabilityFrame:IsShown()) then
						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.DurabilityFrame, "TOPRIGHT", 0, 0);
					else
						button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "TOPRIGHT", 0, 0);
					end
				end
				button.Follower.Status:SetPoint("RIGHT", -countersAreaWidth, 0);

				if (follower.xp == 0 or follower.levelXP == 0) then 
					button.Follower.XPBar:Hide();
				else
					button.Follower.XPBar:Show();
					button.Follower.XPBar:SetWidth((follower.xp/follower.levelXP) * GARRISON_FOLLOWER_LIST_BUTTON_FULL_XP_WIDTH);
				end
			else
				-- don't have this follower
				button.Follower.isCollected = nil;
				button.Follower.Name:SetTextColor(0.25, 0.25, 0.25);
				button.Follower.ILevel:SetText(nil);
				button.Follower.Status:SetPoint("TOPLEFT", button.Follower.ILevel, "TOPRIGHT", 0, 0);
				button.Follower.Class:SetDesaturated(true);
				button.Follower.Class:SetAlpha(0.1);
				button.Follower.PortraitFrame.PortraitRingQuality:Hide();
				button.Follower.PortraitFrame.Portrait:SetDesaturated(true);
				button.Follower.PortraitFrame.PortraitRingCover:Show();
				button.Follower.PortraitFrame.PortraitRingCover:SetAlpha(0.6);
				button.Follower.PortraitFrame:SetQuality(0);
				button.Follower.XPBar:Hide();
				button.Follower.DownArrow:SetAlpha(0);
				button.Follower.BusyFrame:Hide();
			end

			if (canExpand and button.Follower.id == self.expandedFollower and button.Follower.id == followerFrame.selectedFollower) then
				self:ExpandButton(button.Follower, self);
			else
				self:CollapseButton(button.Follower);
			end
			button:SetHeight(button.Follower:GetHeight());
			if ( button.Follower.id == followerFrame.selectedFollower ) then
				button.Follower.Selection:Show();
			else
				button.Follower.Selection:Hide();
			end

			if (follower.isTroop) then
				button.Follower.DurabilityFrame:SetDurability(follower.durability, follower.maxDurability);
			end

			button:Show();
		else
			button:Hide();
		end
	end
	
	-- calculate the total height to pass to the HybridScrollFrame
	for i = 1, numFollowers do
		if (followersList[i] == 0) then
			totalHeight = totalHeight + CATEGORY_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
		else
			totalHeight = totalHeight + FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET;
		end
	end
	if (self.expandedFollower) then
		totalHeight = totalHeight + self.expandedFollowerHeight - (FOLLOWER_BUTTON_HEIGHT - FOLLOWER_LIST_BUTTON_OFFSET);
	end

	local displayedHeight = numButtons * scrollFrame.buttonHeight;
	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);

	followerFrame.lastUpdate = GetTime();
end

function GarrisonFollowerButton_AddCounterButtons(button, follower, numShown, counters, lastUpdate)
	if (not counters) then
		return numShown;
	end
	for i = 1, min(4 - numShown, #counters) do	-- max of 4 icons
		numShown = numShown + 1;
		GarrisonFollowerButton_SetCounterButton(button, follower.followerID, numShown, counters[i], lastUpdate, follower.followerTypeID);
	end

	return numShown;
end

local function GetFollowerButtonCounterSpacings(followerTypeID)
	local options = GarrisonFollowerOptions[followerTypeID];
	local numPerRow = options.followerListCounterNumPerRow;
	local innerSpacing = options.followerListCounterInnerSpacing;
	local outerSpacingX = options.followerListCounterOuterSpacingX;
	local outerSpacingY = options.followerListCounterOuterSpacingY;
	local scale = options.followerListCounterScale;

	return numPerRow, innerSpacing, outerSpacingX, outerSpacingY, scale;
end

function GarrisonFollowerButton_UpdateCounters(frame, button, follower, showCounters, lastUpdate)
	local numShown = 0;
	if ( showCounters and button.isCollected and follower.status ~= GARRISON_FOLLOWER_INACTIVE ) then
		--if a mission is being viewed, show mechanics this follower can counter
		--for followers you have, show counters if they are or could be on the mission
		local counters = frame.followerCounters and frame.followerCounters[follower.followerID];
		if ( counters ) then
			if ( follower.followerTypeID == LE_FOLLOWER_TYPE_SHIPYARD_6_2 ) then
				table.sort(counters, function(left, right) return left.factor > right.factor; end);
			end
		end

		numShown = GarrisonFollowerButton_AddCounterButtons(button, follower, numShown, counters, lastUpdate);

		local traits = frame.followerTraits and frame.followerTraits[follower.followerID];
		numShown = GarrisonFollowerButton_AddCounterButtons(button, follower, numShown, traits, lastUpdate);

		local spells = frame.followerSpells and frame.followerSpells[follower.followerID];
		numShown = GarrisonFollowerButton_AddCounterButtons(button, follower, numShown, spells, lastUpdate);

	end
	local numPerRow, innerSpacing, outerSpacingX, outerSpacingY, scale = GetFollowerButtonCounterSpacings(follower.followerTypeID);
	button.Counters[1]:ClearAllPoints();
	if ( numShown <= numPerRow ) then
		local collapsedButtonHeight = 46;
		button.Counters[1]:SetPoint("RIGHT", button.Counters[1]:GetParent(), "TOPRIGHT", -outerSpacingX, -collapsedButtonHeight/2);
	else
		button.Counters[1]:SetPoint("TOPRIGHT", -outerSpacingX, -outerSpacingY);
	end
	for i = numShown + 1, #button.Counters do
		button.Counters[i].info = nil;
		button.Counters[i]:Hide();
	end

	-- return the counters area width
	if (numShown == 0) then
		return 0;
	elseif (numShown == 1) then
		return 2 * outerSpacingX + button.Counters[1]:GetWidth() * scale;
	else
		return 2 * outerSpacingX + innerSpacing + (2 * button.Counters[1]:GetWidth() * scale);
	end
end

function GarrisonFollowerButton_SetCounterButton(button, followerID, index, info, lastUpdate, followerTypeID)
	local counter = button.Counters[index];
	if ( not counter ) then
		button.Counters[index] = CreateFrame("Frame", nil, button, "GarrisonMissionAbilityCounterTemplate");
		counter = button.Counters[index];
	end
	local numPerRow, innerSpacing, outerSpacingX, outerSpacingY, scale = GetFollowerButtonCounterSpacings(followerTypeID);
	if ((index - 1) % numPerRow ~= 0) then
		counter:SetPoint("RIGHT", button.Counters[index-1], "LEFT", -innerSpacing, 0);
	else
		counter:SetPoint("TOP", button.Counters[index-2], "BOTTOM", 0, -innerSpacing);
	end
	counter:SetScale(scale);
	counter.info = info;

	counter.followerTypeID = followerTypeID;
	if ( info.traitID ) then
		counter.tooltip = nil;
		counter.info.showCounters = false;
		counter.Icon:SetTexture(info.icon);
		counter.Border:Hide();

		if ( GarrisonFollowerAbilities_IsNew(lastUpdate, followerID, info.traitID, GARRISON_FOLLOWER_ABILITY_TYPE_TRAIT ) ) then
			counter.AbilityFeedbackGlowAnim.traitID = info.traitID;
			counter.AbilityFeedbackGlowAnim:Play();
		elseif ( counter.AbilityFeedbackGlowAnim.traitID ~= info.traitID ) then
			counter.AbilityFeedbackGlowAnim.traitID = nil;
			counter.AbilityFeedbackGlowAnim:Stop();
		end
	elseif (info.spellID) then
		counter.tooltip = nil;
		counter.info.showCounters = false;
		counter.Icon:SetTexture(select(3, GetSpellInfo(info.spellID)));
		counter.AbilityFeedbackGlowAnim:Stop();
		counter.Border:Hide();
	else
		counter.tooltip = info.name;
		counter.info.showCounters = true;
		if (GarrisonFollowerOptions[followerTypeID].displayCounterAbilityInPlaceOfMechanic and info.counterID) then
			local abilityInfo = C_Garrison.GetFollowerAbilityInfo(info.counterID);
			counter.Icon:SetTexture(abilityInfo.icon);
			counter.Border:SetShown(ShouldShowFollowerAbilityBorder(followerTypeID, abilityInfo));
		else
			counter.Icon:SetTexture(info.icon);
			counter.Border:Show();

			if ( counter.info.factor <= GARRISON_HIGH_THREAT_VALUE and followerTypeID == LE_FOLLOWER_TYPE_SHIPYARD_6_2 ) then
				counter.Border:SetAtlas("GarrMission_WeakEncounterAbilityBorder");
			else
				counter.Border:SetAtlas("GarrMission_EncounterAbilityBorder");
			end		
		end

		counter.AbilityFeedbackGlowAnim.traitID = nil;
		counter.AbilityFeedbackGlowAnim:Stop();
	end
	counter:Show();
end

function GarrisonFollowerList:ExpandButton(button, followerListFrame)
	local abHeight = self:ExpandButtonAbilities(button, false);
	if (abHeight == -1) then
		return;
	end
	
	button.UpArrow:Show();
	button.DownArrow:Hide();
	button:SetHeight(51 + abHeight);
	followerListFrame.expandedFollowerHeight = 51 + abHeight + 6;
end

function GarrisonFollowerList:ExpandButtonAbilities(button, traitsFirst)
	if ( not button.isCollected ) then
		return -1;
	end

	local abHeight = 0;
	if (not button.info.abilities) then
		button.info.abilities = C_Garrison.GetFollowerAbilities(button.info.followerID);
	end

	local buttonCount = 0;
	for i=1, #button.info.abilities do
		if ( traitsFirst == button.info.abilities[i].isTrait and button.info.abilities[i].icon ) then
			buttonCount = buttonCount + 1;
			abHeight = abHeight + GarrisonFollowerButton_AddAbility(button, buttonCount, button.info.abilities[i], self.followerType);
		end
	end
	for i=1, #button.info.abilities do
		if ( traitsFirst ~= button.info.abilities[i].isTrait and button.info.abilities[i].icon ) then
			buttonCount = buttonCount + 1;
			abHeight = abHeight + GarrisonFollowerButton_AddAbility(button, buttonCount, button.info.abilities[i], self.followerType);
		end
	end

	for i=(#button.info.abilities + 1), #button.Abilities do
		button.Abilities[i]:Hide();
	end
	if (abHeight > 0) then
		abHeight = abHeight + 8;
		button.AbilitiesBG:Show();
		button.AbilitiesBG:SetHeight(abHeight);
	else
		button.AbilitiesBG:Hide();
	end
	return abHeight;
end

function GarrisonFollowerButton_AddAbility(self, index, ability, followerType)
	if (not self.Abilities[index]) then
		self.Abilities[index] = CreateFrame("Frame", nil, self, "GarrisonFollowerListButtonAbilityTemplate");
		self.Abilities[index]:SetPoint("TOPLEFT", self.Abilities[index-1], "BOTTOMLEFT", 0, -2);
	end
	local Ability = self.Abilities[index];
	Ability.followerTypeID = followerType;
	Ability.abilityID = ability.id;
	Ability.Name:SetText(ability.name);
	Ability.Icon:SetTexture(ability.icon);
	Ability.tooltip = ability.description;
	Ability:Show();
	return Ability:GetHeight() + 3;
end

function GarrisonFollowerList:CollapseButton(button)
	self:CollapseButtonAbilities(button);
	button.UpArrow:Hide();
	button.DownArrow:Show();
	button:SetHeight(FOLLOWER_BUTTON_HEIGHT);
end

function GarrisonFollowerList:CollapseButtonAbilities(button)
	button.AbilitiesBG:Hide();
	for i=1, #button.Abilities do
		button.Abilities[i]:Hide();
	end
end

function GarrisonFollowerListButton_OnClick(self, button)
	if (self.mode == "CATEGORY") then
		return;
	end

	local followerList = self:GetFollowerList();
	local followerFrame = followerList.listScroll.followerFrame;
	if ( button == "LeftButton" ) then
		PlaySound("UI_Garrison_CommandTable_SelectFollower");
		followerFrame.selectedFollower = self.id;

		if ( self.isCollected and followerList.canCastSpellsOnFollowers and SpellCanTargetGarrisonFollower(self.id) ) then
			GarrisonFollower_DisplayUpgradeConfirmation(self.id);
		end
		
		if ( followerList.canExpand ) then
			if ( self.isCollected ) then
				if (followerList.expandedFollower == self.id) then
					followerList.expandedFollower = nil;
					PlaySound("UI_Garrison_CommandTable_FollowerAbilityClose");
				else
					followerList.expandedFollower = self.id;
					PlaySound("UI_Garrison_CommandTable_FollowerAbilityOpen");
				end
			else
				followerList.expandedFollower = nil;
				PlaySound("UI_Garrison_CommandTable_FollowerAbilityClose");
			end
		else
			if ( not followerList.canExpand and followerList.expandedFollower ~= self.id ) then
				followerList.expandedFollower = nil;
			end
		end
		followerList:UpdateData();
		if ( followerList.followerTab ) then
			followerList:ShowFollower(self.id);
		end
		CloseDropDownMenus();
	-- Don't show right click follower menu in landing page
	elseif ( button == "RightButton" and not followerList.isLandingPage) then
		if ( self.isCollected ) then
			if ( followerList.OptionDropDown.followerID ~= self.id ) then
				CloseDropDownMenus();
			end
			followerList.OptionDropDown.followerID = self.id;
			ToggleDropDownMenu(1, nil, followerList.OptionDropDown, "cursor", 0, 0);
		else
			followerList.OptionDropDown.followerID = nil;
			CloseDropDownMenus();
		end
	end
end

function GarrisonFollowerListButton_OnModifiedClick(self, button)
	if (self.mode == "CATEGORY") then
		return;
	end
	if ( IsModifiedClick("CHATLINK") ) then
		local followerLink;
		if (self.info.isCollected) then
			followerLink = C_Garrison.GetFollowerLink(self.info.followerID);
		else
			followerLink = C_Garrison.GetFollowerLinkByID(self.info.followerID);
		end
		
		if ( followerLink ) then
			ChatEdit_InsertLink(followerLink);
		end
	end
end

---------------------------------------------------------------------------------
--- Follower filtering and searching                                          ---
---------------------------------------------------------------------------------
function GarrisonFollowerList:DirtyList()
	self.dirtyList = true;
end

local statusPriority = {
	[GARRISON_FOLLOWER_IN_PARTY] = 1,
	[GARRISON_FOLLOWER_WORKING] = 2,
	[GARRISON_FOLLOWER_ON_MISSION] = 3,
	[GARRISON_FOLLOWER_COMBAT_ALLY] = 4,
	[GARRISON_FOLLOWER_EXHAUSTED] = 5,
	[GARRISON_FOLLOWER_INACTIVE] = 6,
}

function GarrisonFollowerList_InitializeDefaultSort(self, followers)
	local mainFrame = self:GetParent();

	for i = 1, #followers do
		local follower = followers[i];
		follower.sortStatus = follower.status;
		-- treat IN_PARTY status as no status
		if (follower.sortStatus == GARRISON_FOLLOWER_IN_PARTY ) then
			follower.sortStatus = nil;
		end
		follower.sortILevel = follower.isMaxLevel and follower.iLevel or 0;	-- item level is only relevant at max level for this sort
	end
end

-- sorting: level > item level > quality
function GarrisonFollowerList_DefaultSort(self, follower1, follower2)
	if ( follower1.sortStatus and not follower2.sortStatus ) then
		return false;
	elseif ( not follower1.sortStatus and follower2.sortStatus ) then
		return true;
	end
	if ( follower1.sortStatus ~= follower2.sortStatus ) then
		return statusPriority[follower1.sortStatus] < statusPriority[follower2.sortStatus];
	end

	if (follower1.level ~= follower2.level) then
		return follower1.level > follower2.level;
	end

	if (follower1.sortILevel ~= follower2.sortILevel) then
		return follower1.sortILevel > follower2.sortILevel;
	end

	if ( follower1.quality ~= follower2.quality ) then
		return follower1.quality > follower2.quality;
	end

	return nil;
end

function GarrisonFollowerList_InitializeDefaultMissionSort(self, followers)
	local mainFrame = self:GetParent();

	local mentorLevel = mainFrame.MissionTab.MissionPage.mentorLevel or 0;
	local mentorItemLevel = mainFrame.MissionTab.MissionPage.mentorItemLevel or 0;

	local missionID = mainFrame:HasMission() and mainFrame.MissionTab.MissionPage.missionInfo.missionID or nil;

	if (missionID) then
		for i = 1, #followers do
			local follower = followers[i];
			follower.sortStatus = follower.status;
			-- treat IN_PARTY status as no status
			if (follower.sortStatus == GARRISON_FOLLOWER_IN_PARTY ) then
				follower.sortStatus = nil;
			end
			local relevantForMission = not follower.sortStatus and follower.isCollected;
			follower.sortNumCounters = relevantForMission and mainFrame.followerCounters[follower.followerID] and #mainFrame.followerCounters[follower.followerID] or 0;
			follower.sortNumTraits = relevantForMission and mainFrame.followerTraits[follower.followerID] and #mainFrame.followerTraits[follower.followerID] or 0;
			follower.sortLevel = max(follower.level, mentorLevel);
			follower.sortILevel = follower.isMaxLevel and max(follower.iLevel, mentorItemLevel) or 0;	-- item level is only relevant at max level for this sort
		end
	end
end

-- sorting: level > item level > (num counters for mission) > (num traits for mission) > quality
function GarrisonFollowerList_DefaultMissionSort(self, follower1, follower2)

	if ( follower1.sortStatus and not follower2.sortStatus ) then
		return false;
	elseif ( not follower1.sortStatus and follower2.sortStatus ) then
		return true;
	end
	if ( follower1.sortStatus ~= follower2.sortStatus ) then
		return statusPriority[follower1.sortStatus] < statusPriority[follower2.sortStatus];
	end

	if (follower1.sortLevel ~= follower2.sortLevel) then
		return follower1.sortLevel > follower2.sortLevel;
	end

	if (follower1.sortILevel ~= follower2.sortILevel) then
		return follower1.sortILevel > follower2.sortILevel;
	end

	if (follower1.sortNumCounters ~= follower2.sortNumCounters) then
		return follower1.sortNumCounters > follower2.sortNumCounters;
	end

	if (follower1.sortNumTraits ~= follower2.sortNumTraits) then
		return follower1.sortNumTraits > follower2.sortNumTraits;
	end

	if ( follower1.quality ~= follower2.quality ) then
		return follower1.quality > follower2.quality;
	end

	return nil;
end

function GarrisonFollowerList_InitializePrioritizeSpecializationAbilityMissionSort(self, followers)
	local mainFrame = self:GetParent();

	local missionID = mainFrame:HasMission() and mainFrame.MissionTab.MissionPage.missionInfo.missionID or nil;

	if (missionID) then
		for i = 1, #followers do
			local follower = followers[i];
			follower.sortStatus = follower.status;
			-- treat IN_PARTY status as no status
			if (follower.sortStatus == GARRISON_FOLLOWER_IN_PARTY ) then
				follower.sortStatus = nil;
			end
			local relevantForMission = not follower.sortStatus and follower.isCollected and (C_Garrison.GetFollowerBiasForMission(missionID, follower.followerID) or -1) > -1;
			follower.sortNumCounters = relevantForMission and mainFrame.followerCounters[follower.followerID] and #mainFrame.followerCounters[follower.followerID] or 0;
			follower.sortNumTraits = relevantForMission and mainFrame.followerTraits[follower.followerID] and #mainFrame.followerTraits[follower.followerID] or 0;
			follower.sortHasSpecCounter = false;
			if (relevantForMission) then
				for i=1, follower.sortNumCounters do
					if (mainFrame.followerCounters[follower.followerID][i].isSpecialization) then
						follower.sortHasSpecCounter = true;
						break;
					end
				end
			end
		end
	end
end

-- sorting: hasSpecCounter > (num counters for mission) > (num traits for mission) > quality
function GarrisonFollowerList_PrioritizeSpecializationAbilityMissionSort(self, follower1, follower2)
	
	if ( follower1.sortStatus and not follower2.sortStatus ) then
		return false;
	elseif ( not follower1.sortStatus and follower2.sortStatus ) then
		return true;
	end
	if ( follower1.sortStatus ~= follower2.sortStatus ) then
		return statusPriority[follower1.sortStatus] < statusPriority[follower2.sortStatus];
	end

	if ( follower1.sortHasSpecCounter ~= follower2.sortHasSpecCounter ) then
		return follower1.sortHasSpecCounter;
	end
	
	if (follower1.sortNumCounters ~= follower2.sortNumCounters) then
		return follower1.sortNumCounters > follower2.sortNumCounters;
	end

	if (follower1.sortNumTraits ~= follower2.sortNumTraits) then
		return follower1.sortNumTraits > follower2.sortNumTraits;
	end

	if ( follower1.quality ~= follower2.quality ) then
		return follower1.quality > follower2.quality;
	end

	return nil;
end

function GarrisonFollowerList_SortFollowers(self)
	local followers = self.followers;
	local comparison = function(index1, index2)
		local follower1 = followers[index1];
		local follower2 = followers[index2];
		local follower1Active = follower1.status ~= GARRISON_FOLLOWER_INACTIVE;
		local follower2Active = follower2.status ~= GARRISON_FOLLOWER_INACTIVE;

		-- collected > troops > inactive is always the primary sort order; the category names rely on this.
		if ( follower1.isCollected ~= follower2.isCollected ) then
			return follower1.isCollected;
		end
		if ( follower1Active ~= follower2Active ) then
			return follower1Active;
		end
		if ( follower1.isTroop ~= follower2.isTroop ) then
			return follower2.isTroop;
		end

		-- run use-specific sort function
		if self.sortFunc then
			local result = self.sortFunc(self, follower1, follower2);
			if (result ~= nil) then
				return result;
			end
		end

		-- last resort; all else being equal sort by name, and then followerID
		local strCmpResult = strcmputf8i(follower1.name, follower2.name);
		if (strCmpResult ~= 0) then
			return strCmpResult < 0;
		end

		return follower1.followerID < follower2.followerID;
	end
	if (self.sortInitFunc) then
		self.sortInitFunc(self, self.followers);
	end
	table.sort(self.followersList, comparison);
end

---------------------------------------------------------------------------------
--- Models                                                                    ---
---------------------------------------------------------------------------------
function GarrisonMission_SetFollowerModel(modelFrame, followerID, displayID, showWeapon)
	if ( not displayID or displayID == 0 ) then
		modelFrame:ClearModel();
		modelFrame:Hide();
		modelFrame.followerID = nil;
		modelFrame.showWeapon = nil;
	else
		modelFrame:Show();
		modelFrame:SetDisplayInfo(displayID);
		modelFrame.followerID = followerID;
		modelFrame.showWeapon = showWeapon;
		GarrisonMission_SetFollowerModelItems(modelFrame);
	end
end

function GarrisonMission_SetFollowerModelItems(modelFrame)
	if ( modelFrame.followerID ) then
		modelFrame:UnequipItems();
		local follower =  C_Garrison.GetFollowerInfo(modelFrame.followerID);
		if ( modelFrame.showWeapon and follower and follower.isCollected ) then
			local modelItems = C_Garrison.GetFollowerModelItems(modelFrame.followerID);
			for i = 1, #modelItems do
				modelFrame:EquipItem(modelItems[i]);
			end
		end
	end
end

function GarrisonCinematicModelBase_OnLoad(self)
	self:RegisterEvent("UI_SCALE_CHANGED");
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
end

function GarrisonCinematicModelBase_OnEvent(self)
	self:RefreshCamera();
end

---------------------------------------------------------------------------------
--- Follower Page                                                             ---
---------------------------------------------------------------------------------
GARRISON_FOLLOWER_PAGE_HEIGHT_MULTIPLIER = .65;
GARRISON_FOLLOWER_PAGE_SCALE_MULTIPLIER = 1.3

function GarrisonFollowerPageItemButton_OnEvent(self, event)
	if ( not self:IsShown() and self.itemID ) then
		GarrisonFollowerPage_SetItem(self, self.itemID, self.itemLevel);
	end
end

function GarrisonFollowerPage_SetItem(itemFrame, itemID, itemLevel)
	if ( itemID and itemID > 0 ) then
		itemFrame.itemID = itemID;
		itemFrame.itemLevel = itemLevel;
		local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID);
		if ( itemName ) then
			itemFrame.Icon:SetTexture(itemTexture);
			itemFrame.Name:SetTextColor(GetItemQualityColor(itemQuality));
			itemFrame.ItemLevel:SetFormattedText(GARRISON_FOLLOWER_ITEM_LEVEL, itemLevel);
			itemFrame:Show();			
			return;
		end
	else
		itemFrame.itemID = nil;
		itemFrame.itemLevel = nil;
	end
	itemFrame:Hide();
end

function GarrisonFollowerList:UpdateValidSpellHighlight(followerID, followerInfo)
	self.followerTab:UpdateValidSpellHighlight(followerID, followerInfo);
end

function GarrisonFollowerList:ShowFollower(followerID)
	local followerList = self;
	self.followerTab:ShowFollower(followerID, followerList);
end

function GarrisonFollowerList:SetSortFuncs(sortFunc, sortInitFunc)
	self.sortFunc = sortFunc;
	self.sortInitFunc = sortInitFunc;
end

function GarrisonFollowerPage_AnchorAbility(abilityFrame, lastAnchor, headerString, isLandingPage)
	abilityFrame:ClearAllPoints();
	if ( lastAnchor ) then
		abilityFrame:SetPoint("LEFT", lastAnchor);
		abilityFrame:SetPoint("TOP", lastAnchor, "BOTTOM", 0, isLandingPage and 13 or 0);			
	else
		abilityFrame:SetPoint("TOPLEFT", headerString, "BOTTOMLEFT", 2, isLandingPage and -5 or -12);
	end
	return abilityFrame;
end

function GarrisonFollowerPageModel_SpellCast_OnMouseDown(self, button)
	local followerList = self:GetParent().followerList;
	if ( button == "LeftButton" and followerList.canCastSpellsOnFollowers and SpellCanTargetGarrisonFollower(self.followerID) ) then
		-- no rotation if you can upgrade this follower
		local followerInfo = self.followerID and C_Garrison.GetFollowerInfo(self.followerID);
		if ( followerInfo and followerInfo.isCollected and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION ) then
			return true;
		end
	end
	return false;
end

function GarrisonFollowerPageModel_OnMouseDown(self, button)
	if (not GarrisonFollowerPageModel_SpellCast_OnMouseDown(self, button)) then
		Model_OnMouseDown(self, button);
	end
end

function GarrisonFollowerPageModel_SpellCast_OnMouseUp(self, button)
	local followerList = self:GetParent().followerList;
	if ( button == "LeftButton" and followerList.canCastSpellsOnFollowers and SpellCanTargetGarrisonFollower(self.followerID) ) then
		-- no rotation if you can upgrade this follower, bring up confirmation dialog
		if ( GarrisonFollower_DisplayUpgradeConfirmation(self.followerID) ) then
			return true;
		end
	end
	return false;
end

function GarrisonFollowerPageModel_OnMouseUp(self, button)
	if (not GarrisonFollowerPageModel_SpellCast_OnMouseUp(self, button)) then
		Model_OnMouseUp(self, button);
	end
end

function GarrisonFollowerPageModelUpgrade_OnLoad(self)
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
end

function GarrisonFollowerPageModelUpgrade_OnEvent(self, event)
	GarrisonFollowerPageModelUpgrade_Update(self);
end

function GarrisonFollowerPageModelUpgrade_Update(self)
	local followerID = self:GetParent().followerID;
	if ( SpellCanTargetGarrisonFollower(followerID) ) then
		local followerInfo = followerID and C_Garrison.GetFollowerInfo(followerID);
		if ( followerInfo and followerInfo.isCollected and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION and (not C_Garrison.TargetSpellHasFollowerTemporaryAbility() or C_Garrison.CanSpellTargetFollowerIDWithAddAbility(followerID)) ) then
			local isValidTarget = (followerInfo.isMaxLevel or not C_Garrison.TargetSpellHasFollowerItemLevelUpgrade());
			self.Text:SetShown(isValidTarget);
			self.Icon:SetShown(isValidTarget);
			self.TextInvalid:SetShown(not isValidTarget);
			self:Show();
			return;
		end
	end
	self:Hide();
end

function GarrisionFollowerPageUpgradeTarget_OnLoad(self)
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 5);
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
end

function GarrisionFollowerPageUpgradeTarget_OnEvent(self, event)
	if (event == "CURRENT_SPELL_CAST_CHANGED") then
		local followerID = self:GetParent().followerID;
		if ( SpellCanTargetGarrisonFollower(followerID) ) then
			local followerInfo = followerID and C_Garrison.GetFollowerInfo(followerID);
			if ( followerInfo and followerInfo.isCollected and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION and (followerInfo.isMaxLevel or not C_Garrison.TargetSpellHasFollowerItemLevelUpgrade()) ) then
				if ( not C_Garrison.TargetSpellHasFollowerTemporaryAbility() or C_Garrison.CanSpellTargetFollowerIDWithAddAbility(followerID) ) then
					self:Show();
					return;
				end
			end
		end
		self:Hide();
	end
end

function GarrisonFollower_DisplayUpgradeConfirmation(followerID)
	local followerInfo = followerID and C_Garrison.GetFollowerInfo(followerID);
	if ( followerInfo and followerInfo.isCollected and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION and (followerInfo.isMaxLevel or not C_Garrison.TargetSpellHasFollowerItemLevelUpgrade()) ) then
		local name = ITEM_QUALITY_COLORS[followerInfo.quality].hex..followerInfo.name..FONT_COLOR_CODE_CLOSE;
		if ( C_Garrison.TargetSpellHasFollowerTemporaryAbility() ) then
			if ( C_Garrison.CanSpellTargetFollowerIDWithAddAbility(followerID) ) then
				StaticPopup_Show("CONFIRM_FOLLOWER_TEMPORARY_ABILITY", name, nil, followerID);
				return true;
			end
		else
			local text;
			local hasReroll, rerollAbilities, rerollTraits = C_Garrison.TargetSpellHasFollowerReroll();
			if ( hasReroll ) then
				if ( rerollAbilities and rerollTraits ) then
					text = CONFIRM_GARRISON_FOLLOWER_REROLL_ALL;
				elseif ( rerollAbilities ) then
					text = CONFIRM_GARRISON_FOLLOWER_REROLL_ABILITIES;
				else
					text = CONFIRM_GARRISON_FOLLOWER_REROLL_TRAITS;
				end
				text = string.format(text, name);
			else
				text = string.format(CONFIRM_GARRISON_FOLLOWER_UPGRADE, name);
			end
			StaticPopup_Show("CONFIRM_FOLLOWER_UPGRADE", text, nil, followerID);
			return true;
		end
	end
	return false;
end


--- GarrisonFollowerTab

GarrisonFollowerTabMixin = { }

function GarrisonFollowerTabMixin:UpdateValidSpellHighlightOnAbilityFrame(abilityFrame, followerID, followerInfo, hideCounters)
	local ability = abilityFrame.ability;
	if ( followerInfo and followerInfo.isCollected 
		and followerInfo.status ~= GARRISON_FOLLOWER_WORKING and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION 
		and ability and SpellCanTargetGarrisonFollowerAbility(followerID, ability.id) ) then
		abilityFrame.IconButton.ValidSpellHighlight:Show();
		if ( not ability.temporary ) then
			abilityFrame.IconButton.OldIcon:SetTexture(ability.icon);
			abilityFrame.IconButton.OldIcon:SetAlpha(0);
		end
	else
		abilityFrame.IconButton.ValidSpellHighlight:Hide();
	end
end

function GarrisonFollowerTabMixin:UpdateValidSpellHighlightOnEquipmentFrame(equipmentFrame, followerID, followerInfo)
	local abilityID = equipmentFrame.abilityID;
	if ( followerInfo and followerInfo.isCollected 
		and followerInfo.status ~= GARRISON_FOLLOWER_WORKING and followerInfo.status ~= GARRISON_FOLLOWER_ON_MISSION 
		and abilityID and SpellCanTargetGarrisonFollowerAbility(followerID, abilityID) 
		and not equipmentFrame.Lock:IsShown()) then
		equipmentFrame.ValidSpellHighlight:Show();
	else
		equipmentFrame.ValidSpellHighlight:Hide();
	end
end


function GarrisonFollowerTabMixin:UpdateValidSpellHighlight(followerID, followerInfo)
	local abilities = self.AbilitiesFrame.Abilities;
	if (self.AbilitiesFrame.Abilities) then
		for i, abilityFrame in ipairs(self.AbilitiesFrame.Abilities) do
			self:UpdateValidSpellHighlightOnAbilityFrame(abilityFrame, followerID, followerInfo);
		end
	end
	if (self.AbilitiesFrame.Equipment) then
		for i, equipmentFrame in ipairs(self.AbilitiesFrame.Equipment) do
			self:UpdateValidSpellHighlightOnEquipmentFrame(equipmentFrame, followerID, followerInfo);
		end
	end
end

function GarrisonFollowerTabMixin:SetupXPBar(followerInfo)
	if ( followerInfo.isCollected ) then
		-- Follower cannot be upgraded anymore
		if (GarrisonFollowerOptions[followerInfo.followerTypeID].followerPaneHideXP or followerInfo.isTroop or followerInfo.isMaxLevel and followerInfo.quality >= GARRISON_FOLLOWER_MAX_UPGRADE_QUALITY) then
			self.XPLabel:Hide();
			self.XPBar:Hide();
			self.XPText:Hide();
			self.XPText:SetText("");
		else
			if (followerInfo.isMaxLevel) then
				self.XPLabel:SetText(GARRISON_FOLLOWER_XP_UPGRADE_STRING);
			else
				self.XPLabel:SetText(GARRISON_FOLLOWER_XP_STRING);
			end
			self.XPLabel:SetWidth(0);
			self.XPLabel:SetFontObject("GameFontHighlight");
			self.XPLabel:SetPoint("TOPRIGHT", self.XPText, "BOTTOMRIGHT", 0, -4);
			self.XPLabel:Show();
			-- If the XPLabel text does not fit within 100 pixels, shrink the font. If it wraps to 2 lines, move the text up.
			if (self.XPLabel:GetWidth() > 100) then
				self.XPLabel:SetWidth(100);
				self.XPLabel:SetFontObject("GameFontWhiteSmall");
				if (self.XPLabel:GetNumLines() > 1) then
					self.XPLabel:SetPoint("TOPRIGHT", self.XPText, "BOTTOMRIGHT", -1, 0);
				end
			end
			self.XPBar:Show();
			self.XPBar:SetMinMaxValues(0, followerInfo.levelXP);
			self.XPBar.Label:SetFormattedText(GARRISON_FOLLOWER_XP_BAR_LABEL, BreakUpLargeNumbers(followerInfo.xp), BreakUpLargeNumbers(followerInfo.levelXP));
			self.XPBar:SetValue(followerInfo.xp);
			local xpLeft = followerInfo.levelXP - followerInfo.xp;
			self.XPText:SetText(format(GARRISON_FOLLOWER_XP_LEFT, xpLeft));
			self.XPText:Show();
		end
	else
		self.XPText:Hide();
		self.XPLabel:Hide();
		self.XPBar:Hide();
	end
end


local positionData = {
	[1] = {
		[1] = { scale=1.0,		facing=0.2,		x=0,	y=0 }
	},
	[2] = {
		[1] = { scale=1.0,		facing=0,		x=-60,	y=0 },
		[2] = { scale=1.0/0.95,	facing=0.4,		x=20,	y=30 },
	},
	[3] = {
		[1] = { scale=1.0/0.8,	facing=0,		x=-10,	y=-22 },
		[2] = { scale=1.0/0.7,	facing=-0.4,	x=-60,	y=58 },
		[3] = { scale=1.0/0.6,	facing=0.4,		x=35,	y=98 },
	},
	[4] = {
		[1] = { scale=1.0/0.8,	facing=0,		x=-10,	y=-22 },
		[2] = { scale=1.0/0.7,	facing=-0.4,	x=-60,	y=58 },
		[3] = { scale=1.0/0.6,	facing=0.4,		x=35,	y=98 },
		[4] = { scale=1.0/0.5,	facing=0.5,		x=-20,	y=158 },
	},
	[5] = {
		[1] = { scale=1.0/0.8,	facing=0,		x=-10,	y=-22 },
		[2] = { scale=1.0/0.7,	facing=-0.4,	x=-60,	y=58 },
		[3] = { scale=1.0/0.6,	facing=0.4,		x=35,	y=98 },
		[4] = { scale=1.0/0.5,	facing=-0.5,	x=-40,	y=138 },
		[5] = { scale=1.0/0.35,	facing=0.5,		x=0,	y=190 },
	}
};



function GarrisonFollowerTabMixin:ShowFollowerModel(followerInfo)
	if (followerInfo) then
		self.NoFollowersLabel:Hide();
		self.PortraitFrame:Show();
		local originX, originY = 12, -78;
		local maxModels = #self.ModelCluster.Child.Model
		local numShown = Clamp(#followerInfo.displayIDs, 1, maxModels);
		local pos = positionData[numShown];
		for i=1,numShown do
			local model = self.ModelCluster.Child.Model[i];
			model:SetAlpha(0);

			model.facing = pos[i].facing;
			model.scale = pos[i].scale;
			model.targetDistance= pos[i].targetDistance;
			model:EnableMouse(i == 1 and numShown <= 2);

			local displayID = followerInfo.displayIDs and followerInfo.displayIDs[i] and followerInfo.displayIDs[i].id;
			local showWeapon = followerInfo.displayIDs and followerInfo.displayIDs[i] and followerInfo.displayIDs[i].showWeapon;
			local followerPageScale = followerInfo.displayIDs and followerInfo.displayIDs[i] and followerInfo.displayIDs[i].followerPageScale or 1;

			GarrisonMission_SetFollowerModel(model, followerInfo.followerID, displayID, showWeapon);
								
			model:SetPoint("TOPLEFT", 12 + pos[i].x, -78 + pos[i].y);
			model:SetHeightFactor(followerInfo.displayHeight or 0.5);
			model:InitializeCamera((followerInfo.displayScale or 1) * pos[i].scale * followerPageScale);
			model:Show();
			self.ModelCluster.Child.Shadows.Shadow[i]:Show();
		end
		for i=numShown+1, maxModels do
			self.ModelCluster.Child.Model[i]:Hide();
			self.ModelCluster.Child.Shadows.Shadow[i]:Hide()
		end
		self.ModelCluster:Show();
	else
		self.NoFollowersLabel:Show();
		self.PortraitFrame:Hide();
		self.ModelCluster:Hide();
	end

	GarrisonFollowerPageModelUpgrade_Update(self.ModelCluster.UpgradeFrame);
end


local function AbilityFrame_OnReleased(pool, abilityFrame)
	FramePool_HideAndClearAnchors(pool, abilityFrame);
	abilityFrame.IconButton.ValidSpellHighlight:Hide();
	abilityFrame.IconButton.Lock:Hide();
	abilityFrame.IconButton.LockBackground:Hide();
end

local function EquipmentFrame_OnReleased(pool, equipmentFrame)
	FramePool_HideAndClearAnchors(pool, equipmentFrame);
	equipmentFrame:SetScale(1);
end


function GarrisonFollowerTabMixin:OnLoad()
	self.abilitiesPool = CreateFramePool("FRAME", self.AbilitiesFrame, "GarrisonFollowerPageAbilityTemplate", AbilityFrame_OnReleased);
	self.equipmentPool = CreateFramePool("BUTTON", self.AbilitiesFrame, "GarrisonFollowerEquipmentTemplate", EquipmentFrame_OnReleased);
	self.countersPool = CreateFramePool("FRAME", self.AbilitiesFrame, "GarrisonMissionMechanicTemplate");
end

function GarrisonFollowerTabMixin:OnHide()
	self.lastUpdate = nil;
end

function GarrisonFollowerTabMixin:IsEquipmentAbility(followerInfo, ability)
	if (GarrisonFollowerOptions[followerInfo.followerTypeID].traitAbilitiesAreEquipment) then
		return ability.isTrait;
	end
	return false;
end

function GarrisonFollowerTabMixin:IsSpecializationAbility(followerInfo, ability)
	return ability.isSpecialization;
end

function GarrisonFollowerTabMixin:SetupAbilities(followerInfo)

	if (not followerInfo.abilities or not followerInfo.unlockableAbilities or not followerInfo.equipment or not followerInfo.unlockableEquipment) then
		local abilities, unlockables = C_Garrison.GetFollowerAbilities(followerInfo.followerID);

		-- filter out equipment from abilities and place them in their own table.
		followerInfo.abilities = { };
		followerInfo.equipment = { };
		
		for i, ability in ipairs(abilities) do
			if (self:IsEquipmentAbility(followerInfo, ability)) then
				tinsert(followerInfo.equipment, ability);
			else
				tinsert(followerInfo.abilities, ability);
			end
		end

		-- filter out equipment from unlockables
		followerInfo.unlockableAbilities = { };
		followerInfo.unlockableEquipment = { };
		if (unlockables) then
			for i, ability in ipairs(unlockables) do
				if (self:IsEquipmentAbility(followerInfo, ability)) then
					tinsert(followerInfo.unlockableEquipment, ability);
				else
					tinsert(followerInfo.unlockableAbilities, ability);
				end
			end
		end
	end

	-- Zone Support
	if (not followerInfo.combatAllySpellIDs) then
		followerInfo.combatAllySpellIDs = { C_Garrison.GetFollowerZoneSupportAbilities(followerInfo.followerID) };
	end

end

local BASE_SPECIALIZATION_LAYOUT_INDEX = 100;
local BASE_ABILITY_LAYOUT_INDEX = 200;
local BASE_TRAIT_LAYOUT_INDEX = 300;
local BASE_COMBAT_ALLY_LAYOUT_INDEX = 400;
local BASE_FLAVORTEXT_LAYOUT_INDEX = 500;

function GarrisonFollowerTabMixin:ShowAbilities(followerInfo)

	local hasSpecialization;
	local hasTrait;
	local hasAbility;
	
	local numCounters = 0;

	self.abilitiesPool:ReleaseAll();
	self.countersPool:ReleaseAll();

	local numAbilitiesWithUnlockables = #followerInfo.abilities + #followerInfo.unlockableAbilities;
	for i=1, numAbilitiesWithUnlockables do
		local ability;
		if (i <= #followerInfo.abilities) then
			ability = followerInfo.abilities[i];
		else
			ability = followerInfo.unlockableAbilities[i - #followerInfo.abilities];
		end

		local abilityFrame = self.abilitiesPool:Acquire();

		if ( followerInfo.isCollected and GarrisonFollowerAbilities_IsNew(self.lastUpdate, followerInfo.followerID, ability.id, GARRISON_FOLLOWER_ABILITY_TYPE_EITHER) ) then			
			if ( ability.temporary ) then
				abilityFrame.LargeAbilityFeedbackGlowAnim:Play();
				PlaySoundKitID(51324);
			else
				abilityFrame.IconButton.Icon:SetAlpha(0);
				abilityFrame.IconButton.OldIcon:SetAlpha(1);
				abilityFrame.AbilityOverwriteAnim:Play();		
			end
		else
			GarrisonFollowerPageAbility_StopAnimations(abilityFrame);
		end
		local name;
		local extraDescriptionText;
		if (ability.requiredQualityLevel ~= nil) then
			name = GRAY_FONT_COLOR:WrapTextInColorCode(ability.name);
			extraDescriptionText = RED_FONT_COLOR:WrapTextInColorCode(string.format(GARRISON_ABILITY_UNLOCK_TOOLTIP, followerInfo.name, _G["ITEM_QUALITY"..ability.requiredQualityLevel.."_DESC"]));
			abilityFrame.IconButton.Lock:Show();
			abilityFrame.IconButton.LockBackground:Show();
		else
			name = ability.name;
		end
		abilityFrame.Name:SetText(name);
		abilityFrame.IconButton.Icon:SetTexture(ability.icon);
		abilityFrame.IconButton.Icon:SetDesaturated(ability.requiredQualityLevel ~= nil);
		abilityFrame.IconButton.abilityID = ability.id;
		abilityFrame.IconButton.Border:SetShown(ShouldShowFollowerAbilityBorder(followerInfo.followerTypeID, ability));
		abilityFrame.IconButton.extraDescriptionText = extraDescriptionText;
		abilityFrame.ability = ability;

		local hasCounters = false;
		if ( ability.counters and not ability.isTrait and not self.isLandingPage and not GarrisonFollowerOptions[followerInfo.followerTypeID].hideCountersInAbilityFrame ) then
			for id, counter in pairs(ability.counters) do
				numCounters = numCounters + 1;
				local counterFrame = self.countersPool:Acquire();
				counterFrame.mainFrame = self:GetParent();
				counterFrame.Icon:SetTexture(counter.icon);
				counterFrame.tooltip = counter.name;
				if ( hasCounters ) then			
					counterFrame:SetPoint("LEFT", self.AbilitiesFrame.Counters[numCounters - 1], "RIGHT", 10, 0);
				else
					counterFrame:SetPoint("LEFT", abilityFrame.CounterString, "RIGHT", 2, -2);
				end
				counterFrame:Show();
				counterFrame.info = counter;
				counterFrame.followerTypeID = followerInfo.followerTypeID;
				hasCounters = true;
			end
		end
		if ( hasCounters ) then
			abilityFrame:SetHeight(60);
			abilityFrame.CounterString:Show();
		else
			if (self.isLandingPage) then
				abilityFrame:SetHeight(30);
			else
				abilityFrame:SetHeight(40);
			end
			abilityFrame.CounterString:Hide();
		end

		if ( self.isLandingPage ) then
			abilityFrame.Category:SetText("");
			abilityFrame.Name:SetFontObject("GameFontHighlightMed2");
			abilityFrame.Name:ClearAllPoints();
			abilityFrame.Name:SetPoint("LEFT", abilityFrame.IconButton, "RIGHT", 8, 0);
			abilityFrame.Name:SetWidth(150);
		else
			local categoryText = "";
			if ( ability.isTrait ) then
				if ( ability.temporary ) then
					categoryText = GARRISON_TEMPORARY_CATEGORY_FORMAT:format(ability.category or "");
				else
					categoryText = ability.category or "";
				end
			end
			abilityFrame.Category:SetText(categoryText);
			abilityFrame.Name:SetFontObject("GameFontNormalLarge2");
			abilityFrame.Name:ClearAllPoints();
			if (hasCounters) then
				abilityFrame.Name:SetPoint("TOPLEFT", abilityFrame.IconButton, "TOPRIGHT", 8, 0);
			else
				abilityFrame.Name:SetPoint("LEFT", abilityFrame.IconButton, "RIGHT", 8, 0);
			end
			abilityFrame.Name:SetWidth(240);
		end

		if (ability.isSpecialization) then
			hasSpecialization = true;
			abilityFrame.layoutIndex = BASE_SPECIALIZATION_LAYOUT_INDEX + i;
		elseif (not ability.isTrait) then
			hasAbility = true;
			abilityFrame.layoutIndex = BASE_ABILITY_LAYOUT_INDEX + i;
		else
			hasTrait = true;
			abilityFrame.layoutIndex = BASE_TRAIT_LAYOUT_INDEX + i;
		end
		abilityFrame:Show();
		abilityFrame.followerTypeID = followerInfo.followerTypeID;
	end

	self.AbilitiesFrame.SpecializationLabel:SetShown(hasSpecialization);
	self.AbilitiesFrame.AbilitiesText:SetShown(hasAbility);
	self.AbilitiesFrame.TraitsText:SetShown(hasTrait);


	-- Combat Ally
	local hasCombatAllySpell = #followerInfo.combatAllySpellIDs ~= 0;

	for i, combatAllySpell in ipairs(followerInfo.combatAllySpellIDs) do
		local _, _, texture = GetSpellInfo(combatAllySpell);
		if (i == 1) then
			self.AbilitiesFrame.CombatAllySpell[i].layoutIndex = BASE_COMBAT_ALLY_LAYOUT_INDEX + 2;
		else
			self.AbilitiesFrame.CombatAllySpell[i].layoutIndex = nil;
		end
		self.AbilitiesFrame.CombatAllySpell[i]:Show();
		self.AbilitiesFrame.CombatAllySpell[i].iconTexture:SetTexture(texture);
		self.AbilitiesFrame.CombatAllySpell[i].spellID = combatAllySpell;
		self.AbilitiesFrame.CombatAllySpell[i].followerID = followerID;
	end
	self.AbilitiesFrame.CombatAllyLabel:SetShown(hasCombatAllySpell);
	self.AbilitiesFrame.CombatAllyLabel.layoutIndex = BASE_COMBAT_ALLY_LAYOUT_INDEX;
	self.AbilitiesFrame.CombatAllyDescriptionLabel:SetShown(hasCombatAllySpell);
	self.AbilitiesFrame.CombatAllyDescriptionLabel.layoutIndex = BASE_COMBAT_ALLY_LAYOUT_INDEX + 1;

	for i = #followerInfo.combatAllySpellIDs + 1, #self.AbilitiesFrame.CombatAllySpell do
		self.AbilitiesFrame.CombatAllySpell[i]:Hide();
	end

	if (followerInfo.flavorText) then
		self.AbilitiesFrame.FlavorText.layoutIndex = BASE_FLAVORTEXT_LAYOUT_INDEX;
		self.AbilitiesFrame.FlavorText:SetText(followerInfo.flavorText);
		self.AbilitiesFrame.FlavorText:Show();
	else
		self.AbilitiesFrame.FlavorText:Hide();
	end

	self.AbilitiesFrame:Layout();
end

function GarrisonFollowerTabMixin:ShowEquipment(followerInfo)
	self.equipmentPool:ReleaseAll();

	local numEquipmentWithUnlockables = #followerInfo.equipment + #followerInfo.unlockableEquipment;

	local lastEquipmentFrame;
	for i=1, numEquipmentWithUnlockables do
		local equipment;
		if (i <= #followerInfo.equipment) then
			equipment = followerInfo.equipment[i];
		else
			equipment = followerInfo.unlockableEquipment[i - #followerInfo.equipment];
		end

		local equipmentFrame = self.equipmentPool:Acquire();
		if (self.isLandingPage) then
			equipmentFrame:SetScale(0.7);
		end

		equipmentFrame.followerTypeID = followerInfo.followerTypeID;
		equipmentFrame.followerList = self:GetFollowerList();
		equipmentFrame.abilityID = equipment.id;
		equipmentFrame.followerID = followerInfo.followerID;
		if (equipment.icon) then
			equipmentFrame.Icon:SetTexture(equipment.icon);
			equipmentFrame.Icon:Show();
			if (not hideCounters) then
				for id, counter in pairs(equipment.counters) do
					equipment.Counter.Icon:SetTexture(counter.icon);
					equipment.Counter.tooltip = counter.name;
					equipment.Counter.mainFrame = mainFrame;
					equipment.Counter.info = counter;
					equipment.Counter:Show();
							
					break;
				end
			end
					
			if (followerInfo.isCollected and GarrisonFollowerAbilities_IsNew(self.lastUpdate, followerID, equipment.id, GARRISON_FOLLOWER_ABILITY_TYPE_EITHER)) then
				equipmentFrame.EquipAnim:Play();
			else
				GarrisonEquipment_StopAnimations(equipmentFrame);
			end
		else
			equipmentFrame.Icon:Hide();
		end

		local tooltipText;
		if (equipment.requiredQualityLevel ~= nil) then
			tooltipText = RED_FONT_COLOR:WrapTextInColorCode(string.format(GARRISON_EQUIPMENT_SLOT_UNLOCK_TOOLTIP, followerInfo.name, _G["ITEM_QUALITY"..equipment.requiredQualityLevel.."_DESC"]));
			equipmentFrame.Lock:Show();
		else
			equipmentFrame.Lock:Hide();
		end
		equipmentFrame.tooltipText = tooltipText;

		if (lastEquipmentFrame) then
			equipmentFrame:SetPoint("TOPLEFT", lastEquipmentFrame, "TOPRIGHT");
		else
			if (self.isLandingPage) then
				equipmentFrame:SetPoint("TOPLEFT", self.AbilitiesFrame.EquipmentSlotsLabel, "BOTTOMLEFT", 118, 0);
			else
				equipmentFrame:SetPoint("TOPLEFT", self.AbilitiesFrame.EquipmentSlotsLabel, "BOTTOMLEFT", 60, -20);
			end
		end
		equipmentFrame:Show();
		lastEquipmentFrame = equipmentFrame;
	end
	if (numEquipmentWithUnlockables > 0) then
		self.AbilitiesFrame.EquipmentSlotsLabel:Show();
		self.ModelCluster.UpgradeFrame:ClearAllPoints();
		self.ModelCluster.UpgradeFrame:SetPoint("BOTTOM", self.AbilitiesFrame.EquipmentSlotsLabel, "TOP", 0, 10);
	else
		self.AbilitiesFrame.EquipmentSlotsLabel:Hide();
		self.ModelCluster.UpgradeFrame:ClearAllPoints();
		self.ModelCluster.UpgradeFrame:SetPoint("BOTTOM", self.ModelCluster, "TOPLEFT", 164, -423);
	end
end


function GarrisonFollowerTabMixin:ShowFollower(followerID, followerList)

	local followerInfo = C_Garrison.GetFollowerInfo(followerID);
	local missionFrame = self:GetParent();

	self.followerID = followerID;
	self.ModelCluster.followerID = followerID;

	self:ShowFollowerModel(followerInfo);
	if (not followerInfo) then
		followerInfo = { };
		followerInfo.followerTypeID = missionFrame:GetFollowerList().followerType;
		followerInfo.quality = 1;
		followerInfo.abilities = { };
		followerInfo.unlockableAbilities = { };
		followerInfo.equipment = { };
		followerInfo.combatAllySpellIDs = { };
	end
	GarrisonMissionPortrait_SetFollowerPortrait(self.PortraitFrame, followerInfo);
	self.Name:SetText(followerInfo.name);
	local color = ITEM_QUALITY_COLORS[followerInfo.quality];	
	self.Name:SetVertexColor(color.r, color.g, color.b);

	if (followerInfo.isTroop) then
		self.DurabilityFrame:Show();
		self.ClassSpec:Hide();
		self.DurabilityFrame:SetDurability(followerInfo.durability, followerInfo.maxDurability);
	else
		self.ClassSpec:Show();
		self.DurabilityFrame:Hide();
		self.ClassSpec:SetText(followerInfo.className);
	end
	self.Class:SetAtlas(followerInfo.classAtlas);

	self:SetupXPBar(followerInfo);
	GarrisonTruncationFrame_Check(self.Name);

	if ( ENABLE_COLORBLIND_MODE == "1" ) then
		self.QualityFrame:Show();
		self.QualityFrame.Text:SetText(_G["ITEM_QUALITY"..followerInfo.quality.."_DESC"]);
	else
		self.QualityFrame:Hide();
	end

	self:SetupAbilities(followerInfo);
	self:ShowAbilities(followerInfo);
	self:ShowEquipment(followerInfo);

	-- gear	/ source
	local showGearOption = GarrisonFollowerOptions[followerInfo.followerTypeID].followerPageShowGear;
	if (showGearOption and followerInfo.isCollected and not self.isLandingPage) then
		local weaponItemID, weaponItemLevel, armorItemID, armorItemLevel = C_Garrison.GetFollowerItems(followerInfo.followerID);
		GarrisonFollowerPage_SetItem(self.ItemWeapon, weaponItemID, weaponItemLevel);
		GarrisonFollowerPage_SetItem(self.ItemArmor, armorItemID, armorItemLevel);
		if ( followerInfo.isMaxLevel ) then
			self.ItemAverageLevel.Level:SetText(ITEM_LEVEL_ABBR .. " " .. followerInfo.iLevel);
			self.ItemAverageLevel.Level:Show();
		else
			self.ItemWeapon:Hide();
			self.ItemArmor:Hide();
			self.ItemAverageLevel.Level:Hide();
		end
	else
		self.ItemWeapon:Hide();
		self.ItemArmor:Hide();
		self.ItemAverageLevel.Level:Hide();
	end

	local showSourceTextOption = GarrisonFollowerOptions[followerInfo.followerTypeID].followerPageShowSourceText;
	if (showSourceTextOption and not (followerInfo.isCollected and not self.isLandingPage)) then
		self.Source.SourceText:SetText(C_Garrison.GetFollowerSourceTextByID(followerID));		
		self.Source.SourceText:Show();
	else
		self.Source.SourceText:Hide();
	end

	self:UpdateValidSpellHighlight(followerID, followerInfo);
	self.lastUpdate = self:IsShown() and GetTime() or nil;
end

function GarrisonFollowerTabMixin:GetFollowerList()
	return self:GetParent():GetFollowerList();
end

function GarrisionFollowerPageUpgradeTarget_OnClick(self, button)
	GarrisonFollower_DisplayUpgradeConfirmation(self:GetParent().followerID);
end

function GarrisonFollowerPageAbility_OnClick(self, button)
	if ( IsModifiedClick("CHATLINK") ) then
		local abilityLink = C_Garrison.GetFollowerAbilityLink(self.abilityID);
		if (abilityLink) then
			ChatEdit_InsertLink(abilityLink);
		end
	else
		local followerTab = self:GetParent():GetParent():GetParent();
		local followerList = followerTab.followerList;
		local followerID = followerTab.followerID;	
		if ( button == "LeftButton" and followerList.canCastSpellsOnFollowers and SpellCanTargetGarrisonFollowerAbility(followerID, self.abilityID) ) then
			local followerInfo = followerID and C_Garrison.GetFollowerInfo(followerID);
			if ( not followerInfo or not followerInfo.isCollected or followerInfo.status == GARRISON_FOLLOWER_ON_MISSION or followerInfo.status == GARRISON_FOLLOWER_WORKING ) then
				return;
			end
			
			local popupData = {};
			popupData.followerID = followerID;
			popupData.abilityID = self.abilityID;
			GarrisonConfirmFollowerAbilityUpgradeFrame.Name:SetText(C_Garrison.GetFollowerAbilityName(self.abilityID));
			GarrisonConfirmFollowerAbilityUpgradeFrame.Icon:SetTexture(C_Garrison.GetFollowerAbilityIcon(self.abilityID));
			local text = CONFIRM_GARRISON_FOLLOWER_ABILITY_REPLACE;
			if ( C_Garrison.GetFollowerAbilityIsTrait(self.abilityID) ) then
				text = CONFIRM_GARRISON_FOLLOWER_TRAIT_REPLACE;
			end
			StaticPopup_Show("CONFIRM_FOLLOWER_ABILITY_UPGRADE", NORMAL_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE, nil, popupData, GarrisonConfirmFollowerAbilityUpgradeFrame);
		end	
	end
end

function GarrisonFollowerPageAbility_StopAnimations(self)
	self.LargeAbilityFeedbackGlowAnim:Stop();
	if ( self.AbilityOverwriteAnim:IsPlaying() ) then
		self.AbilityOverwriteAnim:Stop();
		self.IconButton.Icon:SetAlpha(1);
		self.IconButton.OldIcon:SetAlpha(0);
	end
end

---------------------------------------------------------------------------------
--- Equipment Utils
---------------------------------------------------------------------------------

function GarrisonEquipment_AddEquipment(self)
	local followerList = self.followerList;
	if ( followerList.canCastSpellsOnFollowers ) then
		local followerID = self.followerID;
		local popupData = {};
		local equipmentName;
		if ( SpellCanTargetGarrisonFollowerAbility(followerID, self.abilityID) ) then
			popupData.source = "spell";
			equipmentName = GetEquipmentNameFromSpell();
		elseif ( ItemCanTargetGarrisonFollowerAbility(followerID, self.abilityID) ) then
			popupData.source = "item";
			local itemType, itemID = GetCursorInfo();
			equipmentName = GetItemInfo(itemID);
		else
			return;
		end
		local followerInfo = followerID and C_Garrison.GetFollowerInfo(followerID);
		if ( not followerInfo or not followerInfo.isCollected or followerInfo.status == GARRISON_FOLLOWER_ON_MISSION or followerInfo.status == GARRISON_FOLLOWER_WORKING ) then
			return;
		end
		
		popupData.followerID = followerID;
		popupData.abilityID = self.abilityID;
		local text = format(GarrisonFollowerOptions[followerList.followerType].strings.CONFIRM_EQUIPMENT, equipmentName);
		StaticPopup_Show("CONFIRM_FOLLOWER_EQUIPMENT", text, nil, popupData);
	end
end

function GarrisonEquipment_StopAnimations(frame)
	if (frame.EquipAnim:IsPlaying()) then
		frame.EquipAnim:Stop();
	end
end


---------------------------------------------------------------------------------
--- Abilities Frame
---------------------------------------------------------------------------------
GarrisonAbilitiesFrameMixin = { }

function GarrisonAbilitiesFrameMixin:GetFollowerTab()
	return self:GetParent();
end

function GarrisonAbilitiesFrameMixin:GetFollowerList()
	return self:GetParent():GetFollowerList();
end

---------------------------------------------------------------------------------
--- Mission Sorting                                                           ---
---------------------------------------------------------------------------------

function Garrison_SortMissions(missionsList)
	local comparison = function(mission1, mission2)
		if ( mission1.followerTypeID ~= mission2.followerTypeID ) then
			return mission1.followerTypeID > mission2.followerTypeID;
		end
		
		if ( mission1.level ~= mission2.level ) then
			return mission1.level > mission2.level;
		end

		if ( mission1.isMaxLevel ) then	-- mission 2 level is same as 1's at this point
			if ( mission1.iLevel ~= mission2.iLevel ) then
				return mission1.iLevel > mission2.iLevel;
			end		
		end

		if ( mission1.durationSeconds ~= mission2.durationSeconds ) then
			return mission1.durationSeconds < mission2.durationSeconds;
		end
		
		if ( mission1.isRare ~= mission2.isRare ) then
			return mission1.isRare;
		end

		return strcmputf8i(mission1.name, mission2.name) < 0;
	end

	table.sort(missionsList, comparison);
end

---------------------------------------------------------------------------------
--- Truncation		                                                          ---
---------------------------------------------------------------------------------

function GarrisonTruncationFrame_Check(fontString)
	local self = GarrisonTruncationFrame;
	-- force a resize so IsTruncated will be correct, otherwise it might change a frame later depending on pending resizes
	fontString:GetRect();
	if ( fontString:IsTruncated() ) then
		self:SetParent(fontString:GetParent());
		self:SetFrameLevel(10);	-- needs to be above ModelCluster
		self:SetPoint("TOPLEFT", fontString);
		self:SetPoint("BOTTOMRIGHT", fontString);
		self:Show();
		self.tooltip = fontString:GetText();
	else
		self:Hide();
		self.tooltip = nil;
	end
end

function GarrisonTruncationFrame_OnEnter(self)
	if ( self.tooltip ) then
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:SetText(self.tooltip);
	end
end

function GarrisonTruncationFrame_OnLeave(self)
	GameTooltip:Hide();
end

---------------------------------------------------------------------------------
--- Threat Counters                                                           ---
---------------------------------------------------------------------------------
local weatherIds = {77, 78, 79, 80};
local function IsWeatherThreat(id)
	for i = 1, #weatherIds do
		if ( weatherIds[i] == id ) then
			return true;
		end
	end
	
	return false;
end

function GarrisonThreatCountersFrame_OnLoad(self, followerType, tooltipString)
	if (followerType == nil) then
		followerType = LE_FOLLOWER_TYPE_GARRISON_6_0;
	end
	self.followerType = followerType;
	if (tooltipString == nil) then
		tooltipString = GARRISON_THREAT_COUNTER_TOOLTIP;
	end
	self.tooltipString = tooltipString;
	local mechanics = C_Garrison.GetAllEncounterThreats(followerType);
	-- sort reverse alphabetical because we'll be anchoring buttons right to left
	if ( followerType == LE_FOLLOWER_TYPE_SHIPYARD_6_2 ) then
		-- sort high threats to the left, weather based threats to the right, other wise sort alphabetic
		table.sort(mechanics, function(m1, m2)
			local m1Weather = IsWeatherThreat(m1.id);
			if ( m1Weather ~= IsWeatherThreat(m2.id) ) then
				return m1Weather;
			elseif ( m1.factor == m2.factor ) then
				return strcmputf8i(m1.name, m2.name) > 0;
			else
				return m1.factor < m2.factor;
			end
		end);
	else
		table.sort(mechanics, function(m1, m2) return strcmputf8i(m1.name, m2.name) > 0; end);
	end
	for i = 1, #mechanics do
		local frame = self.ThreatsList[i];
		if ( not frame ) then
			frame = CreateFrame("Button", nil, self, "GarrisonThreatCounterTemplate");
			frame:SetPoint("RIGHT", self.ThreatsList[i-1], "LEFT", -14, 0);
			self.ThreatsList[i] = frame;
		end
		frame.Icon:SetTexture(mechanics[i].icon);
		frame.name = mechanics[i].name;
		frame.id = mechanics[i].id;
		if ( mechanics[i].factor and  mechanics[i].factor <= GARRISON_HIGH_THREAT_VALUE and followerType == LE_FOLLOWER_TYPE_SHIPYARD_6_2 ) then
			frame.Border:SetAtlas("GarrMission_WeakEncounterAbilityBorder");
		else
			frame.Border:SetAtlas("GarrMission_EncounterAbilityBorder");
		end
	end
	self:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE");
end

function GarrisonThreatCountersFrame_OnEvent(self, event, ...)
	if ( self:IsVisible() ) then
		GarrisonThreatCountersFrame_Update(self);
	end
end

function GarrisonThreatCountersFrame_Update(self)
	for i = 1, #self.ThreatsList do
		self.ThreatsList[i].Count:SetText(C_Garrison.GetNumFollowersForMechanic(self.followerType, self.ThreatsList[i].id));
	end
end

function GarrisonThreatCounter_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local text = string.format(self:GetParent().tooltipString, C_Garrison.GetNumFollowersForMechanic(self:GetParent().followerType, self.id), self.name);
	GameTooltip:SetText(text, nil, nil, nil, nil, true);
end

---------------------------------------------------------------------------------
--- Follower Abilities                                                          ---
---------------------------------------------------------------------------------

GARRISON_FOLLOWER_ABILITY_TYPE_ABILITY = 1;
GARRISON_FOLLOWER_ABILITY_TYPE_TRAIT = 2;
GARRISON_FOLLOWER_ABILITY_TYPE_EITHER = 3;

local function IsNewHelper(lastUpdate, abilityIdToTest, ...)
	for i = 1, select("#", ...), 2 do
		local abilityID = select(i, ...);
		local timeGained = select(i + 1, ...);
		if ( timeGained >= lastUpdate and abilityIdToTest == abilityID ) then
			return true;
		end
	end
	return false;
end

function GarrisonFollowerAbilities_IsNew(lastUpdate, followerID, abilityIdToTest, abilityType)
	if ( lastUpdate and followerID and followerID ~= "" ) then
		abilityType = abilityType or GARRISON_FOLLOWER_ABILITY_TYPE_EITHER;

		if ( abilityType == GARRISON_FOLLOWER_ABILITY_TYPE_ABILITY or abilityType == GARRISON_FOLLOWER_ABILITY_TYPE_EITHER ) then
			if ( IsNewHelper(lastUpdate, abilityIdToTest, C_Garrison.GetFollowerRecentlyGainedAbilityIDs(followerID)) ) then
				return true;
			end
		end

		if ( abilityType == GARRISON_FOLLOWER_ABILITY_TYPE_TRAIT or abilityType == GARRISON_FOLLOWER_ABILITY_TYPE_EITHER ) then
			if ( IsNewHelper(lastUpdate, abilityIdToTest, C_Garrison.GetFollowerRecentlyGainedTraitIDs(followerID)) ) then
				return true;
			end
		end
	end

	return false;
end

---------------------------------------------------------------------------------
-- Combat Ally support
---------------------------------------------------------------------------------
GarrisonFollowerCombatAllySpellMixin = { }

function GarrisonFollowerCombatAllySpellMixin:OnEnter()
	if ( self.spellID ) then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
		GameTooltip:SetSpellByID(self.spellID);
		GameTooltip:Show();
	end
end

function GarrisonFollowerCombatAllySpellMixin:OnLeave()
	GameTooltip:Hide();
end


---------------------------------------------------------------------------------
-- GarrisonFollowerEquipmentMixin
---------------------------------------------------------------------------------

GarrisonFollowerEquipmentMixin = { }
function GarrisonFollowerEquipmentMixin:OnEnter()
	if (self.tooltipText) then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
		GameTooltip:SetText(self.tooltipText, RED_FONT_COLOR_CODE.r, RED_FONT_COLOR_CODE.g, RED_FONT_COLOR_CODE.b, RED_FONT_COLOR_CODE.a, true);
	elseif (self.abilityID) then
		ShowGarrisonFollowerAbilityTooltip(self, self.abilityID, self.followerTypeID);
	end
end

function GarrisonFollowerEquipmentMixin:OnLeave()
	GameTooltip:Hide();
	HideGarrisonFollowerAbilityTooltip(self.followerTypeID);
end

function GarrisonFollowerEquipmentMixin:OnClick(button)
	if (self.Lock:IsShown()) then
		return;
	end

	if ( IsModifiedClick("CHATLINK") and self.Icon:IsShown() ) then
		local abilityLink = C_Garrison.GetFollowerAbilityLink(self.abilityID);
		if (abilityLink) then
			ChatEdit_InsertLink(abilityLink);
		end
	elseif (self.abilityID) then
		if ( button == "LeftButton") then
			GarrisonEquipment_AddEquipment(self);
		end	
	end
end

function GarrisonFollowerEquipmentMixin:OnReceiveDrag()
	if (self.abilityID) then
		GarrisonEquipment_AddEquipment(self);
	end
end


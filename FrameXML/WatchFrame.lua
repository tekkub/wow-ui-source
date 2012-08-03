-- Who watches the WatchFrame...?

WATCHFRAME_COLLAPSEDWIDTH = 0;		-- set in WatchFrame_OnLoad
WATCHFRAME_EXPANDEDWIDTH = 204;
WATCHFRAME_LINEHEIGHT = 16;
WATCHFRAME_MAXLINEWIDTH = 0;		-- set in WatchFrame_SetWidth
WATCHFRAME_MULTIPLE_LINEHEIGHT = 0;	-- set in WatchFrame_SetWidth
WATCHFRAME_ITEM_WIDTH = 33;

local DASH_NONE = 0;
local DASH_SHOW = 1;
local DASH_HIDE = 2;
local DASH_ICON = 3;
local DASH_WIDTH;
DASH_ICON_WIDTH = 20;
local IS_HEADER = true;

WATCHFRAME_INITIAL_OFFSET = 0;
WATCHFRAME_TYPE_OFFSET = 10;
WATCHFRAME_QUEST_OFFSET = 10;
WATCHFRAME_SCENARIO_LINE_OFFSET = 10;

WATCHFRAMELINES_FONTSPACING = 0;
WATCHFRAMELINES_FONTHEIGHT = 0;

WATCHFRAME_MAXQUESTS = 10;
WATCHFRAME_MAXACHIEVEMENTS = 10;
WATCHFRAME_CRITERIA_PER_ACHIEVEMENT = 5;

WATCHFRAME_NUM_TIMERS = 0;
WATCHFRAME_NUM_ITEMS = 0;
WATCHFRAME_NUM_POPUPS = 0;

WATCHFRAME_OBJECTIVEHANDLERS = {};
WATCHFRAME_TIMEDCRITERIA = {};
WATCHFRAME_TIMERLINES = {};
WATCHFRAME_ACHIEVEMENTLINES = {};
WATCHFRAME_QUESTLINES = {};
WATCHFRAME_LINKBUTTONS = {};
WATCHFRAME_SCENARIOLINES = {};
local WATCHFRAME_SETLINES = { };			-- buffer to hold lines for a quest/achievement that will be displayed only if there is room
local WATCHFRAME_SETLINES_NUMLINES;		-- the number of visual lines to be rendered for the buffered data - used just for item wrapping right now

CURRENT_MAP_QUESTS = { };
LOCAL_MAP_QUESTS = { };
VISIBLE_WATCHES  = { };

WATCHFRAME_FLAGS = { ["locked"] = 0x01, ["collapsed"] = 0x02 }

WATCHFRAME_ACHIEVEMENT_ARENA_CATEGORY = 165;

local watchFrameTestLine;

WATCHFRAME_SORT_PROXIMITY = 1;
WATCHFRAME_SORT_DIFFICULTY_HIGH = 2;
WATCHFRAME_SORT_DIFFICULTY_LOW = 3;
WATCHFRAME_SORT_MANUAL = 0;
WATCHFRAME_FILTER_ACHIEVEMENTS = 1;
WATCHFRAME_FILTER_COMPLETED_QUESTS = 2;
WATCHFRAME_FILTER_REMOTE_ZONES = 4;
WATCHFRAME_FILTER_NONE = 0;
WATCHFRAME_SORT_TYPE = 0;
WATCHFRAME_FILTER_TYPE = 0;
WATCHFRAME_UPDATE_RATE = 1;

local watchButtonIndex = 1;
local function WatchFrame_GetLinkButton ()
	local button = WATCHFRAME_LINKBUTTONS[watchButtonIndex]
	if ( not button ) then
		WATCHFRAME_LINKBUTTONS[watchButtonIndex] = WatchFrame.buttonCache:GetFrame();
		button = WATCHFRAME_LINKBUTTONS[watchButtonIndex];
	end

	watchButtonIndex = watchButtonIndex + 1;
	return button;
end

local function WatchFrame_ResetLinkButtons ()
	watchButtonIndex = 1;
end

local function WatchFrame_ReleaseUnusedLinkButtons ()
	local watchButton
	for i = watchButtonIndex, #WATCHFRAME_LINKBUTTONS do
		watchButton = WATCHFRAME_LINKBUTTONS[i];
		watchButton.type = nil
		watchButton.index = nil;
		watchButton:Hide();
		watchButton.frameCache:ReleaseFrame(watchButton);
		WATCHFRAME_LINKBUTTONS[i] = nil;
	end
end

function WatchFrameLinkButtonTemplate_OnClick (self, button, pushed)
	if ( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
		if ( self.type == "QUEST" ) then
			local questLink = GetQuestLink(GetQuestIndexForWatch(self.index));
			if ( questLink ) then
				ChatEdit_InsertLink(questLink);
			end
		elseif ( self.type == "ACHIEVEMENT" ) then
			local achievementLink = GetAchievementLink(self.index);
			if ( achievementLink ) then
				ChatEdit_InsertLink(achievementLink);
			end
		end
	elseif ( button ~= "RightButton" ) then
		WatchFrameLinkButtonTemplate_OnLeftClick(self, button);
	else
		local dropDown = WatchFrameDropDown;
		if ( WatchFrame.lastLinkButton ~= self ) then
			CloseDropDownMenus();
		end
		dropDown.type = self.type;
		dropDown.index = self.index;
		WatchFrame.dropDownOpen = true;
		WatchFrame.lastLinkButton = self;
		ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
	end
end

function WatchFrameLinkButtonTemplate_OnLeftClick (self, button)
	CloseDropDownMenus();
	if ( self.type == "QUEST" ) then
		if ( IsModifiedClick("QUESTWATCHTOGGLE") ) then
			WatchFrame_StopTrackingQuest( button, self.index);
		else
			ExpandQuestHeader( GetQuestSortIndex( GetQuestIndexForWatch(self.index) ) );
			-- you have to call GetQuestIndexForWatch again because ExpandQuestHeader will sort the indices
			local questIndex = GetQuestIndexForWatch(self.index);
			if (self.isComplete and GetQuestLogIsAutoComplete(questIndex)) then
				ShowQuestComplete(questIndex);
				WatchFrameAutoQuest_ClearPopUpByLogIndex(questIndex);
			else
				QuestLog_OpenToQuest( questIndex );
			end
		end
		return;
	elseif ( self.type == "ACHIEVEMENT" ) then
		if ( not AchievementFrame ) then
			AchievementFrame_LoadUI();
		end
		if ( IsModifiedClick("QUESTWATCHTOGGLE") ) then
			WatchFrame_StopTrackingAchievement(button, self.index);
		elseif ( not AchievementFrame:IsShown() ) then
			AchievementFrame_ToggleAchievementFrame();
			AchievementFrame_SelectAchievement(self.index);
		else
			if ( AchievementFrameAchievements.selection ~= self.index ) then
				AchievementFrame_SelectAchievement(self.index);
			else
				AchievementFrame_ToggleAchievementFrame();
			end
		end		
		return;
	end		
end

local achievementLineIndex = 1;
local function WatchFrame_GetAchievementLine ()
	local line = WATCHFRAME_ACHIEVEMENTLINES[achievementLineIndex];
	if ( not line ) then
		WATCHFRAME_ACHIEVEMENTLINES[achievementLineIndex] = WatchFrame.lineCache:GetFrame();
		line = WATCHFRAME_ACHIEVEMENTLINES[achievementLineIndex];
	end

	line:Reset();
	achievementLineIndex = achievementLineIndex + 1;
	return line;
end

local function WatchFrame_ResetAchievementLines ()
	achievementLineIndex = 1;
end

local function WatchFrame_ReleaseUnusedAchievementLines ()
	local line
	for i = achievementLineIndex, #WATCHFRAME_ACHIEVEMENTLINES do
		line = WATCHFRAME_ACHIEVEMENTLINES[i];
		line:Hide();
		line.frameCache:ReleaseFrame(line);
		WATCHFRAME_ACHIEVEMENTLINES[i] = nil;
	end
end

local questLineIndex = 1;
local function WatchFrame_GetQuestLine ()
	local line = WATCHFRAME_QUESTLINES[questLineIndex];
	if ( not line ) then
		WATCHFRAME_QUESTLINES[questLineIndex] = WatchFrame.lineCache:GetFrame();
		line = WATCHFRAME_QUESTLINES[questLineIndex];
	end

	line:Reset();
	questLineIndex = questLineIndex + 1;
	return line;
end

local function WatchFrame_ResetQuestLines ()
	questLineIndex = 1;
end

local function WatchFrame_ReleaseUnusedQuestLines ()
	local line
	for i = questLineIndex, #WATCHFRAME_QUESTLINES do
		line = WATCHFRAME_QUESTLINES[i];
		line:Hide();
		line.frameCache:ReleaseFrame(line);
		WATCHFRAME_QUESTLINES[i] = nil;
	end
end

local scenarioLineIndex = 1;
local function WatchFrame_GetScenarioLine(newParent)
	local line = WATCHFRAME_SCENARIOLINES[scenarioLineIndex];
	if ( not line ) then
		WATCHFRAME_SCENARIOLINES[scenarioLineIndex] = WatchFrame.lineCache:GetFrame();
		line = WATCHFRAME_SCENARIOLINES[scenarioLineIndex];
	end

	line:Reset();
	if (newParent ) then
		line:SetParent(newParent);
	end
	scenarioLineIndex = scenarioLineIndex + 1;
	return line;
end

local function WatchFrame_ResetScenarioLines()
	scenarioLineIndex = 1;
end

local function WatchFrame_ReleaseUnusedScenarioLines()
	local line
	for i = scenarioLineIndex, #WATCHFRAME_SCENARIOLINES do
		line = WATCHFRAME_SCENARIOLINES[i];
		line:Hide();
		line.icon:Hide();
		line.dash:SetWidth(0);
		line:SetParent(WatchFrameLines);
		line.frameCache:ReleaseFrame(line);
		WATCHFRAME_SCENARIOLINES[i] = nil;
	end
end

function WatchFrame_OnLoad (self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE");
	self:RegisterEvent("ITEM_PUSH");
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("WORLD_MAP_UPDATE");
	self:RegisterEvent("QUEST_POI_UPDATE");
	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("QUEST_AUTOCOMPLETE");
	self:RegisterEvent("SCENARIO_UPDATE");
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE");
	self:SetScript("OnSizeChanged", WatchFrame_OnSizeChanged); -- Has to be set here instead of in XML for now due to OnSizeChanged scripts getting run before OnLoad scripts.
	self.lineCache = UIFrameCache:New("FRAME", "WatchFrameLine", WatchFrameLines, "WatchFrameLineTemplate");
	self.buttonCache = UIFrameCache:New("BUTTON", "WatchFrameLinkButton", WatchFrameLines, "WatchFrameLinkButtonTemplate")
	watchFrameTestLine = self.lineCache:GetFrame();
	local titleWidth = WatchFrameTitle:GetWidth();
	WATCHFRAME_COLLAPSEDWIDTH = WatchFrameTitle:GetWidth() + 70;
	local _, fontHeight = watchFrameTestLine.text:GetFont();
	watchFrameTestLine.dash:SetText(QUEST_DASH);
	DASH_WIDTH = watchFrameTestLine.dash:GetWidth();
	WATCHFRAMELINES_FONTHEIGHT = fontHeight;
	WATCHFRAMELINES_FONTSPACING = (WATCHFRAME_LINEHEIGHT - WATCHFRAMELINES_FONTHEIGHT) / 2;
	WATCHFRAME_MULTIPLE_LINEHEIGHT = WATCHFRAMELINES_FONTHEIGHT * 2 + 5;
	WatchFrame_AddObjectiveHandler(WatchFrameScenario_DisplayScenario);
	WatchFrame_AddObjectiveHandler(WatchFrameAutoQuest_DisplayAutoQuestPopUps);
	WatchFrame_AddObjectiveHandler(WatchFrame_HandleDisplayQuestTimers);
	WatchFrame_AddObjectiveHandler(WatchFrame_HandleDisplayTrackedAchievements);
	WatchFrame_AddObjectiveHandler(WatchFrame_DisplayTrackedQuests);
	WatchFrame.updateTimer = WATCHFRAME_UPDATE_RATE;
end

function WatchFrame_OnEvent (self, event, ...)
	if ( event == "PLAYER_MONEY" and self.watchMoney ) then
		WatchFrame_Update(self);
		if ( self.collapsed ) then
			UIFrameFlash(WatchFrameTitleButtonHighlight, .5, .5, 5, false);
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		SetMapToCurrentZone();		-- forces WatchFrame event via the WORLD_MAP_UPDATE event
	elseif ( event == "QUEST_LOG_UPDATE" and not self.updating ) then -- May as well check here too and save some time
		if ( WatchFrame.showObjectives ) then
			WatchFrame_GetCurrentMapQuests();
		end
		WatchFrame_Update(self);
		if ( self.collapsed ) then
			UIFrameFlash(WatchFrameTitleButtonHighlight, .5, .5, 5, false);
		end
	elseif ( event == "TRACKED_ACHIEVEMENT_UPDATE" ) then
		local achievementID, criteriaID, elapsed, duration = ...;

		if ( not elapsed or not duration ) then
			-- Don't do anything
		elseif ( elapsed >= duration ) then
			WATCHFRAME_TIMEDCRITERIA[criteriaID] = nil;
		else		
			local timedCriteria = WATCHFRAME_TIMEDCRITERIA[criteriaID] or {};
			timedCriteria.achievementID = achievementID;
			timedCriteria.startTime = GetTime() - elapsed;
			timedCriteria.duration = duration;
			WATCHFRAME_TIMEDCRITERIA[criteriaID] = timedCriteria;
		end
		
		if ( self.collapsed ) then
			UIFrameFlash(WatchFrameTitleButtonHighlight, .5, .5, 5, false);
		end
		
		WatchFrame_Update();
	elseif ( event == "ITEM_PUSH" ) then
		WatchFrame_Update();
	elseif ( event == "SCENARIO_UPDATE" ) then
		local newStep = ...;
		if ( newStep ) then
			WatchFrame_Expand(self);
		else
			WatchFrame_Update();
		end
	elseif ( event == "SCENARIO_CRITERIA_UPDATE" ) then
		if ( not self.collapsed and self:IsShown() ) then
			WatchFrameScenario_ReadyCriteriaAnimation(...);
		end
		WatchFrame_Update();
	elseif ( event == "ZONE_CHANGED_NEW_AREA" ) then
		if ( not WorldMapFrame:IsShown() and WatchFrame.showObjectives ) then
			SetMapToCurrentZone();			-- update the zone to get the right POI numbers for the tracker
		end
	elseif ( event == "WORLD_MAP_UPDATE" or event == "QUEST_POI_UPDATE" and WatchFrame.showObjectives ) then
		WatchFrame_GetCurrentMapQuests();
		WatchFrame_Update();
	elseif ( event == "DISPLAY_SIZE_CHANGED" ) then
		WatchFrame_OnSizeChanged(self);
	elseif ( event == "VARIABLES_LOADED" ) then
		WatchFrame_SetWidth(GetCVar("watchFrameWidth"));
		WATCHFRAME_SORT_TYPE = tonumber(GetCVar("trackerSorting"));
		WATCHFRAME_FILTER_TYPE = tonumber(GetCVar("trackerFilter"));
	elseif ( event == "QUEST_AUTOCOMPLETE" ) then
		local questId = ...;
		if (WatchFrameAutoQuest_AddPopUp(questId, "COMPLETE")) then
			PlaySound("UI_AutoQuestComplete");
		end
	end
end

function WatchFrame_OnUpdate(self, elapsed)
	if ( WATCHFRAME_SORT_TYPE == WATCHFRAME_SORT_PROXIMITY ) then
		self.updateTimer = self.updateTimer - elapsed;
		if ( self.updateTimer < 0 ) then
			if ( SortQuestWatches() ) then
				WatchFrame_Update();
			end
			self.updateTimer = WATCHFRAME_UPDATE_RATE;
		end
	end
end

function WatchFrame_OnSizeChanged(self)
	WatchFrame_ClearDisplay();
	WatchFrame_Update(self)	
end

function WatchFrame_Collapse (self)
	self.collapsed = true;
	self:SetWidth(WATCHFRAME_COLLAPSEDWIDTH);
	WatchFrameLines:Hide();
	local button = WatchFrameCollapseExpandButton;
	local texture = button:GetNormalTexture();
	texture:SetTexCoord(0, 0.5, 0, 0.5);
	texture = button:GetPushedTexture();	
	texture:SetTexCoord(0.5, 1, 0, 0.5);
	WatchFrameScenario_StopCriteriaAnimation();
end

function WatchFrame_Expand (self)
	self.collapsed = nil;
	self:SetWidth(WATCHFRAME_EXPANDEDWIDTH);
	WatchFrameLines:Show();
	local button = WatchFrameCollapseExpandButton;
	local texture = button:GetNormalTexture();
	texture:SetTexCoord(0, 0.5, 0.5, 1);
	texture = button:GetPushedTexture();
	texture:SetTexCoord(0.5, 1, 0.5, 1);
	WatchFrame_Update(self);
end

function GetTimerTextColor (duration, elapsed)
	local START_PERCENTAGE_YELLOW = .66
	local START_PERCENTAGE_RED = .33
	
	local percentageLeft = 1 - ( elapsed / duration )
	if ( percentageLeft > START_PERCENTAGE_YELLOW ) then
		return 1, 1, 1	
	elseif ( percentageLeft > START_PERCENTAGE_RED ) then -- Start fading to yellow by eliminating blue
		local blueOffset = (percentageLeft - START_PERCENTAGE_RED) / (START_PERCENTAGE_YELLOW - START_PERCENTAGE_RED);
		return 1, 1, blueOffset;
	else
		local greenOffset = percentageLeft / START_PERCENTAGE_RED; -- Fade to red by eliminating green
		return 1, greenOffset, 0;
	end
end

function WatchFrame_ClearDisplay ()
	for _, timerLine in pairs(WATCHFRAME_TIMERLINES) do
		timerLine:Reset();
	end
	for _, achievementLine in pairs(WATCHFRAME_ACHIEVEMENTLINES) do
		achievementLine:Reset();
	end
	for _, questLine in pairs(WATCHFRAME_QUESTLINES) do
		questLine:Reset();
	end
	for i = 1, WATCHFRAME_NUM_ITEMS do
		_G["WatchFrameItem" .. i]:Hide();
	end
	QuestPOI_HideAllButtons("WatchFrameLines");
end

function WatchFrame_Update (self)
	self = self or WatchFrame; -- Speeds things up if we pass in this reference when we can conveniently.
	-- Display things in this order: quest timers, achievements, quests, addon subscriptions.
	if ( self.updating ) then
		return;
	end
	
	self.updating = true;
	self.watchMoney = false;
	
	local nextAnchor = nil;
	local lineFrame = WatchFrameLines;
	local maxHeight = (WatchFrame:GetTop() - WatchFrame:GetBottom()); -- Can't use lineFrame:GetHeight() because it could be an invalid rectangle (width of 0)
	
	local maxFrameWidth = WATCHFRAME_MAXLINEWIDTH;
	local maxWidth = 0;
	local maxLineWidth;
	local numObjectives;
	local totalObjectives = 0;
	WATCHFRAME_NUM_POPUPS = 0;
	
	WatchFrame_ResetLinkButtons();
	for i = 1, #WATCHFRAME_OBJECTIVEHANDLERS do
		nextAnchor, maxLineWidth, numObjectives, numPopUps = WATCHFRAME_OBJECTIVEHANDLERS[i](lineFrame, nextAnchor, maxHeight, maxFrameWidth);
		maxWidth = max(maxLineWidth, maxWidth);
		totalObjectives = totalObjectives + numObjectives;
		WATCHFRAME_NUM_POPUPS = WATCHFRAME_NUM_POPUPS + numPopUps;
	end
	
	--disabled for now, might make it an option
	--lineFrame:SetWidth(min(maxWidth, maxFrameWidth));
	
	-- shadow
	if ( WATCHFRAME_NUM_POPUPS > 0) then
		if (not lineFrame.Shadow:IsShown()) then
			lineFrame.Shadow:Show();
			lineFrame.Shadow.FadeIn:Play();
		end
	else
		lineFrame.Shadow:Hide();
	end
	
	if ( totalObjectives > 0 ) then
		WatchFrameHeader:Show();
		WatchFrameCollapseExpandButton:Show();
		WatchFrameTitle:SetText(OBJECTIVES_TRACKER_LABEL.." ("..totalObjectives..")");
		WatchFrameHeader:SetWidth(WatchFrameTitle:GetWidth() + 4);
		-- visible objectives?
		if ( nextAnchor ) then
			if ( self.collapsed and not self.userCollapsed ) then
				WatchFrame_Expand(self);
			end
			WatchFrameCollapseExpandButton:Enable();
		else
			if ( not self.collapsed ) then
				WatchFrame_Collapse(self);
			end
			WatchFrameCollapseExpandButton:Disable();		
		end		
	else
		WatchFrameHeader:Hide();
		WatchFrameCollapseExpandButton:Hide();
	end
	
	WatchFrame_ReleaseUnusedLinkButtons();
	
	self.updating = nil;
end

function WatchFrame_AddObjectiveHandler (func, index)
	local numFunctions = #WATCHFRAME_OBJECTIVEHANDLERS
	for i = 1, numFunctions do
		if ( WATCHFRAME_OBJECTIVEHANDLERS[i] == func ) then
			return;
		end
	end
	
	if ( index ) then
		tinsert(WATCHFRAME_OBJECTIVEHANDLERS, index, func);
	else
		tinsert(WATCHFRAME_OBJECTIVEHANDLERS, func);
	end
	return true;
end

function WatchFrame_RemoveObjectiveHandler (func)
	local numFunctions = #WATCHFRAME_OBJECTIVEHANDLERS
	for i = 1, numFunctions do
		if ( WATCHFRAME_OBJECTIVEHANDLERS[i] == func ) then
			tremove(WATCHFRAME_OBJECTIVEHANDLERS, i);
			return true;
		end
	end
end

function WatchFrame_HandleDisplayQuestTimers (lineFrame, nextAnchor, maxHeight, frameWidth)
	return WatchFrame_DisplayQuestTimers(lineFrame, nextAnchor, maxHeight, frameWidth, GetQuestTimers());
end

local timerLineIndex = 1;
local function WatchFrame_GetTimerLine ()
	local line = WATCHFRAME_TIMERLINES[timerLineIndex];
	if ( not line ) then
		WATCHFRAME_TIMERLINES[timerLineIndex] = WatchFrame.lineCache:GetFrame();
		line = WATCHFRAME_TIMERLINES[timerLineIndex];
	end
	
	line:Reset();
	timerLineIndex = timerLineIndex + 1;
	return line;
end

local function WatchFrame_ResetTimerLines ()
	timerLineIndex = 1;
end

local function WatchFrame_ReleaseUnusedTimerLines ()
	local line
	for i = timerLineIndex, #WATCHFRAME_TIMERLINES do
		line = WATCHFRAME_TIMERLINES[i];
		line:Hide();
		line:SetScript("OnEnter", nil);
		line:SetScript("OnLeave", nil);
		line:EnableMouse(false);
		line.frameCache:ReleaseFrame(line);
		WATCHFRAME_TIMERLINES[i] = nil;
	end
end

function WatchFrame_DisplayQuestTimers (lineFrame, nextAnchor, maxHeight, frameWidth, ...)
	local numTimers = select("#", ...);

	if ( numTimers == 0 ) then
		WatchFrame_ResetTimerLines();
		WatchFrame_ReleaseUnusedTimerLines();
		-- Nothing to see here, move along.
		if ( WATCHFRAME_NUM_TIMERS ~= 0 ) then
			WatchFrameLines_RemoveUpdateFunction(WatchFrame_HandleQuestTimerUpdate);
			WATCHFRAME_NUM_TIMERS = 0;
		end
		return nextAnchor, 0, 0, 0;
	end
	
	WatchFrame_ResetTimerLines();
	
	local lineCache = WatchFrame.lineCache;
	local maxWidth = 0;
	local heightUsed = 0;
	local watchFrame = WatchFrame;
	
	local line = WatchFrame_GetTimerLine();
	line.text:SetText(NORMAL_FONT_COLOR_CODE .. QUEST_TIMERS);
	line:Show();
	line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
	line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
	if (nextAnchor) then
		line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET);
	else
		line:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET)
	end

	heightUsed = heightUsed + line:GetHeight();
	maxWidth = line.text:GetStringWidth();
	
	nextAnchor = line;
	
	for i = 1, numTimers do
		line = WatchFrame_GetTimerLine();
		line.text:SetText(" - " .. SecondsToTime(select(i, ...)));
		line:Show();
		line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
		line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
		line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, 0);
		maxWidth = max(maxWidth, line.text:GetStringWidth());
		line:SetWidth(maxWidth) -- FIXME
		heightUsed = heightUsed + line:GetHeight();
		line:SetScript("OnEnter", function (self) GameTooltip:SetOwner(self); GameTooltip:SetHyperlink(GetQuestLink(GetQuestIndexForTimer(i))); GameTooltip:Show(); end);
		line:SetScript("OnLeave", GameTooltip_Hide);
		line:EnableMouse(true);
		nextAnchor = line;
	end
	
	if ( WATCHFRAME_NUM_TIMERS ~= numTimers ) then
		WATCHFRAME_NUM_TIMERS = numTimers;
		WatchFrameLines_AddUpdateFunction(WatchFrame_HandleQuestTimerUpdate);
	end
	
	WatchFrame_ReleaseUnusedTimerLines();
	return nextAnchor, maxWidth, 0, 0;
end

function WatchFrame_HandleQuestTimerUpdate ()
	return WatchFrame_QuestTimerUpdateFunction(GetQuestTimers());
end

function WatchFrame_QuestTimerUpdateFunction (...)
	local numTimers = select("#", ...);
	
	if ( numTimers ~= WATCHFRAME_NUM_TIMERS ) then
		-- We need to update the entire watch frame, the number of displayed timers has changed.
		return true;
	end
		
	for i = 1, numTimers do
		local line = WATCHFRAME_TIMERLINES[i+1]; -- The first timer line is always the "Quest Timers" line, so skip it.
		local seconds = select(i, ...);
		line.text:SetText(" - " .. SecondsToTime(seconds));
	end
end
	
function WatchFrame_HandleDisplayTrackedAchievements (lineFrame, nextAnchor, maxHeight, frameWidth)
	return WatchFrame_DisplayTrackedAchievements(lineFrame, nextAnchor, maxHeight, frameWidth, GetTrackedAchievements());
end

function WatchFrame_UpdateTimedAchievements (elapsed)
	local numAchievementLines = #WATCHFRAME_ACHIEVEMENTLINES
	local timeNow, timeLeft;
	
	local needsUpdate = false;
	for i = 1, numAchievementLines do
		local line = WATCHFRAME_ACHIEVEMENTLINES[i];
		if ( line and line.criteriaID and WATCHFRAME_TIMEDCRITERIA[line.criteriaID] ) then
			timeNow = timeNow or GetTime();
			timeLeft = math.floor(line.startTime + line.duration - timeNow);
			if ( timeLeft <= 0 ) then
				line.text:SetText(string.format(" - " .. SECONDS_ABBR, 0));
				line.text:SetTextColor(1, 0, 0, 1);
			else
				line.text:SetText(" - " .. SecondsToTime(timeLeft));
				line.text:SetTextColor(GetTimerTextColor(line.duration, line.duration - timeLeft));
				needsUpdate = true;
			end
		end
	end
	
	if ( not needsUpdate ) then
		WatchFrameLines_RemoveUpdateFunction(WatchFrame_UpdateTimedAchievements);
	end
end

function WatchFrame_SetLine(line, anchor, verticalOffset, isHeader, text, dash, hasItem, isComplete, eligible)
	-- anchor
	if ( anchor ) then
		line:SetPoint("RIGHT", anchor, "RIGHT", 0, 0);
		line:SetPoint("LEFT", anchor, "LEFT", 0, 0);
		line:SetPoint("TOP", anchor, "BOTTOM", 0, verticalOffset);
	end
	-- text
	line.text:SetText(text);
	if ( isHeader ) then
		WATCHFRAME_SETLINES_NUMLINES = 0;
		line.text:SetTextColor(0.75, 0.61, 0);
	else
		--this should be the default, set in WatchFrameLineTemplate_Reset
		if ( eligible ~= nil and eligible == false) then
			line.text.eligible = eligible;
			line.text:SetTextColor(DIM_RED_FONT_COLOR.r, DIM_RED_FONT_COLOR.g, DIM_RED_FONT_COLOR.b);
		else
			line.text.eligible = true;
			line.text:SetTextColor(0.8, 0.8, 0.8);
		end
	end
	-- dash
	local usedWidth = 0;
	if ( dash == DASH_SHOW ) then
		line.dash:SetText(QUEST_DASH);
		usedWidth = DASH_WIDTH;
	elseif ( dash == DASH_HIDE ) then
		line.dash:SetText(QUEST_DASH);
		line.dash:Hide();
		usedWidth = DASH_WIDTH;
	elseif ( dash == DASH_ICON ) then
		line.dash:SetWidth(DASH_ICON_WIDTH);
		usedWidth = DASH_ICON_WIDTH;
	end	
	-- multiple lines
	if ( hasItem and WATCHFRAME_SETLINES_NUMLINES < 2 ) then
		usedWidth = usedWidth + WATCHFRAME_ITEM_WIDTH;
	end
	line.text:SetWidth(WATCHFRAME_MAXLINEWIDTH - usedWidth);
	if ( line.text:GetHeight() > WATCHFRAME_LINEHEIGHT ) then
		if ( isComplete ) then
			line:SetHeight(line.text:GetHeight() + 4);
		else
			line:SetHeight(WATCHFRAME_MULTIPLE_LINEHEIGHT);
			line.text:SetHeight(WATCHFRAME_MULTIPLE_LINEHEIGHT);
		end
		WATCHFRAME_SETLINES_NUMLINES = WATCHFRAME_SETLINES_NUMLINES + 2;
	else
		WATCHFRAME_SETLINES_NUMLINES = WATCHFRAME_SETLINES_NUMLINES + 1;
	end
	tinsert(WATCHFRAME_SETLINES, line);	
end

function WatchFrame_DisplayTrackedAchievements (lineFrame, nextAnchor, maxHeight, frameWidth, ...)
	local _; -- Doing this here thanks to IBLJerry!
	local numTrackedAchievements = select("#", ...);
	local line;
	local achievementTitle;
	local previousLine;
	local linkButton;
	
	local numCriteria, criteriaDisplayed;
	local achievementID, achievementName, completed, description, icon;
	local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, name, flags, assetID, quantityString, criteriaID, eligible, achievementCategory;
	local _, instanceType = IsInInstance();
	local displayOnlyArena = ArenaEnemyFrames and ArenaEnemyFrames:IsShown() and (instanceType == "arena");

	local lineWidth = 0;
	local maxWidth = 0;
	local heightUsed = 0;
	local topEdge = 0;
	
	WatchFrame_ResetAchievementLines();	
	if ( bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_ACHIEVEMENTS) == WATCHFRAME_FILTER_ACHIEVEMENTS ) then
		for i = 1, numTrackedAchievements do
			WATCHFRAME_SETLINES = table.wipe(WATCHFRAME_SETLINES or { });
			achievementID = select(i, ...);
			achievementCategory = GetAchievementCategory(achievementID);
			_, achievementName, _, completed, _, _, _, description, _, icon, _, _, wasEarnedByMe = GetAchievementInfo(achievementID);
			if ( not wasEarnedByMe and (not displayOnlyArena) or achievementCategory == WATCHFRAME_ACHIEVEMENT_ARENA_CATEGORY ) then			
				-- achievement name
				line = WatchFrame_GetAchievementLine();
				achievementTitle = line;
				WatchFrame_SetLine(line, previousLine, -WATCHFRAME_QUEST_OFFSET, IS_HEADER, achievementName, DASH_NONE);
				if ( not previousLine ) then
					line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
					line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
					if (nextAnchor) then
						line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET);
					else
						line:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET);
					end
					topEdge = line:GetTop();
				end
				previousLine = line;
				-- criteria
				numCriteria = GetAchievementNumCriteria(achievementID);
				if ( numCriteria > 0 ) then
					criteriaDisplayed = 0;
					for j = 1, numCriteria do
						local dash = DASH_SHOW;		-- default since most will have this
						criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, name, flags, assetID, quantityString, criteriaID, eligible = GetAchievementCriteriaInfo(achievementID, j);
						if ( criteriaCompleted or ( criteriaDisplayed > WATCHFRAME_CRITERIA_PER_ACHIEVEMENT and not criteriaCompleted ) ) then
							-- Do not display this one
							criteriaString = nil;
							dash = DASH_NONE;
						elseif ( criteriaDisplayed == WATCHFRAME_CRITERIA_PER_ACHIEVEMENT ) then
							-- We ran out of space to display incomplete criteria >_<
							criteriaString = "...";
							dash = DASH_HIDE;
						else
							if ( WATCHFRAME_TIMEDCRITERIA[criteriaID] ) then
								-- not sure what this is for
								local timedCriteria = WATCHFRAME_TIMEDCRITERIA[criteriaID]
								line = WatchFrame_GetAchievementLine();
								line.criteriaID = criteriaID;
								line.duration = timedCriteria.duration;
								line.startTime = timedCriteria.startTime;
								WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, "<???>", DASH_NONE);
								previousLine = line;
								criteriaDisplayed = criteriaDisplayed + 1;
								WatchFrameLines_AddUpdateFunction(WatchFrame_UpdateTimedAchievements);
							end
							if ( bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR ) then
								-- progress bar
								if ( string.find(strlower(quantityString), "interface\\moneyframe") ) then	-- no easy way of telling it's a money progress bar
									criteriaString = quantityString.."\n"..description;
								else
									-- remove spaces so it matches the quest look, x/y
									criteriaString = string.gsub(quantityString, " / ", "/").." "..description;
								end
							else
								-- criteriaString and dash are already set for regular criteria
								-- for meta criteria look up the achievement name
								if ( criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID ) then
									_, criteriaString = GetAchievementInfo(assetID);
								end
							end
						end
						-- set up the line
						if ( criteriaString ) then
							line = WatchFrame_GetAchievementLine();
							WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, criteriaString, dash, nil, nil, eligible);
							previousLine = line;
							criteriaDisplayed = criteriaDisplayed + 1;
						end
					end
				else
					-- single criteria type of achievement
					eligible = IsAchievementEligible(achievementID);
					line = WatchFrame_GetAchievementLine();
					WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, description, DASH_SHOW, nil, nil, eligible);
					previousLine = line;				
					for criteriaID, timedCriteria in next, WATCHFRAME_TIMEDCRITERIA do
						if ( timedCriteria.achievementID == achievementID ) then
							-- not sure what this is for
							line = WatchFrame_GetAchievementLine();
							line.criteriaID = criteriaID;
							line.duration = timedCriteria.duration;
							line.startTime = timedCriteria.startTime;
							WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, "<???>", DASH_NONE)
							previousLine = line;
							WatchFrameLines_AddUpdateFunction(WatchFrame_UpdateTimedAchievements);
						end
					end				
				end

				-- stop processing if there's no room to fit the achievement
				local numLines = #WATCHFRAME_SETLINES;
				local previousBottom = previousLine:GetBottom();
				if ( previousBottom and previousBottom < WatchFrame:GetBottom() ) then				
					achievementLineIndex = achievementLineIndex - numLines;
					table.wipe(WATCHFRAME_SETLINES);
					if ( achievementLineIndex > 1 ) then
						previousLine = WATCHFRAME_ACHIEVEMENTLINES[achievementLineIndex - 1];
					else
						previousLine = nil;
					end
					break;
				else
					-- turn on all lines
					for _, line in pairs(WATCHFRAME_SETLINES) do
						line:Show();
						lineWidth = line.text:GetWidth() + line.dash:GetWidth();
						maxWidth = max(maxWidth, lineWidth);
					end
					-- turn on link button
					linkButton = WatchFrame_GetLinkButton();
					linkButton:SetPoint("TOPLEFT", achievementTitle.text);
					linkButton:SetPoint("BOTTOMLEFT", achievementTitle.text);
					linkButton:SetWidth(achievementTitle.text:GetStringWidth());
					linkButton.type = "ACHIEVEMENT";
					linkButton.index = achievementID;
					linkButton.lines = WATCHFRAME_ACHIEVEMENTLINES;
					linkButton.startLine = achievementLineIndex - numLines;
					linkButton.lastLine = achievementLineIndex - 1;
					linkButton.isComplete = nil;
					linkButton:Show();
					
					if ( previousBottom ) then
						heightUsed = topEdge - previousBottom;
					else
						heightUsed = 1;
					end
				end
			end
		end
	end

	WatchFrame_ReleaseUnusedAchievementLines();
	return previousLine or nextAnchor, maxWidth, numTrackedAchievements, 0;
end

function WatchFrame_DisplayTrackedQuests (lineFrame, nextAnchor, maxHeight, frameWidth)
	local _;
	local questTitle;
	local questIndex;	
	local line;
	local lastLine;
	local linkButton;
	local watchItemIndex = 0;
	local numVisible = 0;
	
	local numPOINumeric = 0;
	local numPOICompleteIn = 0;
	local numPOICompleteOut = 0;

	local text, finished, objectiveType;
	local numQuestWatches = GetNumQuestWatches();
	local numObjectives;
	local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID;
	local numValidQuests = 0;

	local maxWidth = 0;
	local lineWidth = 0;
	local topEdge = 0;

	local playerMoney = GetMoney();
	if ( not WorldMapFrame or not WorldMapFrame:IsShown() ) then
		-- For the filter REMOTE ZONES: when it's unchecked we need to display local POIs only. Unfortunately all the POI
		-- code uses the current map so the tracker would not display the right quests if the world map was windowed and
		-- open to a different zone.
		table.wipe(LOCAL_MAP_QUESTS);
		LOCAL_MAP_QUESTS["zone"] = GetCurrentMapZone();
		for id in pairs(CURRENT_MAP_QUESTS) do
			LOCAL_MAP_QUESTS[id] = true;
		end	
	end
	
	table.wipe(VISIBLE_WATCHES);
	WatchFrame_ResetQuestLines();
	
	if ((numQuestWatches == 0) or (not IsQuestWatched(GetQuestLogIndexByID(GetSuperTrackedQuestID())))) then
		SetSuperTrackedQuestID(0);
	end
	
	local inScenario = C_Scenario.IsInScenario();

	for i = 1, numQuestWatches do
		local validQuest = false;
		WATCHFRAME_SETLINES = table.wipe(WATCHFRAME_SETLINES or { });
		questIndex = GetQuestIndexForWatch(i);
		if ( questIndex ) then
			-- don't show non-scenario quests in scenarios
			if ( not inScenario or GetQuestLogQuestType(questIndex) == QUEST_TYPE_SCENARIO ) then
				validQuest = true;
			end
		end
		if ( validQuest ) then
			numValidQuests = numValidQuests + 1;
			title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID, startEvent = GetQuestLogTitle(questIndex);
			
			if (WORLDMAP_SETTINGS and GetSuperTrackedQuestID() == 0) then
				SetSuperTrackedQuestID(questID);
				WORLDMAP_SETTINGS.selectedQuestId = questID;
			end
			
			local questFailed = false;
			local requiredMoney = GetQuestLogRequiredMoney(questIndex);			
			numObjectives = GetNumQuestLeaderBoards(questIndex);
			if ( isComplete and isComplete < 0 ) then
				isComplete = false;
				questFailed = true;
			elseif ( numObjectives == 0 and playerMoney >= requiredMoney and not startEvent ) then
				isComplete = true;		
			end
			-- check filters
			local filterOK = true;
			if ( isComplete and bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_COMPLETED_QUESTS) ~= WATCHFRAME_FILTER_COMPLETED_QUESTS ) then
				filterOK = false;
			elseif ( bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_REMOTE_ZONES) ~= WATCHFRAME_FILTER_REMOTE_ZONES and not LOCAL_MAP_QUESTS[questID] ) then
				filterOK = false;
			end			
			
			if ( filterOK ) then
				local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questIndex);
				if ( requiredMoney > 0 ) then
					WatchFrame.watchMoney = true;	-- for update event			
				end
				questTitle = WatchFrame_GetQuestLine();
				WatchFrame_SetLine(questTitle, lastLine, -WATCHFRAME_QUEST_OFFSET, IS_HEADER, title, DASH_NONE, item);
				if ( not lastLine ) then -- First line
					questTitle:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
					questTitle:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
					if (nextAnchor) then
						questTitle:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET);
					else
						questTitle:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET);
					end
					topEdge = questTitle:GetTop();
				end
				lastLine = questTitle;
				
				if ( isComplete ) then
					local showItem = item and showItemWhenComplete;
					if (GetQuestLogIsAutoComplete(questIndex)) then
						line = WatchFrame_GetQuestLine();
						WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, QUEST_WATCH_QUEST_COMPLETE, DASH_HIDE, showItem, true);
						lastLine = line;
						line = WatchFrame_GetQuestLine();
						WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, QUEST_WATCH_CLICK_TO_COMPLETE, DASH_HIDE, showItem, true);
						lastLine = line;
					else
						line = WatchFrame_GetQuestLine();
						WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, GetQuestLogCompletionText(questIndex), DASH_SHOW, showItem, true);
						lastLine = line;
					end
				elseif ( questFailed ) then
					line = WatchFrame_GetQuestLine();
					WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, FAILED, DASH_HIDE, nil, nil, false);
					lastLine = line;
				else
					for j = 1, numObjectives do
						text, objectiveType, finished = GetQuestLogLeaderBoard(j, questIndex);
						if ( not finished and text ) then
							text = ReverseQuestObjective(text, objectiveType);
							line = WatchFrame_GetQuestLine();
							WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, text, DASH_SHOW, item);
							lastLine = line;
						end
					end
					if ( requiredMoney > playerMoney ) then
						text = GetMoneyString(playerMoney).." / "..GetMoneyString(requiredMoney);
						line = WatchFrame_GetQuestLine();
						WatchFrame_SetLine(line, lastLine, WATCHFRAMELINES_FONTSPACING, not IS_HEADER, text, DASH_SHOW, item);
						lastLine = line;
					end
				end

				-- stop processing if there's no room to fit the quest
				local numLines = #WATCHFRAME_SETLINES;
				local lastBottom = lastLine:GetBottom();
				if ( lastBottom and lastBottom < WatchFrame:GetBottom() ) then
					questLineIndex = questLineIndex - numLines;
					table.wipe(WATCHFRAME_SETLINES);
					break;
				end

				numVisible = numVisible + 1;
				table.insert(VISIBLE_WATCHES, numVisible, questIndex);		-- save the quest log index because watch order can change after dropdown is opened
				-- turn on quest item
				local itemButton;
				if ( item and (not isComplete or showItemWhenComplete) ) then
					watchItemIndex = watchItemIndex + 1;
					itemButton = _G["WatchFrameItem"..watchItemIndex];
					if ( not itemButton ) then
						WATCHFRAME_NUM_ITEMS = watchItemIndex;
						itemButton = CreateFrame("BUTTON", "WatchFrameItem" .. watchItemIndex, lineFrame, "WatchFrameItemButtonTemplate");
					end
					itemButton:Show();
					itemButton:ClearAllPoints();
					itemButton:SetID(questIndex);
					SetItemButtonTexture(itemButton, item);
					SetItemButtonCount(itemButton, charges);
					itemButton.charges = charges;
					WatchFrameItem_UpdateCooldown(itemButton);
					itemButton.rangeTimer = -1;
					itemButton:SetPoint("TOPRIGHT", questTitle, "TOPRIGHT", 10, -2);
				end			
				-- turn on all lines
				for _, line in pairs(WATCHFRAME_SETLINES) do
					line:Show();
					lineWidth = line.text:GetWidth() + line.dash:GetWidth();
					maxWidth = max(maxWidth, lineWidth);
				end
				-- turn on link button
				linkButton = WatchFrame_GetLinkButton();
				linkButton:SetPoint("TOPLEFT", questTitle);
				linkButton:SetPoint("BOTTOMLEFT", questTitle);
				linkButton:SetPoint("RIGHT", questTitle.text);
				linkButton.type = "QUEST"
				linkButton.index = i; -- We want the Watch index, we'll get the quest index later with GetQuestIndexForWatch(i);
				linkButton.lines = WATCHFRAME_QUESTLINES;
				linkButton.startLine = questLineIndex - numLines;
				linkButton.lastLine = questLineIndex - 1;
				linkButton.isComplete = isComplete;
				linkButton:Show();				
				-- quest POI icon
				if ( WatchFrame.showObjectives ) then
					local poiButton;
					if ( CURRENT_MAP_QUESTS[questID] ) then
						if ( isComplete ) then
							numPOICompleteIn = numPOICompleteIn + 1;
							poiButton = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_IN, numPOICompleteIn, questID);
						else
							numPOINumeric = numPOINumeric + 1;
							poiButton = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_NUMERIC, numPOINumeric, questID);
						end
					elseif ( isComplete ) then
						numPOICompleteOut = numPOICompleteOut + 1;
						poiButton = QuestPOI_DisplayButton("WatchFrameLines", QUEST_POI_COMPLETE_OUT, numPOICompleteOut, questID);
					end
					if ( poiButton ) then
						poiButton:SetPoint("TOPRIGHT", questTitle, "TOPLEFT", 0, 5);
					end				
				end
				
			end
		end
	end

	for i = watchItemIndex + 1, WATCHFRAME_NUM_ITEMS do
		_G["WatchFrameItem" .. i]:Hide();
	end
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_NUMERIC, numPOINumeric + 1);
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_IN, numPOICompleteIn + 1);
	QuestPOI_HideButtons("WatchFrameLines", QUEST_POI_COMPLETE_OUT, numPOICompleteOut + 1);
	
	WatchFrame_ReleaseUnusedQuestLines();

	if ( WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuestId ) then
		QuestPOIUpdateIcons();
		QuestPOI_SelectButtonByQuestId("WatchFrameLines", WORLDMAP_SETTINGS.selectedQuestId, true);	
	end
	
	return lastLine or nextAnchor, maxWidth, numValidQuests, 0;
end

function WatchFrameLines_OnUpdate (self, elapsed)
	for i = 1, self.numFunctions do
		if ( self.updateFunctions[i](elapsed) ) then -- If a function returns true, update the entire watch frame (the number of lines changed). 
			WatchFrame_Update(WatchFrame);
			return;
		end
	end
end

function WatchFrameLines_AddUpdateFunction (func)
	local self = WatchFrameLines;
	local numFunctions = self.numFunctions
	for i = 1, numFunctions do
		if ( self.updateFunctions[i] == func ) then
			return;
		end
	end
	
	tinsert(self.updateFunctions, func);
	self.numFunctions = self.numFunctions + 1;
	self:SetScript("OnUpdate", WatchFrameLines_OnUpdate);
end

function WatchFrameLines_RemoveUpdateFunction (func)
	local self = WatchFrameLines;
	local numFunctions = WatchFrameLines.numFunctions
	for i = 1, numFunctions do
		if ( self.updateFunctions[i] == func ) then
			tremove(self.updateFunctions, i);
			self.numFunctions = self.numFunctions - 1;
			break;
		end
	end
	
	if ( self.numFunctions == 0 ) then
		self:SetScript("OnUpdate", nil);
	end
end

function WatchFrame_OpenQuestLog (button, arg1, arg2, checked)
	ExpandQuestHeader(GetQuestIndexForWatch(arg1));
	-- you have to call GetQuestIndexForWatch again because ExpandQuestHeader will sort the indices
	QuestLog_OpenToQuest(GetQuestIndexForWatch(arg1), arg2);
end

function WatchFrame_AbandonQuest (button, arg1, arg2, checked)
	local lastQuest = GetQuestLogSelection();
	local lastNumQuests = GetNumQuestLogEntries();
	SelectQuestLogEntry(GetQuestIndexForWatch(arg1)); -- More or less QuestLogFrameAbandonButton_OnClick, may want to consolidate
	SetAbandonQuest();
	
	local items = GetAbandonQuestItems();
	if ( items ) then
		StaticPopup_Hide("ABANDON_QUEST");
		StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), items);
	else
		StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS");
		StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName());
	end
	SelectQuestLogEntry(lastQuest);
end

function WatchFrame_ShareQuest (button, arg1, arg2, checked)
	QuestLogPushQuest(GetQuestIndexForWatch(arg1));
end

function WatchFrame_StopTrackingQuest (button, arg1, arg2, checked)
	RemoveQuestWatch(GetQuestIndexForWatch(arg1));
	WatchFrame_Update();
	QuestLog_Update();
end

function WatchFrame_OpenMapToQuest (button, arg1)
	local index = GetQuestIndexForWatch(arg1);
	local questID = select(9, GetQuestLogTitle(index));
	WorldMap_OpenToQuest(questID);
end

function WatchFrame_OpenAchievementFrame (button, arg1, arg2, checked)
	if ( not AchievementFrame ) then
		AchievementFrame_LoadUI();
	end

	if ( not AchievementFrame:IsShown() ) then
		AchievementFrame_ToggleAchievementFrame();
		AchievementFrame_SelectAchievement(arg1);
	else
		if ( AchievementFrameAchievements.selection ~= arg1 ) then
			AchievementFrame_SelectAchievement(arg1);
		else
			AchievementFrame_ToggleAchievementFrame();
		end
	end	
end

function WatchFrame_StopTrackingAchievement (button, arg1, arg2, checked)
	RemoveTrackedAchievement(arg1);
	WatchFrame_Update();
	if ( AchievementFrame ) then
		AchievementFrameAchievements_ForceUpdate(); -- Quests handle this automatically because they have spiffy events.
	end
end

function WatchFrameDropDown_OnHide ()
	WatchFrame.dropDownOpen = nil; 
	
	if ( WatchFrame.lastLinkButton ) then 
		WatchFrame.lastLinkButton = nil;
	end 
end

function WatchFrameDropDown_OnLoad (self)
	UIDropDownMenu_Initialize(self, WatchFrameDropDown_Initialize, "MENU");
	self.onHide = WatchFrameDropDown_OnHide;
end

function WatchFrameDropDown_Initialize (self)
	if ( self.type == "QUEST" ) then
		local info = UIDropDownMenu_CreateInfo();
		local questLogIndex = GetQuestIndexForWatch(self.index);
		info.text = GetQuestLogTitle(questLogIndex);
		info.isTitle = 1;
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);

		info = UIDropDownMenu_CreateInfo();
		info.notCheckable = 1;
		
		info.text = OBJECTIVES_VIEW_IN_QUESTLOG;
		info.func = WatchFrame_OpenQuestLog;
		info.arg1 = self.index;
		info.arg2 = true;
		info.noClickSound = 1;		
		info.checked = false;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		
		info.text = OBJECTIVES_STOP_TRACKING;
		info.func = WatchFrame_StopTrackingQuest;
		info.arg1 = self.index;
		info.checked = false;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		
		if ( GetQuestLogPushable(GetQuestIndexForWatch(self.index)) and IsInGroup() ) then
			info.text = SHARE_QUEST;
			info.func = WatchFrame_ShareQuest;
			info.arg1 = self.index;
			info.checked = false;
			UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		end
		if ( WatchFrame.showObjectives ) then
			info.text = OBJECTIVES_SHOW_QUEST_MAP;
			info.func = WatchFrame_OpenMapToQuest;
			info.arg1 = self.index;
			info.checked = false;
			info.noClickSound = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		end
		local numVisibleWatches = #VISIBLE_WATCHES;
		if ( numVisibleWatches > 1 ) then
			local visibleIndex = WatchFrame_GetVisibleIndex(questLogIndex);
			if ( visibleIndex > 1 ) then
				info.text = TRACKER_SORT_MANUAL_UP;
				info.func = WatchFrame_MoveQuest;
				info.arg1 = questLogIndex;
				info.arg2 = -1;
				info.checked = false;
				UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
				info.text = TRACKER_SORT_MANUAL_TOP;
				info.func = WatchFrame_MoveQuest;			
				info.arg1 = questLogIndex;
				info.arg2 = -100;		-- ensure move up to top regardless of reordering after dropdown has been opened
				info.checked = false;
				UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
			end
			if ( visibleIndex < numVisibleWatches ) then
				info.text = TRACKER_SORT_MANUAL_DOWN;
				info.func = WatchFrame_MoveQuest;
				info.arg1 = questLogIndex;
				info.arg2 = 1;
				info.checked = false;
				UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
				info.text = TRACKER_SORT_MANUAL_BOTTOM;
				info.func = WatchFrame_MoveQuest;
				info.arg1 = questLogIndex;
				info.arg2 = 100;		-- ensure move down to bottom regardless of reordering after dropdown has been opened
				info.checked = false;
				UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
			end			
		end
	elseif ( self.type == "ACHIEVEMENT" ) then
		local _, achievementName, _, completed, _, _, _, _, _, icon = GetAchievementInfo(self.index);
		local info = UIDropDownMenu_CreateInfo();
		info.text = achievementName;
		info.isTitle = 1;
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		
		info = UIDropDownMenu_CreateInfo();
		info.notCheckable = 1;
		
		info.text = OBJECTIVES_VIEW_ACHIEVEMENT;
		info.func = WatchFrame_OpenAchievementFrame;
		info.arg1 = self.index;
		info.checked = false;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		
		info.text = OBJECTIVES_STOP_TRACKING;
		info.func = WatchFrame_StopTrackingAchievement;
		info.arg1 = self.index;
		info.checked = false;
		UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	end
end

function WatchFrame_CollapseExpandButton_OnClick (self)
	local WatchFrame = WatchFrame;
	if ( WatchFrame.collapsed ) then
		WatchFrame.userCollapsed = nil;
		WatchFrame_Expand(WatchFrame);
		PlaySound("igMiniMapOpen");
	else
		WatchFrame.userCollapsed = true;
		WatchFrame_Collapse(WatchFrame);
		PlaySound("igMiniMapClose");
	end
end

local function WatchFrameLineTemplate_Reset (self)
	self:ClearAllPoints();
	self.text:SetText("");
	self.text:SetTextColor(0.8, 0.8, 0.8);
	self.text:Show();
	self.dash:SetText(nil);
	self.dash:Show();
	self:SetHeight(WATCHFRAME_LINEHEIGHT);
	self.text:SetHeight(0);	
	self.criteriaID = nil;	
end

function WatchFrameLineTemplate_OnLoad (self)
	local name = self:GetName();
	self.Reset = WatchFrameLineTemplate_Reset;
end

function WatchFrameItem_UpdateCooldown (self)
	local itemCooldown = _G[self:GetName().."Cooldown"];
	local start, duration, enable = GetQuestLogSpecialItemCooldown(self:GetID());
	if ( start ) then
		CooldownFrame_SetTimer(itemCooldown, start, duration, enable);
		if ( duration > 0 and enable == 0 ) then
			SetItemButtonTextureVertexColor(self, 0.4, 0.4, 0.4);
		else
			SetItemButtonTextureVertexColor(self, 1, 1, 1);
		end
	end
end
		
function WatchFrameItem_OnLoad (self)
	self:RegisterForClicks("AnyUp");
end

function WatchFrameItem_OnEvent (self, event, ...)
	if ( event == "PLAYER_TARGET_CHANGED" ) then
		self.rangeTimer = -1;
	elseif ( event == "BAG_UPDATE_COOLDOWN" ) then
		WatchFrameItem_UpdateCooldown(self);
	end
end

function WatchFrameItem_OnUpdate (self, elapsed)
	-- Handle range indicator
	local rangeTimer = self.rangeTimer;
	if ( rangeTimer ) then
		rangeTimer = rangeTimer - elapsed;
		if ( rangeTimer <= 0 ) then
			local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(self:GetID());
			if ( not charges or charges ~= self.charges ) then
				WatchFrame_Update();
				return;
			end
			local count = _G[self:GetName().."HotKey"];
			local valid = IsQuestLogSpecialItemInRange(self:GetID());
			if ( valid == 0 ) then
				count:Show();
				count:SetVertexColor(1.0, 0.1, 0.1);
			elseif ( valid == 1 ) then
				count:Show();
				count:SetVertexColor(0.6, 0.6, 0.6);
			else
				count:Hide();
			end
			rangeTimer = TOOLTIP_UPDATE_TIME;
		end
		
		self.rangeTimer = rangeTimer;
	end
end

function WatchFrameItem_OnShow (self)
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("BAG_UPDATE_COOLDOWN");
end

function WatchFrameItem_OnHide (self)
	self:UnregisterEvent("PLAYER_TARGET_CHANGED");
	self:UnregisterEvent("BAG_UPDATE_COOLDOWN");
end

function WatchFrameItem_OnEnter (self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetQuestLogSpecialItem(self:GetID());
end
		
function WatchFrameItem_OnClick (self, button, down)
	local questIndex = self:GetID();
	if ( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
		local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questIndex);
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
	else
		UseQuestLogSpecialItem(questIndex);
	end
end

function WatchFrameLinkButtonTemplate_Highlight(self, onEnter)
	local line;
	for index = self.startLine, self.lastLine do
		line = self.lines[index];
		if ( line ) then
			if ( index == self.startLine ) then
				-- header
				if ( onEnter ) then
					line.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				else
					line.text:SetTextColor(0.75, 0.61, 0);
				end
			else
				if ( onEnter ) then
					if (line.text.eligible) then
						line.text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
					else
						line.text:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
					end
					line.dash:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				else
					if (line.text.eligible) then
						line.text:SetTextColor(0.8, 0.8, 0.8);
					else
						line.text:SetTextColor(DIM_RED_FONT_COLOR.r, DIM_RED_FONT_COLOR.g, DIM_RED_FONT_COLOR.b);
					end
					line.dash:SetTextColor(0.8, 0.8, 0.8);
				end
			end
		end
	end
end

function WatchFrame_GetCurrentMapQuests()
	local numQuests = QuestMapUpdateAllQuests();
	table.wipe(CURRENT_MAP_QUESTS);	
	for i = 1, numQuests do
		local questId = QuestPOIGetQuestIDByVisibleIndex(i);
		CURRENT_MAP_QUESTS[questId] = i;
	end
end

function WatchFrameQuestPOI_OnClick(self, button)
	WORLDMAP_SETTINGS.selectedQuestId = self.questId;
	QuestPOI_SelectButtonByQuestId("WatchFrameLines", self.questId, true);
	SetSuperTrackedQuestID(self.questId);
	PlaySound("igMainMenuOptionCheckBoxOn");
end

function WatchFrame_SetWidth(width)
	if ( width == "0" ) then
		WATCHFRAME_EXPANDEDWIDTH = 204;
		WATCHFRAME_MAXLINEWIDTH = 192;
	else
		WATCHFRAME_EXPANDEDWIDTH = 306;
		WATCHFRAME_MAXLINEWIDTH = 294;
	end
	WatchFrameScenarioPopUpFrame:SetWidth(WATCHFRAME_EXPANDEDWIDTH);
	if ( WatchFrame:IsShown() and not WatchFrame.collapsed ) then
		WatchFrame:SetWidth(WATCHFRAME_EXPANDEDWIDTH);
		WatchFrame_Update();
	end
end

-- header dropdown
function WatchFrameHeader_OnClick(self, button)
	if ( button == "RightButton" ) then	
		ToggleDropDownMenu(1, nil, WatchFrameHeaderDropDown, "cursor", 3, -3)
	end
end

function WatchFrameHeaderDropDown_OnLoad (self)
	UIDropDownMenu_Initialize(self, WatchFrameHeaderDropDown_Initialize, "MENU");
end

function WatchFrameHeaderDropDown_Initialize (self)
	local info = UIDropDownMenu_CreateInfo();
	-- sort label
	info.text = TRACKER_SORT_LABEL;
	info.isTitle = 1;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- sort: proximity
	info = UIDropDownMenu_CreateInfo();
	info.checked = (WATCHFRAME_SORT_TYPE == WATCHFRAME_SORT_PROXIMITY);
	info.text = TRACKER_SORT_PROXIMITY;
	info.tooltipTitle = TRACKER_SORT_PROXIMITY;
	info.tooltipText = TOOLTIP_TRACKER_SORT_PROXIMITY;
	info.arg1 = WATCHFRAME_SORT_PROXIMITY;
	info.func = WatchFrame_SetSorting;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- sort: difficulty high
	info = UIDropDownMenu_CreateInfo();
	info.checked = (WATCHFRAME_SORT_TYPE == WATCHFRAME_SORT_DIFFICULTY_HIGH);	
	info.text = TRACKER_SORT_DIFFICULTY_HIGH;
	info.tooltipTitle = TRACKER_SORT_DIFFICULTY_HIGH;
	info.tooltipText = TOOLTIP_TRACKER_SORT_DIFFICULTY_HIGH;
	info.arg1 = WATCHFRAME_SORT_DIFFICULTY_HIGH;
	info.func = WatchFrame_SetSorting;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- sort: difficulty low
	info = UIDropDownMenu_CreateInfo();
	info.checked = (WATCHFRAME_SORT_TYPE == WATCHFRAME_SORT_DIFFICULTY_LOW);
	info.text = TRACKER_SORT_DIFFICULTY_LOW;
	info.tooltipTitle = TRACKER_SORT_DIFFICULTY_LOW;
	info.tooltipText = TOOLTIP_TRACKER_SORT_DIFFICULTY_LOW;
	info.arg1 = WATCHFRAME_SORT_DIFFICULTY_LOW;
	info.func = WatchFrame_SetSorting;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- sort: manual	
	info = UIDropDownMenu_CreateInfo();
	info.checked = (WATCHFRAME_SORT_TYPE == WATCHFRAME_SORT_MANUAL);
	info.text = TRACKER_SORT_MANUAL;
	info.tooltipTitle = TRACKER_SORT_MANUAL;
	info.tooltipText = TOOLTIP_TRACKER_SORT_MANUAL;	
	info.arg1 = WATCHFRAME_SORT_MANUAL;
	info.func = WatchFrame_SetSorting;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- filter label
	info.text = TRACKER_FILTER_LABEL;
	info.checked = false;
	info.isTitle = 1;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- filter: achievements
	info = UIDropDownMenu_CreateInfo();
	info.checked = (bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_ACHIEVEMENTS) == WATCHFRAME_FILTER_ACHIEVEMENTS);
	info.text = TRACKER_FILTER_ACHIEVEMENTS;
	info.tooltipTitle = TRACKER_FILTER_ACHIEVEMENTS;
	info.tooltipText = TOOLTIP_TRACKER_FILTER_ACHIEVEMENTS;
	info.arg1 = WATCHFRAME_FILTER_ACHIEVEMENTS;
	info.func = WatchFrame_SetFilter;
	info.isNotRadio = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
	-- filter: completed quests
	info = UIDropDownMenu_CreateInfo();
	info.checked = (bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_COMPLETED_QUESTS) == WATCHFRAME_FILTER_COMPLETED_QUESTS);
	info.text = TRACKER_FILTER_COMPLETED_QUESTS;
	info.tooltipTitle = TRACKER_FILTER_COMPLETED_QUESTS;
	info.tooltipText = TOOLTIP_TRACKER_FILTER_COMPLETED_QUESTS;
	info.arg1 = WATCHFRAME_FILTER_COMPLETED_QUESTS;
	info.func = WatchFrame_SetFilter;
	info.isNotRadio = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);	
	-- filter: current zone
	info = UIDropDownMenu_CreateInfo();
	info.checked = (bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_REMOTE_ZONES) == WATCHFRAME_FILTER_REMOTE_ZONES);
	info.text = TRACKER_FILTER_REMOTE_ZONES;
	info.tooltipTitle = TRACKER_FILTER_REMOTE_ZONES;
	info.tooltipText = TOOLTIP_TRACKER_FILTER_REMOTE_ZONES;
	info.arg1 = WATCHFRAME_FILTER_REMOTE_ZONES;
	info.func = WatchFrame_SetFilter;
	info.isNotRadio = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);	
end

function WatchFrame_SetSorting(button, arg1)
	WATCHFRAME_SORT_TYPE = arg1;
	SetCVar("trackerSorting", WATCHFRAME_SORT_TYPE);
	if ( WATCHFRAME_SORT_TYPE ~= WATCHFRAME_SORT_MANUAL ) then
		SortQuestWatches();
		WatchFrame_Update();
		WatchFrame.updateTimer = WATCHFRAME_UPDATE_RATE;
		if ( WorldMapFrame:IsShown() ) then
			WorldMapFrame_UpdateMap();
		end
	end
end

function WatchFrame_SetFilter(button, arg1)
	if ( bit.band(WATCHFRAME_FILTER_TYPE, arg1) == arg1 ) then
		WATCHFRAME_FILTER_TYPE = WATCHFRAME_FILTER_TYPE - arg1;
	else
		WATCHFRAME_FILTER_TYPE = WATCHFRAME_FILTER_TYPE + arg1;
	end
	SetCVar("trackerFilter", WATCHFRAME_FILTER_TYPE);
	WatchFrame_Update();
end

function WatchFrame_GetVisibleIndex(questLogIndex)
	for i = 1, #VISIBLE_WATCHES do
		if ( VISIBLE_WATCHES[i] == questLogIndex ) then
			return i;
		end
	end
end

function WatchFrame_MoveQuest(button, questLogIndex, numMoves)
	if ( WATCHFRAME_SORT_TYPE ~= WATCHFRAME_SORT_MANUAL ) then
		WatchFrame_SetSorting(nil, WATCHFRAME_SORT_MANUAL);
		UIErrorsFrame:AddMessage(TRACKER_SORT_MANUAL_WARNING, 1.0, 1.0, 0.0, 1.0);
	end
	local numVisibleWatches = #VISIBLE_WATCHES;
	local indexStart = WatchFrame_GetVisibleIndex(questLogIndex);
	local indexEnd = indexStart + numMoves;
	if ( indexEnd < 1 ) then
		indexEnd = 1;
	elseif ( indexEnd > numVisibleWatches ) then
		indexEnd = numVisibleWatches;
	end
	ShiftQuestWatches(GetQuestWatchIndex(questLogIndex), GetQuestWatchIndex(VISIBLE_WATCHES[indexEnd]));
	WatchFrame_Update();
	if ( WorldMapFrame:IsShown() ) then
		WorldMapFrame_UpdateMap();
	end
end


-- AutoQuest pop-ups
local numPopUpFrames = 0;

function WatchFrameAutoQuest_GetOrCreateFrame(parent, index)
	if (_G["WatchFrameAutoQuestPopUp"..index]) then
		return _G["WatchFrameAutoQuestPopUp"..index];
	end
	local frame = CreateFrame("SCROLLFRAME", "WatchFrameAutoQuestPopUp"..index, parent, "WatchFrameAutoQuestPopUpTemplate");	
	frame.isFirst = (index == 1 and WATCHFRAME_NUM_POPUPS == 0);	-- used by slide-in animation
	numPopUpFrames = numPopUpFrames+1;
	return frame;
end

function WatchFrameAutoQuest_DisplayAutoQuestPopUps(lineFrame, nextAnchor, maxHeight, frameWidth)
	local numPopUps = 0;
	local maxWidth = 0;
	local i;
	local numAutoQuestPopUps = GetNumAutoQuestPopUps();
	for i=1, numAutoQuestPopUps do
		local questID, popUpType = GetAutoQuestPopUp(i);
		local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, _ = GetQuestLogTitle(GetQuestLogIndexByID(questID));
				
		if ( isComplete and isComplete > 0 ) then
			isComplete = true;
		else
			isComplete = false;
		end	
			
		if (questTitle and questTitle ~= "") then
			local frame = WatchFrameAutoQuest_GetOrCreateFrame(lineFrame, numPopUps+1);
			frame:Show();
			frame:ClearAllPoints();
			frame:SetParent(lineFrame);
			
			if (not frame.questId) then
				-- Only show the animation for new notifications
				frame.ScrollChild.Flash:Hide();
				WatchFrame_SlideInFrame(frame, "AUTOQUEST");
			end
			
			if (isComplete and popUpType == "COMPLETE") then
				frame.ScrollChild.QuestionMark:Show();
				frame.ScrollChild.Exclamation:Hide();
				frame.ScrollChild.TopText:SetText(QUEST_WATCH_POPUP_CLICK_TO_COMPLETE);
				frame.ScrollChild.BottomText:Hide();
				frame.ScrollChild.TopText:SetPoint("TOP", 0, -12);
				frame.ScrollChild.QuestName:SetPoint("TOP", 0, -32);
				if (frame.questId and frame.type=="OFFER") then
					frame.ScrollChild.Flash:Show();
				end
				frame.type="COMPLETED";
			elseif (popUpType == "OFFER") then
				frame.ScrollChild.QuestionMark:Hide();
				frame.ScrollChild.Exclamation:Show();
				frame.ScrollChild.TopText:SetText(QUEST_WATCH_POPUP_QUEST_DISCOVERED);
				frame.ScrollChild.BottomText:Show();
				frame.ScrollChild.BottomText:SetText(QUEST_WATCH_POPUP_CLICK_TO_VIEW);
				frame.ScrollChild.TopText:SetPoint("TOP", 0, -4);
				frame.ScrollChild.QuestName:SetPoint("TOP", 0, -24);
				frame.ScrollChild.Flash:Hide();
				frame.type="OFFER";
			end
			
			frame:ClearAllPoints();
			if (nextAnchor) then
				if (i == 1) then
					frame:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET);
				else
					frame:SetPoint("TOP", nextAnchor, "BOTTOM", 0, 0);
				end
			else
				-- Cancel out the WATCHFRAME_TYPE_OFFSET here, it will be added into the animation for the first pop-up.  Also add 1 for the initial height of the pop-up.
				-- This prevents tracked quests from moving a bit initially while the background shadow is fading in.
				frame:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET+WATCHFRAME_TYPE_OFFSET+1);
			end
			frame:SetPoint("LEFT", lineFrame, "LEFT", -30, 0);

			frame.ScrollChild.QuestName:SetText(questTitle);
			frame.questId = questID;
			
			maxWidth = max(maxWidth, frame:GetWidth());
			nextAnchor = frame;
			numPopUps = numPopUps+1;
		end
	end
	
	for i=numPopUps+1, numPopUpFrames do
		_G["WatchFrameAutoQuestPopUp"..i].questId = nil;
		_G["WatchFrameAutoQuestPopUp"..i]:Hide();
	end
	
	return nextAnchor, maxWidth, 0, numPopUps;
end

function WatchFrameAutoQuest_OnFinishSlideIn(frame)
	frame.ScrollChild.Shine:Show();
	frame.ScrollChild.IconShine:Show();
	frame.ScrollChild.Shine.Flash:Play();
	frame.ScrollChild.IconShine.Flash:Play();
end

function WatchFrameAutoQuest_AddPopUp(questId, type)
	if (AddAutoQuestPopUp(questId, type)) then
		WatchFrame_Update(WatchFrame);
		WatchFrame_Expand(WatchFrame);
		return true;
	end
	return false;
end

function WatchFrameAutoQuest_ClearPopUp(questId)
	RemoveAutoQuestPopUp(questId);
	WatchFrame_Update(WatchFrame);
end

function WatchFrameAutoQuest_ClearPopUpByLogIndex(questIndex)
	local questId = select(9, GetQuestLogTitle(questIndex));
	WatchFrameAutoQuest_ClearPopUp(questId);
end

--------------------------------------------------------------------------------------------
-- Scenario
--------------------------------------------------------------------------------------------
local SCENARIO_POPUP_BASE_HEIGHT = 83;

function WatchFrameScenario_DisplayScenario(lineFrame, nextAnchor, maxHeight, frameWidth)
	WatchFrame_ResetScenarioLines();
	-- for return values
	local width = 0;
	local numObjectives = 0;
	local numPopups = 0;

	local animationCriteriaID = ScenarioCriteriaAnimationLine.criteriaID;
	local popupFrame = WatchFrameScenarioPopUpFrame;
	local name, currentStage, numStages = C_Scenario.GetInfo();
	if ( currentStage > 0 and currentStage <= numStages ) then
		local initialCriteriaOffset;
		local stageName, stageDescription, numCriteria = C_Scenario.GetStepInfo();
		local inChallengeMode = C_Scenario.IsChallengeMode();
		local linesParent;		-- if using the scenario header, lines need to be parented to WatchFrameScenarioPopUpFrame
		if ( not inChallengeMode ) then
			popupFrame:SetParent(lineFrame);
			popupFrame:ClearAllPoints();
			if (nextAnchor) then
				popupFrame:SetPoint("TOPLEFT", nextAnchor, "BOTTOMLEFT", 0, -WATCHFRAME_TYPE_OFFSET);
			else
				popupFrame:SetPoint("TOPLEFT", lineFrame, "TOPLEFT", 0, -WATCHFRAME_INITIAL_OFFSET + 4)
			end
			local frame = WatchFrameScenarioFrame;
			linesParent = WatchFrameScenarioFrame;
			nextAnchor = frame;
			-- step info
			if ( currentStage == numStages ) then
				frame.stageLevel:SetText(SCENARIO_STAGE_FINAL);
				frame.finalBg:Show();
			else
				frame.stageLevel:SetFormattedText(SCENARIO_STAGE, currentStage);
				frame.finalBg:Hide();
			end
			frame.stageName:SetText(stageName);
			if ( frame.stageName:GetStringWidth() > frame.stageName:GetWrappedWidth() ) then
				frame.stageLevel:SetPoint("TOPLEFT", 15, -10);
			else
				frame.stageLevel:SetPoint("TOPLEFT", 15, -18);
			end
			
			WATCHFRAME_SETLINES_NUMLINES = 0;	-- have to manually reset this since we're not using a normal header
			popupFrame:Show();
			initialCriteriaOffset = 0;
		else
			local line = WatchFrame_GetScenarioLine();
			WatchFrame_SetLine(line, _, WATCHFRAMELINES_FONTSPACING - 6, IS_HEADER, stageName, DASH_NONE);
			line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
			line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
			if (nextAnchor) then
				line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET);
			else
				line:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET);
			end
			line:Show();
			nextAnchor = line;
			popupFrame:Hide();
			initialCriteriaOffset = WATCHFRAME_SCENARIO_LINE_OFFSET;
		end
		-- criteria info
		local contentHeight = SCENARIO_POPUP_BASE_HEIGHT;
		local firstLine = true;
		for i = 1, numCriteria do
			local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, flags, assetID, quantityString, criteriaID = C_Scenario.GetCriteriaInfo(i);
			criteriaString = string.format("%d/%d %s", quantity, totalQuantity, criteriaString);
			local line = WatchFrame_GetScenarioLine(linesParent);
			if ( firstLine ) then
				WatchFrame_SetLine(line, nextAnchor, WATCHFRAMELINES_FONTSPACING - initialCriteriaOffset, not IS_HEADER, criteriaString, DASH_ICON);
				line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0);
				line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0);
				firstLine = false;
			else
				WatchFrame_SetLine(line, nextAnchor, WATCHFRAMELINES_FONTSPACING - WATCHFRAME_SCENARIO_LINE_OFFSET, not IS_HEADER, criteriaString, DASH_ICON);
			end
			if ( criteriaCompleted ) then
				line.text:SetTextColor(0.6, 0.6, 0.6);
				line.icon:SetTexture("Interface\\Scenarios\\ScenarioIcon-Check");
			else
				line.icon:SetTexture("Interface\\Scenarios\\ScenarioIcon-Combat");
			end
			-- animation
			if ( criteriaID == animationCriteriaID and criteriaCompleted ) then
				WatchFrameScenario_PlayCriteriaAnimation(line);
			end

			nextAnchor = line;
			line.icon:Show();
			line:Show();
			contentHeight = contentHeight + line:GetHeight() - WATCHFRAMELINES_FONTSPACING + WATCHFRAME_SCENARIO_LINE_OFFSET;
		end
		
		if ( not inChallengeMode ) then
			WATCHFRAME_SLIDEIN_ANIMATIONS["SCENARIO"].height = contentHeight;
			WATCHFRAME_SLIDEIN_ANIMATIONS["SCENARIO"].scrollStart = contentHeight;
			-- slide in only if new stage
			if ( popupFrame.stage == currentStage ) then
				popupFrame:SetHeight(contentHeight);
			else
				WatchFrame_SlideInFrame(popupFrame, "SCENARIO");
				if ( popupFrame.stage ) then
					PlaySound("UI_Scenario_Stage_End");
				end
			end
			popupFrame.stage = currentStage;
			-- set up return values
			width = WatchFrameScenarioFrame:GetWidth();
			numPopups = 1;
			nextAnchor = popupFrame;
		end
		numObjectives = 1;
	else
		popupFrame:Hide();
		popupFrame.stage = nil;
	end

	WatchFrame_ReleaseUnusedScenarioLines();
	return nextAnchor, width, numObjectives, numPopups;
end

function WatchFrameScenario_ReadyCriteriaAnimation(criteriaID)
	local animationLine = ScenarioCriteriaAnimationLine;
	if ( animationLine.playState == "playing" ) then
		WatchFrameScenario_StopCriteriaAnimation();
	end
	animationLine.playState = "ready";
	animationLine.criteriaID = criteriaID;
end

function WatchFrameScenario_PlayCriteriaAnimation(targetLine)
	local animationLine = ScenarioCriteriaAnimationLine;
	-- always reparent in case lines got shuffled
	animationLine:SetParent(targetLine);
	animationLine:SetAllPoints(targetLine);
	-- start animations if in the ready state
	if ( animationLine.playState == "ready" ) then
		animationLine.playState = "playing";
		animationLine.Glow.ScaleAnim:Play();
		animationLine.Glow.AlphaAnim:Play();
		animationLine.Sheen.Anim:Play();
		animationLine.Check.Anim:Play();
	end
end

function WatchFrameScenario_StopCriteriaAnimation()
	local animationLine = ScenarioCriteriaAnimationLine;
	if ( animationLine.playState ) then
		animationLine.Glow.ScaleAnim:Stop();
		animationLine.Glow.AlphaAnim:Stop();
		animationLine.Sheen.Anim:Stop();
		animationLine.Check.Anim:Stop();
		animationLine.playState = nil;
		animationLine.criteriaID = nil;
	end
end

--------------------------------------------------------------------------------------------
-- Slide-in Animations
--------------------------------------------------------------------------------------------
WATCHFRAME_SLIDEIN_ANIMATIONS = {
	["AUTOQUEST"] = { height = 72, scrollStart = 65, scrollEnd = -9, slideInTime = 0.4, onFinishFunc = WatchFrameAutoQuest_OnFinishSlideIn },
	["SCENARIO"] = { height = nil, scrollStart = nil, scrollEnd = 0, slideInTime = 0.4 },	-- various content heights, nil values must be set
};

function WatchFrame_SlideInFrame(frame, animType)
	frame.totalTime = 0;
	frame.animData = WATCHFRAME_SLIDEIN_ANIMATIONS[animType];
	frame.slideInTime = frame.animData.slideInTime;
	frame:SetHeight(1);
	frame:SetScript("OnUpdate", WatchFrameSlideInFrame_OnUpdate);
end

function WatchFrameSlideInFrame_OnUpdate(frame, timestep)
	local animData = frame.animData;
	local height = animData.height;
	local scrollStart = animData.scrollStart;
	local scrollEnd = animData.scrollEnd;

	-- Pause animation while the lineframe shadow is animating
	if (WatchFrameLinesShadow.FadeIn:IsPlaying()) then
		return;
	end

	-- The first pop-up needs to include the WATCHFRAME_TYPE_OFFSET in the animation
	if (frame.isFirst) then
		height = height + WATCHFRAME_TYPE_OFFSET;
		scrollEnd = scrollEnd - WATCHFRAME_TYPE_OFFSET;
	end

	frame.totalTime = frame.totalTime+timestep;
	if (frame.totalTime > animData.slideInTime) then
		frame.totalTime = animData.slideInTime;
	end

	local scrollPos = scrollEnd;
	if (animData.slideInTime and animData.slideInTime > 0) then
		height = height*(frame.totalTime/animData.slideInTime);
		scrollPos = scrollStart + (scrollEnd-scrollStart)*(frame.totalTime/animData.slideInTime);
	end
	frame:SetHeight(height);
	frame:UpdateScrollChildRect();
	frame:SetVerticalScroll(floor(scrollPos+0.5));

	if (frame.totalTime >= animData.slideInTime) then
		frame:SetScript("OnUpdate", nil);
		WatchFrame_Update();
		if ( animData.onFinishFunc ) then
			animData.onFinishFunc(frame);
		end
	end
end
-- PVP Global Lua Constants

WORLD_PVP_TIME_UPDATE_IINTERVAL = 1;

BATTLEFIELD_TIMER_DELAY = 3;
BATTLEFIELD_TIMER_THRESHOLDS = {600, 300, 60, 15};
BATTLEFIELD_TIMER_THRESHOLD_INDEX = 1;


CURRENT_BATTLEFIELD_QUEUES = {};
PREVIOUS_BATTLEFIELD_QUEUES = {};
MAX_WORLD_PVP_QUEUES = 2;


MAX_ARENA_TEAMS = 3;
MAX_ARENA_TEAM_MEMBERS = 10;
MAX_ARENA_TEAM_MEMBERS_SHOWN = 6;
MAX_ARENA_TEAM_NAME_WIDTH = 310;


MAX_ARENA_TEAM_MEMBER_WIDTH = 320;
MAX_ARENA_TEAM_MEMBER_SCROLL_WIDTH = 300;

NUM_DISPLAYED_BATTLEGROUNDS = 5;

NO_ARENA_SEASON = 0;


BG_BUTTON_WIDTH = 320;
BG_BUTTON_SCROLL_WIDTH = 298;

WARGAME_HEADER_HEIGHT = 16;
WARGAME_BUTTON_HEIGHT = 40;

local BATTLEFIELD_FRAME_FADE_TIME = 0.15


local PVPHONOR_TEXTURELIST = {};
PVPHONOR_TEXTURELIST[1] = "Interface\\PVPFrame\\PvpBg-AlteracValley";
PVPHONOR_TEXTURELIST[2] = "Interface\\PVPFrame\\PvpBg-WarsongGulch";
PVPHONOR_TEXTURELIST[3] = "Interface\\PVPFrame\\PvpBg-ArathiBasin";
PVPHONOR_TEXTURELIST[7] = "Interface\\PVPFrame\\PvpBg-EyeOfTheStorm";
PVPHONOR_TEXTURELIST[9] = "Interface\\PVPFrame\\PvpBg-StrandOfTheAncients";
PVPHONOR_TEXTURELIST[30] = "Interface\\PVPFrame\\PvpBg-IsleOfConquest";
PVPHONOR_TEXTURELIST[32] = "Interface\\PVPFrame\\PvpRandomBg";
PVPHONOR_TEXTURELIST[108] = "Interface\\PVPFrame\\PvpBg-TwinPeaks";
PVPHONOR_TEXTURELIST[120] = "Interface\\PVPFrame\\PvpBg-Gilneas";

local WARGAMES_TEXTURELIST = {
	  [0] = "Interface\\PVPFrame\\RandomPVPIcon",
	  [1] = "Interface\\LFGFrame\\LFGIcon-Battleground",
	  [2] = "Interface\\LFGFrame\\LFGIcon-WarsongGulch",
	  [3] = "Interface\\LFGFrame\\LFGIcon-ArathiBasin",
	  [4] = "Interface\\LFGFrame\\LFGIcon-NagrandArena",
	  [5] = "Interface\\LFGFrame\\LFGIcon-BladesEdgeArena",
	  [7] = "Interface\\LFGFrame\\LFGIcon-NetherBattlegrounds",
	  [8] = "Interface\\LFGFrame\\LFGIcon-RuinsofLordaeron",
	  [9] = "Interface\\LFGFrame\\LFGIcon-StrandoftheAncients",
	 [10] = "Interface\\LFGFrame\\LFGIcon-DalaranSewers",
	 [11] = "Interface\\LFGFrame\\LFGIcon-RingofValor",
	 [30] = "Interface\\LFGFrame\\LFGIcon-IsleOfConquest",
	[108] = "Interface\\LFGFrame\\LFGIcon-TwinPeaksBG",
	[120] = "Interface\\LFGFrame\\LFGIcon-TheBattleforGilneas",
}

local PVPWORLD_TEXTURELIST = {};
PVPWORLD_TEXTURELIST[1] = "Interface\\PVPFrame\\PvpBg-Wintergrasp";
PVPWORLD_TEXTURELIST[21] = "Interface\\PVPFrame\\PvpBg-TolBarad";

local PVPWORLD_DESCRIPTIONS = {};
PVPWORLD_DESCRIPTIONS[1] = WINTERGRASP_DESCRIPTION;
PVPWORLD_DESCRIPTIONS[21] = TOL_BARAD_DESCRIPTION;

ARENABANNER_SMALLFONT = "GameFontNormalSmall"

RANDOM_BG_ID = 32;
MAX_BLACKLIST_BATTLEGROUNDS = 2;

local BlacklistBGCount = 0;
local BlacklistIDs = {};

---- NEW PVP FRAME FUNCTIONS
---- NEW PVP FRAME FUNCTIONS


function PVP_GetSelectedArenaTeam()
	if PVPFrame:IsVisible() and PVPTeamManagementFrame.selectedTeam then
		return PVPTeamManagementFrame.selectedTeam:GetID();
	end
	return nil;
end

function PVP_ArenaTeamFrame()
	return PVPTeamManagementFrame;
end


function PVPMicroButton_SetPushed()
	PVPMicroButtonTexture:SetPoint("TOP", PVPMicroButton, "TOP", 5, -31);
	PVPMicroButtonTexture:SetAlpha(0.5);
end

function PVPMicroButton_SetNormal()
	PVPMicroButtonTexture:SetPoint("TOP", PVPMicroButton, "TOP", 6, -30);
	PVPMicroButtonTexture:SetAlpha(1.0);
end


function TogglePVPFrame()
	if (IsBlizzCon()) then
		return;
	end

	if ( UnitLevel("player") >= SHOW_PVP_LEVEL and not IsPlayerNeutral()) then
			ToggleFrame(PVPFrame);
	end
end


function PVPFrame_OnShow(self)
	
	-- reload the blacklist BGS
	BlacklistBGCount = 0;
	for i=1,MAX_BLACKLIST_BATTLEGROUNDS do
		BlacklistIDs[i] = GetBlacklistMap(i);
		if (BlacklistIDs[i] > 0) then
			BlacklistBGCount = BlacklistBGCount + 1;
		end		
	end
	
	PVPMicroButton_SetPushed();
	UpdateMicroButtons();
	PlaySound("igCharacterInfoOpen");
	if (self.lastSelectedTab) then
		PVPFrame_TabClicked(self.lastSelectedTab);
	else
		PVPFrame_TabClicked(PVPFrameTab1);
	end
	RequestRatedBattlegroundInfo();
	RequestPVPRewards();
	RequestPVPOptionsEnabled();
end

function PVPFrame_OnHide()
	PVPMicroButton_SetNormal();
	UpdateMicroButtons();
	PlaySound("igCharacterInfoClose");
	ClearBattlemaster();
end



function PVPFrame_OnLoad(self)
	PanelTemplates_SetNumTabs(self, 4)
	PVPFrame_TabClicked(PVPFrameTab1);
	SetPortraitToTexture(PVPFramePortrait,"Interface\\BattlefieldFrame\\UI-Battlefield-Icon");
	
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("UNIT_LEVEL");
	
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	self:RegisterEvent("PARTY_LEADER_CHANGED");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");

	self:RegisterEvent("BATTLEFIELD_MGR_QUEUE_REQUEST_RESPONSE");
	self:RegisterEvent("BATTLEFIELD_MGR_QUEUE_INVITE");
	self:RegisterEvent("BATTLEFIELD_MGR_ENTRY_INVITE");
	self:RegisterEvent("BATTLEFIELD_MGR_EJECT_PENDING");
	self:RegisterEvent("BATTLEFIELD_MGR_EJECTED");
	self:RegisterEvent("BATTLEFIELD_MGR_ENTERED");
	self:RegisterEvent("WARGAME_REQUESTED");
	self:RegisterEvent("PVP_RATED_STATS_UPDATE");
	self:RegisterEvent("PVP_REWARDS_UPDATE");
	self:RegisterEvent("BATTLEFIELDS_SHOW");
	self:RegisterEvent("BATTLEFIELDS_CLOSED");
	self:RegisterEvent("PVP_TYPES_ENABLED");
	
	PVPFrame.timerDelay = 0;
	
	PVPFrameTab2.info = ARENA_CONQUEST_INFO;
	PVPFrameTab3.info = ARENA_TEAM_INFO;
end



--function PVPFrame_Update()
	--PVPHonor_UpdateBattlegrounds()
	--PVPConquestFrame_Update(PVPConquestFrame);
--end

function PVPFrame_OnEvent(self, event, ...)
	if  event == "PLAYER_ENTERING_WORLD" then
		FauxScrollFrame_SetOffset(PVPHonorFrameTypeScrollFrame, 0);
		FauxScrollFrame_OnVerticalScroll(PVPHonorFrameTypeScrollFrame, 0, 16, PVPHonor_UpdateBattlegrounds); --We may be changing brackets, so we don't want someone to see an outdated version of the data.
		PVP_UpdateStatus(false, nil);
	elseif event == "CURRENCY_DISPLAY_UPDATE" then
		PVPFrame_UpdateCurrency(self);
		if ( self:IsShown() ) then
			RequestPVPRewards();
		end
	elseif ( event == "UPDATE_BATTLEFIELD_STATUS" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED") then
		local arg1 = ...
		PVP_UpdateStatus(false, arg1);
	--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_QUEUE_REQUEST_RESPONSE" ) then
		local battleID, accepted, warmup, inArea, loggingIn, areaName = ...;
		if(not loggingIn) then
			if(accepted) then
				if(warmup) then
					StaticPopup_Show("BFMGR_CONFIRM_WORLD_PVP_QUEUED_WARMUP", areaName, nil, arg1);
				elseif (inArea) then
					StaticPopup_Show("BFMGR_EJECT_PENDING", areaName, nil, arg1);
				else
					StaticPopup_Show("BFMGR_CONFIRM_WORLD_PVP_QUEUED", areaName, nil, arg1);
				end
			else
				StaticPopup_Show("BFMGR_DENY_WORLD_PVP_QUEUED", areaName, nil, arg1);
			end
		end
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_EJECT_PENDING" ) then
		local battleID, remote, areaName = ...;
		if(remote) then
			local dialog = StaticPopup_Show("BFMGR_EJECT_PENDING_REMOTE", areaName, nil, arg1);
		else
		local dialog = StaticPopup_Show("BFMGR_EJECT_PENDING", areaName, nil, arg1);
		end
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_EJECTED" ) then
		local battleID, playerExited, relocated, battleActive, lowLevel, areaName = ...;
		StaticPopup_Hide("BFMGR_INVITED_TO_QUEUE");
		StaticPopup_Hide("BFMGR_INVITED_TO_QUEUE_WARMUP");
		StaticPopup_Hide("BFMGR_INVITED_TO_ENTER");
		StaticPopup_Hide("BFMGR_EJECT_PENDING");
		if(lowLevel) then
			local dialog = StaticPopup_Show("BFMGR_PLAYER_LOW_LEVEL", areaName, nil, arg1);
		elseif (playerExited and battleActive and not relocated) then
			local dialog = StaticPopup_Show("BFMGR_PLAYER_EXITED_BATTLE", areaName, nil, arg1);
		end
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_QUEUE_INVITE" ) then
		local battleID, warmup, areaName = ...;
		if(warmup) then
			local dialog = StaticPopup_Show("BFMGR_INVITED_TO_QUEUE_WARMUP", areaName, nil, battleID);
		else
			local dialog = StaticPopup_Show("BFMGR_INVITED_TO_QUEUE", areaName, nil, battleID);
		end
		StaticPopup_Hide("BFMGR_EJECT_PENDING");
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_ENTRY_INVITE" ) then
		local battleID, areaName = ...;
		local dialog = StaticPopup_Show("BFMGR_INVITED_TO_ENTER", areaName, nil, battleID);
		StaticPopup_Hide("BFMGR_EJECT_PENDING");
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "BATTLEFIELD_MGR_ENTERED" ) then
		StaticPopup_Hide("BFMGR_INVITED_TO_QUEUE");
		StaticPopup_Hide("BFMGR_INVITED_TO_QUEUE_WARMUP");
		StaticPopup_Hide("BFMGR_INVITED_TO_ENTER");
		StaticPopup_Hide("BFMGR_EJECT_PENDING");
		PVP_UpdateStatus(false);
		--PVPFrame_Update();
	elseif ( event == "PVP_REWARDS_UPDATE" ) then
		PVPFrame_UpdateCurrency(self);
	elseif ( event == "WARGAME_REQUESTED" ) then
		local challengerName, bgName, timeout = ...;
		PVPFramePopup_SetupPopUp(event, challengerName, bgName, timeout);
	elseif ( event == "PARTY_LEADER_CHANGED" ) then
		--PVPFrame_Update();
	elseif ( event == "PVP_RATED_STATS_UPDATE" ) then
		PVPFrame_UpdateCurrency(self);
	elseif ( event == "BATTLEFIELDS_SHOW" )  then
		local isArena, bgId = ...;
		if isArena then
			PVPFrameTab2:Click();
		else
			local numWorldPvP = GetNumWorldPVPAreas();
			local numBgs = GetNumBattlegroundTypes();
			local numTypes = numWorldPvP + numBgs ;
			local numList = 0;
			local index;
			for i=1,numTypes do
				if i <=  numWorldPvP then
					local _, localizedName, _, _, _, canEnter = GetWorldPVPAreaInfo(i);
					if ( localizedName and canEnter ) then
						numList = numList + 1;
					end
				else
					local localizedName, canEnter, _, _, BattleGroundID = GetBattlegroundInfo(i-numWorldPvP);
					if ( localizedName and canEnter ) then
						if ( bgId == BattleGroundID ) then
							PVPHonorFrame.selectedIsWorldPvp = false;
							PVPHonorFrame.selectedPvpID = i-numWorldPvP;
							PVPHonorFrame_ResetInfo();
							PVPHonorFrame_UpdateGroupAvailable();
							index = i-numWorldPvP;
						end
						numList = numList + 1;
					end
				end
			end
			PVPFrameTab1:Click();
			if index then
				local scroll = min(index+1, numList - NUM_DISPLAYED_BATTLEGROUNDS);
				PVPHonorFrameTypeScrollFrameScrollBar:SetMinMaxValues(0, numList*16); 
				PVPHonorFrameTypeScrollFrameScrollBar:SetValue(scroll*16);
			end
		end	
		if not self:IsShown() then
			TogglePVPFrame();
		end
	elseif ( event == "BATTLEFIELDS_CLOSED" )  then
		if self:IsShown() then
			TogglePVPFrame();
		end
	elseif ( event == "PVP_TYPES_ENABLED" )  then
		self.wargamesEnable, self.ratedBGsEnabled, self.ratedArenasEnabled = ...;
	elseif ( event == "UNIT_LEVEL" ) then
		local unit = ...;
		if ( unit == "player" and UnitLevel(unit) == SHOW_CONQUEST_LEVEL ) then
			if ( PVPFrameTab2:IsShown() ) then
				PVPFrame_TabClicked(PVPFrameTab2);
			elseif ( PVPFrameTab3:IsShown() ) then
				PVPFrame_TabClicked(PVPFrameTab3);
			end
		end
	end
end

function PVPFrame_UpdateCurrency(self)
	local currencyID = PVPFrameCurrency.currencyID;
	local currencyName, currencyAmount;
	if ( currencyID ) then
		currencyName, currencyAmount = GetCurrencyInfo(currencyID);
	end
	
	if ( currencyName ) then
		-- show conquest bar?
		if ( currencyID == CONQUEST_CURRENCY ) then
			PVPFrameCurrency:Hide();
			PVPFrameConquestBar:Show();
			local pointsThisWeek, maxPointsThisWeek, tier2Quantity, tier2Limit, tier1Quantity, tier1Limit, randomPointsThisWeek, maxRandomPointsThisWeek = GetPVPRewards();
			-- just want a plain bar
			CapProgressBar_Update(PVPFrameConquestBar, 0, 0, nil, nil, pointsThisWeek, maxPointsThisWeek);
			PVPFrameConquestBar.label:SetFormattedText(CURRENCY_THIS_WEEK, currencyName);
		else
			PVPFrameCurrency:Show();
			PVPFrameConquestBar:Hide();
			PVPFrameCurrencyValue:SetText(currencyAmount);
		end
	else
		PVPFrameCurrency:Hide();
		PVPFrameConquestBar:Hide();
	end
end

function PVPFrameConquestBar_OnEnter(self)
	local currencyName = GetCurrencyInfo(CONQUEST_CURRENCY);
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(MAXIMUM_REWARD);
	GameTooltip:AddLine(format(CURRENCY_RECEIVED_THIS_WEEK, currencyName), 1, 1, 1, true);
	GameTooltip:AddLine(" ");

	local pointsThisWeek, maxPointsThisWeek, tier2Quantity, tier2Limit, tier1Quantity, tier1Limit, randomPointsThisWeek, maxRandomPointsThisWeek = GetPVPRewards();
	
	local r, g, b = 1, 1, 1;
	local capped;
	if ( pointsThisWeek >= maxPointsThisWeek ) then
		r, g, b = 0.5, 0.5, 0.5;
		capped = true;
	end
	GameTooltip:AddDoubleLine(FROM_ALL_SOURCES, format(CURRENCY_WEEKLY_CAP_FRACTION, pointsThisWeek, maxPointsThisWeek), r, g, b, r, g, b);
	
	if ( capped or tier2Quantity >= tier2Limit ) then
		r, g, b = 0.5, 0.5, 0.5;
	else
		r, g, b = 1, 1, 1;
	end
	GameTooltip:AddDoubleLine(" -"..FROM_RATEDBG, format(CURRENCY_WEEKLY_CAP_FRACTION, tier2Quantity, tier2Limit), r, g, b, r, g, b);	
	
	if ( capped or tier1Quantity >= tier1Limit ) then
		r, g, b = 0.5, 0.5, 0.5;
	else
		r, g, b = 1, 1, 1;
	end
	GameTooltip:AddDoubleLine(" -"..FROM_ARENA, format(CURRENCY_WEEKLY_CAP_FRACTION, tier1Quantity, tier1Limit), r, g, b, r, g, b);

	if ( capped or randomPointsThisWeek >= maxRandomPointsThisWeek ) then
		r, g, b = 0.5, 0.5, 0.5;
	else
		r, g, b = 1, 1, 1;
	end
	GameTooltip:AddDoubleLine(" -"..FROM_RANDOMBG, format(CURRENCY_WEEKLY_CAP_FRACTION, randomPointsThisWeek, maxRandomPointsThisWeek), r, g, b, r, g, b);

	GameTooltip:Show();
end

function PVPFrameConquestBarMarker_OnEnter(self)
	local isTier1 = self:GetID() == 1;

	local pointsThisWeek, maxPointsThisWeek, tier2Quantity, tier2Limit, tier1Quantity, tier1Limit, randomPointsThisWeek, maxRandomPointsThisWeek = GetPVPRewards();
	local tier2tooltip = PVP_CURRENCY_CAP_RATEDBG;
	local tier1tooltip = PVP_CURRENCY_CAP_ARENA;
	-- if BG limit is below arena, swap them
	if ( tier2Limit < tier1Limit ) then
		tier1Quantity, tier2Quantity = tier2Quantity, tier1Quantity;
		tier1Limit, tier2Limit = tier2Limit, tier1Limit;
		tier1tooltip, tier2tooltip = tier2tooltip, tier1tooltip;
	end
	local currencyName = GetCurrencyInfo(CONQUEST_CURRENCY);
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(MAXIMUM_REWARD);
	if ( isTier1 ) then
		GameTooltip:AddLine(format(tier1tooltip, currencyName), 1, 1, 1, true);
		GameTooltip:AddLine(format(CURRENCY_THIS_WEEK_WITH_AMOUNT, currencyName, tier1Quantity, tier1Limit));
	else
		GameTooltip:AddLine(format(tier2tooltip, currencyName), 1, 1, 1, true);
		GameTooltip:AddLine(format(CURRENCY_THIS_WEEK_WITH_AMOUNT, currencyName, tier2Quantity, tier2Limit));
	end
	GameTooltip:Show();
end

function PVPFrame_JoinClicked(self, isParty, wargame)
	local tabID =  PVPFrame.lastSelectedTab:GetID();
	if tabID == 1 then --Honor BGs
		if wargame then
			StartWarGame();
		else
			if PVPHonorFrame.selectedIsWorldPvp then
				local pvpID = GetWorldPVPAreaInfo(PVPHonorFrame.selectedPvpID);
				BattlefieldMgrQueueRequest(pvpID); 
			else 
				JoinBattlefield(1, isParty);
			end
		end
	elseif tabID == 2 then
		if PVPConquestFrame.mode == "Arena" then
			JoinArena();
		else -- rated bg
			JoinRatedBattlefield();
		end
	elseif tabID == 3 then	
		StaticPopup_Show("ADD_TEAMMEMBER", nil, nil, PVPTeamManagementFrame.selectedTeam:GetID());
	end
end

function PVPFrame_TabClicked(self)
	local index = self:GetID()	
	PanelTemplates_SetTab(self:GetParent(), index);
	self:GetParent().lastSelectedTab = self;
	PVPFrameRightButton:Hide();
	PVPFrame.panel1:Hide();	
	PVPFrame.panel2:Hide();	
	PVPFrame.panel3:Hide();
	PVPFrame.panel4:Hide();
	
	PVPFrame.lowLevelFrame:Hide();
	PVPFrameLeftButton:Show();
	
	
	PVPFrameTitleText:SetText(self:GetText());	
	PVPFrame.Inset:SetPoint("TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET);
	PVPFrame.topInset:Hide();
	local factionGroup = UnitFactionGroup("player");
	if(factionGroup == nil) then
		return;
	end;
	
	if index == 1 then -- Honor Page
		PVPFrame.panel1:Show();
		PVPFrameRightButton:Show();
		PVPFrameLeftButton:SetText(BATTLEFIELD_JOIN);
		if (PVPHonorFrame.BGMapID and not CheckForMapInBlacklist(PVPHonorFrame.BGMapID)) then
			PVPFrameLeftButton:Enable();
		else
			PVPFrameLeftButton:Disable();
		end
		PVPFrameCurrencyLabel:SetText(HONOR);
		PVPFrameCurrencyIcon:SetTexture("Interface\\PVPFrame\\PVPCurrency-Honor-"..factionGroup);
		PVPFrameCurrency.currencyID = HONOR_CURRENCY;
	elseif index == 4 then -- War games
		PVPFrame.panel4:Show();
		PVPFrameCurrency.currencyID = nil;
	elseif UnitLevel("player") < SHOW_CONQUEST_LEVEL then
		self:GetParent().lastSelectedTab = nil;
		PVPFrameLeftButton:Hide();
		PVPFrame.lowLevelFrame.title:SetText(self:GetText());
		PVPFrame.lowLevelFrame.error:SetFormattedText(PVP_CONQUEST_LOWLEVEL, self:GetText());
		PVPFrame.lowLevelFrame.description:SetText(self.info);
		PVPFrame.lowLevelFrame:Show();
		PVPFrameCurrency.currencyID = nil;
	elseif GetCurrentArenaSeason() == NO_ARENA_SEASON then
		self:GetParent().lastSelectedTab = nil;
		PVPFrameLeftButton:Hide();
		PVPFrame.lowLevelFrame.title:SetText(self:GetText());
		PVPFrame.lowLevelFrame.error:SetText("");
		PVPFrame.lowLevelFrame.description:SetText(ARENA_MASTER_NO_SEASON_TEXT);
		PVPFrame.lowLevelFrame:Show();
		PVPFrameCurrencyIcon:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..factionGroup);
		PVPFrameCurrency.currencyID = CONQUEST_CURRENCY;
	elseif index == 2 then -- Conquest 
		PVPFrame.panel2:Show();	
		PVPFrameLeftButton:SetText(BATTLEFIELD_JOIN);
		PVPFrameCurrencyLabel:SetText(PVP_CONQUEST);
		PVPFrameCurrencyIcon:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..factionGroup);
		PVPFrameCurrency.currencyID = CONQUEST_CURRENCY;
	elseif index == 3 then -- Arena Management
		PVPFrameLeftButton:SetText(ADDMEMBER_TEAM);
		PVPFrameLeftButton:Disable();
		PVPFrame.panel3:Show();	
		PVPFrameCurrencyLabel:SetText(PVP_CONQUEST);
		PVPFrame.topInset:Show();
		PVPFrame.Inset:SetPoint("TOPLEFT", PANEL_INSET_LEFT_OFFSET, -281);
		PVPFrameCurrencyIcon:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..factionGroup);
		PVPFrameCurrency.currencyID = CONQUEST_CURRENCY;
	end
	
	PVPFrame_UpdateCurrency(self);
end



-- Honor Frame functions (the new BG page)
-- Honor Frame functions (the new BG page)

function PVPHonor_UpdateWorldPVPTimer(self, elapsed)
	self.timeStep = self.timeStep + elapsed;
	if self.timeStep > WORLD_PVP_TIME_UPDATE_IINTERVAL then
		self.timeStep = 0;
		local _, name, isActive, canQueue, startTime = GetWorldPVPAreaInfo(self.worldIndex);
		if canQueue then
			self:Enable();
		else
			self:Disable();
			name = GRAY_FONT_COLOR_CODE..name;
		end
		if ( isActive ) then
			name = name.." ("..WINTERGRASP_IN_PROGRESS..")";
		elseif ( startTime > 0 ) then
			name = name.." ("..SecondsToTime(startTime)..")";
		end
		self.title:SetText(name);
	end
end


function PVPHonor_UpdateBattlegrounds()
	local frame, _;
	local localizedName, canEnter, isHoliday, isRandom, BGMapID;
	local pvpID, isActive, canQueue, startTime;
	local tempString, isBig, isWorldPVP;
	
	local offset = FauxScrollFrame_GetOffset(PVPHonorFrameTypeScrollFrame);
	local currentFrameNum = 1;
	local availableBGs = 0;
	
	local numWorldPvP = GetNumWorldPVPAreas();
	local numBgs = GetNumBattlegroundTypes();
	local numTypes = numWorldPvP + numBgs ;
	
	for i=1,numTypes do
		frame = _G["PVPHonorFrameBgButton"..currentFrameNum];
		
		if  i <=  numBgs then
			pvpID = i;
			localizedName, canEnter, isHoliday, isRandom ,_,_, BGMapID = GetBattlegroundInfo(i);
			isActive = false;
			canQueue = true;
			startTime = -1;
			isWorldPVP = false
		else
			pvpID = i-numBgs;
			_, localizedName, isActive, canQueue, startTime, canEnter = GetWorldPVPAreaInfo(i-numBgs);
			isWorldPVP = true;
			isRandom = false;
			BGMapID = -1;
			isHoliday = false;
		end
		
		if ( localizedName and canEnter ) then
			if offset > 0 then
				offset = offset -1;
			elseif ( frame ) then
				frame.pvpID = pvpID;
				frame.localizedName = localizedName;
				frame.isWorldPVP = isWorldPVP;
				frame.isRandom = isRandom;
				frame.BGMapID = BGMapID;
				frame.isHoliday = isHoliday;

				if canQueue then
					frame:Enable();
					if ( not PVPHonorFrame.selectedButtonIndex ) then
						frame:Click();
					end
				else
					frame:Disable();
					localizedName = GRAY_FONT_COLOR_CODE..localizedName;
				end
				tempString = localizedName;
				
				if isWorldPVP then
					frame:SetScript("OnUpdate", PVPHonor_UpdateWorldPVPTimer);
					frame.timeStep = 0;
					frame.worldIndex = i-numBgs;
				else
					frame:SetScript("OnUpdate", nil);
				end
				
				if ( isHoliday ) then
					frame.ThumbsDown.holiday:SetText(" ("..BATTLEGROUND_HOLIDAY..")");
					-- check if the holiday was changed after we blacklisted the BG. The Holiday BG must be allowed
					if (BGMapID > 0 and CheckForMapInBlacklist(BGMapID)) then
						for j=1,MAX_BLACKLIST_BATTLEGROUNDS do
							if (BGMapID == BlacklistIDs[j]) then
								ClearBlacklistMap(BGMapID);
								BlacklistIDs[j] = -1;		
								BlacklistBGCount = BlacklistBGCount - 1;
								if IsPvPFrameSelected(frame) then
									PVPFrameLeftButton:SetEnabled(1);
								end
							end
						end
					end
				else
					frame.ThumbsDown.holiday:SetText("");
				end
				
				if ( isActive ) then
					tempString = tempString.." ("..WINTERGRASP_IN_PROGRESS..")";
				elseif ( startTime > 0 ) then
					tempString = tempString.." ("..SecondsToTime(startTime)..")";
				end
				
				if PVPHonorFrame.selectedPvpID ==  frame.pvpID and PVPHonorFrame.selectedIsWorldPvp == isWorldPVP then
					frame:LockHighlight();
				else
					frame:UnlockHighlight();
				end
					
				frame.title:SetText(tempString);
				frame.ThumbsDown.texture:SetTexture("Interface\\PVPFrame\\Icon-Combat");
				frame.ThumbsDown.texture:Show();
				if ( PVPHonor_ThumbsDownUpdate(frame.ThumbsDown) ) then
					frame:SetNormalFontObject(GameFontNormalLeftRed);
					frame:SetHighlightFontObject(GameFontNormalLeftRed);
				else
					frame:SetNormalFontObject(GameFontNormalLeft);
					frame:SetHighlightFontObject(GameFontHighlightLeft);
				end
				frame:Show();
				currentFrameNum = currentFrameNum + 1;
			end
			availableBGs = availableBGs + 1;
		end
	end
	
	if ( currentFrameNum <= NUM_DISPLAYED_BATTLEGROUNDS ) then
		isBig = true;	--Espand the highlight to cover where the scroll bar usually is.
	end
	
	for i=1,NUM_DISPLAYED_BATTLEGROUNDS do
		frame = _G["PVPHonorFrameBgButton"..i];
		if ( isBig ) then
			frame:SetWidth(BG_BUTTON_WIDTH);
		else
			frame:SetWidth(BG_BUTTON_SCROLL_WIDTH);
		end
	end
	
	for i=currentFrameNum,NUM_DISPLAYED_BATTLEGROUNDS do
		frame = _G["PVPHonorFrameBgButton"..i];
		frame:Hide();
	end
	
	PVPHonor_UpdateQueueStatus();
	
	PVPHonorFrame_UpdateGroupAvailable();
	FauxScrollFrame_Update(PVPHonorFrameTypeScrollFrame, availableBGs, NUM_DISPLAYED_BATTLEGROUNDS, 16);
end

-- helper functions since this logic was being run a bit
function CheckForMapInBlacklist(mapID)
	if (BlacklistBGCount > 0) then
		for i=1,MAX_BLACKLIST_BATTLEGROUNDS do
			if (mapID == BlacklistIDs[i]) then
				return true;
			end
		end
	end
	return false;
end

function IsPvPFrameSelected(self)
	if (self:GetParent().selectedPvpID == self.pvpID and self:GetParent().selectedIsWorldPvp == self.isWorldPVP) then 
		return true;
	end
	return false;
end

function PVPHonor_ButtonClicked(self)
	local id = self:GetID();
	local name = self:GetName();
	name = strsub(name, 1, strlen(name)-1);
	
	for i=1,NUM_DISPLAYED_BATTLEGROUNDS do
		if ( id == i ) then
			_G[name..i]:LockHighlight();
		else
			_G[name..i]:UnlockHighlight();
		end
	end
	
	self:GetParent().selectedButtonIndex = id;
	self:GetParent().selectedIsWorldPvp = self.isWorldPVP;
	self:GetParent().selectedPvpID = self.pvpID;
	self:GetParent().BGMapID = self.BGMapID;
	PVPHonorFrame_ResetInfo();
	PVPHonorFrame_UpdateGroupAvailable();

	-- did we blacklist this map
	if CheckForMapInBlacklist(self.BGMapID) then
		PVPFrameLeftButton:SetEnabled(0);
	else
		PlaySound("igMainMenuOptionCheckBoxOn");
		PVPFrameLeftButton:SetEnabled(1);
	end
end

function PVPHonor_ButtonEnter(self)
	self:LockHighlight();

	-- world pvp won't display thumbs down, nor will queued, nor will the random, nor holiday (removed restriction on showing if 2 or more are banned)
	if (self.isWorldPVP or self.status:IsShown() or self.isRandom or self.isHoliday ) then
		return;
	end

	if CheckForMapInBlacklist(self.BGMapID) then
		return;
	end

	self.ThumbsDown.texture:SetTexture("Interface\\PVPFrame\\bg-down-off");
	self.ThumbsDown.texture:Show();
end

function PVPHonor_ButtonLeave(self)
	-- check the index and world flag to make sure we dont unhighlight the selected button

	if IsPvPFrameSelected(self) == false then
		self:UnlockHighlight();
	end

	-- world pvp won't display thumbs down, nor will queued, nor will the random
	if (self.isWorldPVP or self.status:IsShown() or self.isRandom or self.isHoliday) then
		return;
	end

	if CheckForMapInBlacklist(self.BGMapID) then
		return;
	end

	self.ThumbsDown.texture:Hide();
end

-- fall through to parent handlers
function PVPHonor_ThumbsDownEnter(self)
	-- world pvp won't display thumbs down, nor will queued, nor will the random, nor holiday (removed restriction on showing if 2 or more are banned)
	local parent = self:GetParent();
	if (not parent.isWorldPVP and not parent.status:IsShown() and not parent.isRandom and not parent.isHoliday ) then
		self:SetHighlightTexture("Interface\\PVPFrame\\bg-down-off", "ADD");
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(THUMBS_DOWN_TOOLTIP);
	end

	PVPHonor_ButtonEnter(parent);
end

function PVPHonor_ThumbsDownLeave(self)
	GameTooltip:Hide();
	self:SetHighlightTexture(nil);

	PVPHonor_ButtonLeave(self:GetParent());
end

function PVPHonor_ThumbsDownUpdate(self)
	if (self:GetParent().isWorldPVP or self:GetParent().status:IsShown() or self:GetParent().isRandom or self:GetParent().isHoliday ) then
		return;
	end

	if (BlacklistBGCount > 0) then
		for i=1,MAX_BLACKLIST_BATTLEGROUNDS do
			if (self:GetParent().BGMapID == BlacklistIDs[i]) then
				self.texture:SetTexture("Interface\\PVPFrame\\bg-down-on");
				self.texture:SetTexCoord(0.0, 1.0, 0.0, 1.0);
				self.texture:Show();
				self:Show();
				return true;
			end
		end
	end

	self.texture:Hide();
end


function PVPHonor_ThumbsDownClicked(self)
	if (self:GetParent().isWorldPVP or self:GetParent().status:IsShown() or self:GetParent().isHoliday or self:GetParent().isRandom) then
		return;
	end
	PlaySound("igMainMenuOptionCheckBoxOn");
	if (BlacklistBGCount > 0) then
		for i=1,MAX_BLACKLIST_BATTLEGROUNDS do
			if (self:GetParent().BGMapID == BlacklistIDs[i]) then
				ClearBlacklistMap(BlacklistIDs[i]);
				BlacklistIDs[i] = -1;		
				BlacklistBGCount = BlacklistBGCount - 1;
				if IsPvPFrameSelected(self:GetParent()) then
					PVPFrameLeftButton:SetEnabled(1);
				end
				self:GetParent():SetNormalFontObject(GameFontNormalLeft);
				self:GetParent():SetHighlightFontObject(GameFontHighlightLeft);
				PVPHonor_ButtonEnter(self:GetParent()); 
				return;
			end
		end
	end

	if ( BlacklistBGCount < MAX_BLACKLIST_BATTLEGROUNDS ) then
		self.texture:SetTexture("Interface\\PVPFrame\\bg-down-on");
		self.texture:SetTexCoord(0.0, 1.0, 0.0, 1.0);
		self.texture:Show();
		self:Show();
		BlacklistBGCount = BlacklistBGCount + 1;		
		for i=1,MAX_BLACKLIST_BATTLEGROUNDS do
			if (-1 == BlacklistIDs[i] or nil == BlacklistIDs[i]) then
				BlacklistIDs[i] = self:GetParent().BGMapID;
				SetBlacklistMap(BlacklistIDs[i]);
				self:GetParent():SetNormalFontObject(GameFontNormalLeftRed);
				self:GetParent():SetHighlightFontObject(GameFontNormalLeftRed);
				if IsPvPFrameSelected(self:GetParent()) then
					PVPFrameLeftButton:SetEnabled(0);
				end
				return;
			end
		end
	else
		-- error report, trying to add more than 2
		UIErrorsFrame:AddMessage(ERR_PVP_BLACKLIST_CAP , 1.0, 0.1, 0.1, 1.0);
	end
end



function PVPHonorFrame_ResetInfo()
	if not PVPHonorFrame.selectedIsWorldPvp then
		RequestBattlegroundInstanceInfo(PVPHonorFrame.selectedPvpID);
	end
	PVPHonor_UpdateInfo();
end


function PVPHonor_UpdateInfo()
	if PVPHonorFrame.selectedIsWorldPvp then
		local pvpID = GetWorldPVPAreaInfo(PVPHonorFrame.selectedPvpID);
		local mapDescription = PVPWORLD_DESCRIPTIONS[pvpID]
		if not mapDescription or mapDescription == "" then
			PVPHonorFrameInfoScrollFrameChildFrameDescription:SetText("Missing Map Description");
		else
			PVPHonorFrameInfoScrollFrameChildFrameDescription:SetText(mapDescription);
		end

		if(PVPWORLD_TEXTURELIST[pvpID]) then
			PVPHonorFrameBGTex:SetTexture(PVPWORLD_TEXTURELIST[pvpID]);
		end
		PVPHonorFrameInfoScrollFrameChildFrameRewardsInfo:Hide();
		PVPHonorFrameInfoScrollFrameChildFrameDescription:Show();
	elseif PVPHonorFrame.selectedPvpID then
		local _, canEnter, isHoliday, isRandom, BattleGroundID, mapDescription = GetBattlegroundInfo(PVPHonorFrame.selectedPvpID);
		
		if(PVPHONOR_TEXTURELIST[BattleGroundID]) then
			PVPHonorFrameBGTex:SetTexture(PVPHONOR_TEXTURELIST[BattleGroundID]);
		end
		
		if ( isRandom or isHoliday ) then
			PVPHonor_UpdateRandomInfo();
			PVPHonorFrameInfoScrollFrameChildFrameRewardsInfo:Show();
			PVPHonorFrameInfoScrollFrameChildFrameDescription:Hide();
		else
			if ( mapDescription ~= PVPHonorFrameInfoScrollFrameChildFrameDescription:GetText() ) then
				PVPHonorFrameInfoScrollFrameChildFrameDescription:SetText(mapDescription);
				PVPHonorFrameInfoScrollFrame:SetVerticalScroll(0);
			end
			
			PVPHonorFrameInfoScrollFrameChildFrameRewardsInfo:Hide();
			PVPHonorFrameInfoScrollFrameChildFrameDescription:Show();
		end
	end
end

function PVPHonor_GetRandomBattlegroundInfo()
	return GetBattlegroundInfo(PVPHonorFrame.selectedPvpID);
end

function PVPHonor_UpdateRandomInfo()
	PVPQueue_UpdateRandomInfo(PVPHonorFrameInfoScrollFrameChildFrameRewardsInfo, PVPHonor_GetRandomBattlegroundInfo);
end

function PVPHonor_UpdateQueueStatus()
	local queueStatus, queueMapName, queueInstanceID, frame;
	for i=1, NUM_DISPLAYED_BATTLEGROUNDS do
		frame = _G["PVPHonorFrameBgButton"..i];
		frame.status:Hide();
	end
	
	local factionGroup = UnitFactionGroup("player");
	if(factionGroup == nil) then
		return;
	end
	local factionTexture = "Interface\\PVPFrame\\PVP-Currency-"..factionGroup;
	for i=1, GetMaxBattlefieldID() do
		queueStatus, queueMapName, queueInstanceID = GetBattlefieldStatus(i);
		if ( queueStatus ~= "none" ) then
			for j=1, NUM_DISPLAYED_BATTLEGROUNDS do
				local frame = _G["PVPHonorFrameBgButton"..j];
				if ( frame.localizedName == queueMapName ) then
					if ( queueStatus == "queued" ) then
						frame.status.texture:SetTexture(factionTexture);
						frame.status.texture:SetTexCoord(0.0, 1.0, 0.0, 1.0);
						frame.status.tooltip = BATTLEFIELD_QUEUE_STATUS;
						frame.status:Show();
					elseif ( queueStatus == "confirm" ) then
						frame.status.texture:SetTexture("Interface\\CharacterFrame\\UI-StateIcon");
						frame.status.texture:SetTexCoord(0.45, 0.95, 0.0, 0.5);
						frame.status.tooltip = BATTLEFIELD_CONFIRM_STATUS;
						frame.status:Show();
					end
				end
			end
		end
	end
end

function PVPHonorFrame_OnLoad(self)
	self:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW");
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	self:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE");
	self:RegisterEvent("GROUP_ROSTER_UPDATE");
	self:RegisterEvent("PVP_RATED_STATS_UPDATE");
end

function PVPHonorFrame_OnEvent(self, event, ...)
	if ( event == "PVPQUEUE_ANYWHERE_SHOW" ) then
		self.currentData = true;
		PVPHonor_UpdateBattlegrounds();
		if ( self.selectedButtonIndex ) then
			PVPHonor_UpdateInfo();
		end
	elseif ( event == "UPDATE_BATTLEFIELD_STATUS" ) then
		PVPHonor_UpdateQueueStatus();
	elseif ( event == "PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE") then
		FauxScrollFrame_SetOffset(PVPHonorFrameTypeScrollFrame, 0);
		FauxScrollFrame_OnVerticalScroll(PVPHonorFrameTypeScrollFrame, 0, 16, PVPHonor_UpdateBattlegrounds); --We may be changing brackets, so we don't want someone to see an outdated version of the data.
		if ( self.selectedButtonIndex ) then
			PVPHonorFrame_ResetInfo();
		end
	elseif ( event == "GROUP_ROSTER_UPDATE" ) then
		PVPHonorFrame_UpdateGroupAvailable();
	elseif ( event == "PVP_RATED_STATS_UPDATE" ) then
		PVPHonor_UpdateRandomInfo();
	end
end

function PVPHonorFrame_OnShow(self)	
	SortBGList();
	PVPHonor_UpdateBattlegrounds();
	PVPHonorFrame_ResetInfo();
end

function PVPHonorFrame_UpdateGroupAvailable()
	if ( IsInGroup() and UnitIsGroupLeader("player") ) then
		-- If this is true then can join as a group
		PVPFrameRightButton:Enable();
	else
		PVPFrameRightButton:Disable();
	end
end



-----------------------------------
---- PVPConquestFrame fUNCTIONS ---
-----------------------------------

function PVPConquestFrame_OnLoad(self)
	
	self.arenaButton.title:SetText(ARENA);
	self.ratedbgButton.title:SetText(PVP_RATED_BATTLEGROUND);		
	self.arenaButton:SetWidth(321);
	self.ratedbgButton:SetWidth(321);
	
	
	self:RegisterEvent("GROUP_ROSTER_UPDATE");
	self:RegisterEvent("ARENA_TEAM_UPDATE");
	self:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE");
	self:RegisterEvent("PVP_RATED_STATS_UPDATE");
	
	
	
	local factionGroup = UnitFactionGroup("player");
	if(factionGroup ~= nil and factionGroup ~= "Neutral") then
		self.infoButton.factionIcon = _G["PVPConquestFrameInfoButtonInfoIcon"..factionGroup];
		self.infoButton.factionIcon:Show();
		self.winReward.arenaSymbol:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..factionGroup);
	end
end


function PVPConquestFrame_OnEvent(self, event, ...)
	if not self:IsShown() then
		return;
	end
	
	PVPConquestFrame_Update(PVPConquestFrame);
end


function PVPConquestFrame_Update(self)
	local groupSize = GetNumGroupMembers();
	local validGroup = false;
	local reward = 0;
	local _, size;

	if self.mode == "Arena" then
		self.winReward.winAmount:SetText(0);
		self.noWeeklyFrame:Hide();
	
		local teamName, teamSize, teamRating, teamPlayed, teamWins;
		for i=1,MAX_ARENA_TEAMS do
			teamName, teamSize, teamRating, teamPlayed, teamWins = GetArenaTeam(i);
			if not teamName then
				break;
			elseif teamSize == groupSize then
				validGroup = true;
				self.teamIndex = i;
				ArenaTeamRoster(i);
				
				for j=1,groupSize-1 do
					local name = UnitName("party"..j)
					local found = false;
					for k=1,groupSize*2 do
						if name == GetArenaTeamRosterInfo(i, k) then
							found = true;
							break;
						end
					end
					
					if not found or not UnitIsConnected("party"..j) then
						validGroup = false;
						break;
					end
				end
				break;
			end
		end

		if not validGroup then
			self.infoButton.title:SetText("|cff808080"..ARENA_BATTLES);
			self.infoButton.arenaError:Show();
			self.infoButton.wins:Hide();
			self.infoButton.winsValue:Hide();
			self.infoButton.losses:Hide();
			self.infoButton.lossesValue:Hide();
			self.infoButton.topLeftText:Hide();
			self.infoButton.bottomLeftText:Hide();
			self.teamIndex = nil;
		else
			local ArenaSizesToIndex = {}
			ArenaSizesToIndex[2] = 1;
			ArenaSizesToIndex[3] = 2;
			ArenaSizesToIndex[5] = 3;
			_, reward = GetPersonalRatedArenaInfo(ArenaSizesToIndex[teamSize]);
			self.winReward.winAmount:SetText(reward)
			if reward == 0 then
				RequestRatedArenaInfo(ArenaSizesToIndex[teamSize]);
			end
		
			self.infoButton.title:SetText(teamName);
			self.infoButton.winsValue:SetText(teamWins);
			self.infoButton.lossesValue:SetText(teamPlayed-teamWins);
			self.infoButton.topLeftText:SetText(PVP_RATING.." "..teamRating);
			self.infoButton.bottomLeftText:SetText(_G["ARENA_"..groupSize.."V"..groupSize]);
			
			self.infoButton.arenaError:Hide();
			self.infoButton.wins:Show();
			self.infoButton.winsValue:Show();
			self.infoButton.losses:Show();
			self.infoButton.lossesValue:Show();
			self.infoButton.topLeftText:Show();
			self.infoButton.bottomLeftText:Show();
		end
	else -- Rated BG
		local personalBGRating, ratedBGreward, _, _, _, _, weeklyWins, weeklyPlayed = GetPersonalRatedBGInfo();
		reward = ratedBGreward;
		self.topRatingText:SetText(RATING..": "..personalBGRating);
		self.winReward.winAmount:SetText(ratedBGreward);
		
		
		local name;
		name, size = GetRatedBattleGroundInfo();
		
		validGroup = groupSize==size;
		local prefixColorCode = "|cff808080";
		if validGroup then
			prefixColorCode = "";
		end
		
		
		if name then
			self.infoButton.title:SetText(prefixColorCode..name);
			self.infoButton.bottomLeftText:SetFormattedText(PVP_TEAMTYPE, size, size);
			self.noWeeklyFrame:Hide();
		else
			self.noWeeklyFrame:Show();
			self.noWeeklyFrame:SetFrameLevel(self:GetFrameLevel()+2);
		end
		
		
		self.infoButton.winsValue:SetText(prefixColorCode..weeklyWins);
		self.infoButton.lossesValue:SetText(prefixColorCode..(weeklyPlayed-weeklyWins));
		self.infoButton.topLeftText:SetText(prefixColorCode..ARENA_THIS_WEEK);
		
		self.infoButton.arenaError:Hide();
		self.infoButton.bgOff:Hide();
		
		
		self.infoButton.wins:Show();
		self.infoButton.winsValue:Show();
		self.infoButton.losses:Show();
		self.infoButton.lossesValue:Show();
		self.infoButton.topLeftText:Show();
		self.infoButton.bottomLeftText:Show();
		self.infoButton.bgNorm:Show();
	end
	
	self.partyInfoRollOver.tooltip = nil;
	if validGroup then
		self.partyStatusBG:SetVertexColor(0,1,0);
		self.partyInfoRollOver:Hide();
		self.partyNum:SetFormattedText(GREEN_FONT_COLOR_CODE..PVP_PARTY_SIZE, groupSize);
		self.infoButton.bgNorm:Show();
		self.infoButton.bgOff:Hide();
		SetDesaturation(self.infoButton.factionIcon, false);
		
		self.infoButton.wins:SetText(WINS);
		self.infoButton.losses:SetText(LOSSES);
		if UnitIsGroupLeader("player") then
			PVPFrameLeftButton:Enable();
		else
			PVPFrameLeftButton:Disable();
		end
	else
		self.partyStatusBG:SetVertexColor(1,0,0);
		self.partyInfoRollOver:Show();
		self.partyNum:SetFormattedText(RED_FONT_COLOR_CODE..PVP_PARTY_SIZE, groupSize);
		self.infoButton.bgNorm:Hide();
		self.infoButton.bgOff:Show();
		SetDesaturation(self.infoButton.factionIcon, true);
		
		self.infoButton.wins:SetText("|cff808080"..WINS);
		self.infoButton.losses:SetText("|cff808080"..LOSSES);
		PVPFrameLeftButton:Disable();
		
		if PVPConquestFrame.mode == "RatedBg" and  size and groupSize then
			if  size > groupSize then
				self.partyInfoRollOver.tooltip = string.format(PVP_RATEDBG_NEED_MORE, size - groupSize);
			else
				self.partyInfoRollOver.tooltip = string.format(PVP_RATEDBG_NEED_LESS, groupSize -  size);
			end
		end
	end

	
	if reward > 0 then
		self.rewardDescription:SetText(PVP_REWARD_EXPLANATION);
		self.winReward:Show();
	else
		self.rewardDescription:SetText(PVP_REWARD_FAILURE);
		self.winReward:Hide();
	end
	
	self.validGroup = validGroup;
end


function PVPConquestFrame_OnShow(self)
	if not self.clickedButton then
		self.clickedButton = self.arenaButton;
	end
	self.clickedButton:Click();
	PVPConquestFrame_Update(self);
	
	
	if ( UnitLevel("player") >= SHOW_PVP_LEVEL ) then
	--		ToggleFrame(PVPFrame);
	end
end


function PVPConquestFrame_ButtonClicked(button)
	if button:GetID() == 1 then --Arena
		PVPConquestFrame.mode = "Arena";
		PVPConquestFrame.BG:SetTexCoord(0.00097656, 0.31445313, 0.33789063, 0.88476563);
		PVPConquestFrame.description:SetText(PVP_ARENA_EXPLANATION);
		PVPConquestFrame.title:SetText(ARENA_BATTLES);
		button:LockHighlight();
		PVPConquestFrame.ratedbgButton:UnlockHighlight();
		PVPConquestFrame.topRatingText:Hide();
	else -- Rated BG	
		PVPConquestFrame.mode = "RatedBg";
		PVPConquestFrame.BG:SetTexCoord(0.32324219, 0.63671875, 0.00195313, 0.54882813);
		PVPConquestFrame.description:SetText(PVP_RATED_BATTLEGROUND_EXPLANATION);
		PVPConquestFrame.title:SetText(PVP_RATED_BATTLEGROUNDS);
		button:LockHighlight();
		PVPConquestFrame.arenaButton:UnlockHighlight();
		PVPConquestFrameInfoButton.title:SetText(PVP_RATED_BATTLEGROUND);
		PVPConquestFrameInfoButton.topLeftText:SetText(ARENA_THIS_WEEK);
		PVPConquestFrame.topRatingText:Show();
	end
	PVPConquestFrame_Update(PVPConquestFrame);
	PlaySound("igMainMenuOptionCheckBoxOn");
end


--  PVPTeamManagementFrame
--  PVPTeamManagementFrame

function PVPTeamManagementFrame_OnLoad(self)
	self:RegisterEvent("ARENA_TEAM_UPDATE");
	self:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE");
	local button;
	for i=1, MAX_ARENA_TEAM_MEMBERS_SHOWN do
		button = _G["PVPTeamManagementFrameTeamMemberButton"..i];
		if mod(i, 2) == 0 then 
			button.BG:Show();
		else		
			button.BG:Hide();
		end
	end
	
	PvP_WeeklyText:SetText(ARENA_WEEKLY_STATS);
end



function PVPTeamManagementFrame_OnEvent(self, event, ...)
	if not self:IsShown() then
		return;
	end
	
	local arg1 = ...;
	if ( event == "ARENA_TEAM_UPDATE") then
		PVPTeamManagementFrame_UpdateTeams(self)
	elseif ( event == "ARENA_TEAM_ROSTER_UPDATE" ) then
		PVPTeamManagementFrame_UpdateTeamInfo(self, self.selectedTeam);
	end
end



function PVPTeamManagementFrame_ToggleSeasonal(self)
	local parent  = self:GetParent();
	parent.seasonStats = not parent.seasonStats;	
	PVPTeamManagementFrame_UpdateTeamInfo(parent, parent.selectedTeam);
end

function PVPTeamManagementFrame_UpdateTeamInfo(self, flagbutton)
	if not  flagbutton  then 
		if self.selectedTeam then
			flagbutton = self.selectedTeam;
		else 
			self.noTeams:Show();
			return;
		end
	end
	flagbutton.Glow:Show();	
	flagbutton.GlowHeader:Show();
	flagbutton.NormalHeader:Hide();
	flagbutton.title:SetFontObject(ARENABANNER_SMALLFONT);
	flagbutton.title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	self.selectedTeam = flagbutton;
	local teamIndex = flagbutton:GetID();
	ArenaTeamRoster(teamIndex);
	
	if  IsArenaTeamCaptain(teamIndex) then	
		PVPFrameLeftButton:Enable();
	else	
		PVPFrameLeftButton:Disable();
	end
	
	-- Pull Values
	local teamName, teamSize, teamRating, teamPlayed, teamWins,  seasonTeamPlayed, 
	seasonTeamWins, playerPlayed, seasonPlayerPlayed, teamRank, playerRating = GetArenaTeam(teamIndex);

	self.TeamData:Show()
	local TeamDataName = self.TeamData:GetName();
	local played, wins;
	if ( self.seasonStats ) then
		_G[TeamDataName.."TypeLabel"]:SetText(ARENA_THIS_SEASON);
		played = seasonTeamPlayed;
		wins = seasonTeamWins;
		playerPlayed = seasonPlayerPlayed;
		PvP_WeeklyText:SetText(ARENA_SEASON_STATS);
	else
		_G[TeamDataName.."TypeLabel"]:SetText(ARENA_THIS_WEEK);
		played = teamPlayed;
		wins = teamWins;
		playerPlayed = playerPlayed;
		PvP_WeeklyText:SetText(ARENA_WEEKLY_STATS);
	end

	local loss = played - wins;
	-- Populate Data
	_G[TeamDataName.."Name"]:SetText(_G["ARENA_"..teamSize.."V"..teamSize].."  "..teamName);
	_G[TeamDataName.."Rating"]:SetText(teamRating);
	_G[TeamDataName.."Games"]:SetText(played);
	_G[TeamDataName.."Wins"]:SetText(wins);
	_G[TeamDataName.."Loss"]:SetText(loss);	
	 _G[TeamDataName.."Played"]:SetText(playerPlayed);
	 
	 
	--Show teammates at teamIndex
	local numMembers = GetNumArenaTeamMembers(teamIndex, 1);
	local scrollTeammates =  numMembers > MAX_ARENA_TEAM_MEMBERS_SHOWN;
	local TeammateButtonName = self:GetName().."TeamMemberButton";
	local scrollOffset =  FauxScrollFrame_GetOffset(self.teamMemberScrollFrame);
	
	
	
	if ( teamSize > numMembers ) then
		self.invalidTeam:Show();
		self.invalidTeam:SetFrameLevel(self:GetFrameLevel() + 2);
		if IsArenaTeamCaptain(teamIndex) then
			self.invalidTeam.text:SetText(ARENA_CAPTAIN_INVALID_TEAM);
		else
			self.invalidTeam.text:SetText(ARENA_NOT_CAPTAIN_INVALID_TEAM);
		end		
	else
		self.invalidTeam:Hide();
	end
	
	local nameText, classText, playedText, winLossWin, winLossLoss, winLossText, ratingText;
	-- Display Team Member Specific Info
	local playedValue, winValue, lossValue;
	for i=1, MAX_ARENA_TEAM_MEMBERS_SHOWN, 1 do
		local button = _G[TeammateButtonName..i];		
		if  scrollTeammates then
			button:SetWidth(MAX_ARENA_TEAM_MEMBER_SCROLL_WIDTH);
		else
			button:SetWidth(MAX_ARENA_TEAM_MEMBER_WIDTH);		
		end	
		
		
		if ( i > numMembers ) then
			button:Disable();
			_G[TeammateButtonName..i.."NameText"]:SetText("");
			--classText = _G[TeammateButtonName..i.."ClassText"];  ADD class color and Icon
			_G[TeammateButtonName..i.."PlayedText"]:SetText("");
			_G[TeammateButtonName..i.."WinLossText"]:SetText("");
			_G[TeammateButtonName..i.."RatingText"]:SetText("");
			_G[TeammateButtonName..i.."ClassIcon"]:Hide();
			_G[TeammateButtonName..i.."CaptainIcon"]:Hide();
		else
			button:Enable();
			button.playerIndex = i+scrollOffset;
			-- Get Data
			local name, rank, level, class, online, played, win, seasonPlayed, seasonWin, rating = GetArenaTeamRosterInfo(teamIndex, i+scrollOffset);
			loss = played - win;
			local seasonLoss = seasonPlayed - seasonWin;

			-- Populate Data into the display, season or this week
			if ( self.seasonStats ) then
				playedValue = seasonPlayed;
				winValue = seasonWin;
				lossValue = seasonLoss;
				teamPlayed = seasonTeamPlayed;
			else
				playedValue = played;
				winValue = win;
				lossValue = loss;
				teamPlayed = teamPlayed;
			end			
			
			nameText = _G[TeammateButtonName..i.."NameText"];
			--classText = _G[TeammateButtonName..i.."ClassText"];  ADD class color and Icon
			playedText = _G[TeammateButtonName..i.."PlayedText"]
			winLossText = _G[TeammateButtonName..i.."WinLossText"];
			ratingText = _G[TeammateButtonName..i.."RatingText"];			
			if class then
				_G[TeammateButtonName..i.."ClassIcon"]:SetTexCoord(unpack(CLASS_ICON_TCOORDS[strupper(class)]));
				_G[TeammateButtonName..i.."ClassIcon"]:Show();
			else
				_G[TeammateButtonName..i.."ClassIcon"]:Hide();
			end
			if  rank > 0 then
				_G[TeammateButtonName..i.."CaptainIcon"]:Hide();
			else
				_G[TeammateButtonName..i.."CaptainIcon"]:Show();
			end
			
			nameText:SetText(name);
			--classText:SetText(class);
			playedText:SetText(playedValue);
			winLossText:SetText(winValue.."-"..lossValue);
			ratingText:SetText(rating);
		
			-- Color Entries based on Online status
			local r, g, b;
			if ( online ) then
				if ( rank > 0 ) then
					r = 1.0;	g = 1.0;	b = 1.0;
				else
					r = 1.0;	g = 0.82;	b = 0.0;
				end
			else
				r = 0.5;	g = 0.5;	b = 0.5;
			end

			nameText:SetTextColor(r, g, b);
			playedText:SetTextColor(r, g, b);
			winLossText:SetTextColor(r, g, b);
			ratingText:SetTextColor(r, g, b);

			button:Show();

			-- Highlight the correct who
			if ( GetArenaTeamRosterSelection(teamIndex) == i ) then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
		end		
	end	 
	
	FauxScrollFrame_Update(self.teamMemberScrollFrame, numMembers, MAX_ARENA_TEAM_MEMBERS_SHOWN, 18);
end


function PVPTeamManagementFrame_TeamInfo_OnScroll()
	PVPTeamManagementFrame_UpdateTeamInfo(PVPTeamManagementFrame, PVPTeamManagementFrame.selectedTeam);
end


function PVPTeamManagementFrame_FlagClicked(self)
	local index = self:GetID();
	if index < 0 then   -- Player clicked a flag that is not associated with a current team
		-- Try to make a new Arena Team.
			local teamSize = abs(index);
			PVPBannerFrame.teamSize = teamSize;
			ShowUIPanel(PVPBannerFrame);
			PVPBannerFrameTitleText:SetText(_G["ARENA_"..teamSize.."V"..teamSize]);
	else
		if  self:GetParent().selectedTeam then
			self:GetParent().selectedTeam.Glow:Hide();		
			self:GetParent().selectedTeam.GlowHeader:Hide();
			self:GetParent().selectedTeam.NormalHeader:Show();			
			self:GetParent().selectedTeam.title:SetFontObject(ARENABANNER_SMALLFONT);
			self:GetParent().selectedTeam.title:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
			HideUIPanel(PVPBannerFrame);
		end
		PVPTeamManagementFrame_UpdateTeamInfo(self:GetParent(), self);	
		FauxScrollFrame_SetOffset(self:GetParent().teamMemberScrollFrame, 0);
	end
end


function PVPTeamManagementFrame_UpdateTeams(self)
		
		self.defaultTeam = nil;
		local bannerName = "";
		local flagsList = {};
		flagsList[2] = false;
		flagsList[3] = false;
		flagsList[5] = false;	
		
		local teamName, teamSize, teamRating, emblem, border, _;
		local background = {}; 
		local emblemColor = {} ;
		local borderColor = {}; 		

		for i=1, MAX_ARENA_TEAMS do
			--the ammount of parameter this returns is absurd
			teamName, teamSize, teamRating, _,  _,  _, _, _, _, _, _, 
			background.r, background.g, background.b, 
			emblem, emblemColor.r, emblemColor.g, emblemColor.b, 
			border, borderColor.r, borderColor.g, borderColor.b 												= GetArenaTeam(i);			

			if teamName then
				flagsList[teamSize] = true;			
				bannerName = self["flag"..teamSize]:GetName();
				_G[bannerName]:Enable();
				_G[bannerName]:SetID(i);
				_G[bannerName.."Banner"]:SetVertexColor(background.r, background.g, background.b);
				_G[bannerName.."Emblem"]:Show();
				_G[bannerName.."Emblem"]:SetVertexColor( emblemColor.r, emblemColor.g, emblemColor.b);
				_G[bannerName.."Emblem"]:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-"..emblem);
				_G[bannerName.."Border"]:Show();
				_G[bannerName.."Border"]:SetVertexColor( borderColor.r, borderColor.g, borderColor.b );				
				_G[bannerName.."Border"]:SetTexture("Interface\\PVPFrame\\PVP-Banner-2-Border-"..border);
				_G[bannerName.."Title"]:SetText(_G["ARENA_"..teamSize.."V"..teamSize].."\n"..PVP_RATING.."  "..teamRating);
				_G[bannerName.."Title"]:SetFontObject(ARENABANNER_SMALLFONT);
				_G[bannerName.."Title"]:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				
				if not self.defaultTeam then
					self.defaultTeam =  _G[bannerName];	
				end
			end
		end	
	
		for size, value in pairs(flagsList) do 
			if  not value then 
				local bannerName = self["flag"..size]:GetName();
				_G[bannerName]:SetID(-size);
				_G[bannerName.."Banner"]:SetVertexColor(1, 1, 1);
				_G[bannerName.."Emblem"]:Hide();
				_G[bannerName.."Border"]:Hide();
				_G[bannerName.."Title"]:SetText(_G["ARENA_"..size.."V"..size]);
				_G[bannerName.."Title"]:SetFontObject("GameFontHighlight");
				_G[bannerName.."HeaderSelected"]:Hide();
				_G[bannerName.."Header"]:Show();
				_G[bannerName.."GlowBG"]:Hide();
				if  self.selectedTeam == self["flag"..size] then
					self.selectedTeam = nil;
				end
			end
		end

		self.noTeams:Hide();
		self.weeklyToggleLeft:Enable();
		self.weeklyToggleRight:Enable();
		PVPFrameLeftButton:Enable();
		if  self.selectedTeam then 
			PVPTeamManagementFrame_UpdateTeamInfo(self, self.selectedTeam)
		elseif  self.defaultTeam then 
			PVPTeamManagementFrame_UpdateTeamInfo(self, self.defaultTeam)
		else
			--We have no arena teams
			self.noTeams:Show();
			PVPFrameLeftButton:Disable();
			self.weeklyToggleLeft:Disable();
			self.weeklyToggleRight:Disable();
			self.invalidTeam:Hide();
			self.noTeams:SetFrameLevel(self:GetFrameLevel() + 2);
			FauxScrollFrame_Update(self.teamMemberScrollFrame, 0, MAX_ARENA_TEAM_MEMBERS_SHOWN, 18);
		end	
end


function PVPTeamManagementFrame_OnShow(self)
	PVPTeamManagementFrame_UpdateTeams(self)
end


function PVPTeamManagementFrame_DropDown_Initialize()
	UnitPopup_ShowMenu(UIDROPDOWNMENU_OPEN_MENU, "TEAM", nil, PVPTeamManagementFrameTeamDropDown.name);
end

function PVPTeamManagementFrame_ShowDropdown(name, online)
	HideDropDownMenu(1);
	
	if ( not IsArenaTeamCaptain(PVPTeamManagementFrame.selectedTeam:GetID()) ) then
		if ( online ) then
			PVPTeamManagementFrameTeamDropDown.initialize = PVPTeamManagementFrame_DropDown_Initialize;
			PVPTeamManagementFrameTeamDropDown.displayMode = "MENU";
			PVPTeamManagementFrameTeamDropDown.name = name;
			PVPTeamManagementFrameTeamDropDown.online = online;
			ToggleDropDownMenu(1, nil, PVPTeamManagementFrameTeamDropDown, "cursor");
		end
	else
		PVPTeamManagementFrameTeamDropDown.initialize = PVPTeamManagementFrame_DropDown_Initialize;
		PVPTeamManagementFrameTeamDropDown.displayMode = "MENU";
		PVPTeamManagementFrameTeamDropDown.name = name;
		PVPTeamManagementFrameTeamDropDown.online = online;
		ToggleDropDownMenu(1, nil, PVPTeamManagementFrameTeamDropDown, "cursor");
	end
end


---- PVP PopUp Functions


function PVPFramePopup_OnLoad(self)
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	self:RegisterEvent("BATTLEFIELD_QUEUE_TIMEOUT");
end


function PVPFramePopup_OnEvent(self, event, ...)
	if event == "BATTLEFIELD_QUEUE_TIMEOUT" then
		if self.type == "WARGAME_REQUESTED" then
			self:Hide();
		end
	end
end


function PVPFramePopup_OnUpdate(self, elasped)
	if self.timeout then
		self.timeout = self.timeout - elasped;
		if self.timeout > 0 then
			self.timer:SetText(SecondsToTime(self.timeout))
		end
	end
end


function PVPFramePopup_SetupPopUp(event, challengerName, bgName, timeout)
	PVPFramePopup.title:SetFormattedText(WARGAME_CHALLENGED, challengerName, bgName);
	PVPFramePopup.type = event;
	PVPFramePopup.timeout = timeout  - 3;  -- add a 3 second buffer
	PVPFramePopup.minimizeButton:Disable();
	SetPortraitToTexture(PVPFramePopup.ringIcon,"Interface\\BattlefieldFrame\\UI-Battlefield-Icon");
	StaticPopupSpecial_Show(PVPFramePopup);
	PlaySound("ReadyCheck");
end



function PVPFramePopup_OnResponse(accepted)
	if PVPFramePopup.type == "WARGAME_REQUESTED" then
		WarGameRespond(accepted)
	end
	
	StaticPopupSpecial_Hide(PVPFramePopup);
end



---- PVPTimer


function PVPTimerFrame_OnUpdate(self, elapsed)
	local keepUpdating = false;
	if ( BATTLEFIELD_SHUTDOWN_TIMER > 0 ) then
		keepUpdating = true;
	else
		for i = 1, GetMaxBattlefieldID() do
			if ( GetBattlefieldPortExpiration(i) > 0 ) then
				keepUpdating = true;
			end
		end
	end
	
	if ( not keepUpdating ) then
		PVPTimerFrame:SetScript("OnUpdate", nil);
		PVPTimerFrame.updating = false;
		return;
	end
	
	local frame = PVPFrame;
	
	BATTLEFIELD_SHUTDOWN_TIMER = BATTLEFIELD_SHUTDOWN_TIMER - elapsed;

	-- Set the time for the score frame
	WorldStateScoreFrameTimer:SetFormattedText(SecondsToTimeAbbrev(BATTLEFIELD_SHUTDOWN_TIMER));

	-- Check if I should send a message only once every 3 seconds (BATTLEFIELD_TIMER_DELAY)
	frame.timerDelay = frame.timerDelay + elapsed;
	if ( frame.timerDelay < BATTLEFIELD_TIMER_DELAY ) then
		return;
	else
		frame.timerDelay = 0
	end

	local threshold = BATTLEFIELD_TIMER_THRESHOLDS[BATTLEFIELD_TIMER_THRESHOLD_INDEX];
	if ( BATTLEFIELD_SHUTDOWN_TIMER > 0 ) then
		if ( BATTLEFIELD_SHUTDOWN_TIMER < threshold and BATTLEFIELD_TIMER_THRESHOLD_INDEX ~= #BATTLEFIELD_TIMER_THRESHOLDS ) then
			-- If timer past current threshold advance to the next one
			BATTLEFIELD_TIMER_THRESHOLD_INDEX = BATTLEFIELD_TIMER_THRESHOLD_INDEX + 1;
		else
			-- See if time should be posted
			local currentMod = floor(BATTLEFIELD_SHUTDOWN_TIMER/threshold);
			if ( PREVIOUS_BATTLEFIELD_MOD ~= currentMod ) then
				-- Print message
				local info = ChatTypeInfo["SYSTEM"];
				local string;
				if ( GetBattlefieldWinner() ) then
					local isArena = IsActiveBattlefieldArena();
					if ( isArena ) then
						string = format(ARENA_COMPLETE_MESSAGE, SecondsToTime(ceil(BATTLEFIELD_SHUTDOWN_TIMER/threshold) * threshold));
					else
						string = format(BATTLEGROUND_COMPLETE_MESSAGE, SecondsToTime(ceil(BATTLEFIELD_SHUTDOWN_TIMER/threshold) * threshold));
					end
				else
					string = format(INSTANCE_SHUTDOWN_MESSAGE, SecondsToTime(ceil(BATTLEFIELD_SHUTDOWN_TIMER/threshold) * threshold));
				end
				DEFAULT_CHAT_FRAME:AddMessage(string, info.r, info.g, info.b, info.id);
				PREVIOUS_BATTLEFIELD_MOD = currentMod;
			end
		end
	else
		BATTLEFIELD_SHUTDOWN_TIMER = 0;
	end
end



------		Misc PVP Functions
------		Misc PVP Functions


function PVPQueue_UpdateRandomInfo(base, infoFunc)
	local BGname, canEnter, isHoliday, isRandom = infoFunc();
	
	local hasWin, lossHonor, winHonor, winArena, lossArena;
	
	if ( isRandom ) then
		hasWin, winHonor, winArena, lossHonor, lossArena = GetRandomBGHonorCurrencyBonuses();
		base.title:SetText(RANDOM_BATTLEGROUND);
		base.description:SetText(RANDOM_BATTLEGROUND_EXPLANATION);
	else
		base.title:SetText(BATTLEGROUND_HOLIDAY_LONG);
		base.description:SetText(BATTLEGROUND_HOLIDAY_EXPLANATION);
		hasWin, winHonor, winArena, lossHonor, lossArena = GetHolidayBGHonorCurrencyBonuses();
	end
	
	if (winHonor ~= 0) then
		base.winReward.honorSymbol:Show();
		base.winReward.honorAmount:Show();
		base.winReward.honorAmount:SetText(winHonor);
	else
		base.winReward.honorSymbol:Hide();
		base.winReward.honorAmount:Hide();
	end

	local _, _, pointsThisWeek, maxPointsThisWeek = GetPersonalRatedBGInfo();
	winArena = max(0, min(winArena, maxPointsThisWeek - pointsThisWeek));
	if (winArena ~= 0) then
		base.winReward.arenaSymbol:Show();
		base.winReward.arenaAmount:Show();
		base.winReward.arenaAmount:SetText(winArena);
	else
		base.winReward.arenaSymbol:Hide();
		base.winReward.arenaAmount:Hide();
	end
	
	if (lossHonor ~= 0) then
		base.lossReward.honorSymbol:Show();
		base.lossReward.honorAmount:Show();
		base.lossReward.honorAmount:SetText(lossHonor);
	else
		base.lossReward.honorSymbol:Hide();
		base.lossReward.honorAmount:Hide();
	end
	
	if (lossArena ~= 0) then
		base.lossReward.arenaSymbol:Show();
		base.lossReward.arenaAmount:Show();
		base.lossReward.arenaAmount:SetText(lossArena);
	else
		base.lossReward.arenaSymbol:Hide();
		base.lossReward.arenaAmount:Hide();
	end
		
	local englishFaction = UnitFactionGroup("player");
	base.winReward.honorSymbol:SetTexture("Interface\\PVPFrame\\PVPCurrency-Honor-"..englishFaction);
	base.lossReward.honorSymbol:SetTexture("Interface\\PVPFrame\\PVPCurrency-Honor-"..englishFaction);
	base.winReward.arenaSymbol:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..englishFaction);
	base.lossReward.arenaSymbol:SetTexture("Interface\\PVPFrame\\PVPCurrency-Conquest-"..englishFaction);
end


function IsAlreadyInQueue(mapName)
	local inQueue = nil;
	for index,value in pairs(PREVIOUS_BATTLEFIELD_QUEUES) do
		if ( value == mapName ) then
			inQueue = 1;
		end
	end
	return inQueue;
end



function BattlegroundShineFadeIn()
	-- Fade in the shine and then fade it out with the ComboPointShineFadeOut function
	local fadeInfo = {};
	fadeInfo.mode = "IN";
	fadeInfo.timeToFade = 0.5;
	fadeInfo.finishedFunc = BattlegroundShineFadeOut;
	UIFrameFade(BattlegroundShine, fadeInfo);
end

--hack since a frame can't have a reference to itself in it
function BattlegroundShineFadeOut()
	UIFrameFadeOut(BattlegroundShine, 0.5);
end



function PVP_UpdateStatus(tooltipOnly, mapIndex)
	local status, mapName, instanceID, queueID, levelRangeMin, levelRangeMax, teamSize, registeredMatch;
	local numberQueues = 0;
	local timeInQueue;
	local tooltip;
	local showRightClickText;
	BATTLEFIELD_SHUTDOWN_TIMER = 0;

	for i=1, GetMaxBattlefieldID() do
		status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, registeredMatch, eligibleInQueue, waitingOnOtherActivity = GetBattlefieldStatus(i);
		if ( mapName ) then
			if (  instanceID ~= 0 ) then
				mapName = mapName.." "..instanceID;
			end
			if ( teamSize ~= 0 ) then
				if ( registeredMatch ) then
					mapName = ARENA_RATED_MATCH.." "..format(PVP_TEAMSIZE, teamSize, teamSize);
				else
					mapName = ARENA_CASUAL.." "..format(PVP_TEAMSIZE, teamSize, teamSize);
				end
			end
		end
		tooltip = nil;
		if ( not tooltipOnly and (status ~= "confirm") ) then
			StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY", i);
		end

		if ( status ~= "none" ) then
			numberQueues = numberQueues+1;
			if ( status == "confirm" ) then
				-- Have been accepted show enter battleground dialog
				if ( (i==mapIndex) and (not tooltipOnly) ) then
					local dialog = StaticPopup_Show("CONFIRM_BATTLEFIELD_ENTRY", mapName, nil, i);
					PlaySound("PVPTHROUGHQUEUE");
				end
				PVPTimerFrame:SetScript("OnUpdate", PVPTimerFrame_OnUpdate);
				PVPTimerFrame.updating = true;
			elseif ( status == "active" ) then
				-- In the battleground
				BATTLEFIELD_SHUTDOWN_TIMER = GetBattlefieldInstanceExpiration()/1000;
				if ( BATTLEFIELD_SHUTDOWN_TIMER > 0 and not PVPTimerFrame.updating ) then
					PVPTimerFrame:SetScript("OnUpdate", PVPTimerFrame_OnUpdate);
					PVPTimerFrame.updating = true;
					BATTLEFIELD_TIMER_THRESHOLD_INDEX = 1;
					PREVIOUS_BATTLEFIELD_MOD = 0;
				end
			elseif ( status == "error" ) then
				-- Should never happen haha
			end
		end
	end
end

--
-- WARGAMES
--

function WarGamesFrame_OnLoad(self)
	self.scrollFrame.scrollBar.doNotHide = true;
	self:RegisterEvent("GROUP_ROSTER_UPDATE");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("PLAYER_FLAGS_CHANGED");		-- for leadership changes
	self.scrollFrame.update = WarGamesFrame_Update;
	self.scrollFrame.dynamic =  WarGamesFrame_GetTopButton;
	HybridScrollFrame_CreateButtons(self.scrollFrame, "WarGameButtonTemplate", 0, -1);
end

function WarGamesFrame_OnEvent(self, event, ...)
	if ( self:IsShown() ) then
		WarGameStartButton_Update();
	end
end

function WarGamesFrame_OnShow(self)
	if ( not self.dataLevel or UnitLevel("player") > self.dataLevel ) then
		WarGamesFrame.otherHeaderIndex = nil;
		self.dataLevel = UnitLevel("player");
		UpdateWarGamesList();
	end
	WarGamesFrame_Update();
end

function  WarGamesFrame_GetTopButton(offset)
	local heightLeft = offset;
	local buttonHeight;
	local numWarGames = GetNumWarGameTypes();

	-- find the other header's position if needed (assuming collapsing and expanding headers are a rare occurence for a list this small)
	if ( not WarGamesFrame.otherHeaderIndex ) then
		WarGamesFrame.otherHeaderIndex = 0;
		for i = 2, numWarGames do
			local name = GetWarGameTypeInfo(i);
			if ( name == "header" ) then
				WarGamesFrame.otherHeaderIndex = i;
				break;
			end
		end
	end
	-- determine top button
	local otherHeaderIndex = WarGamesFrame.otherHeaderIndex;
	for i = 1, numWarGames do
		if ( i == 1 or i == otherHeaderIndex ) then
			buttonHeight =	WARGAME_HEADER_HEIGHT;
		else
			buttonHeight = WARGAME_BUTTON_HEIGHT;
		end
		if ( heightLeft - buttonHeight <= 0 ) then
			return i - 1, heightLeft;
		else
			heightLeft = heightLeft - buttonHeight;
		end
	end
end

function WarGamesFrame_Update()
	local scrollFrame = WarGamesFrame.scrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	local numWarGames = GetNumWarGameTypes();
	local selectedIndex = GetSelectedWarGameType();
	
	for i = 1, numButtons do
		local button = buttons[i];
		local index = offset + i;
		if index <= numWarGames  then
			local name, pvpType, collapsed, id, minPlayers, maxPlayers, isRandom = GetWarGameTypeInfo(index);
			if ( name == "header" ) then
				button:SetHeight(WARGAME_HEADER_HEIGHT);
				button.header:Show();
				button.warGame:Hide();
				if ( pvpType == INSTANCE_TYPE_BG ) then
					button.header.name:SetText(BATTLEGROUND);
				elseif ( pvpType == INSTANCE_TYPE_ARENA ) then
					button.header.name:SetText(ARENA);
				else
					button.header.name:SetText(UNKNOWN);
				end
				if ( collapsed ) then
					button.header:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
				else
					button.header:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up"); 
				end
			else
				button:SetHeight(WARGAME_BUTTON_HEIGHT);
				button.header:Hide();
				local warGame = button.warGame;
				warGame:Show();
				warGame.name:SetText(name);
				-- arena?
				if ( pvpType == INSTANCE_TYPE_ARENA ) then
					minPlayers = 2;
					warGame.size:SetText(WARGAME_ARENA_SIZES);
				else
					warGame.size:SetFormattedText(PVP_TEAMTYPE, maxPlayers, maxPlayers);
				end
				warGame.minSize:SetFormattedText(WARGAME_MINIMUM, minPlayers, minPlayers);
				if ( WARGAMES_TEXTURELIST[id] ) then
					warGame.icon:SetTexture(WARGAMES_TEXTURELIST[id]);
				else
					warGame.icon:SetTexture(WARGAMES_TEXTURELIST[0]);
				end
				if ( selectedIndex == index ) then
					warGame.selectedTex:Show();
					warGame.name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
					warGame.size:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				else
					warGame.selectedTex:Hide();
					warGame.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
					warGame.size:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				end
			end
			button:Show();
			button.index = index;
		else
			button:Hide();
		end
	end

	-- keeping it somewhat easy to expand past 2 headers if needed
	local numHeaders = 1;
	if ( WarGamesFrame.otherHeaderIndex and WarGamesFrame.otherHeaderIndex > 0 ) then
		numHeaders = numHeaders + 1;
	end
	
	local totalHeight = numHeaders * WARGAME_HEADER_HEIGHT + (numWarGames - numHeaders) * WARGAME_BUTTON_HEIGHT;
	HybridScrollFrame_Update(scrollFrame, totalHeight, 208);
	
	WarGameStartButton_Update();
end

function WarGameButtonHeader_OnClick(self)
	local index = self:GetParent().index;
	local name, pvpType, collapsed = GetWarGameTypeInfo(index);
	if ( collapsed ) then
		ExpandWarGameHeader(index);
	else
		CollapseWarGameHeader(index);
	end
	WarGamesFrame.otherHeaderIndex = nil;	-- header location probably changed;
	WarGamesFrame_Update();
	PlaySound("igMainMenuOptionCheckBoxOn");
end

function WarGameButton_OnEnter(self)
	self.name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	self.size:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
end

function WarGameButton_OnLeave(self)
	if ( self:GetParent().index ~= GetSelectedWarGameType() ) then
		self.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		self.size:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
end

function WarGameButton_OnClick(self)
	local index = self:GetParent().index;
	SetSelectedWarGameType(index);
	WarGamesFrame_Update();
	PlaySound("igMainMenuOptionCheckBoxOn");
end

function WarGameStartButton_Update()
	local selectedIndex = GetSelectedWarGameType();
	if ( selectedIndex > 0 and not WarGameStartButton_GetErrorTooltip() ) then
		WarGameStartButton:Enable();
	else
		WarGameStartButton:Disable();
	end
end

function WarGameStartButton_OnEnter(self)
	local tooltip = WarGameStartButton_GetErrorTooltip();
	if ( tooltip ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(tooltip, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1, 1);
	end
end

function WarGameStartButton_GetErrorTooltip()
	local name, pvpType, collapsed, id, minPlayers, maxPlayers = GetWarGameTypeInfo(GetSelectedWarGameType());
	if ( name ) then
		if ( not UnitIsGroupLeader("player") ) then
			return WARGAME_REQ_LEADER;
		end	
		if ( not UnitLeadsAnyGroup("target") or UnitIsUnit("player", "target") ) then
			return WARGAME_REQ_TARGET;
		end
		local groupSize = GetNumGroupMembers();
		-- how about a nice game of arena?
		if ( pvpType == INSTANCE_TYPE_ARENA ) then
			if ( groupSize ~= 2 and groupSize ~= 3 and groupSize ~= 5 ) then
				return string.format(WARGAME_REQ_ARENA, name, RED_FONT_COLOR_CODE);
			end
		else
			if ( groupSize < minPlayers or groupSize > maxPlayers ) then
				return string.format(WARGAME_REQ, name, RED_FONT_COLOR_CODE, minPlayers, maxPlayers);
			end
		end
	end
	return nil;
end

function WarGameStartButton_OnClick(self)
	local name = GetWarGameTypeInfo(GetSelectedWarGameType());
	if ( name ) then
		StartWarGame(UnitName("target"), name);
	end
end

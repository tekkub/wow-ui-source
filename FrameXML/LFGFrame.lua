-----
--A note on nomenclature:
--LFD is used for Dungeon-specific functions and values
--LFR is used for Raid-specific functions and values
--LFG is used for for generic functions/values that may be used for LFD, LFR, and any other LF_ system we may implement in the future.
------

--DEBUG FIXME:
function LFGDebug(text, ...)
	if ( GetCVarBool("lfgDebug") ) then
		ConsolePrint("LFGLua: "..format(text, ...));
	end
end

TYPEID_DUNGEON = 1;
TYPEID_RANDOM_DUNGEON = 6;

LFG_SUBTYPEID_DUNGEON = 1;
LFG_SUBTYPEID_HEROIC = 2;
LFG_SUBTYPEID_RAID = 3;
LFG_SUBTYPEID_SCENARIO = 4;

LFG_ID_TO_ROLES = { "DAMAGER", "TANK", "HEALER" };
LFG_RETURN_VALUES = {
	name = 1,
	typeID = 2,
	subtypeID = 3,
	minLevel = 4,
	maxLevel = 5,
	recLevel = 6,	--Recommended level
	minRecLevel = 7,	--Minimum recommended level
	maxRecLevel = 8,	--Maximum recommended level
	expansionLevel = 9,
	groupID = 10,
	texture = 11,
	difficulty = 12,
	maxPlayers = 13,
}

LFG_INSTANCE_INVALID_RAID_LOCKED = 6;

LFG_INSTANCE_INVALID_WRONG_FACTION = 10;
LFG_INSTANCE_INVALID_CODES = { --Any other codes are unspecified conditions (e.g. attunements)
	"EXPANSION_TOO_LOW",
	"LEVEL_TOO_LOW",
	"LEVEL_TOO_HIGH",
	"GEAR_TOO_LOW",
	"GEAR_TOO_HIGH",
	"RAID_LOCKED",
	nil,	--Target level too high
	nil,	--Target level too low
	"AREA_NOT_EXPLORED",
	[1001] = "LEVEL_TOO_LOW",
	[1002] = "LEVEL_TOO_HIGH",
	[1022] = "QUEST_NOT_COMPLETED",
	[1025] = "MISSING_ITEM",
	[1034] = "ACHIEVEMENT_NOT_COMPLETED",
	[10000] = "TEMPORARILY_DISABLED",
}

LFG_ROLE_SHORTAGE_RARE = 1;
LFG_ROLE_SHORTAGE_UNCOMMON = 2;
LFG_ROLE_SHORTAGE_PLENTIFUL = 3;
LFG_ROLE_NUM_SHORTAGE_TYPES = 3;

--Variables to store dungeon info in Lua
--local LFDDungeonList, LFRRaidList, LFGCollapseList, LFGEnabledList, LFDHiddenByCollapseList, LFGLockList;

function LFGEventFrame_OnLoad(self)
	self:RegisterEvent("LFG_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("LFG_LOCK_INFO_RECEIVED");
	self:RegisterEvent("GROUP_ROSTER_UPDATE");
	
	self:RegisterEvent("LFG_OFFER_CONTINUE");
	self:RegisterEvent("LFG_ROLE_CHECK_ROLE_CHOSEN");
	
	self:RegisterEvent("LFG_PROPOSAL_UPDATE");
	self:RegisterEvent("LFG_PROPOSAL_SHOW");
	self:RegisterEvent("LFG_PROPOSAL_FAILED");
	self:RegisterEvent("LFG_PROPOSAL_SUCCEEDED");
	
	self:RegisterEvent("VARIABLES_LOADED");

	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	--These just update states (roles changeable, buttons clickable, etc.)
	self:RegisterEvent("LFG_ROLE_CHECK_SHOW");
	self:RegisterEvent("LFG_ROLE_CHECK_HIDE");
	self:RegisterEvent("LFG_BOOT_PROPOSAL_UPDATE");
	self:RegisterEvent("LFG_ROLE_UPDATE");
	self:RegisterEvent("LFG_UPDATE_RANDOM_INFO");
	self:RegisterEvent("LFG_INVALID_ERROR_MESSAGE");
end

LFGQueuedForList = {};
for i=1, NUM_LE_LFG_CATEGORYS do
	LFGQueuedForList[i] = {};
end
function LFGEventFrame_OnEvent(self, event, ...)
	if ( event == "LFG_UPDATE" ) then
		LFG_UpdateAllRoleCheckboxes();
		LFG_UpdateQueuedList();
		local slot = GetPartyLFGID();
		if ( slot ) then
			local category = GetLFGCategoryForID(slot);
			local mode, subMode = GetLFGMode(category);
			if ( mode == "queued" ) then --We're now queued, remove the backfill popup.
				self.queuedContinueName = nil;
				StaticPopup_Hide("LFG_OFFER_CONTINUE");
			end
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		LFG_UpdateQueuedList();
		LFG_UpdateAllRoleCheckboxes();
		LFG_DisplayGroupLeaderWarning(self);
	elseif ( event == "LFG_LOCK_INFO_RECEIVED" ) then
		LFGLockList = GetLFDChoiceLockedState();
		LFG_UpdateFramesIfShown();
	elseif ( event == "GROUP_ROSTER_UPDATE" ) then
		LFG_UpdateQueuedList();
		LFG_UpdateFramesIfShown();
		LFG_DisplayGroupLeaderWarning(self);
		if ( not CanPartyLFGBackfill() ) then
			self.queuedContinueName = nil;
			StaticPopup_Hide("LFG_OFFER_CONTINUE");
		end
	elseif ( event == "LFG_OFFER_CONTINUE" ) then
		local displayName, lfgID, typeID = ...;
		if ( not UnitAffectingCombat("player") ) then
			local dialog = StaticPopup_Show("LFG_OFFER_CONTINUE", NORMAL_FONT_COLOR_CODE..displayName.."|r");
			if ( dialog ) then
				dialog.data = lfgID;
				dialog.data2 = typeID;
			end
		else
			self.queuedContinueName = displayName;
			self.queuedContinueLfgID = lfgID;
			self.queuedContinueTypeID = typeID;
		end
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		if ( self.queuedContinueName ) then
			if ( CanPartyLFGBackfill() ) then --Make sure we can still backfill.
				local dialog = StaticPopup_Show("LFG_OFFER_CONTINUE", NORMAL_FONT_COLOR_CODE..self.queuedContinueName.."|r");
				if ( dialog ) then
					dialog.data = self.queuedContinueLfgID;
					dialog.data2 = self.queuedContinueTypeID;
				end
			end
			self.queuedContinueName = nil;
		end
		return;	--We don't need to update anything else on this event
	elseif ( event == "LFG_ROLE_CHECK_ROLE_CHOSEN" ) then
		local player, isTank, isHealer, isDamage = ...;

		--Yes, consecutive string concatenation == bad for garbage collection. But the alternative is either extremely unslightly or localization unfriendly. (Also, this happens fairly rarely)
		local roleList;
		
		if ( isTank ) then
			roleList = INLINE_TANK_ICON.." "..TANK;
		end
		if ( isHealer ) then
			if ( roleList ) then
				roleList = roleList..PLAYER_LIST_DELIMITER.." "..INLINE_HEALER_ICON.." "..HEALER;
			else
				roleList = INLINE_HEALER_ICON.." "..HEALER;
			end
		end
		if ( isDamage ) then
			if ( roleList ) then
				roleList = roleList..PLAYER_LIST_DELIMITER.." "..INLINE_DAMAGER_ICON.." "..DAMAGER;
			else
				roleList = INLINE_DAMAGER_ICON.." "..DAMAGER;
			end
		end
		assert(roleList);
		ChatFrame_DisplaySystemMessageInPrimary(string.format(LFG_ROLE_CHECK_ROLE_CHOSEN, player, roleList));
	elseif ( event == "VARIABLES_LOADED" ) then
		LFG_UpdateAllRoleCheckboxes();
	elseif ( event == "LFG_ROLE_UPDATE" ) then
		LFG_UpdateAllRoleCheckboxes();
	elseif ( event == "LFG_PROPOSAL_UPDATE" ) then
		LFGDungeonReadyPopup_Update();
	elseif ( event == "LFG_PROPOSAL_SHOW" ) then
		LFGDungeonReadyPopup.closeIn = nil;
		LFGDungeonReadyPopup:SetScript("OnUpdate", nil);
		LFGDungeonReadyStatus_ResetReadyStates();
		StaticPopupSpecial_Show(LFGDungeonReadyPopup);
		PlaySound("ReadyCheck");
	elseif ( event == "LFG_PROPOSAL_FAILED" ) then
		LFGDungeonReadyPopup_OnFail();
	elseif ( event == "LFG_PROPOSAL_SUCCEEDED" ) then
		LFGDebug("Proposal Hidden: Proposal succeeded.");
		StaticPopupSpecial_Hide(LFGDungeonReadyPopup);
	elseif ( event == "LFG_ROLE_CHECK_HIDE" ) then
		LFG_UpdateFramesIfShown();
	elseif ( event == "LFG_INVALID_ERROR_MESSAGE" ) then
		local reason, reasonArg1, reasonArg2 = ...;
		local info = ChatTypeInfo["SYSTEM"];
		DEFAULT_CHAT_FRAME:AddMessage(format(_G["INSTANCE_UNAVAILABLE_SELF_"..(LFG_INSTANCE_INVALID_CODES[reason] or "OTHER")], "",reasonArg1, reasonArg2), info.r, info.g, info.b, info.id);
	end
	
	LFG_UpdateRolesChangeable();
	LFG_UpdateFindGroupButtons();
	LFG_UpdateLockedOutPanels();
	LFDFrame_UpdateBackfill();
	RaidFinderFrame_UpdateBackfill();
end

function LFG_DisplayGroupLeaderWarning(eventFrame)
	local numRaidMembers = GetNumGroupMembers();
	if ( not HasLFGRestrictions() or not IsInGroup() or IsInScenarioGroup() ) then
		eventFrame.lastLeader = nil;
		return;
	end

	if ( not IsInLFGDungeon() ) then
		--We only want to display the message if we're actually in the dungeon.
		return;
	end

	local leaderName;

	if ( IsInRaid() ) then
		for i=1, numRaidMembers do
			local name, rank = GetRaidRosterInfo(i);
			if ( rank == 2 ) then
				leaderName = name;
			end
		end
	elseif ( UnitIsGroupLeader("player") ) then
		leaderName = UnitName("player");
	else
		for i=1, GetNumSubgroupMembers() do
			if ( UnitIsGroupLeader("party"..i) ) then
				leaderName = UnitName("party"..i);
				break;
			end
		end
	end

	if ( eventFrame.lastLeader ~= leaderName ) then
		--We'll hold this message a little bit longer than most.
		RaidNotice_AddMessage(RaidWarningFrame, format(LFG_LEADER_CHANGED_WARNING, leaderName), ChatTypeInfo["RAID_WARNING"], 18);
		if ( not eventFrame.lastLeader ) then
			local info = ChatTypeInfo["SYSTEM"];
			DEFAULT_CHAT_FRAME:AddMessage(format(LFG_LEADER_CHANGED_WARNING, leaderName), info.r, info.g, info.b, info.id);
		end

	end
	eventFrame.lastLeader = leaderName;
end

function LFG_UpdateLockedOutPanels()
	--[[
	local mode, submode = GetLFGMode();
	
	if ( mode == "listed" ) then
		LFDQueueFrameNoLFDWhileLFR:Show();
		LFDQueueFrameNoLFDWhileLFRDescription:SetText(NO_LFD_WHILE_LFR);
	elseif ( mode == "queued" or mode == "rolecheck" or mode == "proposal" or mode == "suspended" ) then
		local queueType = GetLFGModeType();
		if ( queueType == "raid" ) then
			LFDQueueFrameNoLFDWhileLFR:Show();
			LFDQueueFrameNoLFDWhileLFRDescription:SetText(NO_LFD_WHILE_RF);
		else
			LFDQueueFrameNoLFDWhileLFR:Hide();
		end
	else
		LFDQueueFrameNoLFDWhileLFR:Hide();
	end
	
	if ( mode == "queued" or mode == "proposal" or mode == "rolecheck" or mode == "suspended" ) then
		LFRQueueFrameNoLFRWhileLFD:Show();
	else
		LFRQueueFrameNoLFRWhileLFD:Hide();
	end
	--]]
end

function LFG_UpdateFindGroupButtons()
	LFDQueueFrameFindGroupButton_Update();
	LFRQueueFrameFindGroupButton_Update();
	RaidFinderFrameFindRaidButton_Update();
	ScenarioQueueFrameFindGroupButton_Update();
end

function LFG_UpdateQueuedList()
	for i=1, NUM_LE_LFG_CATEGORYS do
		LFGQueuedForList[i] = GetLFGQueuedList(i, LFGQueuedForList[i]);	--Re-fill table if it already exists, otherwise create
	end
	LFG_UpdateFramesIfShown();
end

function LFG_UpdateFramesIfShown()
	if ( LFDParentFrame:IsVisible() ) then
		LFDQueueFrame_Update();
	end
	if ( LFRParentFrame:IsVisible() ) then
		LFRQueueFrame_Update();
	end
	if ( ScenarioQueueFrame:IsVisible() ) then
		ScenarioQueueFrame_Update();
	end	
end

function LFG_PermanentlyDisableRoleButton(button)
	button.permDisabled = true;
	button:Disable();
	SetDesaturation(button:GetNormalTexture(), true);
	button.cover:Show();
	button.cover:SetAlpha(0.7);
	button.checkButton:Hide();
	button.checkButton:Disable();
	if ( button.background ) then
		button.background:Hide();
	end
	if ( button.shortageBorder ) then
		button.shortageBorder:SetVertexColor(0.5, 0.5, 0.5);
		button.incentiveIcon.texture:SetVertexColor(0.5, 0.5, 0.5);
		button.incentiveIcon.border:SetVertexColor(0.5, 0.5, 0.5);
	end
end

function LFG_DisableRoleButton(button)
	button:Disable();
	button.cover:Show();
	if ( not button.permDisabled ) then
		button.cover:SetAlpha(0.5);
	end
	button.checkButton:Disable();
	if ( button.background ) then
		button.background:Hide();
	end
	if ( button.shortageBorder ) then
		button.shortageBorder:SetVertexColor(0.5, 0.5, 0.5);
		button.incentiveIcon.texture:SetVertexColor(0.5, 0.5, 0.5);
		button.incentiveIcon.border:SetVertexColor(0.5, 0.5, 0.5);
	end
end

function LFG_EnableRoleButton(button)
	button.permDisabled = false;
	button:Enable();
	SetDesaturation(button:GetNormalTexture(), false);
	button.cover:Hide();
	button.checkButton:Show();
	button.checkButton:Enable();
	if ( button.background ) then
		button.background:Show();
	end
	if ( button.shortageBorder ) then
		button.shortageBorder:SetVertexColor(1, 1, 1);
		button.incentiveIcon.texture:SetVertexColor(1, 1, 1);
		button.incentiveIcon.border:SetVertexColor(1, 1, 1);
	end
end

function LFG_UpdateAvailableRoles(tankButton, healButton, dpsButton, leaderButton)
	local canBeTank, canBeHealer, canBeDPS = UnitGetAvailableRoles("player");
	
	if ( canBeTank ) then
		LFG_EnableRoleButton(tankButton);
	else
		LFG_PermanentlyDisableRoleButton(tankButton);
	end
	
	if ( canBeHealer ) then
		LFG_EnableRoleButton(healButton);
	else
		LFG_PermanentlyDisableRoleButton(healButton);
	end
	
	if ( canBeDPS ) then
		LFG_EnableRoleButton(dpsButton);
	else
		LFG_PermanentlyDisableRoleButton(dpsButton);
	end
	
	if ( leaderButton ) then
		if (not IsInGroup() or UnitIsGroupLeader("player")) then
			LFG_EnableRoleButton(leaderButton);
		else
			LFG_PermanentlyDisableRoleButton(leaderButton);
		end
	end
end

function LFG_UpdateAllRoleCheckboxes()
	LFG_UpdateRoleCheckboxes(LE_LFG_CATEGORY_LFD, LFDQueueFrameRoleButtonTank, LFDQueueFrameRoleButtonHealer, LFDQueueFrameRoleButtonDPS, LFDQueueFrameRoleButtonLeader);
	LFG_UpdateRoleCheckboxes(LE_LFG_CATEGORY_LFD, LFDRoleCheckPopupRoleButtonTank, LFDRoleCheckPopupRoleButtonHealer, LFDRoleCheckPopupRoleButtonDPS, nil);
	LFG_UpdateRoleCheckboxes(LE_LFG_CATEGORY_LFR, LFRQueueFrameRoleButtonTank, LFRQueueFrameRoleButtonHealer, LFRQueueFrameRoleButtonDPS, nil);
	LFG_UpdateRoleCheckboxes(LE_LFG_CATEGORY_RF, RaidFinderQueueFrameRoleButtonTank, RaidFinderQueueFrameRoleButtonHealer, RaidFinderQueueFrameRoleButtonDPS, RaidFinderQueueFrameRoleButtonLeader);
end

function LFG_UpdateRoleCheckboxes(category, tankButton, healButton, dpsButton, leaderButton)
	local mode, submode = GetLFGMode(category);
	local inParty, joined, queued, noPartialClear, achievements, lfgComment, slotCount, category, leader, tank, healer, dps = GetLFGInfoServer(category);
	if ( mode ~= "queued" and mode ~= "listed" and mode ~= "suspended" ) then
		leader, tank, healer, dps = GetLFGRoles();
	end

	tankButton.checkButton:SetChecked(tank);
	healButton.checkButton:SetChecked(healer);
	dpsButton.checkButton:SetChecked(dps);
	
	if ( leaderButton ) then
		leaderButton.checkButton:SetChecked(leader);
	end
end

function LFG_UpdateRolesChangeable()
	local mode, subMode = GetLFGMode(LE_LFG_CATEGORY_LFD);
	if ( mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal" or mode == "suspended" ) then
		LFG_DisableRoleButton(LFDQueueFrameRoleButtonTank, true);
		LFG_DisableRoleButton(LFDQueueFrameRoleButtonHealer, true);
		LFG_DisableRoleButton(LFDQueueFrameRoleButtonDPS, true);
		LFG_DisableRoleButton(LFDQueueFrameRoleButtonLeader, true);
	else
		LFG_UpdateAvailableRoles(LFDQueueFrameRoleButtonTank, LFDQueueFrameRoleButtonHealer, LFDQueueFrameRoleButtonDPS, LFDQueueFrameRoleButtonLeader);
	end

	mode, submode = GetLFGMode(LE_LFG_CATEGORY_LFR);
	if ( mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal" or mode == "suspended" ) then
		LFG_DisableRoleButton(LFRQueueFrameRoleButtonTank, true);
		LFG_DisableRoleButton(LFRQueueFrameRoleButtonHealer, true);
		LFG_DisableRoleButton(LFRQueueFrameRoleButtonDPS, true);
	else
		LFG_UpdateAvailableRoles(LFRQueueFrameRoleButtonTank, LFRQueueFrameRoleButtonHealer, LFRQueueFrameRoleButtonDPS, nil);
	end

	mode, submode = GetLFGMode(LE_LFG_CATEGORY_RF);
	if ( mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal" or mode == "suspended" ) then
		LFG_DisableRoleButton(RaidFinderQueueFrameRoleButtonTank, true);
		LFG_DisableRoleButton(RaidFinderQueueFrameRoleButtonHealer, true);
		LFG_DisableRoleButton(RaidFinderQueueFrameRoleButtonDPS, true);
		LFG_DisableRoleButton(RaidFinderQueueFrameRoleButtonLeader, true);
	else
		LFG_UpdateAvailableRoles(RaidFinderQueueFrameRoleButtonTank, RaidFinderQueueFrameRoleButtonHealer, RaidFinderQueueFrameRoleButtonDPS, RaidFinderQueueFrameRoleButtonLeader);
	end

	--Always update the role check popup
	LFG_UpdateAvailableRoles(LFDRoleCheckPopupRoleButtonTank, LFDRoleCheckPopupRoleButtonHealer, LFDRoleCheckPopupRoleButtonDPS, nil);
end

function LFG_SetRoleIconIncentive(roleButton, incentiveIndex)
	if ( incentiveIndex ) then
		local tex;
		if ( incentiveIndex == LFG_ROLE_SHORTAGE_PLENTIFUL ) then
			tex = "Interface\\Icons\\INV_Misc_Coin_19";
		elseif ( incentiveIndex == LFG_ROLE_SHORTAGE_UNCOMMON ) then
			tex = "Interface\\Icons\\INV_Misc_Coin_18";
		elseif ( incentiveIndex == LFG_ROLE_SHORTAGE_RARE ) then
			tex = "Interface\\Icons\\INV_Misc_Coin_17";
		end
		SetPortraitToTexture(roleButton.incentiveIcon.texture, tex);
		roleButton.incentiveIcon:Show();
		roleButton.shortageBorder:Show();
	else
		roleButton.incentiveIcon:Hide();
		roleButton.shortageBorder:Hide();
	end
end

function LFGRoleIconIncentive_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local role = LFG_ID_TO_ROLES[self:GetParent():GetID()];
	
	GameTooltip:SetText(format(LFG_CALL_TO_ARMS, _G[role]), 1, 1, 1);
	GameTooltip:AddLine(LFG_CALL_TO_ARMS_EXPLANATION, nil, nil, nil, 1);
	GameTooltip:Show();
end

function LFGSpecificChoiceEnableButton_SetIsRadio(button, isRadio)
	if ( isRadio ) then
		button:SetSize(17, 17)
		button:SetNormalTexture("Interface\\Buttons\\UI-RadioButton");
		button:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1);
		
		button:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton");
		button:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1);
		
		button:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton");
		button:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1);
		
		button:SetPushedTexture("Interface\\Buttons\\UI-RadioButton");
		button:GetPushedTexture():SetTexCoord(0, 0.25, 0, 1);
		
		button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-RadioButton");
		button:GetDisabledCheckedTexture():SetTexCoord(0.75, 1, 0, 1);
	else
		button:SetSize(20, 20);
		button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		button:GetNormalTexture():SetTexCoord(0, 1, 0, 1);
		
		button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		button:GetHighlightTexture():SetTexCoord(0, 1, 0, 1);
		
		button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
		button:GetCheckedTexture():SetTexCoord(0, 1, 0, 1);
		
		button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
		button:GetPushedTexture():SetTexCoord(0, 1, 0, 1);
		
		button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
		button:GetDisabledCheckedTexture():SetTexCoord(0, 1, 0, 1);
	end	
end

--More functions

function GetTexCoordsForRole(role)
	local textureHeight, textureWidth = 256, 256;
	local roleHeight, roleWidth = 67, 67;
	
	if ( role == "GUIDE" ) then
		return GetTexCoordsByGrid(1, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "TANK" ) then
		return GetTexCoordsByGrid(1, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "HEALER" ) then
		return GetTexCoordsByGrid(2, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "DAMAGER" ) then
		return GetTexCoordsByGrid(2, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetBackgroundTexCoordsForRole(role)
	local textureHeight, textureWidth = 128, 256;
	local roleHeight, roleWidth = 75, 75;
	
	if ( role == "TANK" ) then
		return GetTexCoordsByGrid(2, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "HEALER" ) then
		return GetTexCoordsByGrid(1, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "DAMAGER" ) then
		return GetTexCoordsByGrid(3, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	else
		error("Role does not have background: "..tostring(role));
	end
end

function GetTexCoordsForRoleSmallCircle(role)
	if ( role == "TANK" ) then
		return 0, 19/64, 22/64, 41/64;
	elseif ( role == "HEALER" ) then
		return 20/64, 39/64, 1/64, 20/64;
	elseif ( role == "DAMAGER" ) then
		return 20/64, 39/64, 22/64, 41/64;
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetTexCoordsForRoleSmall(role)
	if ( role == "TANK" ) then
		return 0.5, 0.75, 0, 1;
	elseif ( role == "HEALER" ) then
		return 0.75, 1, 0, 1;
	elseif ( role == "DAMAGER" ) then
		return 0.25, 0.5, 0, 1;
	else
		error("Unknown role: "..tostring(role));
	end
end

function LFGFrameRoleCheckButton_OnEnter(self)
	if ( self.checkButton:IsEnabled() == 1 ) then
		self.checkButton:LockHighlight();
	end
end

function LFGConstructDeclinedMessage(dungeonID)
	local returnVal;
	local hasTimeRestriction = false;
	for i=1, GetLFDLockPlayerCount() do
		local playerName, lockedReason, subReason1, subReason2 = GetLFDLockInfo(dungeonID, i);
		if ( lockedReason == 1029 or lockedReason == 1030 ) then --WRONG_TIME_RANGE or WRONG_TIME
			hasTimeRestriction = true;
		elseif ( lockedReason ~= 0 ) then
			local who;
			if ( i == 1 ) then
				who = "SELF_";
			else
				who = "OTHER_";
			end
			if ( returnVal ) then
				returnVal = returnVal.."\n"..format(_G["INSTANCE_UNAVAILABLE_"..who..(LFG_INSTANCE_INVALID_CODES[lockedReason] or "OTHER")], playerName, subReason1, subReason2);
			else
				returnVal = format(_G["INSTANCE_UNAVAILABLE_"..who..(LFG_INSTANCE_INVALID_CODES[lockedReason] or "OTHER")], playerName, subReason1, subReason2);
			end
		end
	end
	if ( hasTimeRestriction ) then
		--Since time applies for all players, no reason to display it once for each.
		--We may have to change this if we let players group with their past selves via time travel.
		return INSTANCE_UNAVAILABLE_OTHER_TOO_SOON;	
	end
	return returnVal;
end

--Ready popup functions

function LFGDungeonReadyPopup_OnFail()
	PlaySound("LFG_Denied");
	if ( LFGDungeonReadyDialog:IsShown() ) then
		LFGDebug("Proposal Hidden: Proposal failed.");
		StaticPopupSpecial_Hide(LFGDungeonReadyPopup);
	elseif ( LFGDungeonReadyPopup:IsShown() ) then
		LFGDungeonReadyPopup.closeIn = LFD_PROPOSAL_FAILED_CLOSE_TIME;
		LFGDungeonReadyPopup:SetScript("OnUpdate", LFGDungeonReadyPopup_OnUpdate);
	end
end

function LFGDungeonReadyPopup_OnUpdate(self, elapsed)
	self.closeIn = self.closeIn - elapsed;
	if ( self.closeIn < 0 ) then	--We remove the OnUpdate and closeIn OnHide
		LFGDebug("Proposal Hidden: Failure close timer expired.");
		StaticPopupSpecial_Hide(LFGDungeonReadyPopup);
	end
end

local DUNGEON_BACKDROP_TABLE = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 }};
	
local RAID_BACKDROP_TABLE = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 }};

function LFGDungeonReadyPopup_Update()	
	local proposalExists, id, typeID, subtypeID, name, texture, role, hasResponded, totalEncounters, completedEncounters, numMembers, isLeader = GetLFGProposal();
	if ( not proposalExists ) then
		LFGDebug("Proposal Hidden: No proposal exists.");
		StaticPopupSpecial_Hide(LFGDungeonReadyPopup);
		return;
	end
	
	LFGDungeonReadyPopup.dungeonID = id;
	
	if ( subtypeID == LFG_SUBTYPEID_RAID ) then
		LFGDungeonReadyDialog.enterButton:SetText(ENTER_RAID);
	elseif ( subtypeID == LFG_SUBTYPEID_SCENARIO ) then
		LFGDungeonReadyDialog.enterButton:SetText(ENTER_SCENARIO);
	else
		LFGDungeonReadyDialog.enterButton:SetText(ENTER_DUNGEON);
	end

	if ( hasResponded ) then
		if ( subtypeID == LFG_SUBTYPEID_RAID ) then
			LFGDungeonReadyStatus:Show();
			LFGDungeonReadyStatusIndividual:Hide();
			LFGDungeonReadyStatusRoleless:Hide();
			LFGDungeonReadyStatusGrouped:Show();
			LFGDungeonReadyDialog:Hide();
			
			LFGDungeonReadyStatusGrouped_UpdateIcon(LFGDungeonReadyStatusGroupedTank, "TANK", numMembers);
			LFGDungeonReadyStatusGrouped_UpdateIcon(LFGDungeonReadyStatusGroupedHealer, "HEALER", numMembers);
			LFGDungeonReadyStatusGrouped_UpdateIcon(LFGDungeonReadyStatusGroupedDamager, "DAMAGER", numMembers);
			
			if ( not LFGDungeonReadyPopup:IsShown() or StaticPopup_IsLastDisplayedFrame(LFGDungeonReadyPopup) ) then
				LFGDungeonReadyPopup:SetHeight(LFGDungeonReadyStatus:GetHeight());
			end
		elseif ( subtypeID == LFG_SUBTYPEID_SCENARIO ) then
			LFGDungeonReadyDialog:Hide();
			-- there may be solo scenarios
			if ( numMembers > 1 ) then
				LFGDungeonReadyStatus:Show();
				LFGDungeonReadyStatusIndividual:Hide();
				LFGDungeonReadyStatusGrouped:Hide();
				LFGDungeonReadyStatusRoleless:Show();
				LFGDungeonReadyStatusRoleless_UpdateCount(LFGDungeonReadyStatusRoleless.ready, numMembers);
			else
				LFGDungeonReadyStatus:Hide();
			end
		else
			LFGDungeonReadyStatus:Show();
			LFGDungeonReadyStatusGrouped:Hide();
			LFGDungeonReadyStatusRoleless:Hide();
			LFGDungeonReadyStatusIndividual:Show();
			LFGDungeonReadyDialog:Hide();
			
			for i=1, numMembers do
				LFGDungeonReadyStatusIndividual_UpdateIcon(_G["LFGDungeonReadyStatusIndividualPlayer"..i]);
			end
			for i=numMembers+1, NUM_LFD_MEMBERS do
				_G["LFGDungeonReadyStatusIndividualPlayer"..i]:Hide();
			end
		
			if ( not LFGDungeonReadyPopup:IsShown() or StaticPopup_IsLastDisplayedFrame(LFGDungeonReadyPopup) ) then
				LFGDungeonReadyPopup:SetHeight(LFGDungeonReadyStatus:GetHeight());
			end
		end
	else
		LFGDungeonReadyDialog:Show();
		LFGDungeonReadyStatus:Hide();
	
		local LFGDungeonReadyDialog = LFGDungeonReadyDialog; --Make a local copy.
		
		-- there's almost no difference between specific and random scenario display
		if ( typeID == TYPEID_RANDOM_DUNGEON and subtypeID ~= LFG_SUBTYPEID_SCENARIO ) then
			LFGDungeonReadyDialog.background:SetDrawLayer("BACKGROUND");
			LFGDungeonReadyDialog.background:SetWidth(294);
			LFGDungeonReadyDialog.instanceInfo.underline:Show();
		
			LFGDungeonReadyDialog.background:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON");
			
			LFGDungeonReadyDialog.label:SetText(RANDOM_DUNGEON_IS_READY);
			
			LFGDungeonReadyDialog.instanceInfo:Hide();
			
			if ( completedEncounters > 0 ) then
				LFGDungeonReadyDialog.randomInProgress:Show();
				LFGDungeonReadyPopup:SetHeight(223);
				LFGDungeonReadyDialog.background:SetTexCoord(0, 1, 0, 1);
			else
				LFGDungeonReadyDialog.randomInProgress:Hide();
				LFGDungeonReadyPopup:SetHeight(193);
				LFGDungeonReadyDialog.background:SetTexCoord(0, 1, 0, 118/128);
			end
		else
			LFGDungeonReadyDialog.randomInProgress:Hide();
			LFGDungeonReadyPopup:SetHeight(223);
			LFGDungeonReadyDialog.background:SetTexCoord(0, 1, 0, 1);
			if ( subtypeID == LFG_SUBTYPEID_SCENARIO ) then
				texture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-RandomScenario";
				LFGDungeonReadyDialog.background:SetDrawLayer("BORDER");
				LFGDungeonReadyDialog.background:SetWidth(290);
				LFGDungeonReadyDialog.instanceInfo.underline:Hide();
				-- change name for random
				if ( typeID == TYPEID_RANDOM_DUNGEON ) then
					name = RANDOM_SCENARIO;
				end
			else
				texture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-"..texture;
				LFGDungeonReadyDialog.background:SetDrawLayer("BACKGROUND");
				LFGDungeonReadyDialog.background:SetWidth(294);
				LFGDungeonReadyDialog.instanceInfo.underline:Show();
			end
			if ( not LFGDungeonReadyDialog.background:SetTexture(texture) ) then	--We haven't added this texture yet. Default to the Deadmines.
				LFGDungeonReadyDialog.background:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-Deadmines");	--DEBUG FIXME Default probably shouldn't be Deadmines
			end
			
			LFGDungeonReadyDialog.label:SetText(SPECIFIC_DUNGEON_IS_READY);
			LFGDungeonReadyDialog_UpdateInstanceInfo(name, completedEncounters, totalEncounters);
			LFGDungeonReadyDialog.instanceInfo:Show();
		end

		local showRole = true;	-- scenarios will set this to false
		if ( subtypeID == LFG_SUBTYPEID_RAID ) then
			LFGDungeonReadyDialog.filigree:SetTexture("Interface\\LFGFrame\\LFR-Texture");
			LFGDungeonReadyDialog.filigree:SetTexCoord(0.00195313, 0.57617188, 0.58593750, 0.78125000);
			LFGDungeonReadyDialog.filigree:SetSize(294, 50);
			LFGDungeonReadyDialog.filigree:SetPoint("TOPLEFT", 7, -8);
			LFGDungeonReadyDialog.bottomArt:SetTexture("Interface\\LFGFrame\\LFR-Texture");
			LFGDungeonReadyDialog.bottomArt:SetTexCoord(0.00195313, 0.55273438, 0.29296875, 0.57812500);
			LFGDungeonReadyDialog.bottomArt:SetSize(282, 73);
			LFGDungeonReadyDialog:SetBackdrop(RAID_BACKDROP_TABLE);
		else
			LFGDungeonReadyDialog.filigree:SetTexture("Interface\\LFGFrame\\UI-LFG-FILIGREE");
			LFGDungeonReadyDialog.filigree:SetTexCoord(0.02734, 0.59765, 0.578125, 1.0);
			LFGDungeonReadyDialog.filigree:SetSize(292, 54);
			LFGDungeonReadyDialog.filigree:SetPoint("TOPLEFT", 7, -3);
			LFGDungeonReadyDialog.bottomArt:SetTexture("Interface\\LFGFrame\\UI-LFG-FILIGREE");
			if ( subtypeID == LFG_SUBTYPEID_SCENARIO ) then
				showRole = false;
				LFGDungeonReadyDialog.bottomArt:SetTexCoord(0.0, 0.18, 0.0, 0.5625);
			else
				LFGDungeonReadyDialog.bottomArt:SetTexCoord(0.0, 0.5605, 0.0, 0.5625);
			end
			LFGDungeonReadyDialog.bottomArt:SetSize(287, 72);
			LFGDungeonReadyDialog:SetBackdrop(DUNGEON_BACKDROP_TABLE);
		end

		if ( showRole ) then
			LFGDungeonReadyDialogRoleIcon:Show();
			LFGDungeonReadyDialogYourRoleDescription:Show();
			LFGDungeonReadyDialogRoleLabel:SetText(_G[role]);
			LFGDungeonReadyDialogRoleIconTexture:SetTexCoord(GetTexCoordsForRole(role));
			if ( isLeader ) then
				LFGDungeonReadyDialogRoleIconLeaderIcon:Show();
			else
				LFGDungeonReadyDialogRoleIconLeaderIcon:Hide();
			end
		else
			LFGDungeonReadyDialogRoleIcon:Hide();
			LFGDungeonReadyDialogYourRoleDescription:Hide();
			LFGDungeonReadyDialogRoleLabel:SetText(nil);
			LFGDungeonReadyDialogRoleIconLeaderIcon:Hide();
		end

		LFGDungeonReadyDialog_UpdateRewards(id, role);
		LFGDungeonReadyDialogRewardsFrame:ClearAllPoints();
		if ( subtypeID == LFG_SUBTYPEID_SCENARIO ) then
			LFGDungeonReadyDialogRewardsFrame:SetPoint("BOTTOM", LFGDungeonReadyDialogRoleIcon, "BOTTOM", 0, 15);
		else
			LFGDungeonReadyDialogRewardsFrame:SetPoint("BOTTOMLEFT", LFGDungeonReadyDialogRoleIcon, "BOTTOMRIGHT", 19, 15);
		end
	end
end

function LFGDungeonReadyDialog_UpdateRewards(dungeonID, role)
	local doneToday, moneyBase, moneyVar, experienceBase, experienceVar, numRewards = GetLFGDungeonRewards(dungeonID);
	
	local numRandoms = 4 - GetNumSubgroupMembers();
	local moneyAmount = moneyBase + moneyVar * numRandoms;
	local experienceGained = experienceBase + experienceVar * numRandoms;
	
	local frameID = 1;

	if ( moneyAmount > 0 or experienceGained > 0 ) then --hasMiscReward ) then
		LFGDungeonReadyDialogReward_SetMisc(LFGDungeonReadyDialogRewardsFrameReward1);
		frameID = 2;
	end
	
	if ( moneyAmount == 0 and experienceGained == 0 and numRewards == 0 ) then
		LFGDungeonReadyDialogRewardsFrameLabel:Hide();
	else
		LFGDungeonReadyDialogRewardsFrameLabel:Show();
	end
	
	for i = 1, numRewards do
		local frame = _G["LFGDungeonReadyDialogRewardsFrameReward"..frameID];
		if ( not frame ) then
			frame = CreateFrame("FRAME", "LFGDungeonReadyDialogRewardsFrameReward"..frameID, LFGDungeonReadyDialogRewardsFrame, "LFGDungeonReadyRewardTemplate");
			frame:SetID(frameID);
			LFD_MAX_REWARDS = frameID;
		end
		LFGDungeonReadyDialogReward_SetReward(frame, dungeonID, i, "reward")
		frameID = frameID + 1;
	end
	
	for shortageIndex = 1, LFG_ROLE_NUM_SHORTAGE_TYPES do
		local eligible, forTank, forHealer, forDamage, itemCount = GetLFGRoleShortageRewards(dungeonID, shortageIndex);
		if ( eligible and ((role == "TANK" and forTank) or (role == "HEALER" and forHealer) or (role == "DAMAGER" and forDamage)) ) then
			for rewardIndex=1, itemCount do
				local frame = _G["LFGDungeonReadyDialogRewardsFrameReward"..frameID];
				if ( not frame ) then
					frame = CreateFrame("FRAME", "LFGDungeonReadyDialogRewardsFrameReward"..frameID, LFGDungeonReadyDialogRewardsFrame, "LFGDungeonReadyRewardTemplate");
					frame:SetID(frameID);
					LFD_MAX_REWARDS = frameID;
				end
				LFGDungeonReadyDialogReward_SetReward(frame, dungeonID, rewardIndex, "shortage", shortageIndex);
				frameID = frameID + 1;
			end
		end
	end
	
	--Hide the unused ones
	for i = frameID, LFD_MAX_REWARDS do
		_G["LFGDungeonReadyDialogRewardsFrameReward"..i]:Hide();
	end
	
	local usedButtons= frameID - 1;
	
	if ( usedButtons > 0 ) then
		--Set up positions
		local iconOffset;
		if ( usedButtons > 2 ) then
			iconOffset = -5;
		else
			iconOffset = 0;
		end
		local area = usedButtons * LFGDungeonReadyDialogRewardsFrameReward1:GetWidth() + (usedButtons - 1) * iconOffset;
		
		LFGDungeonReadyDialogRewardsFrameReward1:SetPoint("LEFT", LFGDungeonReadyDialogRewardsFrame, "CENTER", -area/2, 5);
		for i = 2, usedButtons do
			_G["LFGDungeonReadyDialogRewardsFrameReward"..i]:SetPoint("LEFT", "LFGDungeonReadyDialogRewardsFrameReward"..(i - 1), "RIGHT", iconOffset, 0);
		end
	end
end

function LFGDungeonReadyDialogReward_SetMisc(button)
	SetPortraitToTexture(button.texture, "Interface\\Icons\\inv_misc_coin_02");
	button.rewardType = "misc";
	button:Show();
end

function LFGDungeonReadyDialogReward_SetReward(button, dungeonID, rewardIndex, rewardType, rewardArg)
	local name, texturePath, quantity;
	if ( rewardType == "reward" ) then
		name, texturePath, quantity = GetLFGDungeonRewardInfo(dungeonID, rewardIndex);
	elseif ( rewardType == "shortage" ) then
		name, texturePath, quantity = GetLFGDungeonShortageRewardInfo(dungeonID, rewardArg, rewardIndex);
	end
	if ( texturePath ) then	--Otherwise, we may be waiting on the item data to come from the server.
		SetPortraitToTexture(button.texture, texturePath);
	end
	button.rewardType = rewardType;
	button.rewardID = rewardIndex;
	button.rewardArg = rewardArg;
	button:Show();
end
	
function LFGDungeonReadyDialogReward_OnEnter(self, dungeonID)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	if ( self.rewardType == "misc" ) then
		GameTooltip:AddLine(REWARD_ITEMS_ONLY);
		local doneToday, moneyBase, moneyVar, experienceBase, experienceVar, numRewards = GetLFGDungeonRewards(LFGDungeonReadyPopup.dungeonID);
		local numRandoms = 4 - GetNumSubgroupMembers();
		local moneyAmount = moneyBase + moneyVar * numRandoms;
		local experienceGained = experienceBase + experienceVar * numRandoms;
		
		if ( experienceGained > 0 ) then
			GameTooltip:AddLine(string.format(GAIN_EXPERIENCE, experienceGained));
		end
		if ( moneyAmount > 0 ) then
			SetTooltipMoney(GameTooltip, moneyAmount, nil);
		end
	elseif ( self.rewardType == "reward" ) then
		GameTooltip:SetLFGDungeonReward(LFGDungeonReadyPopup.dungeonID, self.rewardID);
	elseif ( self.rewardType == "shortage" ) then
		GameTooltip:SetLFGDungeonShortageReward(LFGDungeonReadyPopup.dungeonID, self.rewardArg, self.rewardID);
	end
	GameTooltip:Show();
end

function LFGDungeonReadyDialog_UpdateInstanceInfo(name, completedEncounters, totalEncounters)
	local instanceInfoFrame = LFGDungeonReadyDialogInstanceInfoFrame;
	instanceInfoFrame.name:SetFontObject(GameFontNormalLarge);
	instanceInfoFrame.name:SetText(name);
	if ( instanceInfoFrame.name:GetStringWidth() + 20 > LFGDungeonReadyDialog:GetWidth() ) then
		instanceInfoFrame.name:SetFontObject(GameFontNormal);
	end
	
	if ( totalEncounters > 0 ) then
		instanceInfoFrame.statusText:SetFormattedText(BOSSES_KILLED, completedEncounters, totalEncounters);
	else
		instanceInfoFrame.statusText:SetText(nil);
	end
end

function LFGDungeonReadyDialogInstanceInfo_OnEnter(self)
	local numBosses = select(9, GetLFGProposal());
	local isHoliday = select(13, GetLFGProposal());
	
	if ( numBosses == 0 or isHoliday) then
		return;
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
	GameTooltip:AddLine(BOSSES)
	for i=1, numBosses do
		local bossName, texture, isKilled = GetLFGProposalEncounter(i);
		if ( isKilled ) then
			GameTooltip:AddDoubleLine(bossName, BOSS_DEAD, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		else
			GameTooltip:AddDoubleLine(bossName, BOSS_ALIVE, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
		end
	end
	GameTooltip:Show();
end

function LFGDungeonReadyStatus_ResetReadyStates()
	for i=1, NUM_LFD_MEMBERS do
		local button = _G["LFGDungeonReadyStatusIndividualPlayer"..i];
		button.readyStatus = "unknown";
	end
end

function LFGDungeonReadyStatusIndividual_UpdateIcon(button)
	local isLeader, role, level, responded, accepted, name, class = GetLFGProposalMember(button:GetID());
	
	button.texture:SetTexCoord(GetTexCoordsForRole(role));
	
	if ( not responded ) then
		button.statusIcon:SetTexture(READY_CHECK_WAITING_TEXTURE);
	elseif ( accepted ) then
		if ( button.readyStatus ~= "accepted" ) then
			button.readyStatus = "accepted";
			PlaySound("LFG_RoleCheck");
		end
		button.statusIcon:SetTexture(READY_CHECK_READY_TEXTURE);
	else
		button.statusIcon:SetTexture(READY_CHECK_NOT_READY_TEXTURE);
	end
	
	button:Show();
end

function LFGDungeonReadyStatusGrouped_UpdateIcon(button, buttonRole, numMembers)
	button.texture:SetTexCoord(GetTexCoordsForRole(buttonRole));
	
	local numTotal, numAccepted = 0, 0;
	local didDecline = false;
	for i=1, numMembers do
		local isLeader, role, level, responded, accepted, name, class = GetLFGProposalMember(i);
		if ( role == buttonRole ) then
			numTotal = numTotal + 1;
			if ( responded ) then
				if ( accepted ) then
					numAccepted = numAccepted + 1;
				else
					didDecline = true;
				end
			end
		end
	end
	
	button.count:SetFormattedText(PLAYERS_FOUND_OUT_OF_MAX, numAccepted, numTotal);
	
	if ( didDecline ) then
		button.statusIcon:SetTexture(READY_CHECK_NOT_READY_TEXTURE);
	elseif ( numAccepted == numTotal ) then
		button.statusIcon:SetTexture(READY_CHECK_READY_TEXTURE);
	else
		button.statusIcon:SetTexture(READY_CHECK_WAITING_TEXTURE);
	end
end

function LFGDungeonReadyStatusRoleless_UpdateCount(readyButton, numMembers)
	local numAccepted = 0;
	for i=1, numMembers do
		local isLeader, role, level, responded, accepted, name, class = GetLFGProposalMember(i);
		if ( responded ) then
			if ( accepted ) then
				numAccepted = numAccepted + 1;
			end
		end
	end
	readyButton.count:SetFormattedText(PLAYERS_FOUND_OUT_OF_MAX, numAccepted, numMembers);
end

-------Utility functions-----------
function LFDGetNumDungeons()
	return #LFDDungeonList;
end

function LFRGetNumDungeons()
	return #LFRRaidList;
end

function ScenariosGetNumDungeons()
	return #ScenariosList;
end

function LFGIsIDHeader(id)
	return id < 0;
end

-------List filtering functions-----------
local hasSetUp = false;
function LFGDungeonList_Setup()
	if ( not hasSetUp ) then
		hasSetUp = true;
		LFGCollapseList = GetLFDChoiceCollapseState(LFGCollapseList);	--We maintain this list in Lua
		LFGEnabledList = GetLFDChoiceEnabledState(LFGEnabledList);	--We maintain this list in Lua
		LFGLockList = GetLFDChoiceLockedState(LFGLockList);
		
		LFDQueueFrame_Update();
		LFRQueueFrame_Update();
		ScenarioQueueFrame_Update();
		return true;
	end
	return false;
end

function LFGQueueFrame_UpdateLFGDungeonList(dungeonList, hiddenByCollapseList, checkedList, filterFunc, filterMaxLevelDiff)
	if ( LFGDungeonList_Setup() ) then
		return;
	end
	
	local enableList = checkedList;
	
	table.wipe(hiddenByCollapseList);
	
	--1. Remove all choices that don't match the filter.
	LFGListFilterChoices(dungeonList, filterFunc, filterMaxLevelDiff);
	
	--2. Remove all headers that have no entries below them.
	LFGListRemoveHeadersWithoutChildren(dungeonList);
	
	--3. Update the enabled state of headers.
	LFGListUpdateHeaderEnabledAndLockedStates(dungeonList, enableList, hiddenByCollapseList);
	
	--4. Move the children of collapsed headers into the hiddenByCollapse list.
	LFGListRemoveCollapsedChildren(dungeonList, hiddenByCollapseList);
end

--filterFunc returns true if the object should be shown.
function LFGListFilterChoices(list, filterFunc, filterMaxLevelDiff)
	local currentPosition = 1;
	while ( currentPosition <= #list ) do
		local id = list[currentPosition];
		local isHeader = LFGIsIDHeader(id);
		if ( isHeader or filterFunc(id, filterMaxLevelDiff) ) then
			currentPosition = currentPosition + 1;
		else
			tremove(list, currentPosition);
		end
	end
end

function LFGListRemoveHeadersWithoutChildren(list)
	--This relies on unparented children coming first.
	local currentPosition = 1;
	--The discrepency between nextObject>IsChild< and >isHeader< is due to the way we want to handle empty values.
	local nextObjectIsChild = not LFGIsIDHeader(list[1] or 0);
	while ( currentPosition <= #list ) do
		local isHeader = not nextObjectIsChild;
		nextObjectIsChild = currentPosition < #list and not LFGIsIDHeader(list[currentPosition+1]);
		if ( isHeader and not nextObjectIsChild ) then
			tremove(list, currentPosition);
		else
			currentPosition = currentPosition + 1;
		end
	end
end

--false = no children so far
--0 = all children unchecked
--1 = some children checked, some unchecked
--2 = all children checked
function LFGListUpdateHeaderEnabledAndLockedStates(dungeonList, enabledList, hiddenByCollapseList)
	for i=1, #dungeonList do
		local id = dungeonList[i];
		if ( LFGIsIDHeader(id) ) then
			enabledList[id] = false;
			LFGLockList[id] = true;
		elseif ( not LFGLockList[id] ) then
			local groupID = select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(id));
			LFGLockList[groupID] = false;
			local idState = enabledList[id];
			local groupState = enabledList[groupID];
			if ( idState ) then
				if ( not groupState or groupState == 2 ) then	--This code handles the 3 states of headers (enabled, disabled, someandsome)
					enabledList[groupID] = 2;
				elseif ( groupState == 0 or groupState == 1 ) then
					enabledList[groupID] = 1;
				end
			else
				if ( not groupState or groupState == 0 ) then
					enabledList[groupID] = 0;
				elseif ( groupState == 1 or groupState == 2 ) then
					enabledList[groupID]  = 1;
				end
			end
		end
	end
	for i=1, #hiddenByCollapseList do
		local id = hiddenByCollapseList[i];
		if ( LFGIsIDHeader(id) ) then
			enabledList[id] = false;
			LFGLockList[id] = true;
		elseif ( not LFGLockList[id] ) then
			local groupID = select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(id));
			LFGLockList[groupID] = false;
			local idState = enabledList[id];
			local groupState = enabledList[groupID];
			if ( idState ) then
				if ( not groupState or groupState == 2 ) then
					enabledList[groupID] = 2;
				elseif ( groupState == 0 or groupState == 1 ) then
					enabledList[groupID] = 1;
				end
			else
				if ( not groupState or groupState == 0 ) then
					enabledList[groupID] = 0;
				elseif ( groupState == 1 or groupState == 2 ) then
					enabledList[groupID]  = 1;
				end
			end
		end
	end
end

function LFGListRemoveCollapsedChildren(list, hiddenByCollapseList)
	local currentPosition = 1;
	while ( currentPosition <= #list ) do
		local id = list[currentPosition];
		if ( not LFGIsIDHeader(id) and LFGCollapseList[id] ) then
			tinsert(hiddenByCollapseList, tremove(list, currentPosition));
		else
			currentPosition = currentPosition + 1;
		end
	end
end


--Reward frame functions
function LFGRewardsFrame_UpdateFrame(parentFrame, dungeonID, background, isScenario)
	local parentName = parentFrame:GetName();
	
	if ( not dungeonID ) then
		parentFrame:Hide();
		return;
	end

	parentFrame:Show();
	
	local difficulty;
	local dungeonDescription;
	local textureFilename;
	local dungeonName, typeID, subtypeID,_,_,_,_,_,_,_,textureFilename,difficulty,_,dungeonDescription, isHoliday = GetLFGDungeonInfo(dungeonID);
	local isHeroic = difficulty > 0;
	local doneToday, moneyBase, moneyVar, experienceBase, experienceVar, numRewards = GetLFGDungeonRewards(dungeonID);
	local numRandoms = 4 - GetNumSubgroupMembers();
	local moneyAmount = moneyBase + moneyVar * numRandoms;
	local experienceGained = experienceBase + experienceVar * numRandoms;

	
	local backgroundTexture;
	
	local leaderChecked, tankChecked, healerChecked, damageChecked = LFDQueueFrame_GetRoles();
	
	--HACK
	if ( not isScenario ) then
		if ( dungeonID == 341 ) then	--Trollpocalypse Heroic
			backgroundTexture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-TROLLPOCALYPSE";
		elseif ( dungeonID == 434 ) then	--Hour of Twilight Heroic
			backgroundTexture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-HourofTwilightQ";
		elseif ( textureFilename ~= "" ) then
			if ( subtypeID == LFG_SUBTYPEID_RAID ) then
				backgroundTexture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-"..textureFilename.."Q";
			else
				backgroundTexture = "Interface\\LFGFrame\\UI-LFG-HOLIDAY-BACKGROUND-"..textureFilename;
			end
		elseif ( isHeroic ) then
			backgroundTexture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-HEROIC";
		else
			backgroundTexture = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-QUESTPAPER";
		end
		background:SetTexture(backgroundTexture);
	end

	local lastFrame = parentFrame.rewardsLabel;
	if ( isHoliday ) then
		if ( doneToday ) then
			parentFrame.rewardsDescription:SetText(LFD_HOLIDAY_REWARD_EXPLANATION2);
		else
			parentFrame.rewardsDescription:SetText(LFD_HOLIDAY_REWARD_EXPLANATION1);
		end
		parentFrame.title:SetText(dungeonName);
		parentFrame.description:SetText(dungeonDescription);
	elseif ( subtypeID == LFG_SUBTYPEID_RAID ) then
		if ( doneToday ) then --May not actually be today, but whatever this reset period is.
			parentFrame.rewardsDescription:SetText(RF_REWARD_EXPLANATION2);
		else
			parentFrame.rewardsDescription:SetText(RF_REWARD_EXPLANATION1);
		end
		parentFrame.title:SetText(dungeonName);
		parentFrame.description:SetText(dungeonDescription);
	else
		local numCompletions, isWeekly = LFGRewardsFrame_EstimateRemainingCompletions(dungeonID);
		if ( numCompletions <= 0 ) then
			parentFrame.rewardsDescription:SetText(LFD_RANDOM_REWARD_EXPLANATION2);
		elseif ( isWeekly ) then
			parentFrame.rewardsDescription:SetText(format(LFD_REWARD_DESCRIPTION_WEEKLY, numCompletions));
		else
			parentFrame.rewardsDescription:SetText(format(LFD_REWARD_DESCRIPTION_DAILY, numCompletions));
		end
		if ( not isScenario ) then
			parentFrame.title:SetText(LFG_TYPE_RANDOM_DUNGEON);
			parentFrame.description:SetText(LFD_RANDOM_EXPLANATION);
		end
	end
		
	local itemButtonIndex = 1;
	for i=1, numRewards do
		local name, texture, numItems = GetLFGDungeonRewardInfo(dungeonID, i);
		lastFrame = LFGRewardsFrame_SetItemButton(parentFrame, dungeonID, itemButtonIndex, i, name, texture, numItems, nil);
		itemButtonIndex = itemButtonIndex + 1;
	end
	
	for shortageIndex=1, LFG_ROLE_NUM_SHORTAGE_TYPES do
		local eligible, forTank, forHealer, forDamage, itemCount = GetLFGRoleShortageRewards(dungeonID, shortageIndex);
		if ( eligible and ((tankChecked and forTank) or (healerChecked and forHealer) or (damageChecked and forDamage)) ) then
			for rewardIndex=1, itemCount do
				local name, texture, numItems = GetLFGDungeonShortageRewardInfo(dungeonID, shortageIndex, rewardIndex);
				lastFrame = LFGRewardsFrame_SetItemButton(parentFrame, dungeonID, itemButtonIndex, rewardIndex, name, texture, numItems, shortageIndex, forTank, forHealer, forDamage);
				itemButtonIndex = itemButtonIndex + 1;
			end
		end
	end
	
	for i=itemButtonIndex, parentFrame.numRewardFrames do
		_G[parentName.."Item"..i]:Hide();
	end
	
	local totalRewards = itemButtonIndex - 1;
		
	if ( totalRewards > 0 or ((moneyVar == 0 and experienceVar == 0) and (moneyAmount > 0 or experienceGained > 0)) ) then
		parentFrame.rewardsLabel:Show();
		parentFrame.rewardsDescription:Show();
		lastFrame = parentFrame.rewardsDescription;
	else
		parentFrame.rewardsLabel:Hide();
		parentFrame.rewardsDescription:Hide();
	end
	
	if ( totalRewards > 0 ) then
		lastFrame = _G[parentName.."Item"..(totalRewards - mod(totalRewards+1, 2))];
	end
	
	if ( moneyVar > 0 or experienceVar > 0 ) then
		parentFrame.pugDescription:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -5);
		parentFrame.pugDescription:Show();
		lastFrame = parentFrame.pugDescription;
	else
		parentFrame.pugDescription:Hide();
	end
	
	if ( moneyAmount > 0 ) then
		MoneyFrame_Update(parentFrame.moneyFrame, moneyAmount);
		parentFrame.moneyLabel:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 20, -10);
		parentFrame.moneyLabel:Show();
		parentFrame.moneyFrame:Show()
		
		parentFrame.xpLabel:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -5);
		
		lastFrame = parentFrame.moneyLabel;
	else
		parentFrame.moneyLabel:Hide();
		parentFrame.moneyFrame:Hide();
		
	end
	
	if ( experienceGained > 0 ) then
		parentFrame.xpAmount:SetText(experienceGained);
		
		if ( lastFrame == parentFrame.moneyLabel ) then
			parentFrame.xpLabel:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -5);
		else
			parentFrame.xpLabel:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 20, -10);
		end
		parentFrame.xpLabel:Show();
		parentFrame.xpAmount:Show();
		
		lastFrame = parentFrame.xpLabel;
	else
		parentFrame.xpLabel:Hide();
		parentFrame.xpAmount:Hide();
	end
	
	if ( typeID == TYPEID_RANDOM_DUNGEON ) then
		parentFrame.randomList:Show();
		parentFrame.encounterList:SetPoint("LEFT", parentFrame.randomList, "RIGHT", 5, 0);
	else
		parentFrame.randomList:Hide();
		parentFrame.encounterList:SetPoint("LEFT", parentFrame.randomList, "LEFT", 0, 0);
	end

	parentFrame.encounterList.dungeonID = dungeonID;
	local numEncounters, numCompleted = GetLFGDungeonNumEncounters(dungeonID);
	if ( numCompleted > 0 ) then
		parentFrame.encounterList:Show();
	else
		parentFrame.encounterList:Hide();
	end
	
	parentFrame.spacer:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -10);
end

function LFGRewardsFrame_SetItemButton(parentFrame, dungeonID, index, id, name, texture, numItems, shortageIndex, showTankIcon, showHealerIcon, showDamageIcon)
	local parentName = parentFrame:GetName();
	local frame = _G[parentName.."Item"..index];
	if ( not frame ) then
		frame = CreateFrame("Button", parentName.."Item"..index, _G[parentName], "LFGRewardsLootTemplate");
		parentFrame.numRewardFrames = index;
		if ( mod(index, 2) == 0 ) then
			frame:SetPoint("LEFT", parentName.."Item"..(index-1), "RIGHT", 0, 0);
		else
			frame:SetPoint("TOPLEFT", parentName.."Item"..(index-2), "BOTTOMLEFT", 0, -5);
		end
	end
	frame:SetID(id);
	
	_G[parentName.."Item"..index.."Name"]:SetText(name);
	SetItemButtonTexture(frame, texture);
	SetItemButtonCount(frame, numItems);
	frame.shortageIndex = shortageIndex;
	frame.dungeonID = dungeonID;
	
	if ( shortageIndex ) then
		frame.shortageBorder:Show();
	else
		frame.shortageBorder:Hide();
	end
	
	local numRoles = (showTankIcon and 1 or 0) + (showHealerIcon and 1 or 0) + (showDamageIcon and 1 or 0);
	
	--Show role icons if this reward is specific to a role:
	frame.roleIcon1:Hide();
	frame.roleIcon2:Hide();
	
	if ( numRoles > 0 and numRoles < 3 ) then	--If we give it to all 3 roles, no reason to show icons.
		local roleIcon = frame.roleIcon1;
		if ( showTankIcon ) then
			roleIcon.texture:SetTexCoord(GetTexCoordsForRoleSmallCircle("TANK"));
			roleIcon.role = "TANK";
			roleIcon:Show();
			roleIcon = frame.roleIcon2;
		end
		if ( showHealerIcon ) then
			roleIcon.texture:SetTexCoord(GetTexCoordsForRoleSmallCircle("HEALER"));
			roleIcon.role = "HEALER";
			roleIcon:Show();
			roleIcon = frame.roleIcon2;
		end
		if ( showDamageIcon ) then
			roleIcon.texture:SetTexCoord(GetTexCoordsForRoleSmallCircle("DAMAGER"));
			roleIcon.role = "DAMAGER";
			roleIcon:Show();
			roleIcon = frame.roleIcon2;
		end
		
		if ( numRoles == 2 ) then
			frame.roleIcon1:SetPoint("LEFT", frame, "TOPLEFT", 1, -2);
		else
			frame.roleIcon1:SetPoint("LEFT", frame, "TOPLEFT", 10, -2);
		end
	end
	
	frame:Show();
	return frame;
end

function LFGRewardsFrame_EstimateRemainingCompletions(dungeonID)
	local currencyID, currencyQuantity, specificQuantity, specificLimit, overallQuantity, overallLimit, periodPurseQuantity, periodPurseLimit, purseQuantity, purseLimit, isWeekly = GetLFGDungeonRewardCapInfo(dungeonID);
	if(not currencyID) then
		return 0, false;
	end

	local remainingAllotment = min(specificLimit - specificQuantity, overallLimit - overallQuantity);
	if ( periodPurseLimit ~= 0 ) then
		remainingAllotment = min(remainingAllotment, periodPurseLimit - periodPurseQuantity);
	end

	if (currencyQuantity == 0) then
		return 0, isWeekly;
	end

	return ceil(remainingAllotment / currencyQuantity), isWeekly;
end

function LFGRewardsFrameEncounterList_OnEnter(self)
	local dungeonID = self.dungeonID;
	local numEncounters, numCompleted = GetLFGDungeonNumEncounters(dungeonID);

	if ( numCompleted > 0 ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(ERR_LOOT_GONE);
		for i=1, numEncounters do
			local bossName, texture, isKilled = GetLFGDungeonEncounterInfo(dungeonID, i);
			if ( isKilled ) then
				GameTooltip:AddLine(bossName, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
			end
		end
		GameTooltip:Show();
	end
end

--
-- LFR/LFD group invite stuff
--
function LFGInvitePopup_UpdateAcceptButton()
	if ( LFGInvitePopupRoleButtonTank.checkButton:GetChecked() or LFGInvitePopupRoleButtonHealer.checkButton:GetChecked() or LFGInvitePopupRoleButtonDPS.checkButton:GetChecked() ) then
		LFGInvitePopupAcceptButton:Enable();
	else
		LFGInvitePopupAcceptButton:Disable();
	end
end

function LFGInvitePopupAccept_OnClick()
	AcceptGroup(LFGInvitePopupRoleButtonTank.checkButton:GetChecked(), LFGInvitePopupRoleButtonHealer.checkButton:GetChecked(), LFGInvitePopupRoleButtonDPS.checkButton:GetChecked());
	StaticPopupSpecial_Hide(LFGInvitePopup);
end

function LFGInvitePopupDecline_OnClick()
	DeclineGroup();
	StaticPopupSpecial_Hide(LFGInvitePopup);
end

function LFGInvitePopup_Update(inviter, roleTankAvailable, roleHealerAvailable, roleDamagerAvailable)
	local self = LFGInvitePopup;
	local canBeTank, canBeHealer, canBeDamager = UnitGetAvailableRoles("player");
	local tankButton = LFGInvitePopupRoleButtonTank;
	local healerButton = LFGInvitePopupRoleButtonHealer;
	local damagerButton = LFGInvitePopupRoleButtonDPS;
	local availableRolesField = 0;	--Seems to be a ghetto bit-field
	self.timeOut = STATICPOPUP_TIMEOUT;
	LFGInvitePopupText:SetFormattedText(INVITATION, inviter);
	-- tank
	if ( not canBeTank ) then
		LFG_PermanentlyDisableRoleButton(tankButton);
	elseif ( not roleTankAvailable ) then
		LFG_DisableRoleButton(tankButton);
		tankButton.disabledTooltip = LFG_ROLE_UNAVAILABLE;
	else
		LFG_EnableRoleButton(tankButton);
		tankButton.disabledTooltip = nil;
		availableRolesField = availableRolesField + 2;
	end
	-- healer
	if ( not canBeHealer ) then
		LFG_PermanentlyDisableRoleButton(healerButton);
	elseif ( not roleHealerAvailable ) then
		LFG_DisableRoleButton(healerButton);
		healerButton.disabledTooltip = LFG_ROLE_UNAVAILABLE;
	else
		LFG_EnableRoleButton(healerButton);
		healerButton.disabledTooltip = nil;
		availableRolesField = availableRolesField + 4;
	end
	-- damage
	if ( not canBeDamager ) then
		LFG_PermanentlyDisableRoleButton(damagerButton);
	elseif ( not roleDamagerAvailable ) then
		LFG_DisableRoleButton(damagerButton);
		damagerButton.disabledTooltip = LFG_ROLE_UNAVAILABLE;
	else
		LFG_EnableRoleButton(damagerButton);
		damagerButton.disabledTooltip = nil;
		availableRolesField = availableRolesField + 8;
	end	
	-- if only 1 role is available, check it otherwise check none
	tankButton.checkButton:SetChecked(availableRolesField == 2);
	healerButton.checkButton:SetChecked(availableRolesField == 4);
	damagerButton.checkButton:SetChecked(availableRolesField == 8);

	LFGInvitePopup_UpdateAcceptButton();
end

function LFGInvitePopup_OnUpdate(self, elapsed)
	self.timeOut = self.timeOut - elapsed;
	if ( self.timeOut <= 0 ) then
		LFGInvitePopupDecline_OnClick();
	end
end

function LFGDungeonList_EvaluateListState(category)
	local mode, subMode = GetLFGMode(category);
	local enabled, queued;
	if ( mode == "rolecheck" or mode == "queued" or mode == "listed" or mode == "suspended" or not LFD_IsEmpowered() ) then
		enabled = false;
	else
		enabled = true;
	end
	if ( mode == "queued" or mode == "listed" or mode == "suspended" ) then
		queued = true;
	else
		queued = false;
	end
	return enabled, queued;
end

function LFGDungeonListButton_SetDungeon(button, dungeonID, enabled, checkedList)
	local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday = GetLFGDungeonInfo(dungeonID);
	button.id = dungeonID;
	if ( LFGIsIDHeader(dungeonID) ) then
		button.instanceName:SetText(name);
		button.instanceName:SetFontObject(QuestDifficulty_Header);
		button.instanceName:SetPoint("RIGHT", button, "RIGHT", 0, 0);
		button.level:Hide();

		if ( subtypeID == LFG_SUBTYPEID_HEROIC ) then
			button.heroicIcon:Show();
			button.instanceName:SetPoint("LEFT", button.heroicIcon, "RIGHT", 0, 1);
		else
			button.heroicIcon:Hide();
			button.instanceName:SetPoint("LEFT", 40, 0);
		end

		button.expandOrCollapseButton:Show();
		local isCollapsed = LFGCollapseList[dungeonID];
		button.isCollapsed = isCollapsed;
		if ( isCollapsed ) then
			button.expandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP");
		else
			button.expandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP");
		end
	else
		button.instanceName:SetText(name);
		button.instanceName:SetPoint("RIGHT", button.level, "LEFT", -10, 0);

		button.heroicIcon:Hide();
		button.instanceName:SetPoint("LEFT", 40, 0);

		if ( minLevel == maxLevel ) then
			button.level:SetText(format(LFD_LEVEL_FORMAT_SINGLE, minLevel));
		else
			button.level:SetText(format(LFD_LEVEL_FORMAT_RANGE, minLevel, maxLevel));
		end
		button.level:Show();
		local difficultyColor = GetQuestDifficultyColor(recLevel);
		button.level:SetFontObject(difficultyColor.font);
		
		if ( enabled ) then
			button.instanceName:SetFontObject(difficultyColor.font);
		else
			button.instanceName:SetFontObject(QuestDifficulty_Header);
		end

		button.expandOrCollapseButton:Hide();
		button.isCollapsed = false;
	end

	if ( LFGLockList[dungeonID] ) then
		button.enableButton:Hide();
		button.lockedIndicator:Show();
	else
		button.enableButton:Show();
		button.lockedIndicator:Hide();
	end

	local enableState = checkedList[dungeonID];
	
	if ( enableState == 1 ) then	--Some are checked, some aren't.
		button.enableButton:SetCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Up");
		button.enableButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Disabled");
	else
		button.enableButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
		button.enableButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
	end
	button.enableButton:SetChecked(enableState and enableState ~= 0);

	if ( enabled ) then
		button.enableButton:Enable();
	else
		button.enableButton:Disable();
	end
end

function LFGList_DefaultFilterFunction(dungeonID, maxLevelDiff)
	local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday = GetLFGDungeonInfo(dungeonID);
	local level = UnitLevel("player");

	--Check whether we're initialized yet
	if ( not LFGLockList ) then
		return false;
	end

	--If the server tells us we can join, we won't argue
	if ( not LFGLockList[dungeonID] ) then
		return true;
	end

	--If this doesn't have a header, we won't display it
	if ( groupID == 0 ) then
		return false;
	end

	--If we don't have the right expansion, we won't display it
	if ( EXPANSION_LEVEL < expansionLevel ) then
		return false;
	end

	--If we're too high above the recommended level, we won't display it
	if ( level - maxLevelDiff > recLevel ) then
		return false;
	end

	-- If we're not within the hard level requirements, we won't display it
	if ( level < minLevel or level > maxLevel ) then
		return false;
	end

	--If we're the wrong faction, we won't display it.
	if ( LFGLockList[dungeonID] == LFG_INSTANCE_INVALID_WRONG_FACTION ) then
		return false;
	end

	return true;
end

function LFG_QueueForInstanceIfEnabled(category, queueID)
	if ( not LFGIsIDHeader(queueID) and LFGEnabledList[queueID] and not LFGLockList[queueID] ) then
		SetLFGDungeon(category, queueID);
		return true;
	end
	return false;
end

function LFG_JoinDungeon(category, joinType, dungeonList, hiddenByCollapseList)
	if ( joinType == "specific" ) then	--Random queue
		ClearAllLFGDungeons(category);
		for _, queueID in pairs(dungeonList) do
			LFG_QueueForInstanceIfEnabled(category, queueID);
		end
		for _, queueID in pairs(hiddenByCollapseList) do
			LFG_QueueForInstanceIfEnabled(category, queueID);
		end
		JoinLFG(category);
	elseif ( joinType ) then
		ClearAllLFGDungeons(category);
		SetLFGDungeon(category, joinType);
		JoinLFG(category);
	end
end

function LFGDungeonList_SetHeaderCollapsed(button, dungeonList, hiddenByCollapseList)
	local headerID = button.id;
	local isCollapsed = not button.isCollapsed;
	SetLFGHeaderCollapsed(headerID, isCollapsed);
	LFGCollapseList[headerID] = isCollapsed;
	for _, dungeonID in pairs(dungeonList) do
		if ( select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(dungeonID)) == headerID ) then
			LFGCollapseList[dungeonID] = isCollapsed;
		end
	end
	for _, dungeonID in pairs(hiddenByCollapseList) do
		if ( select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(dungeonID)) == headerID ) then
			LFGCollapseList[dungeonID] = isCollapsed;
		end
	end
end

function LFGDungeonList_SetDungeonEnabled(dungeonID, isEnabled)
	SetLFGDungeonEnabled(dungeonID, isEnabled);
	LFGEnabledList[dungeonID] = not not isEnabled; --Change to true/false.
end

function LFGDungeonList_SetHeaderEnabled(category, headerID, isEnabled, dungeonList, hiddenByCollapseList)
	for _, dungeonID in pairs(dungeonList) do
		if ( select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(dungeonID)) == headerID ) then
			LFGDungeonList_SetDungeonEnabled(dungeonID, isEnabled);
		end
	end
	for _, dungeonID in pairs(hiddenByCollapseList) do
		if ( select(LFG_RETURN_VALUES.groupID, GetLFGDungeonInfo(dungeonID)) == headerID ) then
			LFGDungeonList_SetDungeonEnabled(dungeonID, isEnabled);
		end
	end
	LFGEnabledList[headerID] = not not isEnabled; --Change to true/false.
end

function LFGDungeonListButton_OnEnter(button, tooltipTitle)
	local dungeonID = button.id;
	if ( button.lockedIndicator:IsShown() ) then
		if ( LFGIsIDHeader(dungeonID) ) then
			--GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
			--GameTooltip:AddLine(YOU_MAY_NOT_QUEUE_FOR_CATEGORY, 1.0, 1.0, 1.0);
			--GameTooltip:Show();
		else
			GameTooltip:SetOwner(button, "ANCHOR_TOP");
			GameTooltip:AddLine(tooltipTitle, 1.0, 1.0, 1.0);
			for i=1, GetLFDLockPlayerCount() do
				local playerName, lockedReason, subReason1, subReason2 = GetLFDLockInfo(dungeonID, i);
				if ( lockedReason ~= 0 ) then
					local who;
					if ( i == 1 ) then
						who = "SELF_";
					else
						who = "OTHER_";
					end
					GameTooltip:AddLine(format(_G["INSTANCE_UNAVAILABLE_"..who..(LFG_INSTANCE_INVALID_CODES[lockedReason] or "OTHER")], playerName, subReason1, subReason2));
				end
			end
			GameTooltip:Show();
		end
	end
end

function LFGDungeonListCheckButton_OnClick(button, category, dungeonList, hiddenByCollapseList)
	local parent = button:GetParent();
	local dungeonID = parent.id;
	local isChecked = button:GetChecked();

	PlaySound(isChecked and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOff");
	if ( LFGIsIDHeader(dungeonID) ) then
		LFGDungeonList_SetHeaderEnabled(category, dungeonID, isChecked, dungeonList, hiddenByCollapseList);
	else
		LFGDungeonList_SetDungeonEnabled(dungeonID, isChecked);
		LFGListUpdateHeaderEnabledAndLockedStates(dungeonList, LFGEnabledList, hiddenByCollapseList);
	end
end

function LFG_IsRandomDungeonDisplayable(id)
	local name, typeID, subtypeID, minLevel, maxLevel, _, _, _, expansionLevel = GetLFGDungeonInfo(id);
	local myLevel = UnitLevel("player");
	return myLevel >= minLevel and myLevel <= maxLevel and EXPANSION_LEVEL >= expansionLevel;
end

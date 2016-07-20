
MAX_TALENT_GROUPS = 2;
MAX_TALENT_TABS = 4;
MAX_TALENT_TIERS = 7;
NUM_TALENT_COLUMNS = 3;

MAX_PVP_TALENT_TIERS = 6;
MAX_PVP_TALENT_COLUMNS = 3;

DEFAULT_TALENT_SPEC = "spec1";
DEFAULT_TALENT_TAB = 1;

local min = min;
local max = max;
local huge = math.huge;
local rshift = bit.rshift;

function TalentFrame_Load(TalentFrame)

end

function TalentFrame_Clear(TalentFrame)
	if ( not TalentFrame ) then
		return;
	end

	for tier=1, 6 do
		for column=1, 3 do
			local button = TalentFrame["tier"..tier]["talent"..column];
			if(button ~= nil) then
				SetDesaturation(button.icon, true);
				button.border:Hide();
			end
		end
	end
end

function TalentFrame_Update(TalentFrame, talentUnit)
	if ( not TalentFrame ) then
		return;
	end
	-- have to disable stuff if not active talent group
	local disable;
	if ( TalentFrame.inspect ) then
		-- even though we have inspection data for more than one talent group, we're only showing one for now
		disable = false;
	else
		disable = ( TalentFrame.talentGroup ~= GetActiveSpecGroup(TalentFrame.inspect) );
	end
	if(TalentFrame.bg ~= nil) then
		TalentFrame.bg:SetDesaturated(disable);
	end
	
	for tier=1, MAX_TALENT_TIERS do
		local talentRow = TalentFrame["tier"..tier];
		local rowAvailable = true;
		
		local tierAvailable, selectedTalent = GetTalentTierInfo(tier, TalentFrame.talentGroup, TalentFrame.inspect, talentUnit);
		-- Skip updating rows that we recently selected a talent for but have not received a server response
		if (TalentFrame.inspect or not TalentFrame.talentInfo[tier] or
			(selectedTalent ~= 0 and TalentFrame.talentInfo[tier] == selectedTalent)) then
			
			if (not TalentFrame.inspect and selectedTalent ~= 0) then
				TalentFrame.talentInfo[tier] = nil;
			end
			
			local rowShouldGlow = false;
			for column=1, NUM_TALENT_COLUMNS do
				-- Set the button info
				local talentID, name, iconTexture, selected, available = GetTalentInfo(tier, column, TalentFrame.talentGroup, TalentFrame.inspect, talentUnit);
				rowShouldGlow = rowShouldGlow or (available and not selected);
				local button = talentRow["talent"..column];
				button.tier = tier;
				button.column = column;
				
				if (button and name) then
					button:SetID(talentID);

					SetItemButtonTexture(button, iconTexture);
					if(button.name ~= nil) then
						button.name:SetText(name);
					end

					if(button.knownSelection ~= nil) then
						if( selected ) then
							button.knownSelection:Show();
							button.knownSelection:SetDesaturated(disable);
						else
							button.knownSelection:Hide();
						end
					end
					
					if( TalentFrame.inspect ) then
						SetDesaturation(button.icon, not selected);
						button.border:SetShown(selected);
					else
						button.disabled = (not tierAvailable or disable);
						SetDesaturation(button.icon, button.disabled or (selectedTalent ~= 0 and not selected));
						button.Cover:SetShown(button.disabled);
						button.highlight:SetAlpha((selected or not tierAvailable) and 0 or 1);
					end
					
					button:Show();
				elseif (button) then
					button:Hide();
				end
			end
			if ( talentRow.GlowFrame ) then
				if ( rowShouldGlow and talentUnit == "player" ) then
					talentRow.shouldGlow = true;
					talentRow.GlowFrame:Show();
				else
					talentRow.shouldGlow = false;
					talentRow.GlowFrame:Hide();
				end
			end
			-- do tier level number after every row
			if(talentRow.level ~= nil) then
				if ( selectedTalent == 0 and tierAvailable) then
					talentRow.level:SetTextColor(1, 0.82, 0);
				else
					talentRow.level:SetTextColor(0.5, 0.5, 0.5);
				end
			end
		end
	end
	if(TalentFrame.unspentText ~= nil) then
		local numUnspentTalents = GetNumUnspentTalents();
		if ( not disable and numUnspentTalents > 0 ) then
			TalentFrame.unspentText:SetFormattedText(PLAYER_UNSPENT_TALENT_POINTS, numUnspentTalents);
		else
			TalentFrame.unspentText:SetText("");
		end
	end
end


function TalentFrame_UpdateSpecInfoCache(cache, inspect, pet, talentGroup)
	-- initialize some cache info
	cache.primaryTabIndex = 0;

	local numTabs = GetNumSpecializations(inspect);
	cache.numTabs = numTabs;
	local sex = pet and UnitSex("pet") or UnitSex("player");
	for i = 1, MAX_TALENT_TABS do
		cache[i] = cache[i] or { };
		if ( i <= numTabs ) then
			local id, name, description, icon, background = GetSpecializationInfo(i, inspect, nil, nil, sex);

			-- cache the info we care about
			cache[i].name = name;
			cache[i].icon = icon;
		else
			cache[i].name = nil;
		end
	end
end

function PVPTalentFrame_Update(self, talentUnit)
	local parent = self:GetParent();
	local activeTalentGroup = GetActiveSpecGroup(false);
	local factionGroup = UnitFactionGroup("player");
	local prestigeLevel = UnitPrestige("player");

	if ( not self.inspect ) then
		if ( UnitLevel("player") < MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEVEL_CURRENT] ) then
			self.XPBar:Hide();
			self.NotAvailableYet:SetFormattedText(PVP_TALENTS_BECOME_AVAILABLE_AT_LEVEL, 110);
			self.NotAvailableYet:Show();
		else
			self.NotAvailableYet:Hide();
			self.XPBar:Show();
		end
	end

	local numTalentSelections = 0;
	for tier = 1, MAX_PVP_TALENT_TIERS do
		local talentRow = self.Talents["Tier"..tier];
		local isRowFree, prevSelected = GetPvpTalentRowSelectionInfo(tier);

		if ( not self.inspect and prevSelected == self.talentInfo[tier] ) then
			self.talentInfo[tier] = nil;
		end

		local rowShouldGlow = false;
		for column = 1, MAX_PVP_TALENT_COLUMNS do
			local button = talentRow["Talent"..column];
			local id, name, icon, selected, available, _, unlocked = GetPvpTalentInfo(tier, column, self.talentGroup, self.inspect, talentUnit);
			rowShouldGlow = rowShouldGlow or (available and not selected);
			if ( button.Name ) then
				button.Name:SetText(name);
			end
			button.Icon:SetTexture(icon);
			button.pvpTalentID = id;
			if ( self.inspect ) then
				SetDesaturation(button.Icon, not selected);
				button.border:SetShown(selected);
			else
				if ( not unlocked ) then
					PlayerTalentFramePVPTalents_LockButton(button);
				else
					PlayerTalentFramePVPTalents_UnlockButton(button, activeTalentGroup == self.talentGroup);
					if (talentRow.selectionId == id) then
						numTalentSelections = numTalentSelections + 1;
					end

					button.knownSelection:SetShown(self.talentInfo[tier] == id or (selected and not self.talentInfo[tier]));
					if ( selected or self.talentInfo[tier] ) then
						SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HONOR_TALENT_FIRST_TALENT, true);
						PlayerTalentFramePVPTalents.TutorialBox:Hide();
					end
				end
			end
		end
		if ( talentRow.GlowFrame ) then
			if ( rowShouldGlow ) then
				talentRow.shouldGlow = true;
				talentRow.GlowFrame:Show();
			else
				talentRow.shouldGlow = false;
				talentRow.GlowFrame:Hide();
			end
		end
	end

	if ( not self.inspect ) then
		if ( UnitLevel("player") >= MAX_PLAYER_LEVEL_TABLE[LE_EXPANSION_LEVEL_CURRENT] ) then
			if ( not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HONOR_TALENT_FIRST_TALENT) ) then
				PlayerTalentFramePVPTalents_ShowTutorial(LE_FRAME_TUTORIAL_HONOR_TALENT_FIRST_TALENT);
			elseif ( not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HONOR_TALENT_HONOR_LEVELS) ) then
				PlayerTalentFramePVPTalents_ShowTutorial(LE_FRAME_TUTORIAL_HONOR_TALENT_HONOR_LEVELS);
			elseif ( not GetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_HONOR_TALENT_PRESTIGE) and CanPrestige() ) then
				PlayerTalentFramePVPTalents_ShowTutorial(LE_FRAME_TUTORIAL_HONOR_TALENT_PRESTIGE);
			end
		end
	end
end
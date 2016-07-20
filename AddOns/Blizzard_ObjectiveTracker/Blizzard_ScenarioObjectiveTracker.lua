
SCENARIO_CONTENT_TRACKER_MODULE = ObjectiveTracker_GetModuleInfoTable();
SCENARIO_CONTENT_TRACKER_MODULE.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_SCENARIO;
SCENARIO_CONTENT_TRACKER_MODULE.updateReasonEvents = OBJECTIVE_TRACKER_UPDATE_SCENARIO + OBJECTIVE_TRACKER_UPDATE_SCENARIO_NEW_STAGE + OBJECTIVE_TRACKER_UPDATE_SCENARIO_SPELLS;
SCENARIO_CONTENT_TRACKER_MODULE:SetHeader(ObjectiveTrackerFrame.BlocksFrame.ScenarioHeader, TRACKER_HEADER_SCENARIO, nil);	-- never anim-in the header
SCENARIO_CONTENT_TRACKER_MODULE.blockOffsetX = -20;
SCENARIO_CONTENT_TRACKER_MODULE.fromHeaderOffsetY = -2;
SCENARIO_CONTENT_TRACKER_MODULE.ShowCriteria = C_Scenario.ShouldShowCriteria();

-- we need to go deeper

SCENARIO_TRACKER_MODULE = ObjectiveTracker_GetModuleInfoTable();
SCENARIO_TRACKER_MODULE.usedBlocks = { };
SCENARIO_TRACKER_MODULE.freeLines = { };
SCENARIO_TRACKER_MODULE.lineTemplate = "ObjectiveTrackerCheckLineTemplate";
SCENARIO_TRACKER_MODULE.lineSpacing = 12;
SCENARIO_TRACKER_MODULE.blockOffsetY = -1;
SCENARIO_TRACKER_MODULE.fromHeaderOffsetY = -1;
SCENARIO_TRACKER_MODULE.usedProgressBars = { };
SCENARIO_TRACKER_MODULE.freeProgressBars = { };

function SCENARIO_TRACKER_MODULE:GetBlock()
	-- just 1 block for scenario objectives
	local block = ScenarioObjectiveBlock;
	block.used = true;
	block.height = 0;
	block.currentLine = nil;
	-- prep lines
	if ( block.lines ) then
		for objectiveKey, line in pairs(block.lines) do
			line.used = nil;
		end
	else
		block.lines = { };
	end
	return block;
end

function SCENARIO_TRACKER_MODULE:OnFreeLine(line)
	if ( line.completed ) then
		line.Glow.Anim:Stop();
		line.Sheen.Anim:Stop();
		line.CheckFlash.Anim:Stop();
		line.completed = nil;
	end
end

-- *****************************************************************************************************
-- ***** SLIDING
-- *****************************************************************************************************

function ScenarioBlocksFrame_OnFinishSlideIn()
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = nil;
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_SCENARIO);
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_SCENARIO_BONUS_DELAYED);
end
function ScenarioBlocksFrame_OnFinishSpellExpand()
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = nil;
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_SCENARIO);
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_SCENARIO_BONUS_DELAYED);
end

function ScenarioBlocksFrame_OnFinishSlideOut()
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = nil;
	ScenarioStageBlock.CompleteLabel:Hide();
	local name, currentStage, numStages = C_Scenario.GetInfo();
	if ( currentStage and currentStage <= numStages ) then
		ScenarioBlocksFrame_SlideIn();
	else
		ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_SCENARIO);
	end
end

local SLIDE_IN_DATA = { startHeight = 1, endHeight = 0, duration = 0.4, scroll = true, onFinishFunc = ScenarioBlocksFrame_OnFinishSlideIn };
local SLIDE_OUT_DATA = { startHeight = 0, endHeight = 1, duration = 0.4, scroll = true, startDelay =  0.8, endDelay = 0.6, onFinishFunc = ScenarioBlocksFrame_OnFinishSlideOut };
local SPELL_EXPAND_DATA = { startHeight = 0, endHeight = 0, duration = 0.2, scroll = true, expanding = true, onFinishFunc = ScenarioBlocksFrame_OnFinishSpellExpand };

function ScenarioBlocksFrame_SlideIn()
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = "IN";
	SLIDE_IN_DATA.endHeight = SCENARIO_TRACKER_MODULE.BlocksFrame.height;
	ScenarioStageBlock.Stage:Show();
	ScenarioStageBlock.Name:Show();
	ScenarioStageBlock.CompleteLabel:Hide();
	ScenarioObjectiveBlock:SetShown(SCENARIO_CONTENT_TRACKER_MODULE:ShouldShowCriteria());
	ObjectiveTracker_SlideBlock(SCENARIO_TRACKER_MODULE.BlocksFrame, SLIDE_IN_DATA);
end

function ScenarioSpells_SlideIn(objectiveBlock)
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = "IN";
	SPELL_EXPAND_DATA.startHeight = objectiveBlock.heightBeforeSpells;
	SPELL_EXPAND_DATA.endHeight = SCENARIO_TRACKER_MODULE.BlocksFrame.height;
	ObjectiveTracker_SlideBlock(SCENARIO_TRACKER_MODULE.BlocksFrame, SPELL_EXPAND_DATA);

	-- Only fade in new spells
	for i = 1, #objectiveBlock.spells do
		if (objectiveBlock.spells[i]:IsShown() and objectiveBlock.spells[i].newSpell) then
			objectiveBlock.spells[i]:SetAlpha(0);
			objectiveBlock.spells[i].Fadein:Play();
		end
	end
end

function ScenarioBlocksFrame_SetupStageBlock(scenarioCompleted)
	ScenarioStageBlock.Stage:Hide();
	ScenarioStageBlock.Name:Hide();
	ScenarioStageBlock.CompleteLabel:Show();
	ScenarioObjectiveBlock:Hide();
	if ( scenarioCompleted ) then
		local scenarioType = select(10, C_Scenario.GetInfo());
		local dungeonDisplay = (scenarioType == LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY);
		if( dungeonDisplay ) then
			ScenarioStageBlock.CompleteLabel:SetText(DUNGEON_COMPLETED);
		else
			ScenarioStageBlock.CompleteLabel:SetText(SCENARIO_COMPLETED_GENERIC);
		end
	else
		ScenarioStageBlock.CompleteLabel:SetText(STAGE_COMPLETE);
	end
	if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_SCENARIO_NEW_STAGE ) then
		ScenarioStageBlock.GlowTexture.AlphaAnim:Play();
	end
end

function ScenarioBlocksFrame_SlideOut()
	SCENARIO_TRACKER_MODULE.BlocksFrame.slidingAction = "OUT";
	SLIDE_OUT_DATA.startHeight = ScenarioStageBlock.height;
	ObjectiveTracker_SlideBlock(SCENARIO_TRACKER_MODULE.BlocksFrame, SLIDE_OUT_DATA);
end

function ScenarioBlocksFrame_Hide()
	SCENARIO_TRACKER_MODULE.BlocksFrame.currentStage = nil;
	SCENARIO_TRACKER_MODULE.BlocksFrame.scenarioName = nil;
	SCENARIO_TRACKER_MODULE.BlocksFrame:SetVerticalScroll(0);
	SCENARIO_TRACKER_MODULE.BlocksFrame:Hide();
end

-- *****************************************************************************************************
-- ***** FRAME HANDLERS
-- *****************************************************************************************************

function ScenarioBlocksFrame_OnLoad(self)
	self.module = SCENARIO_CONTENT_TRACKER_MODULE;
	-- scenario uses fixed blocks (stage, objective, challenge mode)
	ScenarioStageBlock.module = SCENARIO_TRACKER_MODULE;
	ScenarioStageBlock.height = ScenarioStageBlock:GetHeight();
	ScenarioObjectiveBlock.module = SCENARIO_TRACKER_MODULE;
	ScenarioChallengeModeBlock.module = SCENARIO_TRACKER_MODULE;
	ScenarioChallengeModeBlock.height = ScenarioChallengeModeBlock:GetHeight();
	ScenarioProvingGroundsBlock.module = SCENARIO_TRACKER_MODULE;
	ScenarioProvingGroundsBlock.height = ScenarioProvingGroundsBlock:GetHeight();

	SCENARIO_TRACKER_MODULE.BlocksFrame = self;

	self:SetWidth(OBJECTIVE_TRACKER_LINE_WIDTH);

	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("WORLD_STATE_TIMER_START");
	self:RegisterEvent("WORLD_STATE_TIMER_STOP");
	self:RegisterEvent("PROVING_GROUNDS_SCORE_UPDATE");
	self:RegisterEvent("SCENARIO_COMPLETED");
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
    self:RegisterEvent("CHALLENGE_MODE_START");
    self:RegisterEvent("SCENARIO_CRITERIA_SHOW_STATE_UPDATE");
end

function ScenarioBlocksFrame_OnEvent(self, event, ...)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		ScenarioTimer_CheckTimers(GetWorldElapsedTimers());
	elseif ( event == "WORLD_STATE_TIMER_START") then
		local timerID = ...;
		ScenarioTimer_CheckTimers(timerID);
	elseif ( event == "WORLD_STATE_TIMER_STOP" ) then
		local timerID = ...;
		ScenarioTimer_Stop(timerID);
	elseif (event == "PROVING_GROUNDS_SCORE_UPDATE") then
		local score = ...
		ScenarioProvingGroundsBlock.Score:SetText(score);
	elseif (event == "SCENARIO_COMPLETED") then
		local rewardQuestID, xp, money = ...;
		if( ( xp and xp > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) or ( money and money > 0 ) ) then
			ScenarioObjectiveTracker_AnimateReward( xp, money );
		end
	elseif (event == "SPELL_UPDATE_COOLDOWN") then
		ScenarioSpellButtons_UpdateCooldowns();
	elseif (event == "CHALLENGE_MODE_START") then
    	ScenarioTimer_CheckTimers(GetWorldElapsedTimers());
    elseif (event == "SCENARIO_CRITERIA_SHOW_STATE_UPDATE") then
    	local show = ...;
    	SCENARIO_CONTENT_TRACKER_MODULE:SetShowCriteria(show);
	end
end

function ScenarioObjectiveStageBlock_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("RIGHT", self, "LEFT", 0, 0);
	local _, currentStage, numStages, flags, _, _, _, xp, money = C_Scenario.GetInfo();
	local name, description = C_Scenario.GetStepInfo();
	if( name and bit.band(flags, SCENARIO_FLAG_SUPRESS_STAGE_TEXT) == SCENARIO_FLAG_SUPRESS_STAGE_TEXT) then
	  GameTooltip:SetText(name, 1, 0.914, 0.682, 1);
	  GameTooltip:AddLine(description, 1, 1, 1, true);
	  GameTooltip:AddLine(" ");
	  if ( xp > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
		GameTooltip:AddLine(string.format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1);
	  end
	  if ( money > 0 ) then
		SetTooltipMoney(GameTooltip, money, nil);
	  end
	  GameTooltip:Show();
	elseif( currentStage <= numStages ) then
	  GameTooltip:SetText(string.format(SCENARIO_STAGE_STATUS, currentStage, numStages), 1, 0.914, 0.682, 1);
	  GameTooltip:AddLine(name, 1, 0.831, 0.380, true);
	  GameTooltip:AddLine(" ");
	  GameTooltip:AddLine(description, 1, 1, 1, true);
	  GameTooltip:Show();
	end
end

-- *****************************************************************************************************
-- ***** TIMER
-- *****************************************************************************************************

local floor = floor;
function ScenarioTimer_OnUpdate(self, elapsed)
	self.timeSinceBase = self.timeSinceBase + elapsed;
	self.updateFunc(self.block, floor(self.baseTime + self.timeSinceBase));
end

function ScenarioTimer_Start(block, updateFunc)
	local _, elapsedTime = GetWorldElapsedTime(block.timerID);
	ScenarioTimerFrame.baseTime = elapsedTime;
	ScenarioTimerFrame.timeSinceBase = 0;
	ScenarioTimerFrame.block = block;
	ScenarioTimerFrame.updateFunc = updateFunc;
	ScenarioTimerFrame:Show();
end

function ScenarioTimer_Stop(timerID)
	local timerFrame = ScenarioTimerFrame;
	if ( timerFrame.block and (not timerID or timerFrame.block.timerID == timerID) ) then
		-- remove the block
		timerFrame.block.timerID = nil;
		timerFrame.block:Hide();
		-- remove the timer
		timerFrame:Hide();
		timerFrame.baseTime = nil;
		timerFrame.timeSinceBase = nil;
		timerFrame.block = nil;
		timerFrame.updateFunc = nil;
		-- update
		ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_SCENARIO);
	end
end

function ScenarioTimer_CheckTimers(...)
	-- only supporting 1 active timer
	for i = 1, select("#", ...) do
		local timerID = select(i, ...);
		local _, elapsedTime, type = GetWorldElapsedTime(timerID);
		if ( type == LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE) then
			local _, _, _, _, _, _, _, mapID = GetInstanceInfo();
			if ( mapID ) then
				local _, _, timeLimit = C_ChallengeMode.GetMapInfo(mapID);
				Scenario_ChallengeMode_ShowBlock(timerID, elapsedTime, timeLimit);
				return;
			end
		elseif ( type == LE_WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND ) then
			local diffID, currWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo()
			if (duration > 0) then
				Scenario_ProvingGrounds_ShowBlock(timerID, elapsedTime, duration, diffID, currWave, maxWave);
				return;
			end
		end
	end
	-- we had an update but didn't find a valid timer, kill the timer if it's running
	ScenarioTimer_Stop();
end

-- *****************************************************************************************************
-- ***** REWARD FRAME
-- *****************************************************************************************************

function ScenarioObjectiveTracker_AnimateReward(xp, money)
	local rewardsFrame = ObjectiveTrackerScenarioRewardsFrame;
	rewardsFrame:Show();
	rewardsFrame:SetScale(0.9);
	local rewards = {};
	if( xp > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
		local t = {};
		t.label = xp;
		t.texture = "Interface\\Icons\\XP_Icon";
		t.count = 0;
		t.font = "NumberFontNormal";
		tinsert(rewards, t);
	end
	if( money > 0 ) then
		local t = {};
		t.label = GetMoneyString(money);
		t.texture = "Interface\\Icons\\inv_misc_coin_01";
		t.count = 0;
		t.font = "GameFontHighlight";
		tinsert(rewards, t);
	end
	local numRewards = #rewards;
	local contentsHeight = 12 + numRewards * 36;
	rewardsFrame.Anim.RewardsBottomAnim:SetOffset(0, -contentsHeight);
	rewardsFrame.Anim.RewardsShadowAnim:SetToScale(0.8, contentsHeight / 16);
	rewardsFrame.Anim:Play();
	-- configure reward frames
	for i = 1, numRewards do
		local rewardItem = rewardsFrame.Rewards[i];
		if ( not rewardItem ) then
			rewardItem = CreateFrame("FRAME", nil, rewardsFrame, "BonusObjectiveTrackerRewardTemplate");
			rewardItem:SetPoint("TOPLEFT", rewardsFrame.Rewards[i-1], "BOTTOMLEFT", 0, -4);
		end
		local rewardData = rewards[i];
		if ( rewardData.count > 1 ) then
			rewardItem.Count:Show();
			rewardItem.Count:SetText(rewardData.count);
		else
			rewardItem.Count:Hide();
		end
		rewardItem.Label:SetFontObject(rewardData.font);
		rewardItem.Label:SetText(rewardData.label);
		rewardItem.ItemIcon:SetTexture(rewardData.texture);
		rewardItem:Show();
		if( rewardItem.Anim:IsPlaying() ) then
			rewardItem.Anim:Stop();
		end
		rewardItem.Anim:Play();
	end
	-- hide unused reward items
	for i = numRewards + 1, #rewardsFrame.Rewards do
		rewardsFrame.Rewards[i]:Hide();
	end
end

function ScenarioObjectiveTracker_OnAnimateRewardDone(self)
	local rewardsFrame = ObjectiveTrackerScenarioRewardsFrame;
	rewardsFrame:Hide();
end

-- *****************************************************************************************************
-- ***** CHALLENGE MODE
-- *****************************************************************************************************

function Scenario_ChallengeMode_ShowBlock(timerID, elapsedTime, timeLimit)
	local block = ScenarioChallengeModeBlock;
	block.timerID = timerID;
	block.timeLimit = timeLimit;
	block.lastMedalShown = nil;
	local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo();
	block.Level:SetText(CHALLENGE_MODE_POWER_LEVEL:format(level));
	if (not wasEnergized) then
		block.wasDepleted = true;
		block.StartedDepleted:Show();
	else
        block.wasDepleted = false;
        block.StartedDepleted:Hide();
    end
	block.TimesUpLootStatus:Hide();
	Scenario_ChallengeMode_SetUpAffixes(block, affixes);
	local statusBar = block.StatusBar;
	statusBar:SetMinMaxValues(0, block.timeLimit);
	Scenario_ChallengeMode_UpdateTime(block, elapsedTime);
	ScenarioTimer_Start(block, Scenario_ChallengeMode_UpdateTime);
	block:Show();
	ObjectiveTracker_Expand();
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_SCENARIO);
end

ScenarioChallengeModeAffixMixin = {};

function ScenarioChallengeModeAffixMixin:SetUp(affixID)
	local _, _, filedataid = C_ChallengeMode.GetAffixInfo(affixID);
	SetPortraitToTexture(self.Portrait, filedataid);

	self.affixID = affixID;

	self:Show();
end

function ScenarioChallengeModeAffixMixin:OnEnter()
	if (self.affixID) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

		local name, description = C_ChallengeMode.GetAffixInfo(self.affixID);

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(name, 1, 1, 1, 1, true);
		GameTooltip:AddLine(description, nil, nil, nil, true);
		GameTooltip:Show();
	end
end

function Scenario_ChallengeMode_SetUpAffixes(block,affixes)
	local frameWidth, spacing, distance = 34, 4, -20;
	local num = #affixes;
	local leftPoint = 28 + (spacing * (num - 1)) + (frameWidth * num);
	block.Affixes[1]:SetPoint("TOPLEFT", block, "TOPRIGHT", -leftPoint, distance);
	for i = 1, num do
		local affixID = affixes[i];

		local affixFrame = block.Affixes[i];
		if (not affixFrame) then
			affixFrame = CreateFrame("Frame", nil, block, "ScenarioChallengeModeAffixTemplate");
			local prev = block.Affixes[i - 1];
			affixFrame:SetPoint("LEFT", prev, "RIGHT", spacing, 0);
		end
		affixFrame:SetUp(affixID);
	end

	for i = num + 1, #block.Affixes do
		block.Affixes[i]:Hide();
	end
end

function Scenario_ChallengeMode_UpdateTime(block, elapsedTime)
	local timeLeft = math.max(0, block.timeLimit - elapsedTime);
	local statusBar = block.StatusBar;
	statusBar:SetValue(timeLeft);
	if (timeLeft == 0) then
		block.TimeLeft:SetTextColor(RED_FONT_COLOR:GetRGB());
		block.StartedDepleted:Hide();
		block.TimesUpLootStatus:Show();
		block.TimesUpLootStatus.NoLoot:SetShown(block.wasDepleted);
	else
		block.TimeLeft:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB());
	end
	block.TimeLeft:SetText(GetTimeStringFromSeconds(timeLeft, false, true));
end

function Scenario_ChallengeMode_TimesUpLootStatus_OnEnter(self)
	local block = self:GetParent();

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(CHALLENGE_MODE_TIMES_UP, 1, 1, 1);
	local line;
	if (block.wasDepleted) then
		if (UnitIsGroupLeader("player")) then
			line = CHALLENGE_MODE_TIMES_UP_NO_LOOT_LEADER;
		else
			line = CHALLENGE_MODE_TIMES_UP_NO_LOOT;
		end
	else
		line = CHALLENGE_MODE_TIMES_UP_LOOT;
	end
	GameTooltip:AddLine(line, nil, nil, nil, true);
	GameTooltip:Show();
end

-- *****************************************************************************************************
-- ***** PROVING GROUNDS
-- *****************************************************************************************************

local PROVING_GROUNDS_ENDLESS_INDEX = 4;
function Scenario_ProvingGrounds_ShowBlock(timerID, elapsedTime, duration, medalIndex, currWave, maxWave)
	local block = ScenarioProvingGroundsBlock;
	local statusBar = block.StatusBar;

	block.timerID = timerID;
	statusBar.duration = duration;
	statusBar:SetMinMaxValues(0, duration);
	if ( CHALLENGE_MEDAL_TEXTURES[medalIndex] ) then
		block.MedalIcon:SetTexture(CHALLENGE_MEDAL_TEXTURES[medalIndex]);
		block.MedalIcon:Show();
	end

	if (medalIndex < PROVING_GROUNDS_ENDLESS_INDEX) then
		block.ScoreLabel:Hide();
		block.Score:Hide();
		block.WaveLabel:SetPoint("TOPLEFT", block.MedalIcon, "TOPRIGHT", 1, -4);
		block.Wave:SetFormattedText(GENERIC_FRACTION_STRING, currWave, maxWave);
		statusBar:SetPoint("TOPLEFT", block.WaveLabel, "BOTTOMLEFT", -2, -6);
	else
		block.ScoreLabel:Show();
		block.Score:Show();
		block.WaveLabel:SetPoint("TOPLEFT", block.MedalIcon, "TOPRIGHT", 1, 4);
		block.Wave:SetText(currWave);
		statusBar:SetPoint("TOPLEFT", block.ScoreLabel, "BOTTOMLEFT", -2, -6);
	end

	Scenario_ProvingGrounds_UpdateTime(block, elapsedTime);
	ScenarioProvingGroundsBlockAnim.CountdownAnim.timeLeft = nil;

	ScenarioTimer_Start(block, Scenario_ProvingGrounds_UpdateTime);
	block:Show();
	ObjectiveTracker_Expand();
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_SCENARIO);
end

function Scenario_ProvingGrounds_UpdateTime(block, elapsedTime)
	local statusBar = block.StatusBar;
	local anim = ScenarioProvingGroundsBlockAnim.CountdownAnim;
	if ( elapsedTime < statusBar.duration ) then
		statusBar:SetValue(statusBar.duration - elapsedTime);
		statusBar.TimeLeft:SetText(GetTimeStringFromSeconds(statusBar.duration - elapsedTime));

		local timeLeft = statusBar.duration - elapsedTime;
		if (timeLeft <= 5) then
			if (not anim:IsPlaying() and anim.cycles == 0) then
				anim:Play();
				anim.cycles = 4;
			end
		else
			anim.cycles = 0;
		end
	else
		anim.cycles = 0;
	end
end

function Scenario_ProvingGrounds_CountdownAnim_OnFinished(self)
	if ( self.cycles > 0 ) then
		self:Play();
		self.cycles = self.cycles - 1;
	else
		self.cycles = 0;
	end
end

-- *****************************************************************************************************
-- ***** LEGION INVASION MODE
-- *****************************************************************************************************

function ScenarioRewardButton_OnEnter(self)
	EmbeddedItemTooltip_SetItemByID(ScenarioStepRewardTooltip.ItemTooltip, self.rewardID);
	ScenarioStepRewardTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT");
	ScenarioStepRewardTooltip:Show();
end

function ScenarioRewardButton_OnLeave(self)
	ScenarioStepRewardTooltip:Hide();
end

-- *****************************************************************************************************
-- ***** SPELLS
-- *****************************************************************************************************

function ScenarioSpellButtons_UpdateCooldowns()
	local objectiveBlock = ScenarioObjectiveBlock;
	for i = 1, objectiveBlock.numSpells or 0 do
		ScenarioSpellButton_UpdateCooldown(objectiveBlock.spells[i].SpellButton);
	end
end

function ScenarioSpellButton_UpdateCooldown(spellButton)
	local start, duration, enable = GetSpellCooldown(spellButton.spellID);
	if ( start ) then
		CooldownFrame_Set(spellButton.Cooldown, start, duration, enable);
		if ( duration > 0 and enable == 0 ) then
			spellButton.Icon:SetVertexColor(0.4, 0.4, 0.4);
		else
			spellButton.Icon:SetVertexColor(1, 1, 1);
		end
	end
end

function ScenarioSpellButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetSpellByID(self.spellID);
end

function ScenarioSpellButton_OnClick(self, button)
	CastSpellByID(self.spellID);
end

function SCENARIO_CONTENT_TRACKER_MODULE:AddSpells(objectiveBlock, spellInfo)
	if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_SCENARIO_SPELLS ) then
		-- Calculate height of block with currently existing spells, so that we only slide in the new ones
		objectiveBlock.heightBeforeSpells = objectiveBlock.height + SCENARIO_TRACKER_MODULE.BlocksFrame.contentsHeight;
		if (objectiveBlock.spells) then
			for i = 1, #objectiveBlock.spells do
				if (objectiveBlock.spells[i]:IsShown()) then
					objectiveBlock.heightBeforeSpells = objectiveBlock.heightBeforeSpells + objectiveBlock.spells[i]:GetHeight();
				end
			end
		end
	end;
	local numSpells = 0;
	if (spellInfo) then
		numSpells = #spellInfo;
	end
	objectiveBlock.numSpells = numSpells;
	if (not objectiveBlock.spells) then
		objectiveBlock.spells = {};
	end
	for spellIndex = 1, numSpells do
		local spellFrame = objectiveBlock.spells[spellIndex];
		if (not spellFrame) then
			spellFrame = CreateFrame("Frame", nil, objectiveBlock, "ScenarioSpellFrameTemplate");
			objectiveBlock.spells[spellIndex] = spellFrame;
		end
		spellFrame.newSpell = not spellFrame:IsShown();
		spellFrame:Show();
		spellFrame.SpellName:SetText(spellInfo[spellIndex].spellName);
		spellFrame.SpellButton.Icon:SetTexture(spellInfo[spellIndex].spellIcon);
		spellFrame.SpellButton.spellID = spellInfo[spellIndex].spellID;
		spellFrame:SetPoint("TOPLEFT", objectiveBlock.currentLine, "BOTTOMLEFT", 0, 0);
		objectiveBlock.currentLine = spellFrame;
		objectiveBlock.height = objectiveBlock.height + spellFrame:GetHeight();
	end
	for i = numSpells + 1, #objectiveBlock.spells do
		objectiveBlock.spells[i]:Hide();
	end
end

-- *****************************************************************************************************
-- ***** PROGRESS BAR
-- *****************************************************************************************************

function ScenarioTrackerProgressBar_GetProgress(self)
	if (self.criteriaIndex) then
		return select(4, C_Scenario.GetCriteriaInfo(self.criteriaIndex)) or 0;
	else
		return select(9, C_Scenario.GetStepInfo()) or 0;
	end
end

function ScenarioTrackerProgressBar_SetValue(self, percent)
	self.Bar:SetValue(percent);
	self.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
	self.AnimValue = percent;
end

function ScenarioTrackerProgressBar_PlayFlareAnim(progressBar, delta)
	if( progressBar.AnimValue >= 100 ) then
		return;
	end

	if( delta > 1 ) then
		local width = progressBar.Bar:GetWidth();
		local offset = width * progressBar.AnimValue/100-12;
		local prefix = "";
		if( delta < 10 ) then
			prefix = "Small";
		end
		local flare = progressBar[prefix.."Flare1"];

		if( flare.FlareAnim:IsPlaying() ) then
			flare = progressBar[prefix.."Flare2"];
			if( not flare.FlareAnim:IsPlaying() ) then
				flare:SetPoint("LEFT", progressBar.Bar, "LEFT", offset,0);
				flare.FlareAnim:Play();
			end
		end
	end

	local barFlare = progressBar["FullBarFlare1"];
	if( barFlare.FlareAnim:IsPlaying() ) then
		barFlare = progressBar["FullBarFlare2"];
		if( barFlare.FlareAnim:IsPlaying() ) then
			return;
		end
	end

	barFlare.FlareAnim:Play();
end

function ScenarioTrackerProgressBar_OnEvent(self, event)
	local weightedProgress = ScenarioTrackerProgressBar_GetProgress(self);
	ScenarioTrackerProgressBar_PlayFlareAnim(self, weightedProgress - self.AnimValue);
	ScenarioTrackerProgressBar_SetValue(self, weightedProgress);
end

function SCENARIO_TRACKER_MODULE:AddProgressBar(block, line, criteriaIndex)
	local progressBar = self.usedProgressBars[block] and self.usedProgressBars[block][line];
	if ( not progressBar ) then
		local numFreeProgressBars = #self.freeProgressBars;
		local parent = block.ScrollContents or block;
		if ( numFreeProgressBars > 0 ) then
			progressBar = self.freeProgressBars[numFreeProgressBars];
			tremove(self.freeProgressBars, numFreeProgressBars);
			progressBar:SetParent(parent);
			progressBar:Show();
		else
			progressBar = CreateFrame("Frame", nil, parent, "ScenarioTrackerProgressBarTemplate");
			progressBar.height = progressBar:GetHeight();
		end
		if ( not self.usedProgressBars[block] ) then
			self.usedProgressBars[block] = { };
		end
		self.usedProgressBars[block][line] = progressBar;
		progressBar:RegisterEvent("SCENARIO_CRITERIA_UPDATE");
		progressBar:Show();
		progressBar.criteriaIndex = criteriaIndex;
		ScenarioTrackerProgressBar_SetValue(progressBar, ScenarioTrackerProgressBar_GetProgress(progressBar));
	end

	progressBar.Bar.Icon:Hide();
	progressBar.Bar.IconBG:Hide();
	progressBar.Bar.BarGlow:SetAtlas("bonusobjectives-bar-glow", true);

	if (not criteriaIndex) then
		local rewardQuestID = select(10, C_Scenario.GetStepInfo());

		if (rewardQuestID ~= 0) then
			-- reward icon; try the first item
			local _, texture = GetQuestLogRewardInfo(1, rewardQuestID);
			-- artifact xp
			local artifactXP, artifactCategory = GetQuestLogRewardArtifactXP(rewardQuestID);
			if ( not texture and artifactXP > 0 ) then
				local name, icon = C_ArtifactUI.GetArtifactXPRewardTargetInfo(artifactCategory);
				texture = icon or "Interface\\Icons\\INV_Misc_QuestionMark";
			end
			-- currency
			if ( not texture and GetNumQuestLogRewardCurrencies(rewardQuestID) > 0 ) then
				_, texture = GetQuestLogRewardCurrencyInfo(1, rewardQuestID);
			end
			-- money?
			if ( not texture and GetQuestLogRewardMoney(rewardQuestID) > 0 ) then
				texture = "Interface\\Icons\\inv_misc_coin_02";
			end
			-- xp
			if ( not texture and GetQuestLogRewardXP(rewardQuestID) > 0 and UnitLevel("player") < MAX_PLAYER_LEVEL ) then
				texture = "Interface\\Icons\\xp_icon";
			end
			if ( texture ) then
				progressBar.Bar.Icon:SetTexture(texture);
				progressBar.Bar.Icon:Show();
				progressBar.Bar.IconBG:Show();
				progressBar.Bar.BarGlow:SetAtlas("bonusobjectives-bar-glow-ring", true);
			end
		end
	end

	-- anchor the status bar
	local anchor = block.currentLine or block.HeaderText;
	if ( anchor ) then
		progressBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -block.module.lineSpacing);
	else
		progressBar:SetPoint("TOPLEFT", 0, -block.module.lineSpacing);
	end

	progressBar.block = block;

	line.ProgressBar = progressBar;
	block.height = block.height + progressBar.height + block.module.lineSpacing;
	block.currentLine = progressBar;
	return progressBar;
end

function SCENARIO_TRACKER_MODULE:FreeProgressBar(block, line)
	local progressBar = line.ProgressBar;
	if ( progressBar ) then
		self.usedProgressBars[block][line] = nil;
		tinsert(self.freeProgressBars, progressBar);
		progressBar:Hide();
		line.ProgressBar = nil;
		progressBar:UnregisterEvent("SCENARIO_CRITERIA_UPDATE");
	end
end

-- *****************************************************************************************************
-- ***** UPDATE FUNCTIONS
-- *****************************************************************************************************

function SCENARIO_CONTENT_TRACKER_MODULE:StaticReanchor()
	local scenarioName, currentStage, numStages, flags, _, _, completed, xp, money = C_Scenario.GetInfo();
	local rewardsFrame = ObjectiveTrackerScenarioRewardsFrame;
	if ( numStages == 0 ) then
		ScenarioBlocksFrame_Hide();
		return;
	end
	if ( ScenarioBlocksFrame:IsShown() ) then
		ObjectiveTracker_AddBlock(SCENARIO_TRACKER_MODULE.BlocksFrame);
	end
end

function ScenarioStage_CustomizeBlock(stageBlock, scenarioType)
	if (scenarioType == LE_SCENARIO_TYPE_LEGION_INVASION) then
		stageBlock.Stage:SetTextColor(0.753, 1, 0);
		stageBlock.NormalBG:SetAtlas("legioninvasion-ScenarioTrackerToast", true);
		stageBlock.RewardButton:Hide();
	else
		stageBlock.Stage:SetTextColor(1, 0.914, 0.682);
		stageBlock.NormalBG:SetAtlas("ScenarioTrackerToast", true);
		stageBlock.RewardButton:Hide();
	end
end

function SCENARIO_CONTENT_TRACKER_MODULE:Update()
	local scenarioName, currentStage, numStages, flags, _, _, _, xp, money, scenarioType = C_Scenario.GetInfo();
	local rewardsFrame = ObjectiveTrackerScenarioRewardsFrame;
	if ( numStages == 0 ) then
		ScenarioBlocksFrame_Hide();
		return;
	end
	local BlocksFrame = SCENARIO_TRACKER_MODULE.BlocksFrame;
	local objectiveBlock = SCENARIO_TRACKER_MODULE:GetBlock();
	local stageBlock = ScenarioStageBlock;

	-- if sliding, ignore updates unless the stage changed
	if ( BlocksFrame.slidingAction ) then
		if ( BlocksFrame.currentStage == currentStage ) then
			ObjectiveTracker_AddBlock(BlocksFrame);
			BlocksFrame:Show();
			return;
		else
			ObjectiveTracker_EndSlideBlock(BlocksFrame);
		end
	end

	BlocksFrame.maxHeight = SCENARIO_CONTENT_TRACKER_MODULE.BlocksFrame.maxHeight;
	BlocksFrame.currentBlock = nil;
	BlocksFrame.contentsHeight = 0;
	SCENARIO_TRACKER_MODULE.contentsHeight = 0;

	local stageName, stageDescription, numCriteria, _, _, _, numSpells, spellInfo, weightedProgress = C_Scenario.GetStepInfo();
	local inChallengeMode = (scenarioType == LE_SCENARIO_TYPE_CHALLENGE_MODE);
	local inProvingGrounds = (scenarioType == LE_SCENARIO_TYPE_PROVING_GROUNDS);
	local dungeonDisplay = (scenarioType == LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY);
	local scenariocompleted = currentStage > numStages;

	if ( scenariocompleted ) then
		ObjectiveTracker_AddBlock(stageBlock);
		ScenarioBlocksFrame_SetupStageBlock(scenariocompleted);
		stageBlock:Show();
	elseif ( inChallengeMode ) then
		if ( ScenarioChallengeModeBlock.timerID ) then
			ObjectiveTracker_AddBlock(ScenarioChallengeModeBlock);
		end
		stageBlock:Hide();
	elseif ( ScenarioProvingGroundsBlock.timerID ) then
		ObjectiveTracker_AddBlock(ScenarioProvingGroundsBlock);
		stageBlock:Hide();
	else
		-- add the stage block
		ObjectiveTracker_AddBlock(stageBlock);
		stageBlock:Show();
		-- update if stage changed
		if ( BlocksFrame.currentStage ~= currentStage or BlocksFrame.scenarioName ~= scenarioName ) then
			SCENARIO_TRACKER_MODULE:FreeUnusedLines(objectiveBlock);
			if ( bit.band(flags, SCENARIO_FLAG_SUPRESS_STAGE_TEXT) == SCENARIO_FLAG_SUPRESS_STAGE_TEXT ) then
				stageBlock.Stage:SetText(stageName);
				stageBlock.Stage:SetSize( 172, 36 );
				stageBlock.Stage:SetPoint("TOPLEFT", 15, -18);
				stageBlock.FinalBG:Hide();
				stageBlock.Name:SetText("");
			else
				if ( currentStage == numStages ) then
					stageBlock.Stage:SetText(SCENARIO_STAGE_FINAL);
					stageBlock.FinalBG:Show();
				else
					stageBlock.Stage:SetFormattedText(SCENARIO_STAGE, currentStage);
					stageBlock.FinalBG:Hide();
				end
				stageBlock.Stage:SetSize( 172, 18 );
				stageBlock.Name:SetText(stageName);
				if ( stageBlock.Name:GetStringWidth() > stageBlock.Name:GetWrappedWidth() ) then
					stageBlock.Stage:SetPoint("TOPLEFT", 15, -10);
				else
					stageBlock.Stage:SetPoint("TOPLEFT", 15, -18);
				end
			end
			ScenarioStage_CustomizeBlock(stageBlock, scenarioType);
		end
	end
	BlocksFrame.scenarioName = scenarioName;
	BlocksFrame.currentStage = currentStage;

	if ( not ScenarioProvingGroundsBlock.timerID and not scenariocompleted ) then
		if (weightedProgress) then
			self:UpdateWeightedProgressCriteria(stageDescription, stageBlock, objectiveBlock, BlocksFrame);
		else
			self:UpdateCriteria(numCriteria, objectiveBlock);
			self:AddSpells(objectiveBlock, spellInfo);

			-- add the objective block
			objectiveBlock:SetHeight(objectiveBlock.height);
			if ( ObjectiveTracker_AddBlock(objectiveBlock) ) then
				if ( not BlocksFrame.slidingAction ) then
					objectiveBlock:Show();
				end
			else
				objectiveBlock:Hide();
				stageBlock:Hide();
			end
		end
	end
	ScenarioSpellButtons_UpdateCooldowns();

	-- add the scenario block
	if ( BlocksFrame.currentBlock ) then
		BlocksFrame.height = BlocksFrame.contentsHeight + 1;
		BlocksFrame:SetHeight(BlocksFrame.contentsHeight + 1);
		ObjectiveTracker_AddBlock(BlocksFrame);
		BlocksFrame:Show();
		if ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_SCENARIO_NEW_STAGE and not inChallengeMode ) then
			if ( ObjectiveTrackerFrame:IsVisible() ) then
				if ( currentStage == 1 ) then
					ScenarioBlocksFrame_SlideIn();
				else
					ScenarioBlocksFrame_SetupStageBlock(scenariocompleted);
					if ( not scenariocompleted ) then
						ScenarioBlocksFrame_SlideOut();
					end
				end
			end
			LevelUpDisplay_PlayScenario();
			-- play sound if not the first stage
			if ( currentStage > 1 and currentStage <= numStages ) then
				PlaySound("UI_Scenario_Stage_End");
			end
		elseif ( OBJECTIVE_TRACKER_UPDATE_REASON == OBJECTIVE_TRACKER_UPDATE_SCENARIO_SPELLS ) then
			ScenarioSpells_SlideIn(objectiveBlock);
		end
		-- header
		if ( inChallengeMode ) then
			SCENARIO_CONTENT_TRACKER_MODULE.Header.Text:SetText(scenarioName);
		elseif ( inProvingGrounds or ScenarioProvingGroundsBlock.timerID ) then
			SCENARIO_CONTENT_TRACKER_MODULE.Header.Text:SetText(TRACKER_HEADER_PROVINGGROUNDS);
		elseif( dungeonDisplay ) then
			SCENARIO_CONTENT_TRACKER_MODULE.Header.Text:SetText(TRACKER_HEADER_DUNGEON);
		else
			SCENARIO_CONTENT_TRACKER_MODULE.Header.Text:SetText(TRACKER_HEADER_SCENARIO);
		end
	else
		ScenarioBlocksFrame_Hide();
	end
end

function SCENARIO_CONTENT_TRACKER_MODULE:UpdateWeightedProgressCriteria(stageDescription, stageBlock, objectiveBlock, BlocksFrame)
	if not self:ShouldShowCriteria() then
		return;
	end

	-- A progress bar here is the entire tree for scenarios
	SCENARIO_TRACKER_MODULE.lineSpacing = 2;
	SCENARIO_TRACKER_MODULE:AddObjective(objectiveBlock, 1, stageDescription);
	objectiveBlock.currentLine.Icon:Hide();
	local progressBar = SCENARIO_TRACKER_MODULE:AddProgressBar(objectiveBlock, objectiveBlock.currentLine);
	objectiveBlock:SetHeight(objectiveBlock.height);
	if ( ObjectiveTracker_AddBlock(objectiveBlock) ) then
		if ( not BlocksFrame.slidingAction ) then
			objectiveBlock:Show();
		end
	else
		objectiveBlock:Hide();
		stageBlock:Hide();
	end
end

function SCENARIO_CONTENT_TRACKER_MODULE:UpdateCriteria(numCriteria, objectiveBlock)
	if not self:ShouldShowCriteria() then
		return;
	end

	for criteriaIndex = 1, numCriteria do
		local criteriaString, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, _, isWeightedProgress = C_Scenario.GetCriteriaInfo(criteriaIndex);
		if (criteriaString) then
			if (not isWeightedProgress) then
				criteriaString = string.format("%d/%d %s", quantity, totalQuantity, criteriaString);
			end
			SCENARIO_TRACKER_MODULE.lineSpacing = 12;
			if ( completed ) then
				local existingLine = objectiveBlock.lines[criteriaIndex];
				SCENARIO_TRACKER_MODULE:AddObjective(objectiveBlock, criteriaIndex, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_SHOW, OBJECTIVE_TRACKER_COLOR["Complete"]);
				objectiveBlock.currentLine.Icon:Show();
				objectiveBlock.currentLine.Icon:SetAtlas("Tracker-Check", true);
				if ( existingLine and not existingLine.completed ) then
					existingLine.Glow.Anim:Play();
					existingLine.Sheen.Anim:Play();
					existingLine.CheckFlash.Anim:Play();
				end
				objectiveBlock.currentLine.completed = true;
			else
				SCENARIO_TRACKER_MODULE:AddObjective(objectiveBlock, criteriaIndex, criteriaString);
				objectiveBlock.currentLine.Icon:Show();
				objectiveBlock.currentLine.Icon:SetAtlas("Objective-Nub", true);
			end
			local line = objectiveBlock.currentLine;
			if (isWeightedProgress and not completed) then
				SCENARIO_TRACKER_MODULE.lineSpacing = 2;
				SCENARIO_TRACKER_MODULE:AddProgressBar(objectiveBlock, objectiveBlock.currentLine, criteriaIndex);
			elseif (line.ProgressBar) then
				SCENARIO_TRACKER_MODULE:FreeProgressBar(objectiveBlock, objectiveBlock.currentLine);
			end
			-- timer bar
			local line = objectiveBlock.currentLine;
			if ( duration > 0 and elapsed <= duration ) then
				SCENARIO_TRACKER_MODULE:AddTimerBar(objectiveBlock, objectiveBlock.currentLine, duration, GetTime() - elapsed);
			elseif ( line.TimerBar ) then
				SCENARIO_TRACKER_MODULE:FreeTimerBar(objectiveBlock, objectiveBlock.currentLine);
			end
		end
	end
end

function SCENARIO_CONTENT_TRACKER_MODULE:ShouldShowCriteria()
	return self.ShowCriteria;
end

function SCENARIO_CONTENT_TRACKER_MODULE:SetShowCriteria(show)
	if (self.ShowCriteria ~= show) then
		self.ShowCriteria = show;
		ScenarioObjectiveBlock:SetShown(show);
		ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_SCENARIO);
	end
end

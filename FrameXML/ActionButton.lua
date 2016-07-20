CURRENT_ACTIONBAR_PAGE = 1;
NUM_ACTIONBAR_PAGES = 6;
NUM_ACTIONBAR_BUTTONS = 12;
NUM_OVERRIDE_BUTTONS = 6;
ATTACK_BUTTON_FLASH_TIME = 0.4;

BOTTOMLEFT_ACTIONBAR_PAGE = 6;
BOTTOMRIGHT_ACTIONBAR_PAGE = 5;
LEFT_ACTIONBAR_PAGE = 4;
RIGHT_ACTIONBAR_PAGE = 3;
RANGE_INDICATOR = "●";

COOLDOWN_TYPE_LOSS_OF_CONTROL = 1;
COOLDOWN_TYPE_NORMAL = 2;

-- Table of actionbar pages and whether they're viewable or not
VIEWABLE_ACTION_BAR_PAGES = {1, 1, 1, 1, 1, 1};

ACTION_HIGHLIGHT_MARKS = { };

function MarkNewActionHighlight(action, mark)
	ACTION_HIGHLIGHT_MARKS[action] = mark;
end

function GetNewActionHighlightMark(action)
	return ACTION_HIGHLIGHT_MARKS[action];
end

function GetActionButtonForID(id)
	if OverrideActionBar and OverrideActionBar:IsShown() then
		if id > NUM_OVERRIDE_BUTTONS then
			return;
		end

		return _G["OverrideActionBarButton"..id];
	end

	return _G["ActionButton"..id];
end

local function CheckUseActionButton(button, checkingFromDown)
	local actionButtonUseKeyDown = GetCVarBool("ActionButtonUseKeyDown");
	local doAction = (checkingFromDown and actionButtonUseKeyDown) or not (checkingFromDown or actionButtonUseKeyDown);

	if doAction then
		if not button.ZoneAbilityDisabled then
			SecureActionButton_OnClick(button, "LeftButton");

			if GetNewActionHighlightMark(button.action) then
				MarkNewActionHighlight(button.action, false);
				ActionButton_UpdateHighlightMark(button, button.action);
			end
		end
		ActionButton_UpdateState(button);
	end
end

local isInPetBattle = C_PetBattles.IsInBattle;
local function CheckPetActionButtonEvent(id, isDown)
	if isInPetBattle() and PetBattleFrame then
		if isDown then
			PetBattleFrame_ButtonDown(id);
		else
			PetBattleFrame_ButtonUp(id);
		end
		return true;
	end

	return false;
end

function ActionButtonDown(id)
	if CheckPetActionButtonEvent(id, true) then
		return;
	end

	local button = GetActionButtonForID(id);
	if button then
		if button:GetButtonState() == "NORMAL" then
			button:SetButtonState("PUSHED");
		end

		CheckUseActionButton(button, true);
	end
end

function ActionButtonUp(id)
	if CheckPetActionButtonEvent(id, false) then
		return;
	end

	local button = GetActionButtonForID(id);
	if button then
		if ( button:GetButtonState() == "PUSHED" ) then
			button:SetButtonState("NORMAL");
			CheckUseActionButton(button, false);
		end
	end
end

function ActionBar_PageUp()
	local nextPage;
	for i=GetActionBarPage() + 1, NUM_ACTIONBAR_PAGES do
		if ( VIEWABLE_ACTION_BAR_PAGES[i] ) then
			nextPage = i;
			break;
		end
	end

	if ( not nextPage ) then
		nextPage = 1;
	end
	ChangeActionBarPage(nextPage);
end

function ActionBar_PageDown()
	local prevPage;
	for i=GetActionBarPage() - 1, 1, -1 do
		if ( VIEWABLE_ACTION_BAR_PAGES[i] ) then
			prevPage = i;
			break;
		end
	end

	if ( not prevPage ) then
		for i=NUM_ACTIONBAR_PAGES, 1, -1 do
			if ( VIEWABLE_ACTION_BAR_PAGES[i] ) then
				prevPage = i;
				break;
			end
		end
	end
	ChangeActionBarPage(prevPage);
end

function ActionBarButtonEventsFrame_OnLoad(self)
	self.frames = { };
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("ACTIONBAR_SHOWGRID");
	self:RegisterEvent("ACTIONBAR_HIDEGRID");
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
	self:RegisterEvent("UPDATE_BINDINGS");
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
end

function ActionBarButtonEventsFrame_OnEvent(self, event, ...)
	-- pass event down to the buttons
	for k, frame in pairs(self.frames) do
		ActionButton_OnEvent(frame, event, ...);
	end
end

function ActionBarButtonEventsFrame_RegisterFrame(frame)
	tinsert(ActionBarButtonEventsFrame.frames, frame);
end

function ActionBarActionEventsFrame_OnLoad(self)
	self.frames = { };
	--self:RegisterEvent("ACTIONBAR_UPDATE_STATE");			not updating state from lua anymore, see SetActionUIButton
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE");
	--self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");		not updating cooldown from lua anymore, see SetActionUIButton
	self:RegisterEvent("SPELL_UPDATE_CHARGES");
	self:RegisterEvent("UPDATE_INVENTORY_ALERTS");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("TRADE_SKILL_SHOW");
	self:RegisterEvent("TRADE_SKILL_CLOSE");
	self:RegisterEvent("ARCHAEOLOGY_CLOSED");
	self:RegisterEvent("PLAYER_ENTER_COMBAT");
	self:RegisterEvent("PLAYER_LEAVE_COMBAT");
	self:RegisterEvent("START_AUTOREPEAT_SPELL");
	self:RegisterEvent("STOP_AUTOREPEAT_SPELL");
	self:RegisterEvent("UNIT_ENTERED_VEHICLE");
	self:RegisterEvent("UNIT_EXITED_VEHICLE");
	self:RegisterEvent("COMPANION_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("LEARNED_SPELL_IN_TAB");
	self:RegisterEvent("PET_STABLE_UPDATE");
	self:RegisterEvent("PET_STABLE_SHOW");
	self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW");
	self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE");
	self:RegisterEvent("UPDATE_SUMMONPETS_ACTION");
	self:RegisterEvent("LOSS_OF_CONTROL_ADDED");
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE");
end

function ActionBarActionEventsFrame_OnEvent(self, event, ...)
	if ( event == "UNIT_INVENTORY_CHANGED" ) then
		local unit = ...;
		if ( unit == "player" and self.tooltipOwner and GameTooltip:GetOwner() == self.tooltipOwner ) then
			ActionButton_SetTooltip(self.tooltipOwner);
		end
	else
		for k, frame in pairs(self.frames) do
			ActionButton_OnEvent(frame, event, ...);
		end
	end
end

function ActionBarActionEventsFrame_RegisterFrame(frame)
	ActionBarActionEventsFrame.frames[frame] = frame;
end

function ActionBarActionEventsFrame_UnregisterFrame(frame)
	ActionBarActionEventsFrame.frames[frame] = nil;
end

function ActionButton_OnLoad (self)
	self.flashing = 0;
	self.flashtime = 0;
	self:SetAttribute("showgrid", 0);
	self:SetAttribute("type", "action");
	self:SetAttribute("checkselfcast", true);
	self:SetAttribute("checkfocuscast", true);
	self:SetAttribute("useparent-unit", true);
	self:SetAttribute("useparent-actionpage", true);
	self:RegisterForDrag("LeftButton", "RightButton");
	self:RegisterForClicks("AnyUp");
	ActionBarButtonEventsFrame_RegisterFrame(self);
	ActionButton_UpdateAction(self);
	ActionButton_UpdateHotkeys(self, self.buttonType);
end

function ActionButton_UpdateHotkeys (self, actionButtonType)
	local id;
    if ( not actionButtonType ) then
        actionButtonType = "ACTIONBUTTON";
		id = self:GetID();
	else
		if ( actionButtonType == "MULTICASTACTIONBUTTON" ) then
			id = self.buttonIndex;
		else
			id = self:GetID();
		end
    end

    local hotkey = self.HotKey;
    local key = GetBindingKey(actionButtonType..id) or
                GetBindingKey("CLICK "..self:GetName()..":LeftButton");

	local text = GetBindingText(key, 1);
    if ( text == "" ) then
        hotkey:SetText(RANGE_INDICATOR);
        hotkey:Hide();
    else
        hotkey:SetText(text);
        hotkey:Show();
    end
end

function ActionButton_CalculateAction (self, button)
	if ( not button ) then
		button = SecureButton_GetEffectiveButton(self);
	end
	if ( self:GetID() > 0 ) then
		local page = SecureButton_GetModifiedAttribute(self, "actionpage", button);
		if ( not page ) then
			page = GetActionBarPage();
			if ( self.isExtra ) then
				page = GetExtraBarIndex();
			elseif ( self.buttonType == "MULTICASTACTIONBUTTON" ) then
				page = GetMultiCastBarIndex();
			end
		end
		return (self:GetID() + ((page - 1) * NUM_ACTIONBAR_BUTTONS));
	else
		return SecureButton_GetModifiedAttribute(self, "action", button) or 1;
	end
end

function ActionButton_UpdateAction (self, force)
	local action = ActionButton_CalculateAction(self);
	if ( action ~= self.action or force ) then
		self.action = action;
		SetActionUIButton(self, action, self.cooldown);
		ActionButton_Update(self);
		ActionButton_UpdateHighlightMark(self, action);
	end
end

function ActionButton_Update (self)
	local action = self.action;
	local icon = self.icon;
	local buttonCooldown = self.cooldown;
	local texture = GetActionTexture(action);

	self.zoneAbilityDisabled = false;
	icon:SetDesaturated(false);
	local type, id = GetActionInfo(action);
	if ((type == "spell" or type == "companion") and ZoneAbilityFrame and ZoneAbilityFrame.baseName and not HasZoneAbility()) then
		local name = GetSpellInfo(ZoneAbilityFrame.baseName);
		local abilityName = GetSpellInfo(id);
		if (name == abilityName) then
			texture = GetLastZoneAbilitySpellTexture();
			self.zoneAbilityDisabled = true;
			icon:SetDesaturated(true);
		end
	end

	if ( HasAction(action) ) then
		if ( not self.eventsRegistered ) then
			ActionBarActionEventsFrame_RegisterFrame(self);
			self.eventsRegistered = true;
		end

		if ( not self:GetAttribute("statehidden") ) then
			self:Show();
		end
		ActionButton_UpdateState(self);
		ActionButton_UpdateUsable(self);
		ActionButton_UpdateCooldown(self);
		ActionButton_UpdateFlash(self);
	else
		if ( self.eventsRegistered ) then
			ActionBarActionEventsFrame_UnregisterFrame(self)
			self.eventsRegistered = nil;
		end

		if ( self:GetAttribute("showgrid") == 0 ) then
			self:Hide();
		else
			buttonCooldown:Hide();
		end

		ClearChargeCooldown(self);
	end

	-- Add a green border if button is an equipped item
	local border = self.Border;
	if border then
		if ( IsEquippedAction(action) ) then
			border:SetVertexColor(0, 1.0, 0, 0.35);
			border:Show();
		else
			border:Hide();
		end
	end

	-- Update Action Text
	local actionName = self.Name;
	if actionName then
		if ( not IsConsumableAction(action) and not IsStackableAction(action) and (IsItemAction(action) or GetActionCount(action) == 0) ) then
			actionName:SetText(GetActionText(action));
		else
			actionName:SetText("");
		end
	end

	-- Update icon and hotkey text
	if ( texture ) then
		icon:SetTexture(texture);
		icon:Show();
		self.rangeTimer = -1;
		ActionButton_UpdateCount(self);
	else
		self.Count:SetText("");
		icon:Hide();
		buttonCooldown:Hide();
		self.rangeTimer = nil;
		local hotkey = self.HotKey;
        if ( hotkey:GetText() == RANGE_INDICATOR ) then
			hotkey:Hide();
		else
			hotkey:SetVertexColor(0.6, 0.6, 0.6);
		end
	end

	-- Update flyout appearance
	ActionButton_UpdateFlyout(self);

	ActionButton_UpdateOverlayGlow(self);

	-- Update tooltip
	if ( GameTooltip:GetOwner() == self ) then
		ActionButton_SetTooltip(self);
	end

	self.feedback_action = action;
end

function ActionButton_UpdateHighlightMark(self, action)
	if ( self.NewActionTexture ) then
		self.NewActionTexture:SetShown(GetNewActionHighlightMark(action));
	end
end

function ActionButton_ShowGrid (button)
	assert(button);

	if ( issecure() ) then
		button:SetAttribute("showgrid", button:GetAttribute("showgrid") + 1);
	end

	if ( button.NormalTexture ) then
		button.NormalTexture:SetVertexColor(1.0, 1.0, 1.0, 0.5);
	end

	if ( button:GetAttribute("showgrid") >= 1 and not button:GetAttribute("statehidden") ) then
		button:Show();
	end
end

function ActionButton_HideGrid (button)
	assert(button);

	local showgrid = button:GetAttribute("showgrid");

	if ( issecure() ) then
		if ( showgrid > 0 ) then
			button:SetAttribute("showgrid", showgrid - 1);
		end
	end

	if ( button:GetAttribute("showgrid") == 0 and not HasAction(button.action) ) then
		button:Hide();
	end
end

function ActionButton_UpdateState (button)
	assert(button);

	local action = button.action;
	local isChecked = IsCurrentAction(action) or IsAutoRepeatAction(action);
	button:SetChecked(isChecked);
end

function ActionButton_UpdateUsable (self)
	local icon = self.icon;
	local normalTexture = self.NormalTexture;
	if ( not normalTexture ) then
		return;
	end

	local isUsable, notEnoughMana = IsUsableAction(self.action);
	if ( isUsable ) then
		icon:SetVertexColor(1.0, 1.0, 1.0);
		normalTexture:SetVertexColor(1.0, 1.0, 1.0);
	elseif ( notEnoughMana ) then
		icon:SetVertexColor(0.5, 0.5, 1.0);
		normalTexture:SetVertexColor(0.5, 0.5, 1.0);
	else
		icon:SetVertexColor(0.4, 0.4, 0.4);
		normalTexture:SetVertexColor(1.0, 1.0, 1.0);
	end
end

function ActionButton_UpdateCount (self)
	local text = self.Count;
	local action = self.action;
	if ( IsConsumableAction(action) or IsStackableAction(action) or (not IsItemAction(action) and GetActionCount(action) > 0) ) then
		local count = GetActionCount(action);
		if ( count > (self.maxDisplayCount or 9999 ) ) then
			text:SetText("*");
		else
			text:SetText(count);
		end
	else
		local charges, maxCharges, chargeStart, chargeDuration = GetActionCharges(action);
		if (maxCharges > 1) then
			text:SetText(charges);
		else
			text:SetText("");
		end
	end
end

function ActionButton_UpdateCooldown(self)
	local locStart, locDuration;
	local start, duration, enable, charges, maxCharges, chargeStart, chargeDuration;
	if ( self.spellID ) then
		locStart, locDuration = GetSpellLossOfControlCooldown(self.spellID);
		start, duration, enable = GetSpellCooldown(self.spellID);
		charges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(self.spellID);
	else
		locStart, locDuration = GetActionLossOfControlCooldown(self.action);
		start, duration, enable = GetActionCooldown(self.action);
		charges, maxCharges, chargeStart, chargeDuration = GetActionCharges(self.action);
	end

	if ( (locStart + locDuration) > (start + duration) ) then
		if ( self.cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL ) then
			self.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge-LoC");
			self.cooldown:SetSwipeColor(0.17, 0, 0);
			self.cooldown:SetHideCountdownNumbers(true);
			self.cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL;
		end

		CooldownFrame_Set(self.cooldown, locStart, locDuration, true, true);
		ClearChargeCooldown(self);
	else
		if ( self.cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL ) then
			self.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge");
			self.cooldown:SetSwipeColor(0, 0, 0);
			self.cooldown:SetHideCountdownNumbers(false);
			self.cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL;
		end

		if( locStart > 0 ) then
			self.cooldown:SetScript("OnCooldownDone", ActionButton_OnCooldownDone );
		end

		if ( charges and maxCharges and maxCharges > 1 and charges < maxCharges ) then
			StartChargeCooldown(self, chargeStart, chargeDuration);
		else
			ClearChargeCooldown(self);
		end

		CooldownFrame_Set(self.cooldown, start, duration, enable);
	end
end

function ActionButton_OnCooldownDone(self)
	self:SetScript("OnCooldownDone", nil);
	ActionButton_UpdateCooldown(self:GetParent());
end

-- Charge Cooldown stuff

local numChargeCooldowns = 0;
local function CreateChargeCooldownFrame(parent)
	numChargeCooldowns = numChargeCooldowns + 1;
	cooldown = CreateFrame("Cooldown", "ChargeCooldown"..numChargeCooldowns, parent, "CooldownFrameTemplate");
	cooldown:SetHideCountdownNumbers(true);
	cooldown:SetDrawSwipe(false);

	cooldown:SetAllPoints(parent);
	cooldown:SetFrameStrata("TOOLTIP");

	return cooldown;
end

function StartChargeCooldown(parent, chargeStart, chargeDuration)
	if chargeStart == 0 then
		ClearChargeCooldown(parent);
		return;
	end

	parent.chargeCooldown = parent.chargeCooldown or CreateChargeCooldownFrame(parent);

	CooldownFrame_Set(parent.chargeCooldown, chargeStart, chargeDuration, true, true);
end

function ClearChargeCooldown(parent)
	if parent.chargeCooldown then
		CooldownFrame_Clear(parent.chargeCooldown);
	end
end


--Overlay stuff
local unusedOverlayGlows = {};
local numOverlays = 0;
function ActionButton_GetOverlayGlow()
	local overlay = tremove(unusedOverlayGlows);
	if ( not overlay ) then
		numOverlays = numOverlays + 1;
		overlay = CreateFrame("Frame", "ActionButtonOverlay"..numOverlays, UIParent, "ActionBarButtonSpellActivationAlert");
	end
	return overlay;
end

function ActionButton_UpdateOverlayGlow(self)
	local spellType, id, subType  = GetActionInfo(self.action);
	if ( spellType == "spell" and IsSpellOverlayed(id) ) then
		ActionButton_ShowOverlayGlow(self);
	elseif ( spellType == "macro" ) then
		local _, _, spellId = GetMacroSpell(id);
		if ( spellId and IsSpellOverlayed(spellId) ) then
			ActionButton_ShowOverlayGlow(self);
		else
			ActionButton_HideOverlayGlow(self);
		end
	else
		ActionButton_HideOverlayGlow(self);
	end
end

function ActionButton_ShowOverlayGlow(self)
	if ( self.overlay ) then
		if ( self.overlay.animOut:IsPlaying() ) then
			self.overlay.animOut:Stop();
			self.overlay.animIn:Play();
		end
	else
		self.overlay = ActionButton_GetOverlayGlow();
		local frameWidth, frameHeight = self:GetSize();
		self.overlay:SetParent(self);
		self.overlay:ClearAllPoints();
		--Make the height/width available before the next frame:
		self.overlay:SetSize(frameWidth * 1.4, frameHeight * 1.4);
		self.overlay:SetPoint("TOPLEFT", self, "TOPLEFT", -frameWidth * 0.2, frameHeight * 0.2);
		self.overlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", frameWidth * 0.2, -frameHeight * 0.2);
		self.overlay.animIn:Play();
	end
end

function ActionButton_HideOverlayGlow(self)
	if ( self.overlay ) then
		if ( self.overlay.animIn:IsPlaying() ) then
			self.overlay.animIn:Stop();
		end
		if ( self:IsVisible() ) then
			self.overlay.animOut:Play();
		else
			ActionButton_OverlayGlowAnimOutFinished(self.overlay.animOut);	--We aren't shown anyway, so we'll instantly hide it.
		end
	end
end

function ActionButton_OverlayGlowAnimOutFinished(animGroup)
	local overlay = animGroup:GetParent();
	local actionButton = overlay:GetParent();
	overlay:Hide();
	tinsert(unusedOverlayGlows, overlay);
	actionButton.overlay = nil;
end

function ActionButton_OverlayGlowOnUpdate(self, elapsed)
	AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, 0.01);
	local cooldown = self:GetParent().cooldown;
	-- we need some threshold to avoid dimming the glow during the gdc
	-- (using 1500 exactly seems risky, what if casting speed is slowed or something?)
	if(cooldown and cooldown:IsShown() and cooldown:GetCooldownDuration() > 3000) then
		self:SetAlpha(0.5);
	else
		self:SetAlpha(1.0);
	end
end

function ActionButton_OnEvent (self, event, ...)
	local arg1 = ...;
	if ((event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") or event == "LEARNED_SPELL_IN_TAB") then
		if ( GameTooltip:GetOwner() == self ) then
			ActionButton_SetTooltip(self);
		end
	elseif ( event == "ACTIONBAR_SLOT_CHANGED" ) then
		if ( arg1 == 0 or arg1 == tonumber(self.action) ) then
			ActionButton_Update(self);
		end
		return;
	elseif ( event == "PLAYER_ENTERING_WORLD" ) then
		ActionButton_Update(self);
		return;
	elseif ( event == "UPDATE_SHAPESHIFT_FORM" ) then
		-- need to listen for UPDATE_SHAPESHIFT_FORM because attack icons change when the shapeshift form changes
		-- This is NOT intended to update everything about shapeshifting; most stuff should be handled by ActionBar-specific events such as UPDATE_BONUS_ACTIONBAR, UPDATE_USABLE, etc.
		local texture = GetActionTexture(self.action);
		if (texture) then
			self.icon:SetTexture(texture);
		end
		return;
	elseif ( event == "ACTIONBAR_SHOWGRID" ) then
		ActionButton_ShowGrid(self);
		return;
	elseif ( event == "ACTIONBAR_HIDEGRID" ) then
		ActionButton_HideGrid(self);
		return;
	elseif ( event == "UPDATE_BINDINGS" ) then
		ActionButton_UpdateHotkeys(self, self.buttonType);
		return;
	elseif ( event == "PLAYER_TARGET_CHANGED" ) then	-- All event handlers below this line are only set when the button has an action
		self.rangeTimer = -1;
	elseif ( (event == "ACTIONBAR_UPDATE_STATE") or
		((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and (arg1 == "player")) or
		((event == "COMPANION_UPDATE") and (arg1 == "MOUNT")) ) then
		ActionButton_UpdateState(self);
	elseif ( event == "ACTIONBAR_UPDATE_USABLE" ) then
		ActionButton_UpdateUsable(self);
	elseif ( event == "LOSS_OF_CONTROL_UPDATE" ) then
		ActionButton_UpdateCooldown(self);
	elseif ( event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "LOSS_OF_CONTROL_ADDED" ) then
		ActionButton_UpdateCooldown(self);
		-- Update tooltip
		if ( GameTooltip:GetOwner() == self ) then
			ActionButton_SetTooltip(self);
		end
	elseif ( event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE"  or event == "ARCHAEOLOGY_CLOSED" ) then
		ActionButton_UpdateState(self);
	elseif ( event == "PLAYER_ENTER_COMBAT" ) then
		if ( IsAttackAction(self.action) ) then
			ActionButton_StartFlash(self);
		end
	elseif ( event == "PLAYER_LEAVE_COMBAT" ) then
		if ( IsAttackAction(self.action) ) then
			ActionButton_StopFlash(self);
		end
	elseif ( event == "START_AUTOREPEAT_SPELL" ) then
		if ( IsAutoRepeatAction(self.action) ) then
			ActionButton_StartFlash(self);
		end
	elseif ( event == "STOP_AUTOREPEAT_SPELL" ) then
		if ( ActionButton_IsFlashing(self) and not IsAttackAction(self.action) ) then
			ActionButton_StopFlash(self);
		end
	elseif ( event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW") then
		-- Has to update everything for now, but this event should happen infrequently
		ActionButton_Update(self);
	elseif ( event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" ) then
		local actionType, id, subType = GetActionInfo(self.action);
		if ( actionType == "spell" and id == arg1 ) then
			ActionButton_ShowOverlayGlow(self);
		elseif ( actionType == "macro" ) then
			local _, _, spellId = GetMacroSpell(id);
			if ( spellId and spellId == arg1 ) then
				ActionButton_ShowOverlayGlow(self);
			end
		elseif (actionType == "flyout" and FlyoutHasSpell(id, arg1)) then
			ActionButton_ShowOverlayGlow(self);
		end
	elseif ( event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" ) then
		local actionType, id, subType = GetActionInfo(self.action);
		if ( actionType == "spell" and id == arg1 ) then
			ActionButton_HideOverlayGlow(self);
		elseif ( actionType == "macro" ) then
			local _, _, spellId = GetMacroSpell(id);
			if (spellId and spellId == arg1 ) then
				ActionButton_HideOverlayGlow(self);
			end
		elseif (actionType == "flyout" and FlyoutHasSpell(id, arg1)) then
			ActionButton_HideOverlayGlow(self);
		end
	elseif ( event == "SPELL_UPDATE_CHARGES" ) then
		ActionButton_UpdateCount(self);
	elseif ( event == "UPDATE_SUMMONPETS_ACTION" ) then
		local actionType, id = GetActionInfo(self.action);
		if (actionType == "summonpet") then
			local texture = GetActionTexture(self.action);
			if (texture) then
				self.icon:SetTexture(texture);
			end
		end
	end
end

function ActionButton_SetTooltip (self)
	if ( GetCVar("UberTooltips") == "1" ) then
		GameTooltip_SetDefaultAnchor(GameTooltip, self);
	else
		local parent = self:GetParent();
		if ( parent == MultiBarBottomRight or parent == MultiBarRight or parent == MultiBarLeft ) then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		end
	end
	if ( GameTooltip:SetAction(self.action) ) then
		self.UpdateTooltip = ActionButton_SetTooltip;
	else
		self.UpdateTooltip = nil;
	end
end

function ActionButton_OnUpdate (self, elapsed)
	if ( ActionButton_IsFlashing(self) ) then
		local flashtime = self.flashtime;
		flashtime = flashtime - elapsed;

		if ( flashtime <= 0 ) then
			local overtime = -flashtime;
			if ( overtime >= ATTACK_BUTTON_FLASH_TIME ) then
				overtime = 0;
			end
			flashtime = ATTACK_BUTTON_FLASH_TIME - overtime;

			local flashTexture = self.Flash;
			if ( flashTexture:IsShown() ) then
				flashTexture:Hide();
			else
				flashTexture:Show();
			end
		end

		self.flashtime = flashtime;
	end

	-- Handle range indicator
	local rangeTimer = self.rangeTimer;
	if ( rangeTimer ) then
		rangeTimer = rangeTimer - elapsed;

		if ( rangeTimer <= 0 ) then
			local count = self.HotKey;
			local valid = IsActionInRange(self.action);
			if ( count:GetText() == RANGE_INDICATOR ) then
				if ( valid == false ) then
					count:Show();
					count:SetVertexColor(1.0, 0.1, 0.1);
				elseif ( valid ) then
					count:Show();
					count:SetVertexColor(0.6, 0.6, 0.6);
				else
					count:Hide();
				end
			else
				if ( valid == false ) then
					count:SetVertexColor(1.0, 0.1, 0.1);
				else
					count:SetVertexColor(0.6, 0.6, 0.6);
				end
			end
			rangeTimer = TOOLTIP_UPDATE_TIME;
		end

		self.rangeTimer = rangeTimer;
	end
end

function ActionButton_GetPagedID (self)
    return self.action;
end

function ActionButton_UpdateFlash (self)
	local action = self.action;
	if ( (IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action) ) then
		ActionButton_StartFlash(self);
	else
		ActionButton_StopFlash(self);
	end
end

function ActionButton_StartFlash (self)
	self.flashing = 1;
	self.flashtime = 0;
	ActionButton_UpdateState(self);
end

function ActionButton_StopFlash (self)
	self.flashing = 0;
	self.Flash:Hide();
	ActionButton_UpdateState (self);
end

function ActionButton_IsFlashing (self)
	if ( self.flashing == 1 ) then
		return 1;
	end

	return nil;
end

function ActionButton_UpdateFlyout(self)
	if not self.FlyoutArrow then
		return;
	end

	local actionType = GetActionInfo(self.action);
	if (actionType == "flyout") then
		-- Update border and determine arrow position
		local arrowDistance;
		if ((SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:GetParent() == self) or GetMouseFocus() == self) then
			self.FlyoutBorder:Show();
			self.FlyoutBorderShadow:Show();
			arrowDistance = 5;
		else
			self.FlyoutBorder:Hide();
			self.FlyoutBorderShadow:Hide();
			arrowDistance = 2;
		end

		-- Update arrow
		self.FlyoutArrow:Show();
		self.FlyoutArrow:ClearAllPoints();
		local direction = self:GetAttribute("flyoutDirection");
		if (direction == "LEFT") then
			self.FlyoutArrow:SetPoint("LEFT", self, "LEFT", -arrowDistance, 0);
			SetClampedTextureRotation(self.FlyoutArrow, 270);
		elseif (direction == "RIGHT") then
			self.FlyoutArrow:SetPoint("RIGHT", self, "RIGHT", arrowDistance, 0);
			SetClampedTextureRotation(self.FlyoutArrow, 90);
		elseif (direction == "DOWN") then
			self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -arrowDistance);
			SetClampedTextureRotation(self.FlyoutArrow, 180);
		else
			self.FlyoutArrow:SetPoint("TOP", self, "TOP", 0, arrowDistance);
			SetClampedTextureRotation(self.FlyoutArrow, 0);
		end
	else
		self.FlyoutBorder:Hide();
		self.FlyoutBorderShadow:Hide();
		self.FlyoutArrow:Hide();
	end
end

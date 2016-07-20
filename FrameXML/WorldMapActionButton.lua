WorldMapActionButtonMixin = {};

function WorldMapActionButtonMixin:OnEvent(event, ...)
	if event == "SPELL_UPDATE_COOLDOWN" then
		self:UpdateCooldown();
	elseif event == "CURRENT_SPELL_CAST_CHANGED" then
		self:UpdateCastingState();
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unitTag, spellName, rank, lineID, spellID = ...;
		if spellID == GetWorldMapActionButtonSpellInfo() then
			PlaySound("UI_OrderHall_Talent_NukeFromOrbit");
		end
	end
end

function WorldMapActionButtonMixin:SetMapAreaID(mapAreaID)
	if self.mapAreaID ~= mapAreaID then
		self.mapAreaID = mapAreaID;
		self:Refresh();
	end
end

function WorldMapActionButtonMixin:SetHasWorldQuests(hasWorldQuests)
	if self.hasWorldQuests ~= hasWorldQuests then
		self.hasWorldQuests = hasWorldQuests;
		self:Refresh();
	end
end

function WorldMapActionButtonMixin:GetDisplayLocation(useAlternateLocation)
	return useAlternateLocation and LE_MAP_OVERLAY_DISPLAY_LOCATION_BOTTOM_LEFT or LE_MAP_OVERLAY_DISPLAY_LOCATION_BOTTOM_RIGHT;
end

function WorldMapActionButtonMixin:SetOnCastChangedCallback(onCastChangedCallback)
	self.onCastChangedCallback = onCastChangedCallback;
end

function WorldMapActionButtonMixin:IsUsingAction()
	return SpellCanTargetQuest();
end

function WorldMapActionButtonMixin:UpdateCastingState()
	local isUsingAction = self:IsUsingAction();
	if self.castingState ~= isUsingAction then
		self.castingState = isUsingAction;
		if self.onCastChangedCallback then
			self.onCastChangedCallback(self.castingState);
		end
	end
end

function WorldMapActionButtonMixin:Clear()
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
	self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED");
	self.spellID = nil;
	self.castingState = nil;
	self:Hide();

	if self:IsUsingAction() then
		SpellStopTargeting();
	end
end

function WorldMapActionButtonMixin:Refresh()
	if not self.mapAreaID or not self.hasWorldQuests then
		self:Clear();
		return;
	end

	local spellID, spellVisualKitID = GetWorldMapActionButtonSpellInfo();
	if not spellID then
		self:Clear();
		return;
	end

	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");

	self.spellID = spellID;

	local _, _, spellIcon = GetSpellInfo(self.spellID);
	self.SpellButton:SetNormalTexture(spellIcon);
	self.SpellButton:SetPushedTexture(spellIcon);

	self:UpdateCooldown();

	self:Show();
end

function WorldMapActionButtonMixin:UpdateCooldown()
	local start, duration, enable = GetSpellCooldown(self.spellID);
	CooldownFrame_Set(self.SpellButton.Cooldown, start, duration, enable);

	self.SpellButton:SetEnabled(duration == 0);
end

function WorldMapActionButtonMixin:OnClick()
	ClickWorldMapActionButton();
end

function WorldMapActionButtonMixin:OnEnter()
	WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -60);
	WorldMapTooltip:SetSpellByID(self.spellID);
end

function WorldMapActionButtonMixin:OnLeave()
	WorldMapTooltip:Hide();
end
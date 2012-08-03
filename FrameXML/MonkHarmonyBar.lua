

MONKHARMONYBAR_SHOW_LEVEL = 0;

function MonkHarmonyBar_SetEnergy(self, active)
	if ( active ) then
		if (self.deactivate:IsPlaying()) then
			self.deactivate:Stop();
		end
		
		if (not self.activate:IsPlaying()) then
			self.activate:Play();
		end
	else
		if (self.activate:IsPlaying()) then
			self.activate:Stop();
		end
		
		if (not self.deactivate:IsPlaying()) then
			self.deactivate:Play();
		end
	end
end

function MonkHarmonyBar_Update(self)
	local light = UnitPower( MonkHarmonyBar:GetParent().unit, SPELL_POWER_LIGHT_FORCE );

	-- if max light changed, show/hide the 5th and update anchors 
	local maxLight = UnitPowerMax( MonkHarmonyBar:GetParent().unit, SPELL_POWER_LIGHT_FORCE );
	if ( self.maxLight ~= maxLight ) then
		if ( maxLight == 4 ) then
			self.lightEnergy1:SetPoint("LEFT", -43, 1);
			self.lightEnergy2:SetPoint("LEFT", self.lightEnergy1, "RIGHT", 5, 0);
			self.lightEnergy3:SetPoint("LEFT", self.lightEnergy2, "RIGHT", 5, 0);
			self.lightEnergy4:SetPoint("LEFT", self.lightEnergy3, "RIGHT", 5, 0);
			self.lightEnergy5:Hide();
		else
			self.lightEnergy1:SetPoint("LEFT", -46, 1);
			self.lightEnergy2:SetPoint("LEFT", self.lightEnergy1, "RIGHT", 1, 0);
			self.lightEnergy3:SetPoint("LEFT", self.lightEnergy2, "RIGHT", 1, 0);
			self.lightEnergy4:SetPoint("LEFT", self.lightEnergy3, "RIGHT", 1, 0);
			self.lightEnergy5:Show();
		end
		self.maxLight = maxLight;
	end
	
	for i = 1, self.maxLight do
		MonkHarmonyBar_SetEnergy(self["lightEnergy"..i], i<=light);
	end
end



function MonkHarmonyBar_OnLoad (self)
	-- Disable frame if not a monk
	local _, class = UnitClass("player");
	if ( class ~= "MONK" ) then
		self:Hide();
		return;
	elseif UnitLevel("player") < MONKHARMONYBAR_SHOW_LEVEL then
		self:RegisterEvent("PLAYER_LEVEL_UP");
		self:SetAlpha(0);
	end
	self.maxLight = 4;
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 2);
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("UNIT_DISPLAYPOWER");
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", "vehicle");
end



function MonkHarmonyBar_OnEvent (self, event, arg1, arg2)
	if ( event == "UNIT_POWER_FREQUENT" ) then
		if ( arg1 == self:GetParent().unit and (arg2 == "LIGHT_FORCE" or arg2 == "DARK_FORCE") ) then
			MonkHarmonyBar_Update(self);
		end
	elseif( event ==  "PLAYER_LEVEL_UP" ) then
		local level = arg1;
		if level >= MONKHARMONYBAR_SHOW_LEVEL then
			self:UnregisterEvent("PLAYER_LEVEL_UP");
			self.showAnim:Play();
			MonkHarmonyBar_Update(self);
		end
	else
		MonkHarmonyBar_Update(self);
	end
end



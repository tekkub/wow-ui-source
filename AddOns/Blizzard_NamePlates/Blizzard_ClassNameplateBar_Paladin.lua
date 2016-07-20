ClassNameplateBarPaladin = {};

function ClassNameplateBarPaladin:OnLoad()
	self.class = "PALADIN";
	self.spec = SPEC_PALADIN_RETRIBUTION;
	self.powerToken = "HOLY_POWER";
	
	ClassNameplateBar.OnLoad(self);
end

function ClassNameplateBarPaladin:OnEvent(event, ...)
	local eventHandled = ClassNameplateBar.OnEvent(self, event, ...);
	if( not eventHandled and event == "PLAYER_LEVEL_UP" ) then
		local level = ...;
		if level >= PALADINPOWERBAR_SHOW_LEVEL then
			self:UnregisterEvent("PLAYER_LEVEL_UP");
			self:ShowNameplateBar();
			self:UpdatePower();
		end
	end
end

function ClassNameplateBarPaladin:Setup()
	if (self:MatchesClass() and self:MatchesSpec() and UnitLevel("player") < PALADINPOWERBAR_SHOW_LEVEL) then
		self:RegisterEvent("PLAYER_LEVEL_UP");
		self:HideNameplateBar();
	else
		ClassNameplateBar.Setup(self);
	end
end

function ClassNameplateBarPaladin:ToggleHolyRune(self, enabled)
	if self.enabled ~= enabled then

		self.enabled = enabled;
		if self.enabled then
			self.TurnOff:Stop();
			self.TurnOn:Play();
		else
			self.TurnOn:Stop();
			self.TurnOff:Play();
		end
	end
end

function ClassNameplateBarPaladin:UpdatePower()
	if ( self.delayedUpdate ) then
		return;
	end
	
	local numHolyPower = UnitPower("player", SPELL_POWER_HOLY_POWER);
	local maxHolyPower = UnitPowerMax("player", SPELL_POWER_HOLY_POWER);
	
	-- If we had more than HOLY_POWER_FULL and then used HOLY_POWER_FULL amount of power, fade out
	-- the top 3 and then move the remaining power from the bottom up to the top
	if ( self.lastPower and self.lastPower > HOLY_POWER_FULL and numHolyPower == self.lastPower - HOLY_POWER_FULL ) then
		for i = 1, HOLY_POWER_FULL do
			self:ToggleHolyRune(self.Runes[i], false);
		end
		self.delayedUpdate = true;
		self.lastPower = nil;
		C_Timer.After(0.2, function()
			self.delayedUpdate = false;
			self:UpdatePower();
		end);
	else
		for i = 1, numHolyPower do
			self:ToggleHolyRune(self.Runes[i], true);
		end
		for i = numHolyPower + 1, maxHolyPower do
			self:ToggleHolyRune(self.Runes[i], false);
		end
		self.lastPower = numHolyPower;
	end
end

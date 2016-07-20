ComboPointPowerBar = {};

function ComboPointPowerBar:OnLoad()
	if (GetCVar("comboPointLocation") ~= "2") then
		self:Hide();
		return;
	end
	
	self.class = "ROGUE";
	self:SetPowerTokens("COMBO_POINTS");
	
	for i = 1, #self.ComboPoints do
		self.ComboPoints[i].on = false;
	end
	self.maxUsablePoints = 5;
	
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 2);
	ClassPowerBar.OnLoad(self);
end

function ComboPointPowerBar:OnEvent(event, arg1, arg2)
	if (event == "UNIT_DISPLAYPOWER" or event == "PLAYER_ENTERING_WORLD" ) then
		self:SetupDruid();
	elseif (event == "UNIT_MAXPOWER") then
		self:UpdateMaxPower();
	else
		ClassPowerBar.OnEvent(self, event, arg1, arg2);
	end
end

function ComboPointPowerBar:Setup()
	local showBar = ClassPowerBar.Setup(self);
	if (showBar) then
		self:RegisterUnitEvent("UNIT_MAXPOWER", "player");
		self:SetPoint("TOP", self:GetParent(), "BOTTOM", 50, 38);
		self:UpdateMaxPower();
	else
		self:SetupDruid();
	end
end

function ComboPointPowerBar:SetupDruid()
	local _, myclass = UnitClass("player");
	if (myclass ~= "DRUID") then
		return;
	end
	self:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	local powerType, powerToken = UnitPowerType("player");
	local showBar = false;
	if (powerType == SPELL_POWER_ENERGY) then
		showBar = true;
		self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player");
		self:RegisterUnitEvent("UNIT_MAXPOWER", "player");
	else
		self:UnregisterEvent("UNIT_POWER_FREQUENT");
		self:UnregisterEvent("UNIT_MAXPOWER");
	end
	if (showBar) then
		self:SetPoint("TOP", self:GetParent(), "BOTTOM", 50, 38);
		self:Show();
		self:UpdateMaxPower();
		self:UpdatePower();
	else
		self:Hide();
	end
end

-- Data driven layout tweaks for differing numbers of combo point frames.
-- Indexed by max "usable" combo points (see below)
local comboPointMaxToLayout = {
	[5] = {
		["width"] = 20, 
		["height"] = 21,
		["xOffs"] = 1,
	},
	[6] = {
		["width"] = 18,
		["height"] = 19,
		["xOffs"] = -1,
	},
};

local function UpdateComboPointLayout(maxUsablePoints, comboPoint, previousComboPoint)
	local layout = comboPointMaxToLayout[maxUsablePoints];

	comboPoint:SetSize(layout.width, layout.height);
	comboPoint.PointOff:SetSize(layout.width, layout.height);
	comboPoint.Point:SetSize(layout.width, layout.height);

	if (previousComboPoint) then
		comboPoint:SetPoint("LEFT", previousComboPoint, "RIGHT", layout.xOffs, 0);
	end
end

function ComboPointPowerBar:UpdateMaxPower()
	local maxComboPoints = UnitPowerMax("player", SPELL_POWER_COMBO_POINTS);
	
	self.ComboPoints[6]:SetShown(maxComboPoints == 6);
	for i = 1, #self.ComboBonus do
		self.ComboBonus[i]:SetShown(maxComboPoints == 8);
	end
	
	if (maxComboPoints == 5 or maxComboPoints == 8) then
		self.maxUsablePoints = 5;
	elseif (maxComboPoints == 6) then
		self.maxUsablePoints = 6;
	end

	for i = 1, self.maxUsablePoints do
		UpdateComboPointLayout(self.maxUsablePoints, self.ComboPoints[i], self.ComboPoints[i - 1]);
	end
end

function ComboPointPowerBar:AnimIn(frame)
	if (not frame.on) then
		frame.on = true;
		frame.AnimIn:Play();

		if (frame.PointAnim) then
			frame.PointAnim:Play();
		end
	end
end

function ComboPointPowerBar:AnimOut(frame)
	if (frame.on) then
		frame.on = false;

		if (frame.PointAnim) then
			frame.PointAnim:Play(true);
		end

		frame.AnimIn:Stop();
		frame.AnimOut:Play();
	end
end


function ComboPointPowerBar:UpdatePower()
	if ( self.delayedUpdate ) then
		return;
	end
	
	local comboPoints = UnitPower("player", SPELL_POWER_COMBO_POINTS);
	local maxComboPoints = UnitPowerMax("player", SPELL_POWER_COMBO_POINTS);
	
	-- If we had more than self.maxUsablePoints and then used a finishing move, fade out
	-- the top row of points and then move the remaining points from the bottom up to the top
	if ( self.lastPower and self.lastPower > self.maxUsablePoints and comboPoints == self.lastPower - self.maxUsablePoints ) then
		for i = 1, self.maxUsablePoints do
			self:AnimOut(self.ComboPoints[i]);
		end
		self.delayedUpdate = true;
		self.lastPower = nil;
		C_Timer.After(0.45, function()
			self.delayedUpdate = false;
			self:UpdatePower();
		end);
	else
		for i = 1, min(comboPoints, self.maxUsablePoints) do
			if (not self.ComboPoints[i].on) then
				self:AnimIn(self.ComboPoints[i]);
			end
		end
		for i = comboPoints + 1, self.maxUsablePoints do
			if (self.ComboPoints[i].on) then
			self:AnimOut(self.ComboPoints[i]);
		end
		end
		
		if (maxComboPoints == 8) then
			for i = 6, comboPoints do
				self:AnimIn(self.ComboBonus[i-5]);
			end
			for i = max(comboPoints + 1, 6), 8 do
				self:AnimOut(self.ComboBonus[i-5]);
			end
		end
		
		self.lastPower = comboPoints;
	end
end

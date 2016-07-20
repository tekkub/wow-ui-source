CHARACTER_SELECT_ROTATION_START_X = nil;
CHARACTER_SELECT_INITIAL_FACING = nil;

CHARACTER_ROTATION_CONSTANT = 0.6;

MAX_CHARACTERS_DISPLAYED = 12;
MAX_CHARACTERS_DISPLAYED_BASE = MAX_CHARACTERS_DISPLAYED;

MAX_CHARACTERS_PER_REALM = 200; -- controled by the server now, so lets set it up high

CHARACTER_LIST_OFFSET = 0;

CHARACTER_SELECT_BACK_FROM_CREATE = false;

MOVING_TEXT_OFFSET = 12;
DEFAULT_TEXT_OFFSET = 0;
CHARACTER_BUTTON_HEIGHT = 57;
CHARACTER_LIST_TOP = 688;
AUTO_DRAG_TIME = 0.5;				-- in seconds

CHARACTER_UNDELETE_COOLDOWN = 0;	-- in seconds
CHARACTER_UNDELETE_COOLDOWN_REMAINING = 0; -- in seconds

local translationTable = { };	-- for character reordering: key = button index, value = character ID

local STORE_IS_LOADED = false;
local ADDON_LIST_RECEIVED = false;
CAN_BUY_RESULT_FOUND = false;
TOKEN_COUNT_UPDATED = false;

function CharacterSelect_OnLoad(self)
	CharacterSelectModel:SetSequence(0);
	CharacterSelectModel:SetCamera(0);

	self.createIndex = 0;
	self.selectedIndex = 0;
	self.selectLast = false;
	self.trialBoostPadlockPool = CreateFramePool("BUTTON", self, "CharSelectLockedTrialButtonTemplate");
	self:RegisterEvent("ADDON_LIST_UPDATE");
	self:RegisterEvent("CHARACTER_LIST_UPDATE");
	self:RegisterEvent("UPDATE_SELECTED_CHARACTER");
	self:RegisterEvent("SELECT_LAST_CHARACTER");
	self:RegisterEvent("SELECT_FIRST_CHARACTER");
	self:RegisterEvent("FORCE_RENAME_CHARACTER");
	self:RegisterEvent("CHAR_RENAME_IN_PROGRESS");
	self:RegisterEvent("STORE_STATUS_CHANGED");
	self:RegisterEvent("CHARACTER_UNDELETE_STATUS_CHANGED");
	self:RegisterEvent("CLIENT_FEATURE_STATUS_CHANGED)");
	self:RegisterEvent("CHARACTER_UNDELETE_FINISHED");
	self:RegisterEvent("TOKEN_CAN_VETERAN_BUY_UPDATE");
	self:RegisterEvent("TOKEN_DISTRIBUTIONS_UPDATED");
	self:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED");
	self:RegisterEvent("VAS_CHARACTER_STATE_CHANGED");
	self:RegisterEvent("STORE_PRODUCTS_UPDATED");
	self:RegisterEvent("CHARACTER_DELETION_RESULT");
	self:RegisterEvent("CHARACTER_DUPLICATE_LOGON");
	self:RegisterEvent("CHARACTER_LIST_RETRIEVING");
	self:RegisterEvent("CHARACTER_LIST_RETRIEVAL_RESULT");
	self:RegisterEvent("DELETED_CHARACTER_LIST_RETRIEVING");
	self:RegisterEvent("DELETED_CHARACTER_LIST_RETRIEVAL_RESULT");

	SetCharSelectModelFrame("CharacterSelectModel");

	-- Color edit box backdrops
	local backdropColor = DEFAULT_TOOLTIP_COLOR;
	CharacterSelectCharacterFrame:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	CharacterSelectCharacterFrame:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6], 0.85);

	CHARACTER_SELECT_BACK_FROM_CREATE = false;

	CHARACTER_LIST_OFFSET = 0;
	if (not IsGMClient()) then
		MAX_CHARACTERS_PER_REALM = 12;
	end
end

function CharacterSelect_OnShow(self)
	DebugLog("Select_OnShow");
	InitializeCharacterScreenData();
	SetInCharacterSelect(true);
	CHARACTER_LIST_OFFSET = 0;
	CharacterSelect_ResetVeteranStatus();
	CharacterTemplateConfirmDialog:Hide();

	if ( #translationTable == 0 ) then
		for i = 1, GetNumCharacters() do
			tinsert(translationTable, i);
		end
	end

	-- request account data times from the server (so we know if we should refresh keybindings, etc...)
	CheckCharacterUndeleteCooldown();

	UpdateAddonButton();

	local serverName, isPVP, isRP = GetServerName();
	local connected = IsConnectedToServer();
	local serverType = "";
	if ( serverName ) then
		if( not connected ) then
			serverName = serverName.."\n("..SERVER_DOWN..")";
		end
		if ( isPVP ) then
			if ( isRP ) then
				serverType = RPPVP_PARENTHESES;
			else
				serverType = PVP_PARENTHESES;
			end
		elseif ( isRP ) then
			serverType = RP_PARENTHESES;
		end
		CharSelectRealmName:SetText(serverName.." "..serverType);
		CharSelectRealmName:Show();
	else
		CharSelectRealmName:Hide();
	end

	if ( connected ) then
		GetCharacterListUpdate();
	else
		UpdateCharacterList();
	end

	-- Gameroom billing stuff (For Korea and China only)
	if ( SHOW_GAMEROOM_BILLING_FRAME ) then
		local paymentPlan, hasFallBackBillingMethod, isGameRoom = GetBillingPlan();
		if ( paymentPlan == 0 ) then
			-- No payment plan
			GameRoomBillingFrame:Hide();
		else
			local billingTimeLeft = GetBillingTimeRemaining();
			-- Set default text for the payment plan
			local billingText = _G["BILLING_TEXT"..paymentPlan];
			if ( paymentPlan == 1 ) then
				-- Recurring account
				billingTimeLeft = ceil(billingTimeLeft/(60 * 24));
				if ( billingTimeLeft == 1 ) then
					billingText = BILLING_TIME_LEFT_LAST_DAY;
				end
			elseif ( paymentPlan == 2 ) then
				-- Free account
				if ( billingTimeLeft < (24 * 60) ) then
					billingText = format(BILLING_FREE_TIME_EXPIRE, format(MINUTES_ABBR, billingTimeLeft));
				end
			elseif ( paymentPlan == 3 ) then
				-- Fixed but not recurring
				if ( isGameRoom == 1 ) then
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = format(BILLING_FIXED_IGR, MinutesToTime(billingTimeLeft, 1));
					end
				else
					-- personal fixed plan
					if ( billingTimeLeft < (24 * 60) ) then
						billingText = BILLING_FIXED_LASTDAY;
					else
						billingText = format(billingText, MinutesToTime(billingTimeLeft));
					end
				end
			elseif ( paymentPlan == 4 ) then
				-- Usage plan
				if ( isGameRoom == 1 ) then
					-- game room usage plan
					if ( billingTimeLeft <= 600 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = BILLING_IGR_USAGE;
					end
				else
					-- personal usage plan
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_TIME_LEFT_30_MINS;
					else
						billingText = format(billingText, billingTimeLeft);
					end
				end
			end
			-- If fallback payment method add a note that says so
			if ( hasFallBackBillingMethod == 1 ) then
				billingText = billingText.."\n\n"..BILLING_HAS_FALLBACK_PAYMENT;
			end
			GameRoomBillingFrameText:SetText(billingText);
			GameRoomBillingFrame:SetHeight(GameRoomBillingFrameText:GetHeight() + 26);
			GameRoomBillingFrame:Show();
		end
	end

	-- fadein the character select ui
	CharacterSelectUI.FadeIn:Play();

	--Clear out the addons selected item
	GlueDropDownMenu_SetSelectedValue(AddonCharacterDropDown, true);

	-- update banner art
	local expansionLevel = min(GetClientDisplayExpansionLevel(), max(GetAccountExpansionLevel(), GetExpansionLevel()));
	if ( expansionLevel > 0 ) then
		expansionLevel = expansionLevel - 1; -- because the upgrade art is indexed as the previous expansion in ACCOUNT_UPGRADE_FEATURES
		ACCOUNT_UPGRADE_FEATURES["VETERAN"].logo = ACCOUNT_UPGRADE_FEATURES[expansionLevel].logo;
		ACCOUNT_UPGRADE_FEATURES["VETERAN"].atlasLogo = ACCOUNT_UPGRADE_FEATURES[expansionLevel].atlasLogo;
		ACCOUNT_UPGRADE_FEATURES["VETERAN"].banner = ACCOUNT_UPGRADE_FEATURES[expansionLevel].banner;
	end

	AccountUpgradePanel_Update(CharSelectAccountUpgradeButton.isExpanded);

	if( IsKioskModeEnabled() ) then
		CharacterSelectUI:Hide();
	end

	-- character templates
	CharacterTemplatesFrame_Update();

	PlayersOnServer_Update();

	CharacterSelect_UpdateStoreButton();

	CharacterServicesMaster_UpdateServiceButton();

	C_PurchaseAPI.GetPurchaseList();
	C_PurchaseAPI.GetProductList();
	C_StoreGlue.UpdateVASPurchaseStates();

	if (not STORE_IS_LOADED) then
		STORE_IS_LOADED = LoadAddOn("Blizzard_StoreUI")
		LoadAddOn("Blizzard_AuthChallengeUI");
	end

	CharacterSelect_CheckVeteranStatus();

	if (C_StoreGlue.GetDisconnectOnLogout()) then
		C_PurchaseAPI.SetDisconnectOnLogout(false);
		GlueDialog_Hide();
		C_Login.DisconnectFromServer();
	end

    if (not HasCheckedSystemRequirements()) then
        CheckSystemRequirements();
        SetCheckedSystemRequirements(true);
    end
end

function CharacterSelect_OnHide(self)
	-- the user may have gotten d/c while dragging
	if ( CharacterSelect.draggedIndex ) then
		local button = _G["CharSelectCharacterButton"..(CharacterSelect.draggedIndex - CHARACTER_LIST_OFFSET)];
		CharacterSelectButton_OnDragStop(button);
	end
	CharacterSelect_SaveCharacterOrder();
	CharacterDeleteDialog:Hide();
	CharacterRenameDialog:Hide();
	AccountReactivate_CloseDialogs();
	if ( DeclensionFrame ) then
		DeclensionFrame:Hide();
	end

	PromotionFrame_Hide();
	C_AuthChallenge.Cancel();
	if ( StoreFrame ) then
		StoreFrame:Hide();
	end
	CopyCharacterFrame:Hide();
	if (AddonDialog:IsShown()) then
		AddonDialog:Hide();
		HasShownAddonOutOfDateDialog = false;
	end

	AccountReactivate_CloseDialogs();
	SetInCharacterSelect(false);
end

function CharacterSelect_SaveCharacterOrder()
	if ( CharacterSelect.orderChanged ) then
		SaveCharacterOrder(translationTable);
		CharacterSelect.orderChanged = nil;
	end
end

function CharacterSelect_SetRetrievingCharacters(retrieving, success)
	if ( retrieving ~= CharacterSelect.retrievingCharacters ) then
		CharacterSelect.retrievingCharacters = retrieving;

		if ( retrieving ) then
			GlueDialog_Show("RETRIEVING_CHARACTER_LIST");
		else
			if ( success ) then
				GlueDialog_Hide("RETRIEVING_CHARACTER_LIST");
			else
				GlueDialog_Show("OKAY", CHAR_LIST_FAILED);
			end
		end

		CharacterSelect_UpdateButtonState();
	end
end

function CharacterSelect_IsRetrievingCharacterList()
	return CharacterSelect.retrievingCharacters;
end

function CharacterSelect_OnUpdate(self, elapsed)
	if ( self.undeleteFailed ) then
		if (not GlueDialog:IsShown()) then
			GlueDialog_Show(self.undeleteFailed == "name" and "UNDELETE_NAME_TAKEN" or "UNDELETE_FAILED");
			self.undeleteFailed = false;
		end
	end

	if ( self.undeleteSucceeded ) then
		if (not GlueDialog:IsShown()) then
			GlueDialog_Show(self.undeletePendingRename and "UNDELETE_SUCCEEDED_NAME_TAKEN" or "UNDELETE_SUCCEEDED");
			self.undeleteSucceeded = false;
			self.undeletePendingRename = false;
		end
	end

	if ( self.pressDownButton ) then
		self.pressDownTime = self.pressDownTime + elapsed;
		if ( self.pressDownTime >= AUTO_DRAG_TIME ) then
			CharacterSelectButton_OnDragStart(self.pressDownButton);
		end
	end

	if ( C_CharacterServices.HasQueuedUpgrade() or C_StoreGlue.GetVASProductReady() ) then
		CharacterServicesMaster_OnCharacterListUpdate();
	end

	if (STORE_IS_LOADED and StoreFrame_WaitingForCharacterListUpdate()) then
		StoreFrame_OnCharacterListUpdate();
	end
end

function CharacterSelect_OnKeyDown(self,key)
	if ( key == "ESCAPE" ) then
		if ( C_Login.IsLauncherLogin() ) then
			GlueMenuFrame:SetShown(not GlueMenuFrame:IsShown());
		elseif (CharSelectServicesFlowFrame:IsShown()) then
			CharSelectServicesFlowFrame:Hide();
		elseif ( CopyCharacterFrame:IsShown() ) then
			CopyCharacterFrame:Hide();
		elseif (CharacterSelect.undeleting) then
			CharacterSelect_EndCharacterUndelete();
		else
			CharacterSelect_Exit();
		end
	elseif ( key == "ENTER" ) then
		if (not CharacterSelect_AllowedToEnterWorld()) then
			return;
		end
		CharacterSelect_EnterWorld();
	elseif ( key == "PRINTSCREEN" ) then
		Screenshot();
	elseif ( key == "UP" or key == "LEFT" ) then
		if (CharSelectServicesFlowFrame:IsShown()) then
			return;
		end
		CharacterSelectScrollUp_OnClick();
	elseif ( key == "DOWN" or key == "RIGHT" ) then
		if (CharSelectServicesFlowFrame:IsShown()) then
			return;
		end
		CharacterSelectScrollDown_OnClick();
	end
end

function CharacterSelect_OnEvent(self, event, ...)
	if ( event == "ADDON_LIST_UPDATE" ) then
		ADDON_LIST_RECEIVED = true;
		if (not STORE_IS_LOADED) then
			STORE_IS_LOADED = LoadAddOn("Blizzard_StoreUI");
			LoadAddOn("Blizzard_AuthChallengeUI");
			CharacterSelect_UpdateStoreButton();
		end
		UpdateAddonButton();
	elseif ( event == "CHARACTER_LIST_UPDATE" ) then
		PromotionFrame_AwaitingPromotion();

		local listSize = ...;
		if ( listSize ) then
			table.wipe(translationTable);
			for i = 1, listSize do
				tinsert(translationTable, i);
			end
			CharacterSelect.orderChanged = nil;
		end
		local numChars = GetNumCharacters();
		if (self.undeleting and numChars == 0) then
			CharacterSelect_EndCharacterUndelete();
			self.undeleteNoCharacters = true;
			return;
		elseif (not CHARACTER_SELECT_BACK_FROM_CREATE and numChars == 0) then
			GlueParent_SetScreen("charcreate");
			return;
		end

		CHARACTER_SELECT_BACK_FROM_CREATE = false;

		if (self.hasPendingTrialBoost) then
			local guid = select(14, GetCharacterInfo(numChars)); -- Brittle, assumes the newly created character will be last on the list.
			C_CharacterServices.TrialBoostCharacter(guid, self.trialBoostFactionID, self.trialBoostSpecID);
			CharacterSelect_SetPendingTrialBoost(false);
		end

		if (self.undeleteNoCharacters) then
			GlueDialog_Show("UNDELETE_NO_CHARACTERS");
			self.undeleteNoCharacters = false;
		end

		UpdateCharacterList();
		UpdateAddonButton(true);
		CharSelectCharacterName:SetText(GetCharacterInfo(GetCharIDFromIndex(self.selectedIndex)));
		if (IsKioskModeEnabled()) then
			if (KioskModeSplash_GetAutoEnterWorld()) then
				EnterWorld();
			else
				KioskDeleteAllCharacters();
				GlueParent_SetScreen("kioskmodesplash");
			end
		end
		CharacterServicesMaster_OnCharacterListUpdate();
	elseif ( event == "UPDATE_SELECTED_CHARACTER" ) then
		local charID = ...;
		if ( charID == 0 ) then
			CharSelectCharacterName:SetText("");
		else
			local index = GetIndexFromCharID(charID);
			self.selectedIndex = index;
			CharSelectCharacterName:SetText(GetCharacterInfo(charID));
		end
		if ((CHARACTER_LIST_OFFSET == 0) and (self.selectedIndex > MAX_CHARACTERS_DISPLAYED)) then
			CHARACTER_LIST_OFFSET = self.selectedIndex - MAX_CHARACTERS_DISPLAYED;
		end
		UpdateCharacterSelection(self);
	elseif ( event == "SELECT_LAST_CHARACTER" ) then
		self.selectLast = true;
	elseif ( event == "SELECT_FIRST_CHARACTER" ) then
		CHARACTER_LIST_OFFSET = 0;
		CharacterSelect_SelectCharacter(1, 1);
	elseif ( event == "FORCE_RENAME_CHARACTER" ) then
		GlueDialog_Hide();
		local message = ...;
		CharacterRenameDialog:Show();
		CharacterRenameText1:SetText(_G[message]);
	elseif ( event == "CHAR_RENAME_IN_PROGRESS" ) then
		GlueDialog_Show("OKAY", CHAR_RENAME_IN_PROGRESS);
	elseif ( event == "STORE_STATUS_CHANGED" ) then
		if (ADDON_LIST_RECEIVED) then
			CharacterSelect_UpdateStoreButton();
		end
	elseif ( event == "CHARACTER_UNDELETE_STATUS_CHANGED") then
		local enabled, onCooldown, cooldown, remaining = GetCharacterUndeleteStatus();

		CHARACTER_UNDELETE_COOLDOWN = cooldown;
		CHARACTER_UNDELETE_COOLDOWN_REMAINING = remaining;

		CharSelectUndeleteCharacterButton:SetEnabled(enabled and not onCooldown);
		if (not enabled) then
			CharSelectUndeleteCharacterButton.tooltip = UNDELETE_TOOLTIP_DISABLED;
		elseif (onCooldown) then
			local timeStr = SecondsToTime(remaining, false, true, 1, false);
			CharSelectUndeleteCharacterButton.tooltip = UNDELETE_TOOLTIP_COOLDOWN:format(timeStr);
		else
			CharSelectUndeleteCharacterButton.tooltip = UNDELETE_TOOLTIP;
		end
	elseif ( event == "CLIENT_FEATURE_STATUS_CHANGED" ) then
		AccountUpgradePanel_Update(CharSelectAccountUpgradeButton.isExpanded);
	elseif ( event == "CHARACTER_UNDELETE_FINISHED" ) then
		GlueDialog_Hide("UNDELETING_CHARACTER");
		CharacterSelect_EndCharacterUndelete();
		local result, guid = ...;

		if ( result == LE_CHARACTER_UNDELETE_RESULT_OK ) then
			self.undeleteGuid = guid;
			self.undeleteFailed = nil;
		else
			self.undeleteGuid = nil;
			if ( result == LE_CHARACTER_UNDELETE_RESULT_ERROR_NAME_TAKEN_BY_THIS_ACCOUNT ) then
				self.undeleteFailed = "name";
			else
				self.undeleteFailed = "other";
			end
		end
	elseif ( event == "TOKEN_DISTRIBUTIONS_UPDATED" ) then
		local result = ...;
		-- TODO: Use lua enum
		if (result == 1) then
			TOKEN_COUNT_UPDATED = true;
			CharacterSelect_CheckVeteranStatus();
		end
	elseif ( event == "TOKEN_CAN_VETERAN_BUY_UPDATE" ) then
		local result = ...;
		CAN_BUY_RESULT_FOUND = result;
		CharacterSelect_CheckVeteranStatus();
	elseif ( event == "TOKEN_MARKET_PRICE_UPDATED" ) then
		local result = ...;
		CharacterSelect_CheckVeteranStatus();
	elseif (event == "VAS_CHARACTER_STATE_CHANGED" or event == "STORE_PRODUCTS_UPDATED") then
		if ( not IsCharacterListUpdatePending() ) then
			UpdateCharacterList();
		end
	elseif ( event == "CHARACTER_DELETION_RESULT" ) then
		local success, errorToken = ...;
		if ( success ) then
			CHARACTER_LIST_OFFSET = 0;
			CharacterSelect_SelectCharacter(1, 1);
			GlueDialog_Hide();
		else
			GlueDialog_Show("OKAY", _G[errorToken]);
		end
	elseif ( event == "CHARACTER_DUPLICATE_LOGON" ) then
		local errorCode = ...;
		GlueDialog_Show("OKAY", _G[errorCode]);
	elseif ( event == "CHARACTER_LIST_RETRIEVING" ) then
		CharacterSelect_SetRetrievingCharacters(true);
	elseif ( event == "CHARACTER_LIST_RETRIEVAL_RESULT" ) then
		local success = ...;
		CharacterSelect_SetRetrievingCharacters(false, success);
	elseif ( event == "DELETED_CHARACTER_LIST_RETRIEVING" ) then
		CharacterSelect_SetRetrievingCharacters(true);
	elseif ( event == "DELETED_CHARACTER_LIST_RETRIEVAL_RESULT" ) then
		local success = ...;
		CharacterSelect_SetRetrievingCharacters(false, success);
		end
	end

function CharacterSelect_SetPendingTrialBoost(hasPendingTrialBoost, factionID, specID)
	CharacterSelect.hasPendingTrialBoost = hasPendingTrialBoost;
	CharacterSelect.trialBoostFactionID = factionID;
	CharacterSelect.trialBoostSpecID = specID;
end

function CharacterSelect_UpdateModel(self)
	UpdateSelectionCustomizationScene();
	self:AdvanceTime();
end

function UpdateCharacterSelection(self)
	local button, paidServiceButton;

	for i=1, MAX_CHARACTERS_DISPLAYED, 1 do
		button = _G["CharSelectCharacterButton"..i];
		paidServiceButton = _G["CharSelectPaidService"..i];
		button.selection:Hide();
		button.upButton:Hide();
		button.downButton:Hide();
		if (self.undeleting or CharSelectServicesFlowFrame:IsShown()) then
			paidServiceButton:Hide();
			CharacterSelectButton_DisableDrag(button);

			if (button.trialBoostPadlock) then
				button.trialBoostPadlock:Hide();
			end
		else
			CharacterSelectButton_EnableDrag(button);
		end
	end

	local index = self.selectedIndex - CHARACTER_LIST_OFFSET;
	if ( (index > 0) and (index <= MAX_CHARACTERS_DISPLAYED) ) then
		button = _G["CharSelectCharacterButton"..index];
		paidServiceButton = _G["CharSelectPaidService"..index];

		if ( button ) then
			button.selection:Show();
			if ( button:IsMouseOver() ) then
				CharacterSelectButton_ShowMoveButtons(button);
			end
			if ( self.undeleting ) then
				paidServiceButton.GoldBorder:Hide();
				paidServiceButton.VASIcon:Hide();
				paidServiceButton.texture:SetTexCoord(.5, 1, .5, 1);
				paidServiceButton.texture:Show();
				paidServiceButton.tooltip = UNDELETE_SERVICE_TOOLTIP;
				paidServiceButton.disabledTooltip = nil;
				paidServiceButton:Show();
			end

			CharacterSelect_UpdateButtonState();
		end
	end
end

function UpdateCharacterList(skipSelect)
	local numChars = GetNumCharacters();
	local coords;

	if ( CharacterSelect.undeleteChanged ) then
		CHARACTER_LIST_OFFSET = 0;
		CharacterSelect.undeleteChanged = false;
	end

	if ( numChars < MAX_CHARACTERS_PER_REALM or
		( (CharacterSelect.undeleting and numChars >= MAX_CHARACTERS_DISPLAYED_BASE) or
		numChars > MAX_CHARACTERS_DISPLAYED_BASE) ) then
		if (MAX_CHARACTERS_DISPLAYED == MAX_CHARACTERS_DISPLAYED_BASE) then
			MAX_CHARACTERS_DISPLAYED = MAX_CHARACTERS_DISPLAYED_BASE - 1;
		end
	else
		MAX_CHARACTERS_DISPLAYED = MAX_CHARACTERS_DISPLAYED_BASE;
	end

	-- select the last("newest") character
	if ( CharacterSelect.selectLast ) then
		CHARACTER_LIST_OFFSET = max(numChars - MAX_CHARACTERS_DISPLAYED, 0);
		CharacterSelect.selectedIndex = numChars;
		CharacterSelect.selectLast = false;
	end

	if ( CharacterSelect.undeleteGuid ) then
		local found = false;
		repeat
			for i = 1, MAX_CHARACTERS_DISPLAYED, 1 do
				local guid, _, _, _, _, forceRename = select(14, GetCharacterInfo(GetCharIDFromIndex(i + CHARACTER_LIST_OFFSET)));
				if ( guid == CharacterSelect.undeleteGuid ) then
					CharacterSelect.selectedIndex = i + CHARACTER_LIST_OFFSET;
					CharacterSelect.undeleteSucceeded = true;
					CharacterSelect.undeletePendingRename = forceRename;
					found = true;
					break;
				end
			end
			if (not found) then
				CHARACTER_LIST_OFFSET = CHARACTER_LIST_OFFSET + 1;
			end
		until found;
		CharacterSelect.undeleteGuid = nil;
	end

	local debugText = numChars..": ";
	local characterLimit = min(numChars, MAX_CHARACTERS_DISPLAYED);
	local areCharServicesShown = CharSelectServicesFlowFrame:IsShown();

	for i=1, characterLimit, 1 do
		local name, race, class, classFileName, classID, level, zone, sex, ghost, PCC, PRC, PFC, PRCDisabled, guid, _, _, _, boostInProgress, _, locked, isTrialBoost, isTrialBoostLocked = GetCharacterInfo(GetCharIDFromIndex(i+CHARACTER_LIST_OFFSET));
		local productID, vasServiceState, vasServiceErrors = C_StoreGlue.GetVASPurchaseStateInfo(guid);
		local button = _G["CharSelectCharacterButton"..i];
		button.isVeteranLocked = false;

		if (button.trialBoostPadlock) then
			CharacterSelect.trialBoostPadlockPool:Release(button.trialBoostPadlock);
			button.trialBoostPadlock = nil;
		end

		if ( name ) then
			zone = zone or "";

			local nameText = button.buttonText.name;
			local infoText = button.buttonText.Info;
			local locationText = button.buttonText.Location;

			if (not areCharServicesShown) then
				nameText:SetTextColor(1, .82, 0, 1);
			end

			if ( CharacterSelect.undeleting ) then
				nameText:SetFormattedText(CHARACTER_SELECT_NAME_DELETED, name);
			elseif ( locked ) then
				nameText:SetText(name..CHARSELECT_CHAR_INACTIVE_CHAR);
			else
				nameText:SetText(name);
			end

			if (vasServiceState == LE_VAS_PURCHASE_STATE_APPLYING_LICENSE and vasServiceErrors) then
				local productInfo = C_PurchaseAPI.GetProductInfo(productID);
				infoText:SetText("|cffff2020"..VAS_ERROR_ERROR_HAS_OCCURRED.."|r");
				if (productInfo and productInfo.name) then
					locationText:SetText("|cffff2020"..productInfo.name.."|r");
				else
					locationText:SetText("");
				end
			elseif (vasServiceState == LE_VAS_PURCHASE_STATE_PROCESSING_FACTION_CHANGE) then
				infoText:SetText(CHARACTER_UPGRADE_PROCESSING);
				locationText:SetFontObject("GlueFontHighlightSmall");
				locationText:SetText(FACTION_CHANGE_CHARACTER_LIST_LABEL);
			elseif (boostInProgress) then
				infoText:SetText(CHARACTER_UPGRADE_PROCESSING);
				locationText:SetFontObject("GlueFontHighlightSmall");
				locationText:SetText(CHARACTER_UPGRADE_CHARACTER_LIST_LABEL);
			else
				if ( locked ) then
					button.isVeteranLocked = true;
				end

				locationText:SetFontObject("GlueFontDisableSmall");

				if isTrialBoost then
					locationText:SetText(CHARACTER_SELECT_INFO_TRIAL_BOOST_APPLY_BOOST_TOKEN);

					if isTrialBoostLocked then
						infoText:SetText(CHARACTER_SELECT_INFO_TRIAL_BOOST_LOCKED);

						local trialBoostPadlock = CharacterSelect.trialBoostPadlockPool:Acquire();
						button.trialBoostPadlock = trialBoostPadlock;
						trialBoostPadlock.characterSelectButton = button;

						trialBoostPadlock.guid = guid;
						trialBoostPadlock:SetParent(button);
						trialBoostPadlock:SetPoint("TOPRIGHT", button, "TOPLEFT", 5, 12);

						trialBoostPadlock:SetShown(not areCharServicesShown);

						if (not areCharServicesShown) then
							nameText:SetTextColor(.5, .5, .5, 1);
						end
					else
						infoText:SetText(CHARACTER_SELECT_INFO_TRIAL_BOOST_PLAYABLE);
					end
				else
				if( ghost ) then
						infoText:SetFormattedText(CHARACTER_SELECT_INFO_GHOST, level, class);
				else
						infoText:SetFormattedText(CHARACTER_SELECT_INFO, level, class);
					end

					locationText:SetText(zone);
				end
			end
		end
		button:Show();
		button.index = i + CHARACTER_LIST_OFFSET;

		-- setup paid service button
		local paidServiceButton = _G["CharSelectPaidService"..i];
		local upgradeIcon = _G["CharacterServicesProcessingIcon"..i];
		upgradeIcon:Hide();
		local serviceType, disableService;
		if (vasServiceState == LE_VAS_PURCHASE_STATE_PAYMENT_PENDING) then
			upgradeIcon:Show();
			upgradeIcon.tooltip = CHARACTER_UPGRADE_PROCESSING;
			upgradeIcon.tooltip2 = CHARACTER_STATE_ORDER_PROCESSING;
		elseif (vasServiceState == LE_VAS_PURCHASE_STATE_APPLYING_LICENSE and vasServiceErrors) then
			upgradeIcon:Show();
			local tooltip, desc;
			if (STORE_IS_LOADED) then
				local info = StoreFrame_GetVASErrorMessage(guid, vasServiceErrors);
				if (info) then
					if (info.other) then
						tooltip = VAS_ERROR_ERROR_HAS_OCCURRED;
					else
						tooltip = VAS_ERROR_ADDRESS_THESE_ISSUES;
					end
					desc = info.desc;
				else
					tooltip = VAS_ERROR_ERROR_HAS_OCCURRED;
					desc = BLIZZARD_STORE_VAS_ERROR_OTHER;
				end
			else
				tooltip = VAS_ERROR_ERROR_HAS_OCCURRED;
				desc = BLIZZARD_STORE_VAS_ERROR_OTHER;
			end
			upgradeIcon.tooltip = "|cffffd200" .. tooltip .. "|r";
			upgradeIcon.tooltip2 = "|cffff2020" .. desc .. "|r";
		elseif (boostInProgress or vasServiceState == LE_VAS_PURCHASE_STATE_PROCESSING_FACTION_CHANGE) then
			upgradeIcon:Show();
			upgradeIcon.tooltip = CHARACTER_UPGRADE_PROCESSING;
			upgradeIcon.tooltip2 = CHARACTER_SERVICES_PLEASE_WAIT;
		elseif ( CharacterSelect.undeleting ) then
			paidServiceButton:Hide();
			paidServiceButton.serviceType = nil;
		elseif ( PFC ) then
			serviceType = PAID_FACTION_CHANGE;
			paidServiceButton.GoldBorder:Show();
			paidServiceButton.VASIcon:SetTexture("Interface\\Icons\\VAS_FactionChange");
			paidServiceButton.VASIcon:Show();
			paidServiceButton.texture:Hide();
			paidServiceButton.tooltip = PAID_FACTION_CHANGE_TOOLTIP;
			paidServiceButton.disabledTooltip = nil;
		elseif ( PRC ) then
			serviceType = PAID_RACE_CHANGE;
			paidServiceButton.GoldBorder:Show();
			paidServiceButton.VASIcon:SetTexture("Interface\\Icons\\VAS_RaceChange");
			paidServiceButton.VASIcon:Show();
			paidServiceButton.texture:Hide();
			disableService = PRCDisabled;
			paidServiceButton.tooltip = PAID_RACE_CHANGE_TOOLTIP;
			paidServiceButton.disabledTooltip = PAID_RACE_CHANGE_DISABLED_TOOLTIP;
		elseif ( PCC ) then
			serviceType = PAID_CHARACTER_CUSTOMIZATION;
			paidServiceButton.GoldBorder:Show();
			paidServiceButton.VASIcon:SetTexture("Interface\\Icons\\VAS_AppearanceChange");
			paidServiceButton.VASIcon:Show();
			paidServiceButton.texture:Hide();
			paidServiceButton.tooltip = PAID_CHARACTER_CUSTOMIZE_TOOLTIP;
			paidServiceButton.disabledTooltip = nil;
		end
		if ( serviceType ) then
			debugText = debugText.." "..(GetCharIDFromIndex(i+CHARACTER_LIST_OFFSET));
			paidServiceButton:Show();
			paidServiceButton.serviceType = serviceType;
			if ( disableService ) then
				paidServiceButton:Disable();
				paidServiceButton.texture:SetDesaturated(true);
				paidServiceButton.GoldBorder:SetDesaturated(true);
				paidServiceButton.VASIcon:SetDesaturated(true);
			elseif ( not paidServiceButton:IsEnabled() ) then
				paidServiceButton.texture:SetDesaturated(false);
				paidServiceButton.GoldBorder:SetDesaturated(false);
				paidServiceButton.VASIcon:SetDesaturated(false);
				paidServiceButton:Enable();
			end
		else
			paidServiceButton:Hide();
		end

		-- is a button being dragged?
		if ( CharacterSelect.draggedIndex ) then
			if ( CharacterSelect.draggedIndex == button.index ) then
				button:SetAlpha(1);
				button.buttonText.name:SetPoint("TOPLEFT", MOVING_TEXT_OFFSET, -5);
				button:LockHighlight();
				paidServiceButton.texture:SetVertexColor(1, 1, 1);
				paidServiceButton.GoldBorder:SetVertexColor(1, 1, 1);
				paidServiceButton.VASIcon:SetVertexColor(1, 1, 1);
			else
				button:SetAlpha(0.6);
				button.buttonText.name:SetPoint("TOPLEFT", DEFAULT_TEXT_OFFSET, -5);
				button:UnlockHighlight();
				paidServiceButton.texture:SetVertexColor(0.35, 0.35, 0.35);
				paidServiceButton.GoldBorder:SetVertexColor(0.35, 0.35, 0.35);
				paidServiceButton.VASIcon:SetVertexColor(0.35, 0.35, 0.35);
			end
		end
	end

	DebugLog(debugText);
	CharacterSelect_UpdateButtonState();

	CharacterSelect_UpdateStoreButton();

	CharacterSelect_ResetVeteranStatus();
	CharacterSelect_CheckVeteranStatus();

	CharacterSelect.createIndex = 0;

	CharSelectCreateCharacterButton:Hide();
	CharSelectUndeleteCharacterButton:Hide();

	local connected = IsConnectedToServer();
	if (numChars < MAX_CHARACTERS_PER_REALM and not CharacterSelect.undeleting) then
		CharacterSelect.createIndex = numChars + 1;
		if ( connected ) then
			--If can create characters position and show the create button
			CharSelectCreateCharacterButton:SetID(CharacterSelect.createIndex);
			CharSelectCreateCharacterButton:Show();
			CharSelectUndeleteCharacterButton:Show();
		end
	end

	if (MAX_CHARACTERS_DISPLAYED < MAX_CHARACTERS_DISPLAYED_BASE) then
		for i = MAX_CHARACTERS_DISPLAYED + 1, MAX_CHARACTERS_DISPLAYED_BASE, 1 do
			_G["CharSelectCharacterButton"..i]:Hide();
			_G["CharSelectPaidService"..i]:Hide();
			_G["CharacterServicesProcessingIcon"..i]:Hide();
		end
	end

	if (numChars < MAX_CHARACTERS_DISPLAYED) then
		for i = numChars + 1, MAX_CHARACTERS_DISPLAYED, 1 do
			_G["CharSelectCharacterButton"..i]:Hide();
			_G["CharSelectPaidService"..i]:Hide();
			_G["CharacterServicesProcessingIcon"..i]:Hide();
		end
	end

	if ( numChars == 0 ) then
		CharacterSelect.selectedIndex = 0;
		CharacterSelect_SelectCharacter(CharacterSelect.selectedIndex, 1);
		return;
	end

	if ( numChars > MAX_CHARACTERS_DISPLAYED ) then
		CharSelectCreateCharacterButton:SetPoint("BOTTOM", -26, 15);
		CharSelectBackToActiveButton:SetPoint("BOTTOM", -8, 15);
		CharacterSelectCharacterFrame:SetWidth(280);
		CharacterSelectCharacterFrame.scrollBar:Show();
		CharacterSelectCharacterFrame.scrollBar:SetMinMaxValues(0, numChars - MAX_CHARACTERS_DISPLAYED);
		CharacterSelectCharacterFrame.scrollBar.blockUpdates = true;
		CharacterSelectCharacterFrame.scrollBar:SetValue(CHARACTER_LIST_OFFSET);
		CharacterSelectCharacterFrame.scrollBar.blockUpdates = nil;
	else
		CharSelectCreateCharacterButton:SetPoint("BOTTOM", -18, 15);
		CharSelectBackToActiveButton:SetPoint("BOTTOM", 0, 15);
		CharacterSelectCharacterFrame.scrollBar.blockUpdates = true;	-- keep mousewheel from doing anything
		CharacterSelectCharacterFrame:SetWidth(260);
		CharacterSelectCharacterFrame.scrollBar:Hide();
	end

	if ( (CharacterSelect.selectedIndex == 0) or (CharacterSelect.selectedIndex > numChars) ) then
		CharacterSelect.selectedIndex = 1;
	end

	if ( not skipSelect ) then
		CharacterSelect_SelectCharacter(CharacterSelect.selectedIndex, 1);
	end
end

function CharacterSelectButton_OnClick(self)
	PlaySound("gsCharacterCreationClass");
	local id = self:GetID() + CHARACTER_LIST_OFFSET;
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
end

function CharacterSelectButton_OnDoubleClick(self)
	local id = self:GetID() + CHARACTER_LIST_OFFSET;
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
	if (CharacterSelect_AllowedToEnterWorld()) then
		CharacterSelect_EnterWorld();
	end
end

function CharacterSelectButton_ShowMoveButtons(button)
	if (CharacterSelect.undeleting) then return end;
	local numCharacters = GetNumCharacters();
	if ( numCharacters <= 1 ) then
		return;
	end
	if ( not CharacterSelect.draggedIndex ) then
		button.upButton:Show();
		button.upButton.normalTexture:SetPoint("CENTER", 0, 0);
		button.upButton.highlightTexture:SetPoint("CENTER", 0, 0);
		button.downButton:Show();
		button.downButton.normalTexture:SetPoint("CENTER", 0, 0);
		button.downButton.highlightTexture:SetPoint("CENTER", 0, 0);
		if ( button.index == 1 ) then
			button.upButton:Disable();
			button.upButton:SetAlpha(0.35);
		else
			button.upButton:Enable();
			button.upButton:SetAlpha(1);
		end
		if ( button.index == numCharacters ) then
			button.downButton:Disable();
			button.downButton:SetAlpha(0.35);
		else
			button.downButton:Enable();
			button.downButton:SetAlpha(1);
		end
	end
end

function CharacterSelect_TabResize(self)
	local buttonMiddle = _G[self:GetName().."Middle"];
	local buttonMiddleDisabled = _G[self:GetName().."MiddleDisabled"];
	local width = self:GetTextWidth() - 8;
	local leftWidth = _G[self:GetName().."Left"]:GetWidth();
	buttonMiddle:SetWidth(width);
	buttonMiddleDisabled:SetWidth(width);
	self:SetWidth(width + (2 * leftWidth));
end

function CharacterSelect_CreateNewCharacter(characterType)
	SetCharacterCreateType(characterType);
	CharacterSelect_SelectCharacter(CharacterSelect.createIndex);
end

function CharacterSelect_SelectCharacter(index, noCreate)
	if ( index == CharacterSelect.createIndex ) then
		if ( not noCreate ) then
			PlaySound("gsCharacterSelectionCreateNew");
			ClearCharacterTemplate();
			GlueParent_SetScreen("charcreate");
		end
	else
		local charID = GetCharIDFromIndex(index);
		SelectCharacter(charID);

		if (not C_WowTokenPublic.GetCurrentMarketPrice() or
			not CAN_BUY_RESULT_FOUND or (CAN_BUY_RESULT_FOUND ~= LE_TOKEN_RESULT_ERROR_SUCCESS and CAN_BUY_RESULT_FOUND ~= LE_TOKEN_RESULT_ERROR_SUCCESS_NO) ) then
			AccountReactivate_RecheckEligibility();
		end
		ReactivateAccountDialog_Open();
		SetBackgroundModel(CharacterSelectModel, GetSelectBackgroundModel(charID));

		-- Update the text of the EnterWorld button based on the type of character that's selected, default to "enter world"
		local text = ENTER_WORLD;

		local isTrialBoostLocked = select(22,GetCharacterInfo(GetCharacterSelection()));
		if ( isTrialBoostLocked ) then
			text = ENTER_WORLD_UNLOCK_TRIAL_CHARACTER;
		end

		CharSelectEnterWorldButton:SetText(text);
	end
end


function CharacterSelect_SelectCharacterByGUID(guid)
	local num = math.min(GetNumCharacters(), MAX_CHARACTERS_DISPLAYED);

	for i = 1, num do
		if (select(14, GetCharacterInfo(GetCharIDFromIndex(i + CHARACTER_LIST_OFFSET))) == guid) then
			local button = _G["CharSelectCharacterButton"..i];
			CharacterSelectButton_OnClick(button);
			button.selection:Show();
			UpdateCharacterSelection(CharacterSelect);
			GetCharacterListUpdate();
			return true;
		end
	end

	return false;
end

function CharacterDeleteDialog_OnShow()
	local name, race, class, classFileName, classID, level = GetCharacterInfo(GetCharIDFromIndex(CharacterSelect.selectedIndex));
	CharacterDeleteText1:SetFormattedText(CONFIRM_CHAR_DELETE, name, level, class);
	CharacterDeleteBackground:SetHeight(16 + CharacterDeleteText1:GetHeight() + CharacterDeleteText2:GetHeight() + 23 + CharacterDeleteEditBox:GetHeight() + 8 + CharacterDeleteButton1:GetHeight() + 16);
	CharacterDeleteButton1:Disable();
end

function CharacterSelect_EnterWorld()
	CharacterSelect_SaveCharacterOrder();
	PlaySound("gsCharacterSelectionEnterWorld");
	local guid, _, _, _, boostInProgress, _, locked, isTrialBoost, isTrialBoostLocked = select(14,GetCharacterInfo(GetCharacterSelection()));

	if ( locked ) then
		SubscriptionRequestDialog_Open();
		return;
	end

	if ( isTrialBoost and isTrialBoostLocked ) then
		CharacterSelect_CheckApplyBoostToUnlockTrialCharacter(guid);
		return;
	end

	StopGlueAmbience();
	EnterWorld();
end

function CharacterSelect_Exit()
	CharacterSelect_SaveCharacterOrder();
	PlaySound("gsCharacterSelectionExit");
	C_Login.DisconnectFromServer();
end

function CharacterSelect_AccountOptions()
	PlaySound("gsCharacterSelectionAcctOptions");
end

function CharacterSelect_TechSupport()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(TECH_SUPPORT_URL);
end

function CharacterSelect_Delete()
	PlaySound("gsCharacterSelectionDelCharacter");
	if ( CharacterSelect.selectedIndex > 0 ) then
		CharacterSelect_SaveCharacterOrder();
		CharacterDeleteDialog:Show();
	end
end

function CharacterSelect_ChangeRealm()
	PlaySound("gsCharacterSelectionDelCharacter");
	CharacterSelect_SaveCharacterOrder();
	C_RealmList.RequestChangeRealmList();
end

function CharacterSelect_AllowedToEnterWorld()
	if (GetNumCharacters() == 0) then
		return false;
	elseif (CharacterSelect.undeleting) then
		return false;
	elseif (AccountReactivationInProgressDialog:IsShown()) then
		return false;
	elseif (GoldReactivateConfirmationDialog:IsShown()) then
		return false;
	elseif (TokenReactivateConfirmationDialog:IsShown()) then
		return false;
	elseif (CharSelectServicesFlowFrame:IsShown()) then
		return false;
	end

	return true;
end

function CharacterSelectFrame_OnMouseDown(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		CHARACTER_SELECT_INITIAL_FACING = GetCharacterSelectFacing();
	end
end

function CharacterSelectFrame_OnMouseUp(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = nil
	end
end

function CharacterSelectFrame_OnUpdate()
	if ( CHARACTER_SELECT_ROTATION_START_X ) then
		local x = GetCursorPosition();
		local diff = (x - CHARACTER_SELECT_ROTATION_START_X) * CHARACTER_ROTATION_CONSTANT;
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		SetCharacterSelectFacing(GetCharacterSelectFacing() + diff);
	end
end

function CharacterSelectRotateRight_OnUpdate(self)
	if ( self:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() + CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelectRotateLeft_OnUpdate(self)
	if ( self:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() - CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelect_ManageAccount()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(AUTH_NO_TIME_URL);
end

function CharacterSelect_PaidServiceOnClick(self, button, down, service)
	local translatedIndex =  GetCharIDFromIndex(self:GetID() + CHARACTER_LIST_OFFSET);
	if (translatedIndex <= 0 or translatedIndex > GetNumCharacters()) then
		-- Somehow our character order got borked, reset the offset and get an updated character list.
		CHARACTER_LIST_OFFSET = 0;
		PAID_SERVICE_CHARACTER_ID = nil;
		PAID_SERVICE_TYPE = nil;
		GetCharacterListUpdate();
		return;
	end

	PAID_SERVICE_CHARACTER_ID = translatedIndex;
	PAID_SERVICE_TYPE = service;
	PlaySound("gsCharacterSelectionCreateNew");
	if (CharacterSelect.undeleting) then
		local guid = select(14, GetCharacterInfo(PAID_SERVICE_CHARACTER_ID));
		CharacterSelect.pendingUndeleteGuid = guid;
		local timeStr = SecondsToTime(CHARACTER_UNDELETE_COOLDOWN, false, true, 1, false);
		GlueDialog_Show("UNDELETE_CONFIRM", UNDELETE_CONFIRMATION:format(timeStr));
	else
		GlueParent_SetScreen("charcreate");
	end
end

function CharacterSelectGoldPanelButton_DeathKnightSwap(self)
	local state;
	if ( not self:IsEnabled() ) then
		state = "disabled";
	elseif ( self.down ) then
		state = "down";
	else
		state = "up";
	end

	local deathKnightTag = "DEATHKNIGHT";
	local currentGlueTag = GetCurrentGlueTag();

	if ( self.currentGlueTag ~= currentGlueTag or self.state ~= state ) then
		self.currentGlueTag = currentGlueTag;
		self.state = state;

		if ( currentGlueTag == deathKnightTag ) then
			if (state == "disabled") then
				local textureBase = "Interface\\Buttons\\UI-DialogBox-goldbutton-disabled";

				self.Left:SetTexture(textureBase.."-left");
				self.Middle:SetTexture(textureBase.."-middle");
				self.Right:SetTexture(textureBase.."-right");
			else
				local textureBase = "UI-DialogBox-goldbutton-" .. state;

				self.Left:SetAtlas(textureBase.."-left-blue");
				self.Middle:SetAtlas(textureBase.."-middle-blue");
				self.Right:SetAtlas(textureBase.."-right-blue");
			end
			self:SetHighlightTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Highlight-Blue");
		else
			local textureBase = "Interface\\Buttons\\UI-DialogBox-goldbutton-" .. state;

			self.Left:SetTexture(textureBase.."-left");
			self.Middle:SetTexture(textureBase.."-middle");
			self.Right:SetTexture(textureBase.."-right");
			self:SetHighlightTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Highlight");
		end
	end
end

function CharacterSelectScrollDown_OnClick()
	PlaySound("igInventoryRotateCharacter");
	local numChars = GetNumCharacters();
	if ( numChars > 1 ) then
		if ( CharacterSelect.selectedIndex < GetNumCharacters() ) then
			local newIndex = CharacterSelect.selectedIndex + 1;
			if (newIndex > MAX_CHARACTERS_DISPLAYED) then
				CHARACTER_LIST_OFFSET = newIndex - MAX_CHARACTERS_DISPLAYED;
			end
			CharacterSelect_SelectCharacter(newIndex);
		else
			CHARACTER_LIST_OFFSET = 0;
			CharacterSelect_SelectCharacter(1);
		end
		UpdateCharacterList();
		UpdateCharacterSelection(CharacterSelect);
	end
end

function CharacterSelectScrollUp_OnClick()
	PlaySound("igInventoryRotateCharacter");
	local numChars = GetNumCharacters();
	if ( numChars > 1 ) then
		if ( CharacterSelect.selectedIndex > 1 ) then
			local newIndex = CharacterSelect.selectedIndex - 1;
			if (newIndex >= MAX_CHARACTERS_DISPLAYED) then
				CHARACTER_LIST_OFFSET = max(newIndex - MAX_CHARACTERS_DISPLAYED, 0);
			end
			CharacterSelect_SelectCharacter(newIndex);
		else
			CHARACTER_LIST_OFFSET = max(numChars - MAX_CHARACTERS_DISPLAYED, 0);
			CharacterSelect_SelectCharacter(numChars);
		end
		UpdateCharacterList();
		UpdateCharacterSelection(CharacterSelect);
	end
end

function CharacterSelectButton_OnDragUpdate(self)
	-- shouldn't be doing this without an index...
	if ( not CharacterSelect.draggedIndex) then
		CharacterSelectButton_OnDragStop(self);
		return;
	end
	-- only check Y-axis, user dragging horizontally should not change anything
	local _, cursorY = GetCursorPosition();
	if ( cursorY <= CHARACTER_LIST_TOP ) then
		-- check if the mouse is on a different button
		local buttonIndex = floor((CHARACTER_LIST_TOP - cursorY) / CHARACTER_BUTTON_HEIGHT) + 1;
		local button = _G["CharSelectCharacterButton"..buttonIndex];
		if ( button and button.index ~= CharacterSelect.draggedIndex and button:IsShown() ) then
			-- perform move
			if ( button.index > CharacterSelect.draggedIndex ) then
				-- move down
				MoveCharacter(CharacterSelect.draggedIndex, CharacterSelect.draggedIndex + 1, true);
			else
				-- move up
				MoveCharacter(CharacterSelect.draggedIndex, CharacterSelect.draggedIndex - 1, true);
			end
		end
	end
end

function CharacterSelectButton_OnDragStart(self)
	if ( GetNumCharacters() > 1 ) then
		CharacterSelect.pressDownButton = nil;
		CharacterSelect.draggedIndex = self:GetID() + CHARACTER_LIST_OFFSET;
		self:SetScript("OnUpdate", CharacterSelectButton_OnDragUpdate);
		for index = 1, MAX_CHARACTERS_DISPLAYED do
			local button = _G["CharSelectCharacterButton"..index];
			if ( button ~= self ) then
				button:SetAlpha(0.6);
				_G["CharSelectPaidService"..index].texture:SetVertexColor(0.35, 0.35, 0.35);
			end
		end
		self.buttonText.name:SetPoint("TOPLEFT", MOVING_TEXT_OFFSET, -5);
		self:LockHighlight();
		self.upButton:Hide();
		self.downButton:Hide();
	end
end

function CharacterSelectButton_OnDragStop(self)
	CharacterSelect.pressDownButton = nil;
	CharacterSelect.draggedIndex = nil;
	self:SetScript("OnUpdate", nil);
	for index = 1, MAX_CHARACTERS_DISPLAYED do
		local button = _G["CharSelectCharacterButton"..index];
		button:SetAlpha(1);
		button:UnlockHighlight();
		button.buttonText.name:SetPoint("TOPLEFT", DEFAULT_TEXT_OFFSET, -5);
		local paidBtn = _G["CharSelectPaidService"..index];
		paidBtn.texture:SetVertexColor(1, 1, 1);
		paidBtn.GoldBorder:SetVertexColor(1, 1, 1);
		paidBtn.VASIcon:SetVertexColor(1, 1, 1);
		if ( button.selection:IsShown() and button:IsMouseOver() ) then
			CharacterSelectButton_ShowMoveButtons(button);
		end
	end
end

function MoveCharacter(originIndex, targetIndex, fromDrag)
	CharacterSelect.orderChanged = true;
	if ( targetIndex < 1 ) then
		targetIndex = #translationTable;
	elseif ( targetIndex > #translationTable ) then
		targetIndex = 1;
	end
	if ( originIndex == CharacterSelect.selectedIndex ) then
		CharacterSelect.selectedIndex = targetIndex;
	elseif ( targetIndex == CharacterSelect.selectedIndex ) then
		CharacterSelect.selectedIndex = originIndex;
	end
	translationTable[originIndex], translationTable[targetIndex] = translationTable[targetIndex], translationTable[originIndex];
	-- update character list
	if ( fromDrag ) then
		CharacterSelect.draggedIndex = targetIndex;
	end
	UpdateCharacterSelection(CharacterSelect);
	UpdateCharacterList();
end

function CharacterSelectButton_DisableDrag(button)
	button:SetScript("OnMouseDown", nil);
	button:SetScript("OnMouseUp", nil);
	button:SetScript("OnDragStart", nil);
	button:SetScript("OnDragStop", nil);
end

function CharacterSelectButton_EnableDrag(button)
	button:SetScript("OnDragStart", CharacterSelectButton_OnDragStart);
	button:SetScript("OnDragStop", CharacterSelectButton_OnDragStop);
	-- Functions here copied from CharacterSelect.xml
	button:SetScript("OnMouseDown", function(self)
		CharacterSelect.pressDownButton = self;
		CharacterSelect.pressDownTime = 0;
	end);
	button:SetScript("OnMouseUp", CharacterSelectButton_OnDragStop);
end

-- translation functions
function GetCharIDFromIndex(index)
	return translationTable[index] or 0;
end

function GetIndexFromCharID(charID)
	-- no need for lookup if the order hasn't changed
	if ( not CharacterSelect.orderChanged ) then
		return charID;
	end
	for index = 1, #translationTable do
		if ( translationTable[index] == charID ) then
			return index;
		end
	end
	return 0;
end

ACCOUNT_UPGRADE_FEATURES = {
	VETERAN = { [1] = { icon = "Interface\\Icons\\achievement_bg_returnxflags_def_wsg", text = VETERAN_FEATURE_1 },
		  [2] = { icon = "Interface\\Icons\\achievement_reputation_01", text = VETERAN_FEATURE_2 },
		  [3] = { icon = "Interface\\Icons\\spell_holy_surgeoflight", text = VETERAN_FEATURE_3 },
		  logo = "Interface\\Glues\\Common\\Glues-WoW-WODLOGO",
		  banner = "accountupgradebanner-wod",
		  buttonText = REACTIVATE_ACCOUNT_NOW,
		  displayCheck =  function() return true end,
		  upgradeOnClick = function() SubscriptionRequestDialog_Open() end,
		  },
	[LE_EXPANSION_BURNING_CRUSADE] =
		{ [1] = { icon = "Interface\\Icons\\achievement_level_85", text = UPGRADE_FEATURE_7 },
		  [2] = { icon = "Interface\\Icons\\achievement_firelands raid_ragnaros", text = UPGRADE_FEATURE_8 },
		  [3] = { icon = "Interface\\Icons\\Ability_Mount_CelestialHorse", text = UPGRADE_FEATURE_9 },
		  logo = "Interface\\Glues\\Common\\Glues-WoW-CCLogo",
		  banner = "accountupgradebanner-cataclysm",
		  buttonText =  UPGRADE_ACCOUNT_SHORT,
		  displayCheck =  function() return GameLimitedMode_IsActive() or CanUpgradeExpansion() end,
		  upgradeOnClick = UpgradeAccount,
		  },
	[LE_EXPANSION_WRATH_OF_THE_LICH_KING] =
		{ [1] = { icon = "Interface\\Icons\\achievement_level_85", text = UPGRADE_FEATURE_7 },
		  [2] = { icon = "Interface\\Icons\\achievement_firelands raid_ragnaros", text = UPGRADE_FEATURE_8 },
		  [3] = { icon = "Interface\\Icons\\Ability_Mount_CelestialHorse", text = UPGRADE_FEATURE_9 },
		  logo = "Interface\\Glues\\Common\\Glues-WoW-CCLogo",
		  banner = "accountupgradebanner-cataclysm",
		  buttonText =  UPGRADE_ACCOUNT_SHORT,
		  displayCheck =  function() return GameLimitedMode_IsActive() or CanUpgradeExpansion() end,
		  upgradeOnClick = UpgradeAccount,
		  },
	[LE_EXPANSION_CATACLYSM] =
		{ [1] = { icon = "Interface\\Icons\\achievement_level_90", text = UPGRADE_FEATURE_10 },
		  [2] = { icon = "Interface\\Glues\\AccountUpgrade\\upgrade-panda", text = UPGRADE_FEATURE_11 },
		  [3] = { icon = "Interface\\Icons\\achievement_zone_jadeforest", text = UPGRADE_FEATURE_12 },
		  logo = "Interface\\Glues\\Common\\Glues-WoW-MPLogo",
		  banner = "accountupgradebanner-mop",
		  buttonText =  UPGRADE_ACCOUNT_SHORT,
		  displayCheck =  function() return GameLimitedMode_IsActive() or CanUpgradeExpansion() end,
		  upgradeOnClick = UpgradeAccount,
		  },
	[LE_EXPANSION_MISTS_OF_PANDARIA] =
		{ [1] = { icon = "Interface\\Icons\\Achievement_Quests_Completed_06", text = UPGRADE_FEATURE_2 },
		  [2] = { icon = "Interface\\Icons\\Achievement_Level_100", text = UPGRADE_FEATURE_14 },
		  [3] = { icon = "Interface\\Icons\\UI_Promotion_Garrisons", text = UPGRADE_FEATURE_15 },
		  logo = "Interface\\Glues\\Common\\Glues-WoW-WODLOGO",
		  banner = "accountupgradebanner-wod",
		  buttonText =  UPGRADE_ACCOUNT_SHORT,
		  displayCheck =  function() return GameLimitedMode_IsActive() or CanUpgradeExpansion() end,
		  upgradeOnClick = UpgradeAccount,
		  },
	[LE_EXPANSION_WARLORDS_OF_DRAENOR] =
		{ [1] = { icon = "Interface\\Icons\\ClassIcon_DemonHunter", text = UPGRADE_FEATURE_16 },
		  [2] = { icon = "Interface\\Icons\\Icon_TreasureMap", text = UPGRADE_FEATURE_17 },
		  [3] = { icon = "Interface\\Icons\\UI_Promotion_CharacterBoost", text = UPGRADE_FEATURE_18 },
		  atlasLogo = "Glues-WoW-LegionLogo",
		  banner = "accountupgradebanner-legion",
		  buttonText = UPGRADE_ACCOUNT_SHORT,
		  displayCheck =  function() return GameLimitedMode_IsActive() or CanUpgradeExpansion() end,
		  upgradeOnClick = function()
			if ( CharacterSelect_IsStoreAvailable() and C_PurchaseAPI.HasProductType(LE_BATTLEPAY_PRODUCT_ITEM_7_0_BOX_LEVEL) ) then
				StoreFrame_SetGamesCategory();
				StoreFrame_SetShown(true);
			else
				-- if the store is down or parentally locked, send the player to the web
				UpgradeAccount();
			end
		  end,
		  },
}

-- Account upgrade panel
function AccountUpgradePanel_GetExpansionTag(isExpanded)
	local tag, logoTag;
	if ( IsTrialAccount() ) then
		-- Trial users have the starter edition logo with an upgrade banner that brings you to the lowest expansion level available.
		tag = max(GetAccountExpansionLevel(), GetExpansionLevel()) - 1;
		logoTag = "TRIAL";
	elseif ( IsVeteranTrialAccount() ) then
		-- Trial users have the starter edition logo with an upgrade banner that brings you to the lowest expansion level available.
		tag = "VETERAN";
		logoTag = min(GetClientDisplayExpansionLevel(), max(GetAccountExpansionLevel(), GetExpansionLevel()));
	else
		tag = min(GetClientDisplayExpansionLevel(), max(GetAccountExpansionLevel(), GetExpansionLevel()));
		logoTag = tag;
		if ( IsExpansionTrial() ) then
			tag = tag - 1;
		end
	end
	return tag, logoTag;
end

-- Account upgrade panel
function AccountUpgradePanel_Update(isExpanded)
	local tag, logoTag = AccountUpgradePanel_GetExpansionTag();

	SetExpansionLogo(CharacterSelectLogo, logoTag);

	if ( not ACCOUNT_UPGRADE_FEATURES[tag] or not ACCOUNT_UPGRADE_FEATURES[tag].displayCheck() ) then
		CharSelectAccountUpgradePanel:Hide();
		CharSelectAccountUpgradeButton:Hide();
		CharSelectAccountUpgradeMiniPanel:Hide();
		CharacterSelectServerAlertFrame:SetPoint("TOP", CharacterSelectLogo, "BOTTOM", 0, -5);
	else
		CharSelectAccountUpgradeButton:SetText(ACCOUNT_UPGRADE_FEATURES[tag].buttonText);
		CharacterSelectServerAlertFrame:SetPoint("TOP", CharSelectAccountUpgradeMiniPanel, "BOTTOM", 0, -25);
		local featureTable = ACCOUNT_UPGRADE_FEATURES[tag];
		CharSelectAccountUpgradeButton:Show();
		if ( isExpanded ) then
			CharSelectAccountUpgradePanel:Show();
			CharSelectAccountUpgradeMiniPanel:Hide();

			if(featureTable.logo) then
				CharSelectAccountUpgradePanel.logo:SetTexture(featureTable.logo);
			else
				CharSelectAccountUpgradePanel.logo:SetAtlas(featureTable.atlasLogo, false);
			end
			CharSelectAccountUpgradePanel.banner:SetAtlas(featureTable.banner, true);

			local featureFrames = CharSelectAccountUpgradePanel.featureFrames;
			for i=1, #featureTable do
				local frame = featureFrames[i];
				if ( not frame ) then
					frame = CreateFrame("FRAME", "CharSelectAccountUpgradePanelFeature"..i, CharSelectAccountUpgradePanel, "UpgradeFrameFeatureTemplate");
					frame:SetPoint("TOPLEFT", featureFrames[i - 1], "BOTTOMLEFT", 0, 0);
				end

				frame.icon:SetTexture(featureTable[i].icon);
				frame.text:SetText(featureTable[i].text);
			end
			for i=#featureTable + 1, #featureFrames do
				featureFrames[i]:Hide();
			end

			CharSelectAccountUpgradeButtonExpandCollapseButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up");
			CharSelectAccountUpgradeButtonExpandCollapseButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down");
			CharSelectAccountUpgradeButtonExpandCollapseButton:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled");
		else
			CharSelectAccountUpgradePanel:Hide();
			CharSelectAccountUpgradeMiniPanel:Show();

			if(featureTable.logo) then
				CharSelectAccountUpgradeMiniPanel.logo:SetTexture(featureTable.logo);
			else
				CharSelectAccountUpgradeMiniPanel.logo:SetAtlas(featureTable.atlasLogo, false);
			end
			CharSelectAccountUpgradeMiniPanel.banner:SetAtlas(featureTable.banner, true);

			CharSelectAccountUpgradeButtonExpandCollapseButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up");
			CharSelectAccountUpgradeButtonExpandCollapseButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down");
			CharSelectAccountUpgradeButtonExpandCollapseButton:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled");
		end
	end
	CharSelectAccountUpgradeButton.isExpanded = isExpanded;
	SetCVar("expandUpgradePanel", isExpanded and "1" or "0");
end

function AccountUpgradePanel_ToggleExpandState()
	AccountUpgradePanel_Update(not CharSelectAccountUpgradeButton.isExpanded);
end

function AccountUpgradePanel_UpdateExpandState()
	if ( CharacterSelectServerAlertFrame:IsShown() ) then
		CharSelectAccountUpgradeButton.isExpanded = false;
		CharSelectAccountUpgradeButton.expandCollapseButton:Hide();
	elseif ( GameLimitedMode_IsActive() ) then
		CharSelectAccountUpgradeButton.isExpanded = true;
		CharSelectAccountUpgradeButton.expandCollapseButton:Show();
		CharSelectAccountUpgradeButton.expandCollapseButton:Disable();
	else
		CharSelectAccountUpgradeButton.expandCollapseButton:Show();
		CharSelectAccountUpgradeButton.expandCollapseButton:Enable();
	end
	AccountUpgradePanel_Update(CharSelectAccountUpgradeButton.isExpanded);
end

function CharSelectAccountUpgradeButton_OnClick(self)
	PlaySound("gsTitleOptionOK");
	local tag = AccountUpgradePanel_GetExpansionTag();
	ACCOUNT_UPGRADE_FEATURES[tag].upgradeOnClick();
end

function CharacterSelect_ScrollList(self, value)
	if ( not self.blockUpdates ) then
		CHARACTER_LIST_OFFSET = floor(value);
		UpdateCharacterList(true);	-- skip selecting
		UpdateCharacterSelection(CharacterSelect);	-- for button selection
		if (CharSelectServicesFlowFrame:IsShown()) then
			CharacterServicesMaster_Restart();
		end
	end
end

function CharacterTemplatesFrame_Update()
	if (IsGMClient() and HideGMOnly()) then
		return;
	end

	local self = CharacterTemplatesFrame;
	local numTemplates = GetNumCharacterTemplates();
	if ( numTemplates > 0 and IsConnectedToServer() ) then
		if ( not self:IsShown() ) then
			-- set it up
			self:Show();
			GlueDropDownMenu_SetAnchor(self.dropDown, -100, 54, "TOP", self, "TOP");
			GlueDropDownMenu_SetWidth(self.dropDown, 160);
			GlueDropDownMenu_Initialize(self.dropDown, CharacterTemplatesFrameDropDown_Initialize);
			GlueDropDownMenu_SetSelectedID(self.dropDown, 1);
		end
	else
		self:Hide();
	end
end

function CharacterTemplatesFrameDropDown_Initialize()
	local info = GlueDropDownMenu_CreateInfo();
	for i = 1, GetNumCharacterTemplates() do
		local name, description = GetCharacterTemplateInfo(i);
		info.text = name;
		info.checked = nil;
		info.func = CharacterTemplatesFrameDropDown_OnClick;
		info.tooltipTitle = name;
		info.tooltipText = description;
		GlueDropDownMenu_AddButton(info);
	end
end

function ToggleStoreUI()
	if (STORE_IS_LOADED) then
		local wasShown = StoreFrame_IsShown();
		if ( not wasShown ) then
			--We weren't showing, now we are. We should hide all other panels.
			-- not sure if anything is needed here at the gluescreen
		end
		StoreFrame_SetShown(not wasShown);
	end
end

function CharacterTemplatesFrameDropDown_OnClick(button)
	GlueDropDownMenu_SetSelectedID(CharacterTemplatesFrameDropDown, button:GetID());
end

function PlayersOnServer_Update()
	if (IsGMClient() and HideGMOnly()) then
		return;
	end

	local self = PlayersOnServer;
	local connected = IsConnectedToServer();
	if (not connected) then
		self:Hide();
		return;
	end

	local showPlayers, numHorde, numAlliance = GetPlayersOnServer();
	if showPlayers then
		if not self:IsShown() then
			self:Show();
		end
		self.HordeCount:SetText(numHorde);
		self.AllianceCount:SetText(numAlliance);
		self.HordeStar:SetShown(numHorde < numAlliance);
		self.AllianceStar:SetShown(numAlliance < numHorde);
	else
		self:Hide();
	end
end

function CharacterSelect_ActivateFactionChange()
	if IsConnectedToServer() then
		EnableChangeFaction();
		GetCharacterListUpdate();
	end
end

function CharacterSelect_IsStoreAvailable()
	return C_StorePublic.IsEnabled() and not C_StorePublic.IsDisabledByParentalControls() and GetNumCharacters() > 0 and not GameLimitedMode_IsActive();
end

function CharacterSelect_UpdateStoreButton()
	if ( CharacterSelect_IsStoreAvailable() and not IsKioskModeEnabled()) then
		StoreButton:Show();
	else
		StoreButton:Hide();
	end
end

GlueDialogTypes["TOKEN_GAME_TIME_OPTION_NOT_AVAILABLE"] = {
	text = ACCOUNT_REACTIVATE_OPTION_UNAVAILABLE,
	button1 = OKAY,
	escapeHides = true,
}

function CharacterSelect_HasVeteranEligibilityInfo()
	return TOKEN_COUNT_UPDATED and ((C_WowTokenGlue.GetTokenCount() > 0 or CAN_BUY_RESULT_FOUND) and C_WowTokenPublic.GetCurrentMarketPrice());
end

function CharacterSelect_ResetVeteranStatus()
	CAN_BUY_RESULT_FOUND = false;
	TOKEN_COUNT_UPDATED = false;
end

function CharacterSelect_CheckVeteranStatus()
	if (IsVeteranTrialAccount() and CharacterSelect_HasVeteranEligibilityInfo()) then
		ReactivateAccountDialog_Open();
	elseif (IsVeteranTrialAccount()) then
		if (not TOKEN_COUNT_UPDATED) then
			C_WowTokenPublic.UpdateTokenCount();
		end
		if (not CAN_BUY_RESULT_FOUND and TOKEN_COUNT_UPDATED) then
			C_WowTokenGlue.CheckVeteranTokenEligibility();
		end
		if (not C_WowTokenPublic.GetCurrentMarketPrice() and CAN_BUY_RESULT_FOUND) then
			C_WowTokenPublic.UpdateMarketPrice();
		end
	end
end

function CharacterSelect_UpdateButtonState()
	local hasCharacters = GetNumCharacters() > 0;
	local servicesEnabled = not CharSelectServicesFlowFrame:IsShown();
	local undeleting = CharacterSelect.undeleting;
	local undeleteEnabled, undeleteOnCooldown = GetCharacterUndeleteStatus();
	local redemptionInProgress = AccountReactivationInProgressDialog:IsShown() or GoldReactivateConfirmationDialog:IsShown() or TokenReactivateConfirmationDialog:IsShown();

	local boostInProgress = select(18,GetCharacterInfo(GetCharacterSelection()));
	CharSelectEnterWorldButton:SetEnabled(CharacterSelect_AllowedToEnterWorld());
	CharacterSelectBackButton:SetEnabled(servicesEnabled and not undeleting and not boostInProgress);
	CharacterSelectDeleteButton:SetEnabled(hasCharacters and servicesEnabled and not undeleting and not redemptionInProgress and not CharacterSelect_IsRetrievingCharacterList());
	CharSelectChangeRealmButton:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress);
	CharSelectUndeleteCharacterButton:SetEnabled(servicesEnabled and undeleteEnabled and not undeleteOnCooldown and not redemptionInProgress);
	CharacterSelectAddonsButton:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress and not IsKioskModeEnabled());
	CopyCharacterButton:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress);
	ActivateFactionChange:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress);
	ActivateFactionChange.texture:SetDesaturated(not (servicesEnabled and not undeleting and not redemptionInProgress));
	CharacterTemplatesFrame.CreateTemplateButton:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress);
	CharacterSelectMenuButton:SetEnabled(servicesEnabled and not redemptionInProgress);
	CharSelectCreateCharacterButton:SetEnabled(servicesEnabled and not redemptionInProgress);
	StoreButton:SetEnabled(servicesEnabled and not undeleting and not redemptionInProgress);

	if( CharacterSelect.CharacterBoosts ) then
		for _, frame in pairs(CharacterSelect.CharacterBoosts) do
			frame:SetEnabled(not redemptionInProgress);
		end
	end

	CharSelectAccountUpgradeButton:SetEnabled(not redemptionInProgress and not undeleting);
end

function CharacterSelect_DeleteCharacter(charID)
	if CharacterSelect_IsRetrievingCharacterList() then
		return;
	end

	DeleteCharacter(GetCharIDFromIndex(CharacterSelect.selectedIndex));
	CharacterDeleteDialog:Hide();
	PlaySound("gsTitleOptionOK");
	GlueDialog_Show("CHAR_DELETE_IN_PROGRESS");
end

-- CHARACTER BOOST (SERVICES)
function CharacterServicesMaster_UpdateServiceButton()
	if( not CharacterSelect.CharacterBoosts ) then
		CharacterSelect.CharacterBoosts = {}
	else
		for _, frame in pairs(CharacterSelect.CharacterBoosts) do
			frame:Hide();
			frame.Glow:Hide();
			frame.GlowSpin:Hide();
			frame.GlowPulse:Hide();
			frame.GlowSpin.SpinAnim:Stop();
			frame.GlowPulse.PulseAnim:Stop();
		end
	end
	UpgradePopupFrame:Hide();
	CharacterSelectUI.WarningText:Hide();

	if (CharacterSelect.undeleting or CharSelectServicesFlowFrame:IsShown()) then
		return;
	end

	local upgradeAmounts = C_SharedCharacterServices.GetUpgradeDistributions();
	-- merge paid boosts into the free boosts of the same id and mark as having a paid boost
	-- level 90 boosts are treated differently
	local hasPurchasedBoost = false;
	for id, data in pairs(upgradeAmounts) do
		if( id == LE_BATTLEPAY_PRODUCT_ITEM_LEVEL_90_CHARACTER_UPGRADE ) then
			hasPurchasedBoost = hasPurchasedBoost or data.numPaid > 0;
		else
			hasPurchasedBoost = hasPurchasedBoost or data.numPaid > 0;
			if( data.numFree > 0 ) then
				data.numFree = data.numFree + data.numPaid;
				data.numPaid = 0;
			end
		end
	end

	-- support refund notice for Korea
	if ( hasPurchasedBoost and C_PurchaseAPI.GetCurrencyID() == CURRENCY_KRW ) then
		CharacterSelectUI.WarningText:Show();
	end

	local boostFrameIdx = 1;
	local freeFrame = nil;
	for _, displayData in pairs(CharacterUpgrade_DisplayOrder) do
		local charUpgradeDisplayData; -- display data
		local amount = 0;
		local upgradeData = upgradeAmounts[displayData.productId];
		if ( upgradeData ) then
			if ( displayData.free ) then
				amount = upgradeData.numFree or 0;
				charUpgradeDisplayData = CharacterUpgrade_Items[displayData.productId].free;
			else
				amount = upgradeData.numPaid or 0;
				charUpgradeDisplayData = CharacterUpgrade_Items[displayData.productId].paid;
			end
		end

		if ( amount > 0 ) then
			local frame = CharacterSelect.CharacterBoosts[boostFrameIdx];
			if ( not frame ) then
				frame = CreateFrame("Button", "CharacterSelectCharacterBoost"..boostFrameIdx, CharacterSelect, "CharacterBoostTemplate");
			end

			frame.data = charUpgradeDisplayData;

			if ( charUpgradeDisplayData.Size ) then
				frame:SetSize(charUpgradeDisplayData.Size.x, charUpgradeDisplayData.Size.y);
				frame.IconBorder:SetSize(charUpgradeDisplayData.Size.x, charUpgradeDisplayData.Size.y);
			else
				frame:SetSize(59, 60);
				frame.IconBorder:SetSize(59, 60);
			end

			SetPortraitToTexture(frame.Icon, charUpgradeDisplayData.icon);
			SetPortraitToTexture(frame.Highlight.Icon, charUpgradeDisplayData.icon);
			frame.IconBorder:SetAtlas(charUpgradeDisplayData.iconBorder);
			frame.Highlight.IconBorder:SetAtlas(charUpgradeDisplayData.iconBorder);

			if ( boostFrameIdx > 1 ) then
				frame:SetPoint("TOPRIGHT", CharacterSelect.CharacterBoosts[boostFrameIdx-1], "TOPLEFT", -3, 0);
			else
				frame:SetPoint("TOPRIGHT", CharacterSelectCharacterFrame, "TOPLEFT", -18, -4);
			end

			if ( amount > 1 ) then
				frame.Ring:Show();
				frame.NumberBackground:Show();
				frame.Number:Show();
				frame.Number:SetText(amount);
			else
				frame.Ring:Hide();
				frame.NumberBackground:Hide();
				frame.Number:Hide();
			end
			frame:Show();

			if ( displayData.free and (not freeFrame or freeFrame.data.expansion < frame.data.expansion) ) then
				freeFrame = frame;
			end
			boostFrameIdx = boostFrameIdx + 1;
		end
	end

	if ( freeFrame and C_SharedCharacterServices.GetLastSeenUpgradePopup() < freeFrame.data.expansion ) then
		local freeFrameData = freeFrame.data;
		if ( freeFrameData.glowOffset ) then
			freeFrame.Glow:SetPoint("CENTER", freeFrame.IconBorder, "CENTER", freeFrameData.glowOffset.x, freeFrameData.glowOffset.y)
		else
			freeFrame.Glow:SetPoint("CENTER", freeFrame.IconBorder, "CENTER", 0, 0);
		end
		freeFrame.Glow:Show();
		freeFrame.GlowSpin.SpinAnim:Play();
		freeFrame.GlowPulse.PulseAnim:Play();
		freeFrame.GlowSpin:Show();
		freeFrame.GlowPulse:Show();

		local popupData = freeFrameData.popupDesc;
		local popupFrame = UpgradePopupFrame;
		popupFrame.data = freeFrameData;
		popupFrame.Title:SetText(popupData.title);
		popupFrame.Description:SetText(popupData.desc);
		popupFrame.Top:SetAtlas(popupData.topAtlas, true);
		popupFrame.Middle:SetAtlas(popupData.middleAtlas, false);
		popupFrame.Bottom:SetAtlas(popupData.bottomAtlas, true);

		local hasCloseButton = popupData.closeButtonAtlas ~= nil;
		popupFrame.CloseButtonBG:SetShown(hasCloseButton);
		popupFrame.CloseButton:SetShown(hasCloseButton);

		if hasCloseButton then
			popupFrame.CloseButtonBG:SetAtlas(popupData.closeButtonAtlas, true);
		end

		popupFrame:SetWidth(popupData.width);

		popupFrame:ClearAllPoints();

		if popupData.centerScreenAnchorOverride then
			popupFrame:SetPoint("CENTER", GlueParent, "CENTER", popupData.offset.x, popupData.offset.y);
		else
		popupFrame:SetPoint("TOPRIGHT", freeFrame, "CENTER", popupData.offset.x, popupData.offset.y);
		end

		popupFrame:SetHeight( popupFrame:GetTop() - popupFrame.LaterButton:GetBottom() + 45 );
		popupFrame:Show();
	end
end

local function CharacterUpgradePopup_CheckSetPopupSeen(data)
	if UpgradePopupFrame and UpgradePopupFrame.data and UpgradePopupFrame:IsVisible() then
		if (data.expansion == UpgradePopupFrame.data.expansion and C_SharedCharacterServices.GetLastSeenUpgradePopup() < data.expansion) then
			C_SharedCharacterServices.SetPopupSeen(data.expansion);
		end
	end
end

local function HandleUpgradePopupButtonClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn"); -- TODO: Is there a better sound to play in case this is a close button?
	local data = self:GetParent().data;
	CharacterUpgradePopup_CheckSetPopupSeen(data);
	return data;
end

function CharacterUpgradePopup_BeginCharacterUpdgradeFlow(data)
	CharacterUpgradePopup_CheckSetPopupSeen(data);
	CharacterUpgradeFlow:SetTarget(data);
	CharSelectServicesFlowFrame:Show();
	CharacterServicesMaster_SetFlow(CharacterServicesMaster, CharacterUpgradeFlow);
end

function CharacterUpgradePopup_BeginUnlockTrialCharacter(flowData, guid)
	CharacterUpgradeFlow:SetAutoSelectGuid(guid);
	CharacterUpgradePopup_BeginCharacterUpdgradeFlow(flowData);
end

function CharacterUpgradePopup_OnStartClick(self)
	local data = HandleUpgradePopupButtonClick(self);
	CharacterUpgradePopup_BeginCharacterUpdgradeFlow(data);
end

function CharacterUpgradePopup_OnTryNewClick(self)
	HandleUpgradePopupButtonClick(self);

	if (C_CharacterServices.IsTrialBoostEnabled()) then
		CharacterUpgrade_BeginNewCharacterCreation(LE_CHARACTER_CREATE_TYPE_TRIAL_BOOST);
	end
end

function CharacterUpgradePopup_OnCloseClick(self)
	HandleUpgradePopupButtonClick(self);
	CharacterServicesMaster_UpdateServiceButton();
end

function CharacterServicesTokenBoost_OnClick(self)
	if HasSufficientExperienceForAdvancedCreation() then
		CharacterUpgradePopup_BeginCharacterUpdgradeFlow(self.data);
	else
		GlueDialog_Show("CHARACTER_BOOST_NO_CHARACTERS_WARNING", nil, self.data);
	end
end

function CharacterServicesMaster_OnLoad(self)
	self.flows = {};

	self:RegisterEvent("PRODUCT_DISTRIBUTIONS_UPDATED");
	self:RegisterEvent("CHARACTER_UPGRADE_STARTED");
	self:RegisterEvent("PRODUCT_ASSIGN_TO_TARGET_FAILED");
end

local completedGuid;

function CharacterServicesMaster_OnEvent(self, event, ...)
	if (event == "PRODUCT_DISTRIBUTIONS_UPDATED") then
		CharacterServicesMaster_UpdateServiceButton();
	elseif (event == "CHARACTER_UPGRADE_STARTED") then
		UpdateCharacterList(true);
		UpdateCharacterSelection(CharacterSelect);
	elseif (event == "PRODUCT_ASSIGN_TO_TARGET_FAILED") then
		GlueDialog_Show("PRODUCT_ASSIGN_TO_TARGET_FAILED");
	end
end

function CharacterServicesMaster_OnCharacterListUpdate()
	local startAutomatically, automaticProduct = C_CharacterServices.GetStartAutomatically();
	if (CharacterServicesMaster.waitingForLevelUp) then
		C_CharacterServices.ApplyLevelUp();
		CharacterServicesMaster.waitingForLevelUp = false;
	elseif (CharacterUpgrade_IsCreatedCharacterUpgrade() or startAutomatically) then
		if (CharacterUpgrade_IsCreatedCharacterUpgrade()) then
			CharacterUpgradeFlow.data = CHARACTER_UPGRADE_CREATE_CHARACTER_DATA;
		else
			CharacterUpgradeFlow.data = CharacterUpgrade_Items[automaticProduct].paid;
		end

		if CharacterUpgradeFlow.data then
			CharSelectServicesFlowFrame:Show();
		CharacterServicesMaster_SetFlow(CharacterServicesMaster, CharacterUpgradeFlow);
		end

		CharacterUpgrade_ResetBoostData();
		C_SharedCharacterServices.SetStartAutomatically(false);
	elseif (C_CharacterServices.HasQueuedUpgrade()) then
		local guid = C_CharacterServices.GetQueuedUpgradeGUID();

	  	CharacterServicesMaster.waitingForLevelUp = CharacterSelect_SelectCharacterByGUID(guid);

		C_CharacterServices.ClearQueuedUpgrade();
	end
end

function CharacterServicesMaster_SetFlow(self, flow)
	self.flow = flow;
	if (not self.flows[flow]) then
		setmetatable(flow, { __index = CharacterServicesFlowPrototype });
	end
	self.flows[flow] = true;
	flow:Initialize(self);
	SetPortraitToTexture(self:GetParent().Icon, flow.data.icon);
	self:GetParent().TitleText:SetText(flow.data.flowTitle);
	self:GetParent().FinishButton:SetText(flow.FinishLabel);
	for i = 1, #flow.Steps do
		local block = flow.Steps[i];
		if (not block.HiddenStep) then
			block.frame:SetFrameLevel(CharacterServicesMaster:GetFrameLevel()+2);
			block.frame:SetParent(self);
		end
	end
end

function CharacterServicesMaster_SetCurrentBlock(self, block, wasFromRewind)
	local parent = self:GetParent();
	if (not block.HiddenStep) then
		CharacterServicesMaster_SetBlockActiveState(block);
	end
	self.currentBlock = block;
	self.blockComplete = false;
	parent.BackButton:SetShown(block.Back);
	parent.NextButton:SetShown(block.Next);
	parent.FinishButton:SetShown(block.Finish);
	if (block.Finish) then
		self.FinishTime = GetTime();
	end

	-- Some blocks may remember user choices when the user returns to
	-- them.  As such, even though the block isn't finished for purposes
	-- of advancing to the next step, the next button should still be
	-- enabled.  This addresses an issue where the "alert, next is ready!"
	-- animation was playing even though from the user's point of view
	-- the next button never really appeared disabled.

	local isFinished = block:IsFinished(wasFromRewind);

	if wasFromRewind then
		local forwardStateWouldBeFinished = block:IsFinished();
		parent.NextButton:SetEnabled(forwardStateWouldBeFinished);
	else
		parent.NextButton:SetEnabled(isFinished);
	end

	-- Since there's no way to finish the entire flow and then go back,
	-- the finishButton is always enabled based on the block actually
	-- being finished.
	parent.FinishButton:SetEnabled(isFinished);
end

function CharacterServicesMaster_Restart()
	local self = CharacterServicesMaster;

	if (self.flow) then
		self.flow:Restart(self);
	end
end

function CharacterServicesMaster_Update()
	local self = CharacterServicesMaster;
	local parent = self:GetParent();
	local block = self.currentBlock;

	if (block and block:IsFinished()) then
		if (not block.HiddenStep and (block.AutoAdvance or self.blockComplete)) then
			CharacterServicesMaster_SetBlockFinishedState(block);
		end

		if (block.AutoAdvance) then
			self.flow:Advance(self);
		else
			if (block.Next) then
				if (not parent.NextButton:IsEnabled()) then
					parent.NextButton:SetEnabled(true);
					if ( parent.NextButton:IsVisible() ) then
						parent.NextButton.Flash:Show();
						parent.NextButton.PulseAnim:Play();
					end
				end
			elseif (block.Finish) then
				parent.FinishButton:SetEnabled(true);
			end
		end
	elseif (block) then
		if (block.Next) then
			parent.NextButton:SetEnabled(false);

			if ( parent.NextButton:IsVisible() ) then
				parent.NextButton.PulseAnim:Stop();
				parent.NextButton.Flash:Hide();
			end
		elseif (block.Finish) then
			parent.FinishButton:SetEnabled(false);
		end
	end
	self.currentTime = 0;
end

function CharacterServicesMaster_OnHide(self)
	for flow, _ in pairs(self.flows) do
		flow:OnHide();
	end
end

function CharacterServicesMaster_SetBlockActiveState(block)
	block.frame.StepLabel:Show();
	block.frame.StepNumber:Show();
	block.frame.StepActiveLabel:Show();
	block.frame.StepActiveLabel:SetText(block.ActiveLabel);
	block.frame.ControlsFrame:Show();
	block.frame.Checkmark:Hide();
	block.frame.StepFinishedLabel:Hide();
	block.frame.ResultsLabel:Hide();
end

function CharacterServicesMaster_SetBlockFinishedState(block)
	block.frame.Checkmark:Show();
	block.frame.StepFinishedLabel:Show();
	block.frame.StepFinishedLabel:SetText(block.ResultsLabel);
	block.frame.ResultsLabel:Show();
	if (block.FormatResult) then
		block.frame.ResultsLabel:SetText(block:FormatResult());
	else
		block.frame.ResultsLabel:SetText(block:GetResult());
	end
	block.frame.StepLabel:Hide();
	block.frame.StepNumber:Hide();
	block.frame.StepActiveLabel:Hide();
	block.frame.ControlsFrame:Hide();
end

function CharacterServicesMasterBackButton_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn");
	local master = CharacterServicesMaster;
	master.flow:Rewind(master);
end

function CharacterServicesMasterNextButton_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn");
	local master = CharacterServicesMaster;
	if ( master.currentBlock.Popup and
		( not master.currentBlock.ShowPopupIf or master.currentBlock:ShowPopupIf() )) then
		local text;
		if ( master.currentBlock.GetPopupText ) then
			text = master.currentBlock:GetPopupText();
		end
		GlueDialog_Show(master.currentBlock.Popup, text);
		return;
	end

	CharacterServicesMaster_Advance();
end

function CharacterServicesProcessingIcon_OnEnter(self)
	GlueTooltip:SetOwner(self, "ANCHOR_LEFT", -20, 0);
	GlueTooltip:AddLine(self.tooltip, 1.0, 1.0, 1.0);
	GlueTooltip:AddLine(self.tooltip2, nil, nil, nil, 1, 1);
	GlueTooltip:Show();
end

function CharacterServicesMaster_Advance()
	local master = CharacterServicesMaster;
	master.blockComplete = true;
	CharacterServicesMaster_Update();
	master.flow:Advance(master);
end

function CharacterServicesMasterFinishButton_OnClick(self)
	-- wait a bit after button is shown so no one accidentally upgrades the wrong character
	if ( GetTime() - CharacterServicesMaster.FinishTime < 0.5 ) then
		return;
	end
	local master = CharacterServicesMaster;
	local parent = master:GetParent();
	local success = master.flow:Finish(master);
	if (success) then
		PlaySound("gsCharacterSelectionCreateNew");
		parent:Hide();
	else
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end

function CharacterServicesTokenBoost_OnEnter(self)
	self.Highlight:Show();
	GlueTooltip:SetOwner(self, "ANCHOR_LEFT");
	if ( self.data.productId == LE_BATTLEPAY_PRODUCT_ITEM_LEVEL_90_CHARACTER_UPGRADE and self.data.free and
		C_SharedCharacterServices.HasFreePromotionalUpgrade() ) then
		-- handle with free Asia character boost
		title = CHARACTER_UPGRADE_WOD_TOKEN_TITLE_ASIA;
		desc = CHARACTER_UPGRADE_WOD_TOKEN_DESCRIPTION_ASIA;
	else
		title = self.data.tooltipTitle;
		desc = self.data.tooltipDesc;
	end
	GlueTooltip:AddLine(title, 1.0, 1.0, 1.0);
	GlueTooltip:AddLine(desc, nil, nil, nil, 1, 1);
	GlueTooltip:Show();
end

function CharacterServicesTokenBoost_OnLeave(self)
	self.Highlight:Hide();
	GlueTooltip:Hide();
end

function CharacterUpgradeSecondChanceWarningFrameConfirmButton_OnClick(self)
	CharacterUpgradeSecondChanceWarningFrame.warningAccepted = true;

	CharacterUpgradeSecondChanceWarningFrame:Hide();

	CharacterServicesMasterFinishButton_OnClick(CharacterServicesMasterFinishButton);
end

function CharacterUpgradeSecondChanceWarningFrameCancelButton_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn");

	CharacterUpgradeSecondChanceWarningFrame:Hide();

	CharacterUpgradeSecondChanceWarningFrame.warningAccepted = false;
end

-- CHARACTER UNDELETE

GlueDialogTypes["UNDELETE_FAILED"] = {
	text = UNDELETE_FAILED_ERROR,
	button1 = OKAY,
	escapeHides = true,
}

GlueDialogTypes["UNDELETE_NAME_TAKEN"] = {
	text = UNDELETE_NAME_TAKEN,
	button1 = OKAY,
	escapeHides = true,
}

GlueDialogTypes["UNDELETE_NO_CHARACTERS"] = {
	text = UNDELETE_NO_CHARACTERS;
	button1 = OKAY,
	button2 = nil,
}

GlueDialogTypes["UNDELETE_SUCCEEDED"] = {
	text = UNDELETE_SUCCESS,
	button1 = OKAY,
	escapeHides = true,
}

GlueDialogTypes["UNDELETE_SUCCEEDED_NAME_TAKEN"] = {
	text = UNDELETE_SUCCESS_NAME_CHANGE_REQUIRED,
	button1 = OKAY,
	escapeHides = true,
}

GlueDialogTypes["UNDELETE_CONFIRM"] = {
	text = UNDELETE_CONFIRMATION,
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function ()
		CharacterSelect_FinishUndelete(CharacterSelect.pendingUndeleteGuid);
		CharacterSelect.pendingUndeleteGuid = nil;
	end,
	OnCancel = function ()
		CharacterSelect.pendingUndeleteGuid = nil;
	end,
}

function CharacterSelect_StartCharacterUndelete()
	CharacterSelect.undeleting = true;
	CharacterSelect.undeleteChanged = true;

	CharSelectCreateCharacterButton:Hide();
	CharSelectUndeleteCharacterButton:Hide();
	CharSelectBackToActiveButton:Show();
	CharSelectChangeRealmButton:Hide();
	CharSelectUndeleteLabel:Show();

	AccountReactivate_CloseDialogs();

	CharacterServicesMaster_UpdateServiceButton();
	StartCharacterUndelete();
end

function CharacterSelect_EndCharacterUndelete()
	CharacterSelect.undeleting = false;
	CharacterSelect.undeleteChanged = true;

	CharSelectBackToActiveButton:Hide();
	CharSelectCreateCharacterButton:Show();
	CharSelectUndeleteCharacterButton:Show();
	CharSelectChangeRealmButton:Show();
	CharSelectUndeleteLabel:Hide();

	CharacterServicesMaster_UpdateServiceButton();
	EndCharacterUndelete();
end

function CharacterSelect_FinishUndelete(guid)
	GlueDialog_Show("UNDELETING_CHARACTER");

	UndeleteCharacter(guid);
	CharacterSelect.createIndex = 0;
end

-- COPY CHARACTER

MAX_COPY_CHARACTER_BUTTONS = 19;
COPY_CHARACTER_BUTTON_HEIGHT = 16;

GlueDialogTypes["COPY_CHARACTER"] = {
	text = "",
	button1 = OKAY,
	button2 = CANCEL,
	escapeHides = true,
	OnAccept = function ()
		CopyCharacterFromLive();
	end,
}

GlueDialogTypes["COPY_ACCOUNT_DATA"] = {
	text = COPY_ACCOUNT_CONFIRM,
	button1 = OKAY,
	button2 = CANCEL,
	escapeHides = true,
	OnAccept = function ()
		CopyCharacter_AccountDataFromLive();
	end,
}

GlueDialogTypes["COPY_IN_PROGRESS"] = {
	text = COPY_IN_PROGRESS,
	button1 = nil,
	button2 = nil,
	ignoreKeys = true,
	spinner = true,
}

GlueDialogTypes["UNDELETING_CHARACTER"] = {
	text = RESTORING_CHARACTER_IN_PROGRESS,
	ignoreKeys = true,
	spinner = true,
}

function CopyCharacterFromLive()
	CopyAccountCharacterFromLive(CopyCharacterFrame.SelectedIndex);
	GlueDialog_Show("COPY_IN_PROGRESS");
end

function CopyCharacter_AccountDataFromLive()
	local allowed = CopyAccountCharactersAllowed();
	if ( allowed >= 2 ) then
		CopyAccountDataFromLive(GlueDropDownMenu_GetSelectedValue(CopyCharacterFrame.RegionID));
	elseif ( allowed == 1 ) then
		CopyAccountDataFromLive(GlueDropDownMenu_GetSelectedValue(CopyCharacterFrame.RegionID), CopyCharacterFrame.RealmName:GetText(), CopyCharacterFrame.CharacterName:GetText());
	end
	GlueDialog_Show("COPY_IN_PROGRESS");
end

function CopyCharacterButton_OnLoad(self)
	if (IsGMClient() and HideGMOnly()) then
		return;
	end
	self:SetShown( CopyAccountCharactersAllowed() > 0 );
end

function CopyCharacterButton_OnClick(self)
	CopyCharacterFrame:SetShown( not CopyCharacterFrame:IsShown() );
end

function CopyCharacterSearch_OnClick(self)
	ClearAccountCharacters();
	CopyCharacterFrame_Update(CopyCharacterFrame.scrollFrame);
	RequestAccountCharacters(GlueDropDownMenu_GetSelectedValue(CopyCharacterFrame.RegionID), CopyCharacterFrame.RealmName:GetText(), CopyCharacterFrame.CharacterName:GetText());
	self:Disable();
end

function CopyCharacterCopy_OnClick(self)
	if ( CopyCharacterFrame.SelectedIndex and not GlueDialog:IsShown() ) then
		local name, realm = GetAccountCharacterInfo(CopyCharacterFrame.SelectedIndex);
		GlueDialog_Show("COPY_CHARACTER", format(COPY_CHARACTER_CONFIRM, name, realm));
	end
end

function CopyAccountData_OnClick(self)
	if ( not GlueDialog:IsShown() ) then
		GlueDialog_Show("COPY_ACCOUNT_DATA");
	end
end

function CopyCharacterEntry_OnClick(self)
	if ( CopyCharacterFrame.SelectedButton ) then
		CopyCharacterFrame.SelectedButton:UnlockHighlight();
		if ( not CopyCharacterFrame.SelectedButton.mouseOver ) then
			CopyCharacterEntry_Unhighlight( CopyCharacterFrame.SelectedButton );
		end
	end

	self:LockHighlight();
	CopyCharacterFrame.SelectedButton = self;
	CopyCharacterFrame.SelectedIndex = self:GetID() + FauxScrollFrame_GetOffset(CopyCharacterFrame.scrollFrame);
	CopyCharacterFrame.CopyButton:SetEnabled(true);
end

function CopyCharacterEntry_Highlight(self)
	self.Name:SetFontObject("GameFontHighlight");
	self.Server:SetFontObject("GameFontHighlight");
	self.Class:SetFontObject("GameFontHighlight");
	self.Level:SetFontObject("GameFontHighlight");
end

function CopyCharacterEntry_OnEnter(self)
	CopyCharacterEntry_Highlight(self);
	self.mouseOver = true;
end

function CopyCharacterEntry_Unhighlight(self)
	self.Name:SetFontObject("GameFontNormalSmall");
	self.Server:SetFontObject("GameFontNormalSmall");
	self.Class:SetFontObject("GameFontNormalSmall");
	self.Level:SetFontObject("GameFontNormalSmall");
end

function CopyCharacterEntry_OnLeave(self)
	if ( CopyCharacterFrame.SelectedButton ~= self) then
		CopyCharacterEntry_Unhighlight(self);
	end
	self.mouseOver = false;
end

function CopyCharacterFrame_OnLoad(self)
	FauxScrollFrame_SetOffset(self.scrollFrame, 0);
	self.scrollFrame.ScrollBar.scrollStep = COPY_CHARACTER_BUTTON_HEIGHT;
	ButtonFrameTemplate_HidePortrait(self);
	self:RegisterEvent("ACCOUNT_CHARACTER_LIST_RECIEVED");
	self:RegisterEvent("CHAR_RESTORE_COMPLETE");
	self:RegisterEvent("ACCOUNT_DATA_RESTORED");
	for i=2, MAX_COPY_CHARACTER_BUTTONS do
		local newButton = CreateFrame("BUTTON", nil, CopyCharacterFrame, "CopyCharacterEntryTemplate");
		newButton:SetPoint("TOP", self.CharacterEntries[i-1], "BOTTOM", 0, -4);
		newButton:SetID(i);
		self.CharacterEntries[i] = newButton;
	end
end

function CopyCharacterFrame_OnShow(self)
	if ( self.SelectedButton ) then
		self.SelectedButton:UnlockHighlight();
		CopyCharacterEntry_Unhighlight(self.SelectedButton);
	end
	self.SelectedButton = nil;
	self.SelectedIndex = nil;
	self.CopyButton:SetEnabled(false);

	GlueDropDownMenu_SetWidth(self.RegionID, 80);
	GlueDropDownMenu_SetSelectedValue(self.RegionID, 1);
	GlueDropDownMenu_Initialize(self.RegionID, CopyCharacterFrameRegionIDDropdown_Initialize);
	GlueDropDownMenu_SetAnchor(self.RegionID, 0, 0, "TOPLEFT", self.RegionID, "BOTTOMLEFT");
	GlueDropDownMenu_Refresh(self.RegionID);

	ClearAccountCharacters();
	CopyCharacterFrame_Update(self.scrollFrame);

	if ( CopyAccountCharactersAllowed() >= 2 ) then
		self.RealmName:Hide();
		self.CharacterName:Hide();
		self.SearchButton:Hide();
		RequestAccountCharacters(GlueDropDownMenu_GetSelectedValue(CopyCharacterFrame.RegionID));
	elseif ( CopyAccountCharactersAllowed() == 1) then
		self.RealmName:Show();
		self.RealmName:SetFocus();
		self.CharacterName:Show();
		self.SearchButton:Show();
	end
end

function CopyCharacterFrameRegionIDDropdown_Initialize()
	local info = GlueDropDownMenu_CreateInfo();
	local selectedValue = GlueDropDownMenu_GetSelectedValue(CopyCharacterFrame.RegionID);
	info.func = CopyCharacterFrameRegionIDDropdown_OnClick;

	info.text = NORTH_AMERICA;
	info.value = 1;
	info.checked = (info.value == selectedValue);
	GlueDropDownMenu_AddButton(info);

	info.text = KOREA;
	info.value = 2;
	info.checked = (info.value == selectedValue);
	GlueDropDownMenu_AddButton(info);

	info.text = EUROPE;
	info.value = 3;
	info.checked = (info.value == selectedValue);
	GlueDropDownMenu_AddButton(info);

	info.text = TAIWAN;
	info.value = 4;
	info.checked = (info.value == selectedValue);
	GlueDropDownMenu_AddButton(info);

--	info.text = "China";
--	info.value = 5;
--	info.checked = (info.value == selectedValue);
--	GlueDropDownMenu_AddButton(info);
end

function CopyCharacterFrameRegionIDDropdown_OnClick(button)
	GlueDropDownMenu_SetSelectedValue(CopyCharacterFrame.RegionID, button.value);
	if ( CopyAccountCharactersAllowed() >= 2 ) then
		RequestAccountCharacters(button.value);
	end
end

function CopyCharacterFrame_OnEvent(self, event, ...)
	if ( event == "ACCOUNT_CHARACTER_LIST_RECIEVED" ) then
		CopyCharacterFrame_Update(self.scrollFrame);
		self.SearchButton:Enable();
	elseif ( event == "CHAR_RESTORE_COMPLETE" or event == "ACCOUNT_DATA_RESTORED") then
		local success, token = ...;
		GlueDialog_Hide();
		self:Hide();
		if (not success) then
			GlueDialog_Show("OKAY", COPY_FAILED);
		end
	end
end

function CopyCharacterFrame_Update(self)
	local offset = FauxScrollFrame_GetOffset(self) or 0;
	local count = GetNumAccountCharacters();
	-- turn off the selected button, we'll see if it moved
	if (CopyCharacterFrame.SelectedButton) then
		CopyCharacterFrame.SelectedButton:UnlockHighlight();
		if (not CopyCharacterFrame.SelectedButton.mouseOver) then
			CopyCharacterEntry_Unhighlight(CopyCharacterFrame.SelectedButton);
		end
	end

	for i=1, MAX_COPY_CHARACTER_BUTTONS do
		local characterIndex = offset + i;
		local button = CopyCharacterFrame.CharacterEntries[i];
		if ( characterIndex <= count ) then
			local name, realm, class, level = GetAccountCharacterInfo(characterIndex);
			button.Name:SetText(name);
			button.Server:SetText(realm);
			button.Class:SetText(class);
			button.Level:SetText(level);
			-- The list moved, so we need to shuffle the selected button
			if ( CopyCharacterFrame.SelectedIndex == characterIndex ) then
				button:LockHighlight();
				CopyCharacterEntry_Highlight(button);
				CopyCharacterFrame.SelectedButton = button;
			end
			button:Enable();
			button:Show();
		else
			button:Disable();
			button:Hide();
		end
	end
	FauxScrollFrame_Update(CopyCharacterFrameScrollFrame, count, MAX_COPY_CHARACTER_BUTTONS, COPY_CHARACTER_BUTTON_HEIGHT );
end

function CopyCharacterScrollFrame_OnVerticalScroll(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, COPY_CHARACTER_BUTTON_HEIGHT, CopyCharacterFrame_Update)
end

function CopyCharacterEditBox_OnLoad(self)
	self.parent = self:GetParent();
end

function CopyCharacterEditBox_OnShow(self)
	self:SetText("");
end

function CopyCharacterEditBox_OnEnterPressed(self)
	self:GetParent().SearchButton:Click();
end

function CopyCharacterRealmNameEditBox_OnTabPressed(self)
	self:GetParent().CharacterName:SetFocus();
end

function CopyCharacterCharacterNameEditBox_OnTabPressed(self)
	self:GetParent().RealmName:SetFocus();
end

function CharSelectLockedTrialButton_OnClick(self)
	CharacterSelectButton_OnClick(self.characterSelectButton);
	CharacterSelect_CheckApplyBoostToUnlockTrialCharacter(self.guid);
end

function CharacterSelect_CheckApplyBoostToUnlockTrialCharacter(guid)
	-- Search user upgrades to see if they have the required boost
	local upgrades = C_SharedCharacterServices.GetUpgradeDistributions();
	local hasBoost = false;
	local useFreeBoost = false;

	for id, data in pairs(upgrades) do
		if id == LE_BATTLEPAY_PRODUCT_ITEM_LEVEL_100_CHARACTER_UPGRADE then
			hasBoost = hasBoost or (data.numPaid) > 0 or (data.numFree > 0);
			useFreeBoost = useFreeBoost or (data.numFree > 0);
		end
	end

	if hasBoost then
		local flowData = CharacterUpgrade_Items[LE_BATTLEPAY_PRODUCT_ITEM_LEVEL_100_CHARACTER_UPGRADE];

		if useFreeBoost then
			flowData = flowData.free;
		else
			flowData = flowData.paid;
		end

		CharacterUpgradePopup_BeginUnlockTrialCharacter(flowData, guid);
	else
		if not StoreFrame_IsShown or not StoreFrame_IsShown() then
			ToggleStoreUI();
		end

		StoreFrame_SelectLevel100BoostProduct(guid);
	end
end

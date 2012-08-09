EVENT_TRACE_EVENT_HEIGHT = 16;
EVENT_TRACE_MAX_ENTRIES = 1000;

DEBUGLOCALS_LEVEL = 4;
local _normalFontColor = { 1, .82, 0, 1 };

EVENT_TRACE_SYSTEM_TIMES = {};
EVENT_TRACE_SYSTEM_TIMES["System"] = true;
EVENT_TRACE_SYSTEM_TIMES["Elapsed"] = true;

EVENT_TRACE_EVENT_COLORS = {};
EVENT_TRACE_EVENT_COLORS["System"] = _normalFontColor;
EVENT_TRACE_EVENT_COLORS["Elapsed"] = { .6, .6, .6, 1 };

local _EventTraceFrame;

local _framesSinceLast = 0;
local _timeSinceLast = 0;

local _timer = CreateFrame("FRAME");
_timer:SetScript("OnUpdate", function (self, elapsed) _framesSinceLast = _framesSinceLast + 1; _timeSinceLast = _timeSinceLast + elapsed; end);

function EventTraceFrame_OnLoad (self)
	self.buttons = {};
	self.events = {};
	self.times = {};
	self.rawtimes = {};
	self.eventids = {};
	self.eventtimes = {};
	self.numhandlers = {};
	self.slowesthandlers = {};
	self.slowesthandlertimes = {}
	self.timeSinceLast = {};
	self.framesSinceLast = {};
	self.args = { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} };
	self.ignoredEvents = {};
	self.lastIndex = 0;
	self.visibleButtons = 0;
	_EventTraceFrame = self;
	self:SetScript("OnSizeChanged", EventTraceFrame_OnSizeChanged); 
	EventTraceFrame_OnSizeChanged(self, self:GetWidth(), self:GetHeight());
	self:EnableMouse(true);
	self:EnableMouseWheel(true);
	self:SetScript("OnMouseWheel", EventTraceFrame_OnMouseWheel);
end

local _workTable = {};
function EventTraceFrame_OnEvent (self, event, ...)
	if ( not self.ignoredEvents[event] ) then
		if ( _framesSinceLast ~= 0 and event ~= "On Update") then
			EventTraceFrame_OnEvent(self, "On Update");
		end
		
		local nextIndex = self.lastIndex + 1;
		if ( nextIndex > EVENT_TRACE_MAX_ENTRIES ) then
			local staleIndex = nextIndex - EVENT_TRACE_MAX_ENTRIES;
			self.events[staleIndex] = nil;
			self.times[staleIndex] = nil;
			self.rawtimes[staleIndex] = nil;
			self.timeSinceLast[staleIndex] = nil;
			self.framesSinceLast[staleIndex] = nil;
			self.eventids[staleIndex] = nil;
			self.eventtimes[staleIndex] = nil;
			self.numhandlers[staleIndex] = nil;
			self.slowesthandlers[staleIndex] = nil;
			self.slowesthandlertimes[staleIndex] = nil;
			for k, v in next, self.args do
				self.args[k][staleIndex] = nil;
			end
		end
		
		if ( event == "Begin Capture" or event == "End Capture" ) then
			self.times[nextIndex] = "System";
			if ( self.eventsToCapture ) then
				self.events[nextIndex] = string.format("%s (%s events)", event, tostring(self.eventsToCapture));
			else
				self.events[nextIndex] = event;
			end
			self.timeSinceLast[nextIndex] = 0;
			self.framesSinceLast[nextIndex] = 0;
		elseif ( event == "On Update" ) then
			self.times[nextIndex] = "Elapsed";
			self.events[nextIndex] = string.format("%.3f sec - %d frame(s)", _timeSinceLast, _framesSinceLast);
			self.timeSinceLast[nextIndex] = _timeSinceLast;
			self.framesSinceLast[nextIndex] = _framesSinceLast;
			_timeSinceLast = 0;
			_framesSinceLast = 0;
		else
			self.events[nextIndex] = event;
			local seconds = GetTime();
			local minutes = math.floor(math.floor(seconds) / 60);
			local hours = math.floor(minutes / 60);
			seconds = seconds - 60 * minutes;
			minutes = minutes - 60 * hours;
			hours = hours % 1000;
			self.times[nextIndex] = string.format("%.2d:%.2d:%06.3f", hours, minutes, seconds);
			self.timeSinceLast[nextIndex] = 0;
			self.framesSinceLast[nextIndex] = 0;
			self.eventids[nextIndex] = GetCurrentEventID();

			local numArgs = select("#", ...);
			for i=1, numArgs do
				if ( not self.args[i] ) then
					self.args[i] = {};
				end
				self.args[i][nextIndex] = select(i, ...);
			end
			
			if ( self.eventsToCapture ) then
				self.eventsToCapture = self.eventsToCapture - 1;
			end
		end
		
		-- NOTE: Remember that this work will be captured in the elapsed time for this event, so 
		-- don't do anything slow here or it will throw off the profiled data
		
		self.rawtimes[nextIndex] = GetTime();
		self.lastIndex = nextIndex;		
		if ( self.eventsToCapture and self.eventsToCapture <= 0 ) then
			self.eventsToCapture = nil;
			EventTraceFrame_StopEventCapture();
		end
	end
end

function EventTraceFrame_OnShow(self)
	wipe(self.ignoredEvents);
	local scrollBar = _G["EventTraceFrameScroll"];
	local minValue, maxValue = scrollBar:GetMinMaxValues();
	scrollBar:SetValue(maxValue);
end

function EventTraceFrame_OnUpdate (self, elapsed)
	EventTraceFrame_Update();
end

function EventTraceFrame_OnSizeChanged (self, width, height)
	local numButtonsToDisplay = math.floor((height - 36)/EVENT_TRACE_EVENT_HEIGHT);
	local numButtonsCreated = #self.buttons;
	
	if ( numButtonsCreated < numButtonsToDisplay ) then
		for i = numButtonsCreated + 1, numButtonsToDisplay do
			local button = CreateFrame("BUTTON", "EventTraceFrameButton" .. i, self, "EventTraceEventTemplate");
			button:SetPoint("BOTTOMLEFT", 12, (16 * (i - 1)) + 12);
			button:SetPoint("RIGHT", -28, 0);
			tinsert(self.buttons, button);
		end
		for i = self.visibleButtons + 1, numButtonsToDisplay do
			self.buttons[i]:Show();
		end
		self.visibleButtons = numButtonsToDisplay;
		EventTraceFrame_Update();
	elseif ( self.visibleButtons < numButtonsToDisplay ) then
		for i = self.visibleButtons + 1, numButtonsToDisplay do
			self.buttons[i]:Show();
		end
		self.visibleButtons = numButtonsToDisplay;
		EventTraceFrame_Update();
	elseif ( numButtonsToDisplay < self.visibleButtons ) then
		for i = numButtonsToDisplay + 1, self.visibleButtons do
			self.buttons[i]:Hide();
		end
		self.visibleButtons = numButtonsToDisplay;
	end
end

function EventTraceFrame_Update ()
	local offset = 0;
	
	local scrollBar = _G["EventTraceFrameScroll"];
	local scrollBarValue = scrollBar:GetValue();
	local minValue, maxValue = scrollBar:GetMinMaxValues();
	
	local firstID = max(1, _EventTraceFrame.lastIndex - EVENT_TRACE_MAX_ENTRIES + 1);
	local lastID = _EventTraceFrame.lastIndex or 1;
	
	if ( firstID >= lastID ) then
		scrollBar:SetMinMaxValues(firstID-1, lastID);
	else
		scrollBar:SetMinMaxValues(firstID, lastID);
	end
	if ( scrollBarValue < firstID ) then
		scrollBar:SetValue(firstID);
		scrollBarValue = firstID;
	end
	
	if ( scrollBarValue < 1 ) then
		scrollBarValue = 1;
	elseif ( not _EventTraceFrame.selectedEvent ) then
		if ( scrollBarValue == maxValue ) then
			scrollBar:SetValue(_EventTraceFrame.lastIndex);
		end
	end
	
	for i = 1, _EventTraceFrame.visibleButtons do
		local button = _EventTraceFrame.buttons[i];
		if ( button ) then
			local index = scrollBarValue - (i - 1);
			local event = _EventTraceFrame.events[index];
			if ( event ) then
				local timeString = _EventTraceFrame.times[index]
				button.index = index;
				button.time:SetText(timeString);
				button.event:SetText(event);
				if (_EventTraceFrame.eventids[index] and not _EventTraceFrame.eventtimes[index]) then
					local eventTime, numHandlers, slowestHandler, slowestHandlerTime = GetEventTime(_EventTraceFrame.eventids[index]);
					_EventTraceFrame.eventtimes[index] = eventTime;
					_EventTraceFrame.numhandlers[index] = numHandlers;
					_EventTraceFrame.slowesthandlers[index] = slowestHandler;
					_EventTraceFrame.slowesthandlertimes[index] = slowestHandlerTime;
				end
				local color = EVENT_TRACE_EVENT_COLORS[event] or EVENT_TRACE_EVENT_COLORS[timeString];
				if ( color ) then
					button.time:SetTextColor(unpack(color));
					button.event:SetTextColor(unpack(color));
				else
					local eventTime = _EventTraceFrame.eventtimes[index];
					if (eventTime and eventTime > 50.0) then
						button.time:SetTextColor(1, 0, 0, 1);
						button.event:SetTextColor(1, 0, 0, 1);
					elseif (eventTime and eventTime > 20.0) then
						button.time:SetTextColor(1, .5, 0, 1);
						button.event:SetTextColor(1, .5, 0, 1);
					elseif (eventTime and eventTime > 10.0) then
						button.time:SetTextColor(1, .8, 0, 1);
						button.event:SetTextColor(1, .8, 0, 1);
					elseif (eventTime and eventTime > 5.0) then
						button.time:SetTextColor(1, 1, .6, 1);
						button.event:SetTextColor(1, 1, .6, 1);
					else
						button.time:SetTextColor(1, 1, 1, 1);
						button.event:SetTextColor(1, 1, 1, 1);
					end
				end
				button:Show();
				if ( _EventTraceFrame.selectedEvent ) then
					if ( index == _EventTraceFrame.selectedEvent ) then
						EventTraceFrameEvent_DisplayTooltip(button);
						button:GetHighlightTexture():SetVertexColor(.15, .25, 1, .35);
						button:LockHighlight(true);
						button.wasSelected = true;
					elseif ( button.wasSelected ) then
						button.wasSelected = nil;
						button:GetHighlightTexture():SetVertexColor(.8, .8, 1, .15);
						button:UnlockHighlight();
					end
				else
					if ( button.wasSelected ) then
						button.wasSelected = nil;
						button:GetHighlightTexture():SetVertexColor(.8, .8, 1, .15);
						button:UnlockHighlight();
					end
				end
				if ( button:IsMouseOver() ) then
					EventTraceFrameEvent_OnEnter(button);
				else
					button.HideButton:Hide();
				end
			else
				button.index = index;
				button:Hide();
			end
		end
	end
	
	EventTraceFrame_UpdateKeyboardStatus();	
end

function EventTraceFrame_StartEventCapture ()
	if ( _EventTraceFrame.started ) then -- Nothing to do?
		return;
	end
	
	_EventTraceFrame.started = true;
	_framesSinceLast = 0;
	_timeSinceLast = 0;
	_EventTraceFrame:RegisterAllEvents();
	EventTraceFrame_OnEvent(_EventTraceFrame, "Begin Capture");
end

function EventTraceFrame_StopEventCapture ()
	if ( not _EventTraceFrame.started ) then -- Nothing to do!
		return;
	end
	
	_EventTraceFrame.started = false;
	_framesSinceLast = 0;
	_timeSinceLast = 0;	
	_EventTraceFrame:UnregisterAllEvents();
	EventTraceFrame_OnEvent(_EventTraceFrame, "End Capture");
end

function EventTraceFrame_HandleSlashCmd (msg)
	msg = strlower(msg);
	if ( msg == "start" ) then
		EventTraceFrame_StartEventCapture();
	elseif ( msg == "stop" ) then
		EventTraceFrame_StopEventCapture();
	elseif ( tonumber(msg) and tonumber(msg) > 0 ) then
		if ( not _EventTraceFrame.started ) then
			_EventTraceFrame.eventsToCapture = tonumber(msg);
			EventTraceFrame_StartEventCapture();
		end
	elseif ( msg == "" ) then
		if ( not _EventTraceFrame:IsShown() ) then
			_EventTraceFrame:Show();
			if ( _EventTraceFrame.started == nil ) then
				EventTraceFrame_StartEventCapture(); -- If this is the first time we're showing the window, start capturing events immediately.
			end
		else
			_EventTraceFrame:Hide();
		end
	end
end

function EventTraceFrame_OnMouseWheel (self, delta)
	local scrollBar = _G["EventTraceFrameScroll"];
	local minVal, maxVal = scrollBar:GetMinMaxValues();
	local currentValue = scrollBar:GetValue();
	
	local newValue = currentValue - ( delta * 3 );
	newValue = max(newValue, minVal);
	newValue = min(newValue, maxVal);
	if ( newValue ~= currentValue ) then
		scrollBar:SetValue(newValue);
	end
end

function EventTraceFrame_UpdateKeyboardStatus ()
	if ( _EventTraceFrame.selectedEvent ) then
		local focus = GetMouseFocus();
		if ( focus == _EventTraceFrame or (focus and focus:GetParent() == _EventTraceFrame) ) then
			_EventTraceFrame:EnableKeyboard(true);
			return;
		end
	end
	_EventTraceFrame:EnableKeyboard(false);
end

function EventTraceFrame_OnKeyUp (self, key)
	if ( key == "ESCAPE" ) then
		self.selectedEvent = nil;
		EventTraceTooltip:Hide();
		EventTraceFrame_Update();
	end
end

function EventTraceFrame_RemoveEvent(i)
	if (i >= 1 and i <= EventTraceFrame.lastIndex) then
		tremove(EventTraceFrame.events, i);
		tremove(EventTraceFrame.times, i);
		tremove(EventTraceFrame.rawtimes, i);
		tremove(EventTraceFrame.timeSinceLast, i);
		tremove(EventTraceFrame.framesSinceLast, i);
		tremove(EventTraceFrame.eventtimes, i);
		tremove(EventTraceFrame.eventids, i);
		tremove(EventTraceFrame.numhandlers, i);
		tremove(EventTraceFrame.slowesthandlers, i);
		tremove(EventTraceFrame.slowesthandlertimes, i);
		
		for k, v in next, EventTraceFrame.args do
			-- can't use tremove because some of these are nil
			for j = i, EventTraceFrame.lastIndex do
				EventTraceFrame.args[k][j] = EventTraceFrame.args[k][j+1];
			end
		end
		EventTraceFrame.lastIndex = EventTraceFrame.lastIndex-1;
	end
end

local TIME_LABEL = "Time:";
local DETAILS_LABEL = "Details:";
local SLOWEST_LABEL = "Slowest:";
local ARGUMENT_LABEL_FORMAT = "arg %d:";
local NUM_HANDLERS_FORMAT = "(%d handlers)";
local EVENT_TIME_FORMAT = "%.2fms";

local function EventTrace_FormatArgValue (val)
	if ( type(val) == "string" ) then
		return string.format('"%s"', val);
	elseif ( type(val) == "number" ) then
		return tostring(val);
	elseif ( type(val) == "boolean" ) then
		return string.format('|cffaaaaff%s|r', tostring(val));
	elseif ( type(val) == "table" or type(val) == "bool" ) then
		return string.format('|cffffaaaa%s|r', tostring(val));
	end
end

function EventTraceFrameEvent_DisplayTooltip (eventButton)
	local index = eventButton.index;
	if ( not index ) then
		return;
	end
	
	local tooltip = _G["EventTraceTooltip"];
	tooltip:SetOwner(eventButton, "ANCHOR_NONE");
	tooltip:SetPoint("TOPLEFT", eventButton, "TOPRIGHT", 24, 2);
	local timeString = _EventTraceFrame.times[index]
	if ( EVENT_TRACE_SYSTEM_TIMES[timeString] ) then
		tooltip:AddLine(timeString, 1, 1, 1);
		tooltip:AddDoubleLine(TIME_LABEL, _EventTraceFrame.rawtimes[index], 1, .82, 0, 1, 1, 1);
		tooltip:AddDoubleLine(DETAILS_LABEL, _EventTraceFrame.events[index], 1, .82, 0, 1, 1, 1);
	else	
		tooltip:AddLine(_EventTraceFrame.events[index], 1, 1, 1);
		local eventTime = _EventTraceFrame.eventtimes[index];
		if (eventTime) then
			if (eventTime < 0) then
				eventTime = "?";
			else
				eventTime = format(EVENT_TIME_FORMAT, eventTime);
			end
			tooltip:AddDoubleLine(TIME_LABEL, eventTime .. "  " .. format(NUM_HANDLERS_FORMAT, _EventTraceFrame.numhandlers[index] or 0), 1, .82, 0, 1, 1, 1);
		else
			tooltip:AddDoubleLine(TIME_LABEL, _EventTraceFrame.rawtimes[index], 1, .82, 0, 1, 1, 1);
		end
		if (_EventTraceFrame.slowesthandlers[index]) then
			tooltip:AddDoubleLine(SLOWEST_LABEL, format("%s  (%.2fms)", _EventTraceFrame.slowesthandlers[index], _EventTraceFrame.slowesthandlertimes[index]), 1, .82, 0, 1, 1, 1);
		end
		for k, v in ipairs(EventTraceFrame.args) do
			if ( v[index] ) then
				tooltip:AddDoubleLine(format(ARGUMENT_LABEL_FORMAT, k), EventTrace_FormatArgValue(v[index]), 1, .82, 0, 1, 1, 1);
			end
		end
	end
	tooltip:Show();
end

function EventTraceFrameEvent_OnEnter (self)
	if (not EVENT_TRACE_SYSTEM_TIMES[EventTraceFrame.times[self.index]]) then
		self.HideButton:Show();
	else
		self.HideButton:Hide();
	end
	if ( _EventTraceFrame.selectedEvent ) then
		return;
	else
		EventTraceFrameEvent_DisplayTooltip(self);
	end
end

function EventTraceFrameEvent_OnLeave (self)
	if ( not self.HideButton:IsMouseOver()) then
		self.HideButton:Hide();
	end
	if ( not _EventTraceFrame.selectedEvent ) then
		EventTraceTooltip:Hide();
	end
end

function EventTraceFrameEvent_OnClick (self)
	if ( _EventTraceFrame.selectedEvent == self.index ) then
		_EventTraceFrame.selectedEvent = nil;
	else
		_EventTraceFrame.selectedEvent = self.index;
	end
	EventTraceFrame_Update();
end

function EventTraceFrameEventHideButton_OnClick (button)
	local eventName = button:GetParent().event:GetText();
	EventTraceFrame.ignoredEvents[eventName] = 1;
	EventTraceFrame.selectedEvent = nil;

	-- Remove matching all events of this type
	for i = EventTraceFrame.lastIndex, 1, -1  do
		if (EventTraceFrame.events[i] == eventName) then
			EventTraceFrame_RemoveEvent(i);
		end
	end

	-- Consolidate "Elapsed" lines
	local lastWasElapsed = false;
	for i = EventTraceFrame.lastIndex, 1, -1  do
		if (EventTraceFrame.times[i] == "Elapsed") then
			if (lastWasElapsed) then
				EventTraceFrame.timeSinceLast[i] = EventTraceFrame.timeSinceLast[i] + EventTraceFrame.timeSinceLast[i+1];
				EventTraceFrame.framesSinceLast[i] = EventTraceFrame.framesSinceLast[i] + EventTraceFrame.framesSinceLast[i+1];
				EventTraceFrame.events[i] = string.format(string.format("%.3f sec", EventTraceFrame.timeSinceLast[i]) .. " - %d frame(s)", EventTraceFrame.framesSinceLast[i]);
				EventTraceFrame_RemoveEvent(i+1);
			end
			lastWasElapsed = true;
		else
			lastWasElapsed = false;
		end
	end
	
	EventTraceFrame_Update();
end

local ERROR_FORMAT = [[|cffffd200Message:|cffffffff %s
|cffffd200Time:|cffffffff %s
|cffffd200Count:|cffffffff %s
|cffffd200Stack:|cffffffff %s
|cffffd200Locals:|cffffffff %s]];

local INDEX_ORDER_FORMAT = "%d / %d"

local _ScriptErrorsFrame;

function ScriptErrorsFrame_OnLoad (self)
	self.title:SetText(LUA_ERROR);
	self:RegisterForDrag("LeftButton");
	self.seen = {};
	self.order = {};
	self.count = {};
	self.messages = {};
	self.times = {};
	self.locals = {};
	_ScriptErrorsFrame = self;
end

function ScriptErrorsFrame_OnShow (self)
	ScriptErrorsFrame_Update();
end

function ScriptErrorsFrame_OnError (message, keepHidden)
	local stack = debugstack(DEBUGLOCALS_LEVEL);
	
	local messageStack = message..stack; -- Fix me later
	
	if ( _ScriptErrorsFrame ) then
		local index = _ScriptErrorsFrame.seen[messageStack];
		if ( index ) then
			_ScriptErrorsFrame.count[index] = _ScriptErrorsFrame.count[index] + 1;
			_ScriptErrorsFrame.messages[index] = message;
			_ScriptErrorsFrame.times[index] = date();
			_ScriptErrorsFrame.locals[index] = debuglocals(DEBUGLOCALS_LEVEL);
		else
			tinsert(_ScriptErrorsFrame.order, stack);
			index = #_ScriptErrorsFrame.order;
			_ScriptErrorsFrame.count[index] = 1;
			_ScriptErrorsFrame.messages[index] = message;
			_ScriptErrorsFrame.times[index] = date();
			_ScriptErrorsFrame.seen[messageStack] = index;
			_ScriptErrorsFrame.locals[index] = debuglocals(DEBUGLOCALS_LEVEL);
		end
		
		if ( not _ScriptErrorsFrame:IsShown() and not keepHidden ) then
			_ScriptErrorsFrame.index = index;
			_ScriptErrorsFrame:Show();
		else
			ScriptErrorsFrame_Update();
		end
	end
end

function ScriptErrorsFrame_Update ()
	local editBox = ScriptErrorsFrameScrollFrameText;
	local index = _ScriptErrorsFrame.index;
	if ( not index or not _ScriptErrorsFrame.order[index] ) then
		index = #_ScriptErrorsFrame.order;
		_ScriptErrorsFrame.index = index;
	end
	
	if ( index == 0 ) then
		editBox:SetText("");
		ScriptErrorsFrame_UpdateButtons();
		return;
	end
	
	local text = string.format(
		ERROR_FORMAT, 
		_ScriptErrorsFrame.messages[index], 
		_ScriptErrorsFrame.times[index], 
		_ScriptErrorsFrame.count[index], 
		_ScriptErrorsFrame.order[index],
		_ScriptErrorsFrame.locals[index] or "<none>"
		);

	local parent = editBox:GetParent();
	local prevText = editBox.text;
	editBox.text = text;
	if ( prevText ~= text ) then
		editBox:SetText(text);
		editBox:HighlightText(0);
		editBox:SetCursorPosition(0);
	else
		ScrollingEdit_OnTextChanged(editBox, parent);
	end
	parent:SetVerticalScroll(0);

	ScriptErrorsFrame_UpdateButtons();
end

function ScriptErrorsFrame_UpdateButtons ()
	local index = _ScriptErrorsFrame.index;
	local numErrors = #_ScriptErrorsFrame.order;
	if ( index == 0 ) then
		_ScriptErrorsFrame.next:Disable();
		_ScriptErrorsFrame.previous:Disable();
	else
		if ( numErrors == 1 ) then
			_ScriptErrorsFrame.next:Disable();
			_ScriptErrorsFrame.previous:Disable();
		elseif ( index == 1 ) then
			_ScriptErrorsFrame.next:Enable();
			_ScriptErrorsFrame.previous:Disable();
		elseif ( index == numErrors ) then
			_ScriptErrorsFrame.next:Disable();
			_ScriptErrorsFrame.previous:Enable();
		else
			_ScriptErrorsFrame.next:Enable();
			_ScriptErrorsFrame.previous:Enable();
		end
	end
	
	_ScriptErrorsFrame.indexLabel:SetText(string.format(INDEX_ORDER_FORMAT, index, numErrors));
end

function ScriptErrorsFrame_DeleteError (index)
	if ( _ScriptErrorsFrame.order[index] ) then
		_ScriptErrorsFrame.seen[_ScriptErrorsFrame.messages[index] .. _ScriptErrorsFrame.order[index]] = nil;
		tremove(_ScriptErrorsFrame.order, index);
		tremove(_ScriptErrorsFrame.messages, index);
		tremove(_ScriptErrorsFrame.times, index);
		tremove(_ScriptErrorsFrame.count, index);
	end
end

function ScriptErrorsFrameButton_OnClick (self)
	local id = self:GetID();
	
	
	if ( id == 1 ) then
		_ScriptErrorsFrame.index = _ScriptErrorsFrame.index + 1;
	else
		_ScriptErrorsFrame.index = _ScriptErrorsFrame.index - 1;
	end
		
	ScriptErrorsFrame_Update();
end

--[[  function ScriptErrorsFrameDelete_OnClick (self);
	local index = _ScriptErrorsFrame.index;
	ScriptErrorsFrame_DeleteError(index);
	
	local numErrors = #_ScriptErrorsFrame.order;
	if ( numErrors == 0 ) then
		_ScriptErrorsFrame.index = 0;
	elseif ( index > numErrors ) then
		_ScriptErrorsFrame.index = numErrors;
	end
	
	ScriptErrorsFrame_Update();
end ]]

function DebugTooltip_OnLoad(self)
	self:SetFrameLevel(self:GetFrameLevel() + 2);
	self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
	self.statusBar2 = getglobal(self:GetName().."StatusBar2");
	self.statusBar2Text = getglobal(self:GetName().."StatusBar2Text");
end

function FrameStackTooltip_Toggle (showHidden)
	local tooltip = _G["FrameStackTooltip"];
	if ( tooltip:IsVisible() ) then
		tooltip:Hide();
	else
		tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -CONTAINER_OFFSET_X - 13, CONTAINER_OFFSET_Y);
		tooltip.default = 1;
		tooltip.showHidden = showHidden;
		tooltip:SetFrameStack(showHidden);
	end
end

FRAMESTACK_UPDATE_TIME = .1
local _timeSinceLast = 0
function FrameStackTooltip_OnUpdate (self, elapsed)
	_timeSinceLast = _timeSinceLast - elapsed;
	if ( _timeSinceLast <= 0 ) then
		_timeSinceLast = FRAMESTACK_UPDATE_TIME;
		self:SetFrameStack(self.showHidden);
	end
end

function FrameStackTooltip_OnShow (self)
	local parent = self:GetParent() or UIParent;
	local ps = parent:GetEffectiveScale();
	local px, py = parent:GetCenter();
	px, py = px * ps, py * ps;
	local x, y = GetCursorPosition();
	self:ClearAllPoints();
	if (x > px) then
		if (y > py) then
			self:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20);
		else
			self:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -20);
		end
	else
		if (y > py) then
			self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20);
		else
			self:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -20);
		end
	end
end

FrameStackTooltip_OnEnter = FrameStackTooltip_OnShow;

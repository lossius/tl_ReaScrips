
-- @description Set up two instances of stereo FX to process channels 1-4
-- @version 1.0
-- @author Trond Lossius
-- @website http://www.trondlossius.no
-- @noindex
-- @changelog
--    #header

--[[ @details Utility for FX processing of first order ambisonics using two stereo FXs

If the next FX in the chain has the same name, it is deleted
A new plugin is instantiated as a copy of the currently selected one
This will also copy all current parameter settings

Input and output pins are set so that
- 1st FX instance processes channels 1-2
- 2nd FX instance processes channels 3-4
]]

function msg(s)
    if s then
        reaper.ShowConsoleMsg(s..'\n')
    end
end

-- Reset console
msg("")

-- Get first selected track
track = reaper.GetSelectedTrack(0, 0)

-- Get visible FX on this track
FxVisible = reaper.TrackFX_GetChainVisible(track)
retvalue, FxName = reaper.TrackFX_GetFXName(track, FxVisible, "")
msg("Visible FX: :"..(FxName))

--[[ Get number of FXs on this track
numberOfFXs = reaper.TrackFX_GetCount(track)
reaper.ShowConsoleMsg("Number of FXs = "..(numberOfFXs).."\n")

-- Post names of all the FXs
for i = 0, numberOfFXs - 1 do
	retvalue, FxName = reaper.TrackFX_GetFXName(track, i, "")
	reaper.ShowConsoleMsg("FX "..i..":"..(FxName).."\n")
end
reaper.ShowConsoleMsg("\n")
]]

--If an FX copy for channel 3-4 already exists, it is deleted
retvalue, NextFxName = reaper.TrackFX_GetFXName(track, FxVisible + 1, "")
if FxName == NextFxName then
	reaper.TrackFX_Delete(track, FxVisible + 1)
end

-- Make a new copy
reaper.TrackFX_CopyToTrack(track, FxVisible, track, FxVisible, 0)

-- Explore number of channels as well as numbver of inlets and outlets to FX
numChannels = math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN"))
retval, inputPins, outputPins = reaper.TrackFX_GetIOSize(track, FxVisible)

--[[
reaper.ShowConsoleMsg("Number of channels : "..(numChannels).."\n")
reaper.ShowConsoleMsg("Number of inout pins :"..(inputPins).."\n")
reaper.ShowConsoleMsg("Number of output pins :"..(outputPins).."\n")
]]

-- Set IO pins

-- First set all input pins to off
for i = 0, inputPins - 1 do
	result = reaper.TrackFX_SetPinMappings(track, FxVisible,     0, i, 0, 0)
	result = reaper.TrackFX_SetPinMappings(track, FxVisible,     1, i, 0, 0)
	result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 0, i, 0, 0)
	result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 1, i, 0, 0)
end

-- Route channels 1, 2 to 1st FX and then back to channels 1, 2
result = reaper.TrackFX_SetPinMappings(track, FxVisible,     0, 0, 1, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible,     0, 1, 2, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible,     1, 0, 1, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible,     1, 1, 2, 0)
-- Route channels 3, 4 to 2st FX and then back to channels 3, 4
result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 0, 0, 4, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 0, 1, 8, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 1, 0, 4, 0)
result = reaper.TrackFX_SetPinMappings(track, FxVisible + 1, 1, 1, 8, 0)




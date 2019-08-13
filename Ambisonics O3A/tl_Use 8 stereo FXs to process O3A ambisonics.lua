-- @description Set up eight instances of stereo FX to process channels 1-16
-- @version 1.0
-- @author Trond Lossius
-- @website http://www.trondlossius.no
-- @noindex
-- @changelog
--    #header

--[[ @details Utility for FX processing of third order ambisonics using eight stereo FXs

  1) A new plugin is instantiated as a copy of the currently selected one
  2) This will also copy all current parameter settings
  3) All parameters of second instance are linked to the parameters of the first
  4) Input and output pins are set so that
      - 1st FX instance processes channels 1-2
      - 2nd FX instance processes channels 3-4
      - etc.

  Big kudos to MPL and Ulstraschall for scripts and documentation that helped me patch this together
]]

-----------------------------------------------------------------------------

-- Deals with Lua magical characters in strings
function literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
    if str then
        return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
    end
end

-----------------------------------------------------------------------------

-- Extracts JS plugin name and filepath from one line of reaper-jsfx.ini
function getSymbols(aString)
  local first, second, path, name, temp
  local reverse
  
  -- If line starts with REV, first and second need to be reversed
  temp = string.sub(aString, 1, 3)
  if temp == "REV" then
    reverse = true
    temp = string.gsub(aString, "REV ", "") -- get rid of "REV "
  else
    reverse = false
    temp = string.gsub(aString, "NAME ", "") -- else get rid of "NAME "
  end
  
  -- Is first symbol wrapped in quotaion marks?
  local i, j = string.find(temp, '\"')
  if i == 1 then
    temp = string.sub(temp, 2)
    i, j = string.find(temp, '\"')
    first = string.sub(temp, 1, i-1)
    -- is there only one symbbol?
    if j == string.len(temp) then
      second = first
    else
      second = string.sub(temp, j+2)
    end
  else
    i, j = string.find(temp, ' ')
    if i then
      first = string.sub(temp, 1, i-1)
      second = string.sub(temp, i+1)
    else
      first = temp
      second = temp
    end
  end
  
  if reverse then
    name = first
    path = second
  else
    name = second
    path = first
  end
    
  --If name has quotation marks, we have to remove them, as well as "JS: " at the start
  local i, j = string.find(name, '\"')
  if i == 1 then
    name = string.gsub(name, "\"", "")
    name = string.gsub(name, "JS: ", "")
  end
  
  -- If path has space, it need to be wrapped with quotartion marks again (not very elegant, but works)
  local i, j = string.find(path, ' ')
  if i then
    path = '"'..path..'"'
  end

  return name, path
end

-----------------------------------------------------------------------------

-- FX chunk wrap (start and end) depends on plugin type. 
function getChunkWrapFromPluginType(pluginNameAsString)
    local string2 = string.sub(pluginNameAsString, 1, 2)
    local string3 = string.sub(pluginNameAsString, 1, 3)
    local string4 = string.sub(pluginNameAsString, 1, 4)
    
    local chunkStart, chunkEnd
    
    -- AudioUnit
    if string2 == 'AU' then
      pluginType = 'AU'
      chunkStart = '<AU "'..pluginNameAsString
      chunkEnd   = '.-WAK %d'
      return chunkStart, chunkEnd, 'AU'
    -- VST and VST3
    elseif string3 == 'VST' then
      pluginType = 'VST'
      chunkStart = '<VST "'..pluginNameAsString
      chunkEnd   = '.-WAK %d'
      return chunkStart, chunkEnd, 'VST'
    -- JSFX
    elseif string2 == 'JS' then        
      --[[ JSFX plugin names are defined by name provided by "desc:" command in the .jsfx file, 
      but the reaper .RPP project file instead uses the path to the .jsfx.
      This is resolved by searching reaper-jsfx.ini for how to map name to file path.
      ]]
      local resourcePath = reaper.GetResourcePath().."/reaper-jsfx.ini"
      io.input(resourcePath)
      local jsString = io.read("*all")
      
      -- Make table with one element per line
      local lines = {}
      for s in jsString:gmatch("[^\r\n]+") do
          table.insert(lines, s)
      end
      
      -- Iterate over lines in search of the filepath of our JS effect
      local name, path
      local jsToLookFor = string.sub(pluginNameAsString, 5) -- remove first 4 characters: 'JS: '
      for i=1, #lines do
        name, path = getSymbols(lines[i])
        if (name == jsToLookFor) then
          jsPath = path
          break
        end
      end
      
      chunkStart = '<JS '..jsPath
      chunkEnd   = '.-WAK %d'
      return chunkStart, chunkEnd, 'JS'
    else
      return 0, 0, 'NONE'
    end
end


-----------------------------------------------------------------------------


-- Make a new FX chunk
function ModNewFxChunk(FxChunk, fxGUID, modGUID, track, fx, linkFX, fxType, numParams, link_str)
  --[[ Arguments:
    FxChunk
    string fxGUID - GUID of the FX to copy
    boolean modGUID - define a new GUID for this plugin? Required when making a new FX instance
    number fx - number in FX chain of the FX that is to be copied
    boolean linkFX - link the params of this FX to those of the previous FX in the FX chain?
    string fxType - 'VST', 'AU' or 'JS'
    number numParams - number of parameters of the FX
    string link_str - used when linking params to the params of the previous FX in the FX chain
  ]]
  
  -- get new GUID
  local FxChunk_new = FxChunk
  if modGUID then 
    local FxChunk_new = FxChunk:gsub(literalize(fxGUID), reaper.genGuid('' ))
  end
  
  -- add parameter links
  
  if linkFX then
    local PM_str = ''
    
    -- Set up parameter links for all FX parameters
    for param_id = 0,  numParams-3 do
      if fxType == 'VST' then
        paramBase = 0
      else -- AU or JS
        local retval, minval, maxval, midval = reaper.TrackFX_GetParamEx(track, fx, param_id)
        paramBase = minval
      end
      
      PM_str = PM_str..
    [[<PROGRAMENV ]]..param_id..[[ 0
        PARAMBASE ]]..paramBase..[[
        LFO 0
        LFOWT 1 1
        AUDIOCTL 0
        AUDIOCTLWT 1 1
        PLINK 1 ]]..link_str..' '..param_id..[[ 0
      >]]..'\n'
    end
      
    -- Add bypass link
    param_id = numParams-2
    PM_str = PM_str..
      [[<PROGRAMENV ]]..param_id..[[:bypass 0
        PARAMBASE 0
        LFO 0
        LFOWT 1 1
        AUDIOCTL 0
        AUDIOCTLWT 1 1
        PLINK 1 ]]..link_str..' '..param_id..[[ 0
      >]]..'\n'
      
    -- Add wet link
    param_id = numParams-1
    PM_str = PM_str..
      [[<PROGRAMENV ]]..param_id..[[:wet 0
        PARAMBASE 0
        LFO 0
        LFOWT 1 1
        AUDIOCTL 0
        AUDIOCTLWT 1 1
        PLINK 1 ]]..link_str..' '..param_id..[[ 0
      >]]..'\n'
            
    FxChunk_new = FxChunk_new:gsub('WAK',PM_str..'WAK' )    
  end
    
  return FxChunk_new
end

-----------------------------------------------------------------------------


function tl_AmbiProcess16ChannelsUsing8StereoFXs()

  -- Clear console
  reaper.ShowConsoleMsg("")
  
  --Get selected FX and its track
  local retval, tracknumber, itemnumber, fx = reaper.GetFocusedFX()
  if not ( retval == 1 and fx >= 0 ) then
    return
  end
  
  local track = reaper.CSurf_TrackFromID( tracknumber, false )
  
  -- Check for number of channels, temrinate if there are to few
  local numChannels = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
  if numChannels < 16 then 
    reaper.ShowConsoleMsg("Error: Track has insufficient number of channels.\n")
    return
  end
  
  local fxName
  retval, fxName = reaper.TrackFX_GetFXName( track, fx, "")
  
  -- ChunkStart varies depending on plugin type (VST, VST3, AU, JS)
  local chunkStart, chunkEnd, fxType = getChunkWrapFromPluginType( fxName )
  
  local numParams = reaper.TrackFX_GetNumParams( track, fx )
  
  -- copy/mod chunk
  
  -- Get FX chunk
  local fxGUID          = reaper.TrackFX_GetFXGUID( track, fx )
  local ret, TrackChunk = reaper.GetTrackStateChunk( track, '', false )
  local FXchunk         = TrackChunk:match( literalize( chunkStart )..'.-'..literalize( fxGUID )..chunkEnd )
  if not FXchunk then
    return
  end
  
  local link_strFX = "none"
  local NewFXchunk   = ModNewFxChunk( FXchunk, fxGUID, false,  track, fx, false,  fxType, numParams, link_strFX )
  
  for i = 1, 7 do
    local link_strFX = ( fx+i )..':'..(-i)
    local FXchunkAppend   = ModNewFxChunk( FXchunk, fxGUID, true,   track, fx, true,   fxType, numParams, link_strFX )
    NewFXchunk = NewFXchunk..'\n'..FXchunkAppend
  end
    
  TrackChunk = TrackChunk:gsub( literalize( FXchunk ), NewFXchunk )
  reaper.SetTrackStateChunk( track, TrackChunk , true )
  
  ------------------------------
  -- Set IO pins
  
  -- Get number of IO pins
  local retval, inputPins, outputPins = reaper.TrackFX_GetIOSize(track, fx)
  
  -- Set all input pins to off, required in case FX has more that 2 inputPins
  for i = 0, inputPins - 1 do
    for j = 0, 7 do
  	  reaper.TrackFX_SetPinMappings(track, fx + j, 0, i, 0, 0)
  	  reaper.TrackFX_SetPinMappings(track, fx + j, 1, i, 0, 0)
    end
  end
  
  -- Route two channels to each FX and then back to to the same channels
  local pin = 1
  for i = 0, 7 do
    reaper.TrackFX_SetPinMappings(track, fx + i,     0, 0, pin, 0)
    reaper.TrackFX_SetPinMappings(track, fx + i,     1, 0, pin, 0)
    pin = pin*2
    reaper.TrackFX_SetPinMappings(track, fx + i,     0, 1, pin, 0)
    reaper.TrackFX_SetPinMappings(track, fx + i,     1, 1, pin, 0)
    pin = pin*2
  end
end


-----------------------------------------------------------------------------


-- Finally!
tl_AmbiProcess16ChannelsUsing8StereoFXs()
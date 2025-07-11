local M = {}

local speedLimit = 0
local speedLimitState = false

M.speedLimitChange = function(data)
    speedLimit = data * 0.277778
end


M.enableSpeedLimit = function()
    speedLimitState = true
end

M.disableSpeedLimit = function()
    speedLimitState = false
end

M.updateGFX = function(dt)
    if speedLimitState then
        local currentSpeed = obj:getVelocity():length()
        if currentSpeed > speedLimit then
            electrics.values.throttle = 0
        end
    end
end

local function onExtensionLoaded()
end

M.onExtensionLoaded = onExtensionLoaded

return M
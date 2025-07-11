local M = {}

local delayTime = 0.5
local timeElapsed = 0
local backflipInProgress = false
local strength = 7
local data = {}
local test = false

local function dirAngle(dir_vec1, dir_vec2)
	--return math.acos(dir_vec1:dot(dir_vec2))
	return math.abs(math.atan2(dir_vec1.y, dir_vec1.x) - math.atan2(dir_vec2.y, dir_vec2.x))
	--return math.acos(dir_vec1:dot(dir_vec2) / (dir_vec1:length() * dir_vec2:length()))
end

local function jump()
    obj:applyClusterLinearAngularAccel(
    v.data.refNodes[0].ref,
    vec3(0, 0, strength) * obj:getPhysicsFPS(),
    vec3(0, 0, 0))
end
local function addAngularVelocity(x, y, z, pitchAV, rollAV, yawAV)
	local refNode = v.data.refNodes[0].ref
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = (vec3(0, 0 ,0)):rotated(rot)
	
	local vel = vec3(x, y, z) - cog:cross(vec3(pitchAV, rollAV, yawAV))
	local physicsFPS = obj:getPhysicsFPS()
	local velMulti = 1
			
	obj:applyClusterLinearAngularAccel(
		refNode,
		vel * physicsFPS * velMulti,
		-vec3(pitchAV, rollAV, yawAV) * physicsFPS
	)
end                 

M.backflipEnable = function()
    if not playerInfo.anyPlayerSeated then return end
    data.target_dir = obj:getDirectionVector()
    jump()
    backflipInProgress = true
    timeElapsed = 0
end

M.updateGFX = function(dt)
    if not playerInfo.anyPlayerSeated then return end
    timeElapsed = timeElapsed + dt
    if test and timeElapsed >= delayTime+0.5 then
        local target_dir = obj:getDirectionVector()
	    if dirAngle(target_dir, data.target_dir) < 0.06 then
            local spin = obj:getDirectionVectorRight():normalized() * -4
            addAngularVelocity(0, 0, 0, spin.x, spin.y, spin.z)
            test = false
        end
    end
    if backflipInProgress then
        if timeElapsed >= delayTime then
            local right_dir = obj:getDirectionVectorRight():normalized() * strength
            addAngularVelocity(0, 0, 0, right_dir.x, right_dir.y, right_dir.z)
            backflipInProgress = false
            test = true
        end
    end
end


return M
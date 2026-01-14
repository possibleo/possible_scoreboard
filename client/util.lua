local config = require('shared.config')

---@param action string The action you wish to target
---@param data any The data you wish to send along with this action
function SendAngularMessage(action, data)
	SendNUIMessage({
		action = action,
		data = data
	})
end

local resourceName = GetCurrentResourceName()

---@param ... any Values to print to the console
function debugPrint(...)
	if not config.Debug then return end
	local args <const> = { ... }

	local appendStr = ''
	for _, v in ipairs(args) do
		appendStr = appendStr .. ' ' .. tostring(v)
	end
	print(('^3[%s]^0%s'):format(resourceName, appendStr))
end

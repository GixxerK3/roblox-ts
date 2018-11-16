local TS = require(script.Parent.RuntimeLib)

local RbxJs = {
	undefined = nil,
	null = {}
}
local undefined = RbxJs.undefined
local null = RbxJs.null

local __mt_null = {
	__index = function()
		error("null reference")
	end,
	__newindex = function()
		error("Cannot assign to null value")
	end,
	__metatable = false
}
setmetatable(null, __mt_null)

local __mt_symbol = {}

local __mt_NaN = {
	__eq = function(self, val)
		return false
	end,
	__tostring = function(x)
		return "nan"
	end
}

RbxJs.NaN = function()
	local nan = setmetatable({}, __mt_NaN)
	return nan
end

function RbxJs.isNaN(x)
	return x == __mt_NaN or getmetatable(x) == __mt_NaN
end

RbxJs.Infinity = math.huge

RbxJs.Date = {}
local __mt_date = {
	__index = RbxJs.Date
}

RbxJs.Array = {}
local __mt_array = {
	__index = RbxJs.Array
}

function __mt_array:new(...)
	self = ((self ~= nil and self ~= RbxJs.Array) and self) or setmetatable({}, __mt_array)
	local args = {...}
	local _private = { length = 0 }

	local mt = getmetatable(self)
	-- save a copy of the original __index metamethod
	_private._index = mt.__index
	-- to maintain the inheritance chain, store a copy of the old __index
	mt.__definition = _private._index

	if (#args == 1 and RbxJs.typeof(args[1]) == "number") then
		_private.length = args[1]
	else
		_private.length = #args
		local i = 0
		while (i < #args) do
			rawset(self, i, args[i])
		end
	end
end

function __mt_array__newindex(t, key, value, _private)
end

setmetatable(RbxJs.Array, {
	new = function()

	end
})
function isArray(v)
	return getmetatable(v) == __mt_array
end

local function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

function pop(arr)
	local v = arr[#arr]
	arr[#arr] = nil
	return v
end

function push(arr, ...)
	local input = {...}
	for _, v in ipairs(input) do
		arr[#arr + 1] = v
	end
	return #arr
end

function reverse(arr)
	local i = #arr
	local res = {}
	while i > 0 do
		res[#res + 1] = arr[i]
		i = i - 1
	end
	return res
end

function flattenArray(arr)
	local stack = shallowCopy(arr)
	local res = {}
	while #stack > 0 do
		local n = pop(stack)
		if (isArray(n)) then
			push(stack, unpack(n))
		else
			push(res, n)
		end
	end
	return reverse(res)
end

-- Defined for equivalency with ECMA-262 v5.1 Section 11.4.3
function RbxJs.typeof(x)
	local tx = typeof(x)
	local mtx = getmetatable(x)
	if x == undefined or x == nil then
		return "undefined"
	elseif x == null then
		return "object"
	elseif tx == "boolean" then
		return "boolean"
	elseif tx == "number" then
		return "number"
	elseif RbxJs.isNaN(x) then
		return "number"
	elseif tx == "string" then
		return "string"
	elseif mtx == __mt_symbol then
		return "symbol"
	elseif tx == "function" then
		return "function"
	elseif tx == "table" then
		return "object"
	else
		return tx
	end
end

-- Defined for equivalency with ECMA-262 v5.1 Section 15.3.5.3
function ecma262_hasInstance(f, v)
	local tv = RbxJs.typeof(v)
	if (tv ~= "object") then
		return false
	end
	local o = f
	local _v = v.__index
	repeat
		if (_v == o) then
			return true
		end
	until _v == null
	return false
end

-- Defined for equivalency with ECMA-262 v5.1 Section 11.8.6
function RbxJs.instanceOf(t, instance)
	return ecma262_hasInstance(t, instance)
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.3.1
function ecma262_parseStringNumericLiteral(str)
	-- Implement this according to ecma-262 section 9.3.1 only if it fails tests
	return tonumber(str)
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.11
function ecma262_isCallable(x)
	if (x == nil) then
		return false
	elseif (x == null) then
		return false
	else
		local tx = RbxJs.typeof(x)
		if (tx == "boolean") then
			return false
		elseif (tx == "number") then
			return false
		elseif (tx == "string") then
			return false
		elseif (tx == "function") then
			return true
		else
			local mtx = getmetatable(x)
			if (type(mtx.__call) == "function") then
				return true
			else
				return false
			end
		end
	end
end

-- Defined for equivalency with ECMA-262 v5.1 Section 4.3.2
function ecma262_isPrimitive(x, typeOfX)
	if (x == nil or x == null) then
		return true
	end
	local typeOfX = typeOfX or RbxJs.typeof(x)
	return typeOfX == "boolean" or typeOfX == "number" or typeOfX == "string"
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.9
function ecma262_toObject(x)
	if (x == nil or x == null) then
		error("type error")
	end
	-- All primitive types in Lua are immutable so simply return the value
	return x
end

-- Defined for equivalency with ECMA-262 v5.1 Section 15.2.4.4
function ecma262_valueOf(o)
	return ecma262_toObject(o)
end

-- Defined for equivalency with ECMA-262 v5.1 Section 8.12.8
function ecma262_defaultValue(o, hint, typeOfX)
	hint = hint or (RbxJs.instanceOf(RbxJs.Date, o) and "string") or "number"
	local mto = getmetatable(o)
	if (hint == "string") then
		local _toString = mto.__tostring or tostring
		if (ecma262_isCallable(_toString)) then
			local str = _toString(o)
			if (ecma262_isPrimitive(str, typeOfX)) then
				return str
			end
		end
		local _valueOf = mto.__valueOf or ecma262_valueOf
		if (ecma262_isCallable(_valueOf)) then
			local _val = _valueOf(o)
			if (ecma262_isPrimitive(_val, typeOfX)) then
				return _val
			end
		end
		error("type error")
	end
	if (hint == "number") then
		local _valueOf = mto.__valueOf or ecma262_valueOf
		if (ecma262_isCallable(_valueOf)) then
			local _val = _valueOf(o)
			if (ecma262_isPrimitive(_val, typeOfX)) then
				return _val
			end
		end
		local _toString = mto.__tostring or tostring
		if (ecma262_isCallable(_toString)) then
			local str = _toString(o)
			if (ecma262_isPrimitive(str, typeOfX)) then
				return str
			end
		end
		error("type error")
	end
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.1
function ecma262_toPrimitive(x, preferredType, typeOfX)
	typeOfX = typeOfX or RbxJs.typeof(x)
	if (x == nil) then
		return x
	elseif (x == null) then
		return x
	elseif (typeOfX == "boolean") then
		return x
	elseif (typeOfX == "number") then
		return x
	elseif (typeOfX == "string") then
		return x
	else
		local mt = getmetatable(x)
		local _defaultValue = mt.__defaultValue or ecma262_defaultValue
		return _defaultValue(x, preferredType, typeOfX)
	end
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.2
function ecma262_toBoolean(x, typeOfX)
	if (x == nil or x == RbxJs.null) then
		return false
	end
	typeOfX = typeOfX or RbxJs.typeof(x)
	if (typeOfX == "boolean") then
		return x
	end
	if (typeOfX == "number") then
		return x ~= 0 and x ~= -0 and not RbxJs.isNaN(x)
	end
	if (typeOfX == "string") then
		return x ~= ""
	end
	if (typeOfX == "object") then
		return true
	end
	error("undefined type conversion")
end

-- Defined for equivalency with ECMA-262 v5.1 Section 9.3
function ecma262_toNumber(x)
	if (x == nil) then
		return NaN()
	elseif (x == null) then
		return 0
	end
	local tx = RbxJs.typeof(x)
	if (tx == "number") then
		return x
	elseif(tx == "string") then
		return ecma262_parseStringNumericLiteral(x)
	else
		return ecma262_toNumber(ecma262_toPrimitive(x, "number", tx))
	end
end

-- Defined for equivalency with ECMA-262 v5.1 Section 8.7.1
function ecma262_getValue(v)
	-- Implement this according to ecma-262 section 8.7.1 only if it fails tests
	-- The only cause for implementation would be if js "Reference" type end up being necessary for roblox-ts
	return v
end

-- Defined for equivalency with ECMA-262 v5.1 Section 11.9.3
function ecma262_abstractEquality(x, y)
	local tx = RbxJs.typeof(x) --type(x)
	local ty = RbxJs.typeof(y) --type(y)
	local mtx = getmetatable(tx)
	local mty = getmetatable(ty)

	-- Type(x) == Type(y)
	--if tx == ty and mtx == mty then
	if (tx == ty) then
		if (x == undefined or x == nil) then
			return true
		end
		if (x == null) then
			return true
		end
		if (tx == "number") then
			if (RbxJs.isNaN(x)) then
				return false
			end
			if (RbxJs.isNaN(y)) then
				return false
			end
			if (x == y) then
				return true
			end
			if (x == 0 and y == -0) then
				return true
			end
			if (x == -0 and y == 0) then
				return true
			end

			return false
		end
		if (tx == "string") then
			return x == y
		end
		if (tx == "boolean") then
			return x == y
		end

		return x == y
	end
	if (x == null and y == nil) then
		return true
	end
	if (x == nil and y == null) then
		return true
	end
	if (tx == "number" and ty == "string") then
		return x == ecma262_toNumber(y)
	end
	if (tx == "string" and ty == "number") then
		return ecma262_toNumber(x) == y
	end
	if (tx == "boolean") then
		return ecma262_toNumber(x) == y
	end
	if (ty == "boolean") then
		return x == ecma262_toNumber(y)
	end
	if ((tx == "string" or tx == "number") and ty == "object") then
		return x == ecma262_toPrimitive(y)
	end
	if (tx == "object" and (ty == "string" or ty == "number")) then
		return ecma262_toPrimitive(x) == y
	end
	return false
end

-- Defined for equivalency with ECMA-262 v5.1 Section 11.9.6
function ecma262_strictEquality(x, y)
	local tx = RbxJs.typeof(x) --type(x)
	local ty = RbxJs.typeof(y) --type(y)
	local mtx = getmetatable(tx)
	local mty = getmetatable(ty)

	if (tx ~= ty) then
		return false
	end

	if (tx == nil or tx == null) then
		return true
	end

	if (tx == "number") then
		if (RbxJs.isNaN(x)) then
			return false
		end

		if (RbxJs.isNaN(y)) then
			return false
		end

		if (x == y) then
			return true
		end

		if (x == 0 and y == -0) then
			return true
		end

		if (x == -0 and y == 0) then
			return true
		end

		return false
	end

	if (tx == "string") then
		-- Lua strings of an equivalent sequence of character are incapable of having different
		-- references. May need to create an abstraction around string to resolve issues with
		-- ts/js code that depends on that side effect
		return x == y
	end

	if (tx == "boolean") then
		return (x == true and y == true) or (x == false and y == false)
	end

	return x == y
end

RbxJs.strictEquality = ecma262_strictEquality
RbxJs.abstractEquality = ecma262_abstractEquality
RbxJs.toBoolean = function (x) return ecma262_toBoolean(x) end
RbxJs.toNumber = function (x) return ecma262_toNumber(x) end
RbxJs.toObject = function (x) return ecma262_toObject(x) end

return RbxJs

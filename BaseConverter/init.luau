--!strict
--!native
--!optimize 2

--[[
BaseConverter v1.1.0


WHY:
- Any storage form keeps data as string, taking more space for datatypes like numbers
	"10000000" as Base10 is 8 bytes but the same converted to Base88 is "GC7o" which is only 4 bytes


NOTES:
- Only allows number to string and back


TESTS:
[PASSED] Encode and Decode (to and fro) for the same data


UPDATES:
- 06-09-2026
	Minor changes and rearrangements for use in external editors
]]


-- Removed [space] and [|] from the set so they can be used freely for concat, and other string operations
local CHARACTER_SET = {
	"a","b","c","d","e","f","g","h","i","j",
	"k","l","m","n","o","p","q","r","s","t",
	"u","v","w","x","y","z",

	"A","B","C","D","E","F","G","H","I","J",
	"K","L","M","N","O","P","Q","R","S","T",

	"U","V","W","X","Y","Z",

	"0","1","2","3","4","5","6","7","8","9",

	"!","@","#","$","%","^","&","*","(",")",
	"-","_","=","+","[","]","{","}",";",":",
	",",".","<",">","?","~"
}


-- Base of the encoded string value
local BASE = #CHARACTER_SET


-- Negative sign
local NEGATIVE_SIGN = "|"


-- Reverse map
local CHAR_TO_VALUE = {}


-- Build the reverse map
for index, char in ipairs(CHARACTER_SET) do
	assert(not CHAR_TO_VALUE[char], "Duplicate character: "..char)
	CHAR_TO_VALUE[char] = index - 1
end


-- Encode a number to its string form
local function Encode(n: number): string


	-- Determine whether the number is negative
	local isNegative = n < 0


	-- Convert to positive number
	n = math.abs(n)


	-- No modulus loop is required if the number is zero
	if n == 0 then
		return CHARACTER_SET[1]
	end


	-- Store the characters
	local result = {}


	-- Store the remainder
	local remainder: number


	-- Keep finding the modulus till number reaches less than base
	while n > 0 do
		remainder = n % BASE
		n = math.floor(n / BASE)


		-- Add each character to the table
		table.insert(result, CHARACTER_SET[remainder + 1])
	end


	-- Concat of the table gives the final encoded string
	local encoded = table.concat(result)


	-- Add the negative sign if necessary
	if isNegative then
		return NEGATIVE_SIGN .. encoded
	end


	return encoded
end


-- Decode an encoded string back to its numeric form
local function Decode(s: string): number


	-- Check for negative sign
	local isNegative = s:sub(1, 1) == NEGATIVE_SIGN


	-- Remove the sign if negative
	if isNegative then
		s = s:sub(2)
	end


	-- Final numeric value, start with 0
	local value = 0


	-- Store the current character and its conversion
	local char: string
	local digit: number


	-- For each character, find the number from the reverse map
	for i = #s, 1, -1 do


		-- Convert the character
		char = s:sub(i, i)
		digit = CHAR_TO_VALUE[char]


		-- Assert if the digit exists
		assert(digit ~= nil, "Invalid character: "..char)


		-- Add the value
		value = value * BASE + digit
	end


	-- Return the final sum of all letters converted to number
	if isNegative then
		return -value
	end


	return value
end


-- Return a table with the encode and decode methods
return table.freeze({
	Encode = Encode,
	Decode = Decode
})

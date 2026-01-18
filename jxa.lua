JXA = {}


JXA.jsonify = hs.json.encode

JXA.nullify = '(item) => null'
JXA.identify = '(item) => item'

JXA.map = function (fun) return '.map( ' .. JXA[fun] .. ')' end
-- JXA.map = function (fun) return '.map( ' .. fun .. ')' end
JXA.limit = function (limit, map, thenMap)
	map = map and JXA[map] or JXA.identify
	thenMap = thenMap and JXA[thenMap] or JXA.nullify
	return string.format(
		'.map( (item, index) => (index < %d ) ? (%s)(item) : (%s)(item) )',
		limit, map, thenMap)
end

JXA.selection = 'Application("Photos").selection()'

JXA.displayString =
'(item) => item?Automation.getDisplayString(item):null'
JXA.toDisplayStrings = JXA.map'displayString'

JXA.objectSpecifier = '(spec) => spec?eval(spec):null'
JXA.toObjectSpecifiers = JXA.map'objectSpecifier'

--- calling methods of media items should be wrapped in this function
--- to handle the case where the item has an invalid album reference
JXA.mediaItemMethod = function (action)
	return [[ (item) => {
	if (!item) return null
	try {
		return["]] .. action .. [["]()
	} catch {
		return Application("Photos").mediaItems.byId(
			Automation.getDisplayString(item).match(
				/mediaItems\.byId\("([^"]+)"\)/
			)[1]
		)["]] .. action .. [["]()
	}
}]]
end
JXA.propertyMap = [[(item)=> {
	if (!item) return null
	value=(]] .. JXA.mediaItemMethod'properties' .. [[)(item)
	if (value.date) {
		value.date = Math.floor( value.date.getTime() / 1000)
	}
	return value
}]]
JXA.toPropertyMaps = JXA.map'propertyMap'


return setmetatable(JXA,
	{
		__call = function (self, ...)
			---@type fun(string,string): table
			local split = hs.fnutils.split

			---@type fun(table,function): table
			local imap = hs.fnutils.imap
			-- local jxa = table.concat(
			-- 	imap({ ... },
			-- 		function (a) return self[a] end
			-- 	)
			-- )
			local args = { ... }
			if #args == 1 then
				args = split(args[1], '[| ]')
			end
			local jxa = table.concat(
				imap(args,
					function (a) return self[a] end
				)
			)

			print(jxa)
			local ok, result, err = hs.osascript.javascript(
				jxa
			)
			if ok then return ok, err end
			return result
		end,
		---@type fun(table,string): any
		__index = function (self, key)
			---@type fun(string,string): table
			local split = hs.fnutils.split
			local parts = split(key, '[(,)]')
			local ok, result = pcall(
				function (fun, ...)
					return self[fun](...)
				end,
				table.unpack(parts, 1, #parts - 1)
			)
			return ok and result or key
		end,
	}
)

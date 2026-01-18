JXA = {}

---
---
--- dependencies
---

local json = hs.json.encode
local jxaExec = hs.osascript.javascript
---@type fun(string,string): table
local split = hs.fnutils.split
---@type fun(table,function): table
local imap = hs.fnutils.imap

---
---
--- utility JXA snippets and snippit-generators
---

---
---@param spec string the string representation of an object specifier
---@return string jxa evaluating to the object specifier
JXA.specifier = function (spec)
	return 'eval(' .. json{ spec } .. '[0])'
end


JXA.activate = 'Application("Photos").activate()'
JXA.open = '.spotlight(); Application("Photos").activate()'
JXA.byId = function (id, class)
	return (
		'Application("Photos").'
		.. (class or 'mediaItems')
		.. '.byId("' .. id .. '")'
	)
end
---@param specs string string representations of object specifiers
---@return string jxa evaluating to array of the object specifiers
JXA.specifiers = function (specs)
	return json(specs) .. '.map(eval)(spec))'
end

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



-- this checks if the item is being referenced through an invlid album,
-- as is the case when a media item is being viewed/edited directly from the
-- Library, i.e. not from an album.
--
-- It adds overhead: checking the length of every selection,
-- and fetching the id of selections with a single element.
-- I thing the overhead is worth it so we don't have to
-- worry about working with invalid data.
--
JXA.selection = [[( (selection) => {
	if (selection.length !== 1) return selection
	try {
		_ = selection[0].id()
		return selection
	} catch {
		return [
			Application("Photos").mediaItems.byId(
				Automation.getDisplayString(
					selection[0]
				).match(
					/mediaItems\.byId\("([^"]+)"\)/
				)[1]
			)
		]
	}
})( Application("Photos").selection() )]]

-- jxa function that returns a string version of an object specifier
JXA.string =
'(item) => item?Automation.getDisplayString(item):null'
JXA.strings = JXA.map'string'

JXA.property = [[(item) => {
	value = item?.properties()
	if (!value) return null
	if (value.date) {
		value.date = Math.floor( value.date.getTime() / 1000)
	}
	return value
}]]
JXA.properties = JXA.map'property'


return setmetatable(JXA,
	{
		__call = function (self, ...)
			local args = { ... }
			if #args == 1 then
				args = split(args[1], '[| ]')
			end
			local jxa = table.concat(
				imap(args,
					function (a) return self[a] end
				)
			)
			print('JXA TO EXECUTE=> ' .. jxa and jxa or 'NIL')
			local ok, result, err = jxaExec(
				jxa
			)
			if not ok then return nil, err end
			return result, nil
		end,
		__index = function (self, key)
			local parts = split(key, '[(,)]')
			D(parts)
			local ok, result, err = pcall(
				function (fun, ...)
					return self[fun](...)
				end,
				table.unpack(parts, 1, #parts - 1)
			)
			D(ok, result, err)
			return ok and result or key
		end,
	}
)

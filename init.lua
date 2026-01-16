Photos = {}
---@class Photos
---@field origin string? the origin of the Photos App. Default: `http://localhost:6330`
---this can be different from the host:port settings--it is where photos should
---be expected to be found. For instance, I use `http://photos.local`.

Photos.__index = Photos

Photos.origin = 'http://localhost:6330'


---@class MediaItem
---@field keywords string[] | nil?
---@field name string? -- AKA the title
---@field description string?
---@field favorite boolean?
---@field date number? -- in seconds since unix epoch
---@field id string? -- includes a suffix starting with /
---@field height number? -- in pixels
---@field width number? -- in pixels
---@field filename string -- no directory information
---@field altitude number?
---@field size number? -- in bytes
---@field location [ number, number ]? -- latitude, longitude

---@alias MediaItemKey
---| 'keywords' | 'name' | 'description' | 'favorite' | 'date' | 'id'
---| 'height' | 'width' | 'filename' | 'altitude' | 'size' | 'location'

local Photos = {
	origin = 'http://localhost:6330',
}

---@vararg MediaItemKey? a list of properties to retrieve, nil for all
---@return {}|[MediaItem]? selection empty table if no selection, nil on error
---@return string|table error raw data string or error table returned by osascript
function Photos.selection(...)
	local _, array, err = hs.osascript.javascript(
		[[
const getProp=(item,propName)=>{
	let value
	try {
		value = item[propName]()
	}
	catch {
		value = Application("Photos").mediaItems.byId(
			Automation.getDisplayString(item).match(
				/mediaItems\.byId\("([^"]+)"\)/
			)[1]
		)[propName]()
	}
	if ( value?.date ) {
		value.date=Math.floor(value.date.getTime()/1000)
	} else if ( propName =="date") {
		value=Math.floor(value.getTime()/1000)
	}
	return value
}
const getProps=(propNames)=> Application("Photos").selection().map(
	(item) => propNames.length ? propNames.reduce(
		(values, propName) => {
			values[propName]=getProp(item,propName)
			return values
		}, {}
	) : getProp(item,"properties")
)
getProps(]] .. hs.json.encode{ ... } .. ')'
	)
	return array, err
end

---@type fun(table, function): table
local imap = hs.fnutils.imap

local function notify(message, subtitle)
	hs.notify.show('Apple Photos', subtitle or '', message)
end

local function altText(self)
	return self.name or self.description
	    or self.keywords and self.keywords[1]
	    or self.filename
end
local function toMarkdown(self)
	D(self)
	return string.format(
		'![%s](%s/%s)', altText(self), Photos.origin,
		-- id doesn't require the /... suffix
		self.id:gsub('/.*$', '')
	)
end
---@rerturn integer? number of items copied, nil on error
function Photos:copySelectionAsMarkdown()
	local selection = Photos.selection() -- all properties
	if selection == nil then return nil end -- unexpected error
	if #selection > 0 then
		hs.pasteboard.setContents(table.concat(
			imap(selection, toMarkdown), '\n'
		))
		notify(string.format(
			'Copied %d %s to clipboard.',
			#selection,
			#selection == 1 and 'markdown link' or
			'markdown links'
		))
	else
		notify'Nothing selected to copy.'
	end
	return #selection
end

-- This method will be removed
-- when photosApplication is moved to its own spoon
---@param mapping table
---@return PhotosServer
function Photos:bindHotkeys(mapping)
	local spec = {
		self.copySelectionAsMarkdown,
	}
	hs.spoons.bindHotkeysToSpec(spec, mapping)
	return self
end

return Photos

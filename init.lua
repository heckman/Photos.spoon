Photos = {}
---@class Photos
---@field origin string? the origin of the Photos App. Default: `http://localhost:6330`
---this can be different from the host:port settings--it is where photos should
---be expected to be found. For instance, I use `http://photos.local`.

local Photos = {
	__index = Photos,
	origin = 'http://localhost:6330',
	announce = 'notification',
}

Photos.JXA = dofile(hs.spoons.resourcePath'jxa.lua')

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

---@alias Photos.uuid string
---uuids maatch [0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/L[0-9]{2}/[0-9]{3}
---the last three characters indicate that the object is a media item 001 or an album 040
---@alias Photos.MediaItem.uuid string  Photos.uuid that ends in 001
---@alias Photos.Album.uuid string  Photos.uuid that ends in 040

---this specifies a media item, and optionally also an album it is being viewed within


local announce = {}
function announce.notify(message, subtitle)
	hs.notify.show('Apple Photos', subtitle or '', message)
end

-- an alias because I often con't remember which name I chose to use
announce.notification = announce.notify
function announce.alert(message, subtitle)
	-- print(string.format([[
	hs.osascript.javascript(string.format([[
Application("Photos").includeStandardAdditions = true;
Application("Photos").displayAlert('Apple Photos', {
	message: %s,
	as: "informational",
	buttons: ["OK","Dismiss"],
	defaultButton: "OK",
	cancelButton: "Dismiss", // so escape key closes the alert too!
	givingUpAfter: 5
})]], hs.json.encode{ message }:sub(2, -2)))
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

-- alias this so we can annotate it
---@type fun(table, function): table
local imap = hs.fnutils.imap

Photos.selectionProperties = function ()
	return Photos.JXA'selection|toPropertyMaps'
end

---@rerturn integer? number of items copied, nil on error
function Photos:copySelectionAsMarkdown()
	local selection = Photos.selectionProperties() -- all properties
	if selection == nil then return nil end -- unexpected error
	if #selection > 0 then
		hs.pasteboard.setContents(table.concat(
			imap(selection, toMarkdown), '\n'
		))
		announce[self.announce](string.format(
			'Copied %d %s to clipboard.',
			#selection,
			#selection == 1 and 'markdown link' or
			'markdown links'
		))
	else
		announce[self.announce]'Nothing selected to copy.'
	end
	return #selection
end

-- This method will be removed
-- when photosApplication is moved to its own spoon
---@param mapping table
---@return PhotosServer
function Photos:bindHotkeys(mapping)
	local spec = {
		copyMarkdown = self.copySelectionAsMarkdown,
	}
	hs.spoons.bindHotkeysToSpec(spec, mapping)
	return self
end

return Photos

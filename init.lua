Photos = {}
---@class Photos
---@field origin string? the origin of the Photos App. Default: `http://localhost:6330`
---this can be different from the host:port settings--it is where photos should
---be expected to be found. For instance, I use `http://photos.local`.

local Photos = {
	__index = Photos,
	origin = 'http://localhost:6330',
	announce = 'notification',
	selectionLimit = 100,
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

---@alias MediaItemList
---@field itemId fun(index, crop): string
---@field albumId fun(index,crop): string

---this specifies a media item, and optionally also an album it is being viewed within


local announce = {}
function announce.notify(message, subtitle)
	hs.notify.show('Apple Photos', subtitle or '', message)
end

-- an alias because I often con't remember which name I chose to use
announce.notification = announce.notify


function announce.alert(message, subtitle)
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
	return string.format(
		'![%s](%s/%s/%s/%s)',
		altText(self), self.origin,
		-- id doesn't require the /... suffix
		self.id:gsub('/.*$', ''),
		os.date('%Y-%m-%d', self.date),
		self.filename
	)
end

-- alias this so we can annotate it
---@type fun(table, function): table
local imap = hs.fnutils.imap



function Photos:selectionProperties()
	return Photos.JXA(
		'selection limit(' .. self.selectionLimit .. ',property)'
	)
end

---@param url string
function Photos:openUrl(url)
	if not self.origin then return nil, 'origin not set' end
	local pattern = '^' .. self.origin .. '/([^/]+)'
	local uuid = string.match(url, pattern)
	if not uuid then return nil, 'poorly-formatted URL' end
	return Photos.JXA('byId(' .. uuid .. ') open')
end

---@rerturn integer? number of items copied, nil on error
function Photos:copySelectionAsMarkdown()
	local selection = self:selectionProperties()
	if selection == nil then return nil end
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

function Photos:Init() return self end

function Photos:Start() return self end

function Photos:Stop() return self end

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

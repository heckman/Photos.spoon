local Photos = {
	name = 'Photos',
	version = '0.2.0',
	author = 'Erik Ben Heckman <erik@heckman.ca>',
	description =
	'Copies, and opens, HTTP addresses for media items in Apple Photos.',
	homepage = 'https://github.com/Heckman/Photos.spoon',
	license = 'MIT - https://opensource.org/licenses/MIT',
	--
	-- default config:
	origin = 'http://localhost:6330',
	announce = 'notification', -- notification or alert
	selectionLimit = 100, -- should me much smaller if using short URLs
	imagePrexixes = { 'IMG_', 'IMAG', 'MVI_', 'Dscn', 'Picture_' },
	useShortUrls = false, -- true is slower, but produces prettier URLs
}


---@class Photos
---@field origin string? the origin of the Photos App. Default: `http://localhost:6330`
---this can be different from the host:port settings--it is where photos should
---be expected to be found. For instance, I use `http://photos.local`.
---@field announce 'alert'|'notification' the method to use to announce actions. Default: `notification`
---@field selectionLimit integer the maximum number of items to process from a selection. Default: `100`


---- Photos.JXA = dofile(hs.spoons.resourcePath'jxa.lua')

---@class Photos.MediaItem
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


---An osascript.javascript  wrapper that provides common jxa functions
---
---@return any|nil result always nil when unsuccessful
---the first return value will also be nil on a successful 'null' result
---@return nil|table error-table when unsuccessful
Photos.jxa = dofile(hs.spoons.resourcePath'jxa.lua')



local announcers = {}

function announcers.notify(message, subtitle)
	hs.notify.show('Apple Photos', subtitle or '', message)
end

-- an alias because I often con't remember which name I chose to use
announcers.notification = announcers.notify
function announcers.alert(message, subtitle)
	hs.osascript.javascript([[
Application("Photos").includeStandardAdditions = true;
Application("Photos").displayAlert(
	'Apple Photos', {
		message: ]] .. hs.json.encode{ message }:sub(2, -2) .. [[,
		as: "informational",
		buttons: ["OK","Dismiss"],
		defaultButton: "OK", // so return key closes alert
		cancelButton: "Dismiss", // so escape key closes it too
		givingUpAfter: 5
	}
);]]
	)
end

---@return string non-empty when trimmed string leaves non-whitespace characters
---@return nil empty there is nothing but empty space
local function trimmedNonEmpty(s)
	return (s and s:match'^%s*([^%s].-)%s*$')
end

function Photos:altText(mediaItem)
	return trimmedNonEmpty(mediaItem.name)
	    or trimmedNonEmpty(mediaItem.description)
	    or mediaItem.keywords and mediaItem.keywords[1]
	    or mediaItem.filename:gsub('%..*', '')
end

---@param filename string
---@return string trimmed-filename
function Photos:trimFilename(filename)
	for _, prefix in ipairs(Photos.imagePrexixes) do
		if filename:sub(1, #prefix) == prefix then
			filename = filename:sub(#prefix + 1)
			break
		end
	end
	return (filename:gsub('%.[^.]*$', '')) -- remove extension
end

--- Return the url for a mediaItem
---
--- If we have a location, date, and utility to calculate the local
--- date at that location, we use that to generate one version of the utl.
--- If we don't have that, then we generate a url that doesn't depend on the date.
---
--- The server tries to find the media item from the first url path component.
--- It first tries to get it by uuid, using the first 32 characters of the component.
--- If that fails, it uses the component to do a search, after
--- replacing . ~ and + characters with spaces.
---
--- Ideally, I'd like the url path as "<YYYY-MM-DD>.<FILENAME_FRAGMENT>"
--- where the filename has had it's extension and prefix removed.
--- This should sort chronologically, grouped by day/camera.
---
--- Before using that though, I need to check it returns a unique result.
--- If it doesn't find anything, try the days before and after because of UTC.
---
--- If the query is still ambiguous (or turns up nothing), use the UUID
--- with the date and filename fragment appended.
---
function Photos:url(mediaItem, useShortUrls)
	if useShortUrls == nil then useShortUrls = Photos.useShortUrls end
	local confirmed_search
	local trimmed_filename = self:trimFilename(
		mediaItem.filename
	)
	if useShortUrls then
		local epoch_milliseconds = mediaItem.date * 1000
		confirmed_search = self.jxa([[
filename = "]] .. trimmed_filename .. [[";
date = new Date(]] .. epoch_milliseconds .. [[);
unique = (q) => (search(q).length == 1 ? q : null);
query = (d, w) => `${d.toISOString().slice(0, 10)} ${w}`;
good = unique(query(date, filename));
if (!good) {
date.setDate(date.getDate() - 1);
good = unique(query(date, filename));
if (!good) {
date.setDate(date.getDate() + 2);
good = unique(query(date, filename));
}
}
good.replace(/ /g, '.');
]]
		)
	end
	local url = (self.origin or '.') .. '/' .. (
		confirmed_search and confirmed_search or (
			mediaItem.id:gsub('/.*$', '') -- drop uuid labels
			.. '/' .. os.date('%Y-%m-%d', mediaItem.date) -- no time
			.. '.' .. trimmed_filename)
	)
	return url
end

function Photos:toMarkdown(mediaItem, useShortUrls)
	local alt = self:altText(mediaItem)
	local url = self:url(mediaItem, useShortUrls)
	local markdown = '![' .. alt .. '](' .. url .. ')'
	print(markdown)
	return markdown
end

-- alias this so we can annotate it
---@type fun(table, function): table
local imap = hs.fnutils.imap



function Photos:selectionProperties()
	return self.jxa(
		'selection().limitedMap('
		.. self.selectionLimit
		.. ',properties);'
	)
end

---@param url string
function Photos:openUrl(url)
	if not self.origin then return nil, 'origin not set' end
	local pattern = '^' .. self.origin .. '/([^/]+)'
	local identifier = string.match(url, pattern)
	if not identifier then return nil, 'poorly-formatted URL' end
	identifier = hs.json.encode{
		(identifier:gsub('[~.+]', ' ')),
	}:sub(2, -2)
	local result, err = self.jxa([[
try{
	itemById(]] .. identifier .. [[).spotlight();activate()
} catch {
	search(]] .. identifier .. [[)[0].spotlight();activate()
}]]
	)
	if not result then
		print('cannot open ' .. identifier)
		announcers[self.announce]('Cannot open ' .. identifier)
	end
	return result
end

---@rerturn integer? number of items copied, nil on error
function Photos:copySelectionAsMarkdown(useShortUrls)
	local selection = self:selectionProperties()
	if selection == nil then return nil end
	if #selection > 0 then
		hs.pasteboard.setContents(table.concat(
			imap(selection,
				function (item)
					return self:toMarkdown(
						item, useShortUrls)
				end), '\n'
		))
		announcers[self.announce](string.format(
			'Copied %d %s to clipboard.',
			#selection,
			#selection == 1 and 'markdown link' or
			'markdown links'
		))
	else
		announcers[self.announce]'Nothing selected to copy.'
	end
	return #selection
end

function Photos:Init()
	hs.spoons.resourcePath'regional-time'

	return self
end

function Photos:Stop() return self end

-- This method will be removed
-- when photosApplication is moved to its own spoon
---@param mapping table
---@return PhotosServer

Photos.hotkeys = {}

function Photos:bindHotkeys(mapping)
	local spec = {
		copyMarkdown = function () self:copySelectionAsMarkdown() end,
	}
	-- Create the hotkeys one at a time so we can add them to our list
	for name, mods_key in pairs(mapping) do
		if spec[name] then
			table.insert(
				self.hotkeys,
				hs.hotkey.new(
					mods_key[1], mods_key[2],
					spec[name]
				)
			)
		end
	end
	return self
end

function Photos:start()
	-- Create the window filter for the Photos app
	self.filter = hs.window.filter.new'Photos'
	self.filter:subscribe(
		hs.window.filter.windowFocused,
		function ()
			for _, hk in pairs(self.hotkeys) do hk:enable() end
		end
	)
	self.filter:subscribe(
		hs.window.filter.windowUnfocused,
		function ()
			for _, hk in pairs(self.hotkeys) do hk:disable() end
		end
	)
	return self
end

return Photos

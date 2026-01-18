# Photos.spoon

A Spoon for
[Hammerspoon](https://www.hammerspoon.org/)
that provides an interface to
[Apple Photos](https://apps.apple.com/app/photos/id1584215428).

It was created to accompany the
[PhotosServer](https://github.com/heckman/PhotosServer.spoon) spoon,
which servers the Apple Photos library locally via HTTP. At the moment this spoon is of narrow focus, capturing the items selected in the Photos Application. It's feature set will grow in time, but for now it only provides two functions.

In the following video, I copy a markdown link from Photos,
then I paste it into a markdown document.

![](https://github.com/user-attachments/assets/16ac318c-68bb-4076-a2af-77be5abd7f88)

The link for that image is http://photos.local/31F5FDDB-26D6-4EF6-A9E7-4A636F6E6EE2,
and the PhotosServer spoon makes the image availabe at that URL.

## Installation

### Manual Installation

Download the two `init.lua`
and put it in a directory named `PhotosServer`
within your Spoons directory.

There is also a [command-line utitlity](#bonus) included
in the `cli` directory that will print a json array
with properties of the media items
currently selected in the Photos application.

### Automatic Installation

This has not yet been implemented.
When I figure out how,
I'll have github generate a zip file with the packaged Spoon.

## Configuration

This assumes you are somewhat familiar with Hammerspoon.

The simplest way to use this Spoon is to put this in your `lua.init` file:

```lua
hs.loadspoon('Photos')
```

It doesn't need to be started.

## API

#### Properties

There are two settings:

- **Photos.origin** _string_ :
  is the base url to use for addressing
  media items from the Photos Application when copying links.
  It defaults to **_http://localhost:6330_**,
  which corresponds to the default settings of the PhotosServer Spoon.
  On my personal machine,
  although I use the default settings in the PhotosServer Spoon,
  I set **_Photos.origin_** to **_http://photos.local_**
  and use some system configurations to map that to **_http://localhost:6330_**.
  This lets me use a pretty domain name. I describe how Iaccomplish this in the
  [Advanced setup](https://github.com/heckman/PhotosServer.spoon#advanced-setup)
  section of the README.md in the PhotosServer Spoon.

- **Photos.announce** _"notification"|"alert"|"none"_ :
  determines how Photos announces its results:
  a notification in the top-right of the screen,
  an alert in the middle of the screen, or none at all.
  The default is **_notification_**. Unsetting this variable is equivalent to setting it to "none".

#### Methods

- **PhotosServer:start(** \[ _config-table_ \] **)** starts the HTTP server, If the optional _config-table_ is specified then the configure method will be called with it prior to starting the server.

- **PhotosServer:stop( )** stops the HTTP server.

- **PhotosServer:configure(** _config-table_ **)** if _config-table_ is not nil or empty, each of its keys will set
  and option. Options not included in the table are not affected. The available options are:

  - **name** _string?_ : An optional name. The HTTP server will advertise itself with Bonjour using this name. (This is not the hostname of the server.) By default it is unset.
  - **host** _string_ : The address on which to serve; the default is **_127.0.0.1_**.
  - **port** _integer_ : The port to listen to; the default is **_6330_**. Note that the system will prevent you from setting this to a small number.
  - **origin** _string_ : The origin of the server; the default is **_http://localhost:6330_**.
    This can be different from the host and port settings. It defines where media items can
    be accessed and is used when copying links from the media items selected in the Photos application.
    I have this set to **_http://photos.local_**.}.
    The [Advanced Setup](#advanced-setup) section explains how this works.
    When the feature that allows you to copy markdown links moves to its own Spoon,
    this setting will likely go with it.

#### Methods

Currently these methods can also be called as static functions (without _self_), but that may change for the one that generates markdown.

- **Photos:copySelectionAsMarkdown()**: copies markdown links that will
  resolve to the media items currently selected in the Photos Application.

- **Photos:selection(** _[ properties.. ]_ **)**:
  returns an array of the media items currently selected in the Photos Application.

  Each media item is represented by a table of its properties.
  If any _properties_ are specified, only those properties will be included.
  ( This is more efficient if you want a single property for a large selection.)
  If no properties are specified, all available properties are included.

  The available properties are:

  - **keywords** _[ string ]?_ : A list of keywords associated with a media item. This will be nil rather than an empty array.
  - **name** _string?_ : The name (title) of the media item.
  - **description** _string?_ : A description of the media item.
  - **favorite** _boolean?_ : Whether the media item has been favourited.
  - **date** _integer?_ : The date of the media item in seconds since the Unix epoch.
  - **id** _string_ : The unique ID of the media item.
  - **height** _integer_ : The height of the media item in pixels.
  - **width** _integer_ : The width of the media item in pixels.
  - **filename** _string_ : The name of the file on disk.
  - **altitude** _float?_ : The GPS altitude in meters.
  - **size** _integer_ : The selected media item file size.
  - **location** _[ float?, float? ]_ : The GPS latitude and longitude,
    in an ordered list of 2 numbers or missing values.
    Latitude in range -90.0 to 90.0, longitude in range -180.0 to 180.0. This property will exist even if it is an empty array.

  If any provided property names are invalid, this function will return two values:
  _nil_ and the error table returned from the Photos application.

#### Key bindings

For now, the PhotosServer Spoon offers a single keybinding:

- **copyMarkdown** : Calls the **_copySelectionAsMarkdown()_** method.

## Bonus CLI utility

IThis Spoon includes a command-line utility
n the **_cli_** directory called **_photos-selection_**
that will print a json array of the media items
currently selected in the Photos application.
It's a wrapper for the **_Photos:selection()_** method and works in the same manner.

---

## License

The project is shared under the MIT License.

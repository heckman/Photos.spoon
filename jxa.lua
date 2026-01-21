return function (jxaCode)
	local script = [[
App=Application("Photos");
selection=()=>( (selection) => {
	if (selection.length !== 1) return selection
	try {
		_ = selection[0].id(); // test access to trigger errors
		return selection;
	}
	catch {
		return [
			App.mediaItems.byId(
				Automation.getDisplayString(
					selection[0]
				).match(
					/mediaItems\.byId\("([^"]+)"\)/
				)[1]
			)
		];
	}
})( App.selection() );
activate=()=>App.activate();
search=(q)=>App.search({for:q});
itemById=(id)=>App.mediaItems.byId(id);
nullify=(_)=>null;
identify=(x)=>x;
string=(m)=>m?Automation.getDisplayString(m):null;
properties=(m)=>{
	p = m?.properties();
	if (p?.date) p.date = Math.floor( p.date.getTime() / 1000);
	return p;
};
Array.prototype.limitedMap=function(limit,fun=identify,alt=nullify){
	return this.map(
		(i,n) => (n<limit) ? fun(i) : alt(i)
	);
};
]] .. jxaCode
	-- print(script)
	local ok, res, err = hs.osascript.javascript(script)
	return res or nil, err
end

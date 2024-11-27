Glide.MAP_SURFACE_OVERRIDES = {}

-- Load surface material overrides for this map
hook.Add( "InitPostEntity", "Glide.LoadMapOverrides", function()
    local path = "data_static/glide/surface_overrides/" .. game.GetMap() .. ".json"
    local data = file.Read( path, "GAME" )
    if not data then return end

    Glide.Print( "Found material surface overrides at: %s", path )

    data = Glide.FromJSON( data )

    local overrides = Glide.MAP_SURFACE_OVERRIDES
    local StartsWith = string.StartsWith

    for originalMat, overrideMat in pairs( data ) do
        local k = _G[originalMat]
        local v = _G[overrideMat]

        if type( k ) ~= "string" or not StartsWith( k, "MAT_" ) then
            Glide.Print( "Ignoring invalid original surface ID: %s", k )

        elseif type( v ) ~= "string" or not StartsWith( v, "MAT_" ) then
            Glide.Print( "Ignoring invalid override surface ID: %s", v )

        else
            overrides[k] = v
        end
    end
end )


--[[
=head1 NAME

applets.IckStream.IckStreamApplet - IckStream applet

=head1 DESCRIPTION

IckStream is an applet expose a Squeezebox as a player device in the ickStream network

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local pairs, ipairs, tostring, tonumber, package, type = pairs, ipairs, tostring, tonumber, package, type

local oo               = require("loop.simple")
local os               = require("os")
local io               = require("io")
local string           = require("jive.utils.string")

local System           = require("jive.System")
local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")

local hasNetworking, Networking  = pcall(require, "jive.net.Networking")
local Player           = require("jive.slim.Player")
local Timer            = require("jive.ui.Timer")
local SocketTcp        = require("jive.net.SocketTcp")
local SocketHttp       = require("jive.net.SocketHttp")
local lfs              = require("lfs")
local json             = require("json")
local md5              = require("md5")
local jsonfilters = require("jive.utils.jsonfilters")
local ltn12            = require("ltn12")
local RequestHttp = require("jive.net.RequestHttp")
local jsonfilters = require("jive.utils.jsonfilters")

local appletManager    = appletManager
local jiveMain         = jiveMain
local jnt              = jnt

module(..., Framework.constants)
oo.class(_M, Applet)


----------------------------------------------------------------------------------------
-- Helper Functions
--

function init(self)
	self.playlistTracksByUrl = {}
	self.playlistTracksById = {}
	os.execute("chmod +x ".._getAppletDir().."IckStream/ickSocketDaemon")
	os.execute("killall ickSocketDaemon;nice ".._getAppletDir().."IckStream/ickSocketDaemon &")
	Timer(5000,
		function() 
			self:_initializeSocket() 
		end,
		true
		):start()

	jnt:subscribe(self)
end

function notify_serverDisconnected(self,server, noOfRetries)
	-- TODO: Handle server disconnect notification
end

function notify_serverConnected(self,server)
	-- TODO: Handle server connected notification
end

function notify_networkConnected(self)
	-- TODO: Handle network connected
	log:warn("Network connected")
end

function _initializeSocket(self)
	self.socket = SocketTcp(jnt, "127.0.0.1", 20530, "ickstream")
	self.socket:t_connect();
	self.socket:t_addWrite(function(err)
						log:info("About to initialize ickSocketDaemon")
						if (err) then
							log:warn(err)
							return _handleDisconnect(self, err)
						end
						local ipAddress = self:_getCurrentIpAddress()
						local uuid = System:getUUID()
						if uuid then
							uuid = string.upper(string.sub(uuid,1,8)).."-"..string.upper(string.sub(uuid,9,12)).."-"..string.upper(string.sub(uuid,13,16)).."-"..string.upper(string.sub(uuid,17,20)).."-"..string.upper(string.sub(uuid,21,32))
						else
							uuid = "ED845EB7-274F-4EB1-829D-"..string.upper(string.gsub(System.getMacAddress(),":",""))
						end
						if ipAddress then
							local name = "SqueezePlay player"
							if Player:getLocalPlayer() then
								name = Player:getLocalPlayer():getName()
							end
							log:info("Initializing ickSocketDaemon with: "..uuid..", "..ipAddress..", "..name)
							self.socket.t_sock:send("INIT\n"..uuid.."\n"..ipAddress.."\n"..name.."\0")
							self:_updateIpAddressInCloud()
						else
							log:warn("No IP detected")
						end
						self.socket:t_removeWrite()
					end,
					10)
	self.socket:t_addRead(function()
					   local chunk, err, partial = self.socket.t_sock:receive(100000)
					   local message = chunk or partial
					   if err and err ~= "timeout" then
							-- TODO: Add proper error handling
						   log:error(err)
						   self.socket:t_removeRead()
					   else
						   local i = string.find(message, "\n", 0)  
						   local deviceId = string.sub(message,0,i-1)
						   local j = string.find(message, "\n", i+1)  
						   local messageType = string.sub(message,i+1,j-1)
						   if messageType == "MESSAGE" then
							   local jsonData = json.decode(string.sub(message,j+1))
							   log:info("GOT MESSAGE (from "..deviceId.."): ".. string.sub(message,j+1))
							   if jsonData then
							   		if not jsonData.params then
							   			jsonData.params = {}
							   		end
							   		self:_handleJSONRPCRequest(deviceId, jsonData)
							   end
							elseif messageType == "DEVICE" then
								local k = string.find(message,"\n",j+1);
								local services = string.sub(message,j+1,k)
								local updateType = string.sub(message,k+1,k+3)
								log:info("GOT DEVICE (from "..deviceId.."): updateType="..updateType..", services="..services)
							else 
								log:warn("Unknown message type");
							end
						end
				   end, 
				   0)
end

function _getCurrentIpAddress(self)
	local model = System:getMachine()
	local ifObj = hasNetworking and Networking:activeInterface()
	if ifObj or model=='squeezeplay' then
		local ipAddress
		if not ifObj and model == 'squeezeplay' then
			ipAddress = '172.16.0.91'
		else
			ipAddress = ifObj:getIPAddressAndSubnet()
		end
		return ipAddress
	end
	return nil
end

function _getAppletDir()
	local appletdir = nil
	if lfs.attributes("/usr/share/jive/applets") ~= nil then
		appletdir = "/usr/share/jive/applets/"
	else
		-- find the applet directory
		for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		        dir = dir .. "applets"
		        local mode = lfs.attributes(dir, "mode")
		        if mode == "directory" then
		                appletdir = dir.."/"
		                break
		        end
		end
	end
	if appletdir then
		log:debug("Applet dir is: "..appletdir)
	else
		log:error("Can't locate lua \"applets\" directory")
	end
	return appletdir
end

function free(self)
        -- we cannot be unloaded
        return false
end

function _sendJsonRpcResponse(self, deviceId, version, id, result, err)
	local response = {}
	response.jsonrpc = version
	response.id = id
	if err then
		response["error"] = err
	else
		response.result = result
	end
	if not deviceId then
		deviceId = 'ALL'
	end
	local jsonString = json.encode(response)
	self.socket:t_addWrite(function(err)
					if (err) then
						log:warn(err)
						return _handleDisconnect(self, err)
					end
					log:warn("Writing to "..deviceId..": "..jsonString)
					self.socket.t_sock:send("MESSAGE\n"..deviceId.."\n"..jsonString.."\0")
					self.socket:t_removeWrite()
				end,
				10)

end

function _handleJSONRPCRequest(self, deviceId, json)
	if json.method == 'setPlayerConfiguration' then
		self:_setPlayerConfiguration(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlayerConfiguration' then
		self:_getPlayerConfiguration(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlayerStatus' then
		self:_getPlayerStatus(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)		
	elseif json.method == 'setPlaylistName' then
		self:_setPlaylistName(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlaylist' then
		self:_getPlaylist(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'addTracks' then
		self:_addTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'removeTracks' then
		self:_removeTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'moveTracks' then
		self:_moveTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTracks' then
		self:_setTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'play' then
		self:_play(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getSeekPosition' then
		self:_getSeekPosition(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setSeekPosition' then
		self:_setSeekPosition(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getTrack' then
		self:_getTrack(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTrack' then
		self:_setTrack(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTrackMetadata' then
		self:_setTrackMetadata(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getVolume' then
		self:_getVolume(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setVolume' then
		self:_setVolume(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, json.jsonrpc, json.id, result, err)
		end)
	else
		log:debug("Ignoring request with method="..json.method)
	end
end

function _notImplemented()
	return undef,{
		code = -32001,
		message = 'Not implemented'
	}
end

-- Below this line follows the implementation of all ickStream Player Protocol methods

function _updateIpAddressInCloud(self)
	local accessToken = self:getSettings()["accessToken"]
	if accessToken then
		local ipAddress = self:_getCurrentIpAddress()
		local http = SocketHttp(jnt, "api.ickstream.com", 80)
		local req = RequestHttp(function(chunk, err)
				if err then
					log:warn(err)
				elseif chunk then
					chunk = json.decode(chunk)
					if chunk.error then
						log:warn("Unable to register IP address in cloud: "..chunk.error.code..": "..chunk.error.message)
					else
						log:debug("Successfully updated device access in cloud")
					end
				end
			end,
			'POST', "/ickstream-cloud-core/jsonrpc",
			{
				t_bodySource = _getBodySource(
					{
						jsonrpc = "2.0",
						id = 1,
						method = "setDeviceAddress",
						params = {
							address = ipAddress
						}
					}),
				headers = {
					Authorization = 'OAuth '..accessToken
				}
			})
			http:fetch(req)
	end
end

function _getBodySource(data)
	local sent = false
	return ltn12.source.chain(
		function()
			if sent then
				return nil
			else
				sent = true
				return data
			end
		end, 
		jsonfilters.encode
	)
end

function _setPlayerConfiguration(self,params,sink)
	if params.accessToken then
		self:getSettings()["accessToken"] = params.accessToken
		self:_updateIpAddressInCloud()
	end
	if params.playerName then
		local player = Player:getLocalPlayer()
		if player and player:getSlimServer() and player:getSlimServer():isConnected() then
			player:getSlimServer():userRequest(function(chunk,err)
					if err then
						log:warn(err)
						sink(undef,{
							code = -32001,
							message = 'Unable to change name in server'
						})
					else
						self:_getPlayerConfiguration({},sink)
					end
				end,
				player and player:getId(),
				{'name',params.playerName}
			)
		else
			sink(undef,{
				code = -32001,
				message = 'Player not connected to server, cannot change name'
			})
		end
	else
		self:_getPlayerConfiguration({},sink)
	end
end

function _getPlayerConfiguration(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		result.playerName = player:getName()
		result.playerModel = "Squeezebox"
		if System:getUUID() then
			result.hardwareId = System:getUUID()
		end
		sink(result);
	else 
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _parsePlaylistTrack(self,item, server)
	if item.url and self.playlistTracksByUrl[item.url] then
		return self.playlistTracksByUrl[item.url]
	end

	local track = {}
	if item.url and server and not server:isSqueezeNetwork() and string.sub(item.url,1,4) == 'file' then
		local d = md5.new()
		d:update(item.url)
		local md5url = d:digest()
		track.id = string.upper(server:getId())..":lms:track:"..md5url
		track.streamingRefs = {
			{
				url = "service://"..string.upper(server:getId()).."/plugins/IckStreamPlugin/music/"..md5url.."/download"
			}
		}
	else
		track.streamingRefs = {
			{
				url = item.url
			}
		}
	end
	track.text = item.title
	if item.artwork_url then
		if string.sub(item.artwork_url,1,4) == 'http' then
			track.image = item.artwork_url
		else
			if server and not server:isSqueezeNetwork() then
				track.image = "service://"..string.upper(server:getId()).."/"..item.artwork_url
			end
		end
	elseif item.coverid then
		if server and not server:isSqueezeNetwork() then
			track.image = "service://"..string.upper(server:getId()).."/music/"..item.coverid.."/cover"
		end
	end
	track.type = 'track'
	track.itemAttributes = {}
	if item.tracknum then
		track.trackNumber = item.tracknum
	end	
	if item.disc then
		track.disc = item.disc
	end
	if item.duration then
		track.itemAttributes.duration = item.duration
	end
	if item.album then
		track.itemAttributes.album = {
			name = item.album
		}
	end
	if item.artist then
		track.itemAttributes.mainartists = {
			{
				name = item.artist
			}
		}
	end
	return track
end

function _getPlayerStatus(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		local playerStatus = player:getPlayerStatus()
		if player:getPlayerMode() == 'play' then
			result.playing = true
		else
			result.playing = false
		end
		if player:getVolume()<0 then
			result.muted = true
			result.volumeLevel = -player:getVolume()/100
		else
			result.volumeLevel = player:getVolume()/100
		end
		if playerStatus.item_loop then
				result.playlistPos = player:getPlaylistCurrentIndex()-1
				local elapsed,duration = player:getTrackElapsed()
				result.seekPos = elapsed
				result.track = {
					text = playerStatus.item_loop[1].text
				}
				local server = player:getSlimServer()
				server:userRequest(function(chunk,err)
						if err then
							log:warn(err)
							log:error("Sending error response for getPlaylist")
							sink(undef,{
								code = -32001,
								message = 'Server not available'
							})
						else
							local resultitems = {}
							if chunk.data.playlist_loop[1] then
								result.track = self:_parsePlaylistTrack(chunk.data.playlist_loop[1],server)
							end
							sink(result)
						end
					end,
					player and player:getId(),
					{'status',result.playlistPos,1,'tags:uasdelcK'}
				)
		else
			sink(result)
		end
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _setPlaylistName(self,params,sink)
	sink(_notImplemented())
end

function _getPlaylist(self,params,sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		local offset = params.offset or 0
		local count = params.count or 200
		local server = player:getSlimServer()
		server:userRequest(function(chunk,err)
				if err then
					log:warn(err)
					sink(undef,{
						code = -32001,
						message = 'Server not available'
					})
				else
					local resultitems = {}
					local i = 1;
					if chunk.data.playlist_loop then
						for _,item in ipairs(chunk.data.playlist_loop) do
							resultitems[i] = self:_parsePlaylistTrack(item,server)
							i=i+1
						end
					end
					local result = {
						offset = offset,
						count = #resultitems,
						countAll = player:getPlaylistSize(),
						items = resultitems
					}
					sink(result)
				end
			end,
			player and player:getId(),
			{'status',tostring(offset),tostring(count),'tags:uasdelcK'}
		)
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _addTracks(self,params,sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		local i = 1
		for _,item in ipairs(params.items) do
			self.playlistTracksById[item.id] = item
			if item.streamingRefs[1] then
				self.playlistTracksByUrl[item.streamingRefs[1].url] = item
			end
			i=i+1
		end
	
		for _,item in ipairs(params.items) do
			if item.streamingRefs[1] and item.streamingRefs[1].url then
				local url = item.streamingRefs[1].url
				if url then
					player:getSlimServer():userRequest(function(chunk,err)
							if err then
								log:warn(err)
							end
						end,
						player and player:getId(),
						{'playlist', 'add', url}
					)
				end
			end
		end
		if player:getPlaylistCurrentIndex() then
			sink({
				playlistPos = player:getPlaylistCurrentIndex()-1,
				result = true
			})
		else 
			sink({
				result = true
			})
		end
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _removeTracks(self,params,sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		local removed = 0
		for _,item in ipairs(params.items) do
			if item.playlistPos then
				player:getSlimServer():userRequest(function(chunk,err)
						if err then
							log:warn(err)
						end
					end,
					player and player:getId(),
					{'playlist', 'delete', item.playlistPos-removed}
				)
				local track = self.playlistTracksById[item.id]
				self.playlistTracksById[item.id] = nil
				if track and track.streamingRefs[1] then
					self.playlistTracksByUrl[track.streamingRefs[1].url] = nil
				end
				removed = removed + 1
			end
		end
		if player:getPlaylistCurrentIndex() then
			sink({
				playlistPos = player:getPlaylistCurrentIndex()-1,
				result = true
			})
		else 
			sink({
				result = true
			})
		end
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _moveTracks(self,params,sink)
	sink(_notImplemented())
end

function _setTracks(self,params,sink)
	sink(_notImplemented())
end

function _play(self,params,sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		if params.playing then
			player:getSlimServer():userRequest(function(chunk,err)
					if err then
						log:warn(err)
					else
					end
				end,
				player and player:getId(),
				{'play'}
			)
			return {
				playing = true
			}
		else
			player:getSlimServer():userRequest(function(chunk,err)
					if err then
						log:warn(err)
					else
					end
				end,
				player and player:getId(),
				{'pause'}
			)
			return {
				playing = false
			}
		end
		sink({
			result = playing
		})
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _getSeekPosition(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		local playlistPos = player:getPlaylistCurrentIndex()-1
		if playlistPos then
			local elapsed,duration = player:getTrackElapsed()
			result.playlistPos = playlistPos
			result.seekPos = elapsed
		end
		sink(result)
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _setSeekPosition(self,params,sink)
	sink(_notImplemented())
end

function _getTrack(self,params,sink)
	sink(_notImplemented())
end

function _setTrack(self,params,sink)
	local player = Player:getLocalPlayer()
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		if params.playlistPos<player:getPlaylistSize() then
			player:getSlimServer():userRequest(function(chunk,err)
					if err then
						log:warn(err)
						sink(undef,{
							code = -32001,
							message = 'Unable to modify track position'
						})
					else
						sink({
							playlistPos = params.playlistPos
						})
					end
				end,
				player and player:getId(),
				{'playlist','index',params.playlistPos}
			)
		else
			sink(undef,{
				code = -32602,
				message = 'Invalid playlist position'
			})
		end
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _setTrackMetadata(self,params,sink)
	sink(_notImplemented())
end

function _getVolume(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		if player:getVolume()<0 then
			result.muted = true
			result.volumeLevel = -player:getVolume()/100
		else
			result.volumeLevel = player:getVolume()/100
		end
		sink(result)
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end	
end

function _setVolume(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		if params.volumeLevel then
			local newVolume = params.volumeLevel * 100
			player:volume(newVolume,1,false)
		end
		self:_getVolume({},sink)
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

--[[

=head1 LICENSE

Copyright (C) 2013 ickStream GmbH
All rights reserved.

=cut
--]]





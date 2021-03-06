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
local table            = require("jive.utils.table")

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
local math = require("math")
local url       = require("socket.url")
local http = require("socket.http")
local Window           = require("jive.ui.Window")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local dumper           = require("jive.utils.dumper")


local appletManager    = appletManager
local jiveMain         = jiveMain
local jnt              = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

----------------------------------------------------------------------------------------
-- Helper Functions
--

function init(self)
	self.playlistStorage = System.getUserDir().."/settings/IckStream_playlist.json"
	log:info("Open file "..self.playlistStorage)
	local fh = io.open(self.playlistStorage, "r")
	if fh then
		log:info("Reading from "..self.playlistStorage)
		local content = fh:read("*all")
		self.playlistTracks = json.decode(content)
		fh:close()
		self.playlistIndex = self:getSettings()["playlistIndex"]
	else 
		self.playlistTracks = nil
		self.playlistIndex = nil
	end
	if not self.playlistTracks then
		self.playlistTracks = {}
	end
	if self.playlistIndex and #self.playlistTracks<self.playlistIndex then
		self.playlistIndex = nil
	end
	self.playlistId = self:getSettings()["playlistId"] or nil
	self.playlistName = self:getSettings()["playlistName"] or nil
	self.playerStatusTimestamp = os.time()
	self.playlistTimestamp = os.time()
	self.volumeChangedTimer = nil
	self.localServices = {}
	self.cloudServices = {}
	self.localServiceNames = {}
	self.serviceInformationRequests = {}
	self.serviceInformationRequestId = 1
	if not self:getSettings()["playbackQueueMode"] then
		self:getSettings()["playbackQueueMode"] = "QUEUE"
		self:storeSettings()
	end

	os.execute("chmod +x ".._getAppletDir().."IckStream/ickSocketDaemon")
	self.usingDaemon = nil
	jnt:subscribe(self)
end

function _startDaemon(self)
	if not self.usingDaemon then
		if log:isDebug() then
			os.execute("killall ickSocketDaemon;nice ".._getAppletDir().."IckStream/ickSocketDaemon > /var/log/ickstream.log 2>&1 &")
		else
			os.execute("killall ickSocketDaemon;nice ".._getAppletDir().."IckStream/ickSocketDaemon &")
		end
		Timer(5000,
			function() 
				self:_initializeSocket() 
			end,
			true
			):start()
	end
end


function notify_playerConnected(self,player)
	-- TODO: Handle server connected notification
	if Player:getLocalPlayer() == player and player:getSlimServer() and not player:getSlimServer():isSqueezeNetwork() then
		local server = player:getSlimServer()
		server:userRequest(function(chunk,err)
			if err then
				log:debug("Starting daemon since plugin not running on server("..server.name..")")
				self:_startDaemon();
			else
				if tonumber(chunk.data._enabled) == 1 then
					if self.usingDaemon then
						log:debug("Killing daemon since plugin is running on server("..server.name..")")
						self.usingDaemon = nil
						os.execute("killall ickSocketDaemon");
					end
				else
					log:debug("Starting daemon since plugin not configured for this player on server("..server.name..")")
					self:_startDaemon();
				end
			end
		end,
		player and player:getId(),
		{'ickstream','player','?'})
	elseif player:getSlimServer() and player:getSlimServer():isSqueezeNetwork() then
		log:debug("Starting daemon since connected to mysqueezebox.com")
		self:_startDaemon();
	elseif player:getSlimServer() then
		log:debug("Ignore server("..player:getSlimServer().name..") which is not connected to local player")
	end
end

function notify_networkConnected(self)
	-- TODO: Handle network connected
	log:debug("Network connected")
end

function notify_playerModeChange(self, player, mode)
	if Player:getLocalPlayer():getId() == player:getId() and self.usingDaemon then
		if player:isPowerOn() then
			if mode == 'stop' then
				if self.playlistIndex ~= nil and self.playlistIndex<#self.playlistTracks-1 then
					log:debug("Switching to next track")
					self.playlistIndex = self.playlistIndex + 1
					self:_playCurrentTrack(function(success)
							if success then
								log:debug("Successfully switch to next track")
							else
								log:warn("Failed to switch to next track")
							end
						end)
				elseif self.playlistIndex ~= nil and #self.playlistTracks>0 and (self:getSettings()["playbackQueueMode"] == 'QUEUE_REPEAT' or self:getSettings()["playbackQueueMode"] == 'QUEUE_REPEAT_SHUFFLE') then
					log:debug("Restarting playlist")
					if self:getSettings()["playbackQueueMode"] == 'QUEUE_REPEAT_SHUFFLE' then
						log:debug("Shuffle before restarting")
						_shuffleTable(self.playlistTracks)
						self:_updatePlaybackQueueTimestamp()
						self:_sendPlaybackQueueChangedNotification()
					end
					self.playlistIndex = 0
					self:_playCurrentTrack(function(success)
							if success then
								log:debug("Successfully switch to next track")
							else
								log:debug("Failed to switch to next track")
							end
						end)
				else
					log:debug("Reached end of playlist")
					self:_updatePlayerStatusTimestamp()
					self:_sendPlayerStatusChangedNotification()
				end
			else
				log:debug("Ignoring mode change to: "..mode)
			end
		end
	end
end

function _initializeSocket(self)
	self.previousMessagePart = nil
	self.socket = SocketTcp(jnt, "127.0.0.1", 20530, "ickstream")
	self.socket:t_connect();
	self.socket:t_addRead(function()
					   local chunk, err, partial = self.socket.t_sock:receive(100000)
					   if err and err ~= "timeout" then
							-- TODO: Add proper error handling
						   log:error(err)
						   self.socket:t_removeRead()
						   self.socket:close()
						   	local player = Player:getLocalPlayer()
						   	if player and player:getSlimServer() then
								self: notify_playerConnected(player)
						   	end
					   else
					   	   local completeMessage
					   	   if self.previousMessagePart then
					   	   		completeMessage = self.previousMessagePart .. (chunk or partial)
					   	   else
					   	   		completeMessage = (chunk or partial)
					   	   end
					       local nextMsg = string.find(completeMessage, "\n!END!\n");
					       local message
					       if nextMsg ~= nil then
					           message = string.sub(completeMessage,0,nextMsg)
					           self.previousMessagePart = nil
					       else
					           self.previousMessagePart = string.sub(completeMessage,0)
					       end
					       while message ~= nil and string.len(message)>0 do
							   local i = string.find(message, "\n", 0)  
							   local deviceId = string.sub(message,0,i-1)
							   local j = string.find(message, "\n", i+1)  
							   local messageType = string.sub(message,i+1,j-1)
							   if messageType == "MESSAGE" then
								   local k = string.find(message,"\n",j+1);
								   local services = string.sub(message,j+1,k-1)
								   local jsonData = json.decode(string.sub(message,k+1))
								   log:debug("GOT MESSAGE (from "..deviceId.."("..services..")): ".. string.sub(message,k+1))
								   if jsonData then
								   		if jsonData.method then
									   		if not jsonData.params then
									   			jsonData.params = {}
									   		end
									   		self:_handleJSONRPCRequest(deviceId, services, jsonData)
									   	else
									   		self:_handleJSONRPCResponse(deviceId, services, jsonData)
									   	end
								   end
								elseif messageType == "DEVICE" then
									local k = string.find(message,"\n",j+1);
									local services = string.sub(message,j+1,k-1)
									local updateType = string.sub(message,k+1,k+3)
									log:debug("GOT DEVICE (from "..deviceId.."): updateType="..updateType..", services="..services)
									if (updateType == "UPD" or updateType == "ADD") and (services == "4" or services == "5" or services == "6") then
										Timer(1000,
											function() 
												self:_getServiceInformation(deviceId);
											end,
											true
											):start()
									elseif (updateType == "DEL") then
										for i,existingDeviceId in pairs(self.serviceInformationRequests) do
											if existingDeviceId == deviceId then
												self.serviceInformationRequests[tonumber(i)] = nil
											end
										end
									end
								else 
									log:warn("Unknown message type");
								end
								
								if nextMsg ~= nil then
									local terminator = string.find(completeMessage,"\n!END!\n",nextMsg+7)
									if terminator ~= nil then
										message = string.sub(completeMessage,nextMsg+7,terminator)
										self.previousMessagePart = nil
									else
										message = nil
										self.previousMessagePart = string.sub(completeMessage,nextMsg+7)
									end
									nextMsg=terminator
								else
									message = nil
								end
							end
						end
				   end, 
				   0)
	self.socket:t_addWrite(function(err)
						log:info("About to initialize ickSocketDaemon")
						if (err) then
							log:warn(err)
							return _handleDisconnect(self, err)
						end
						local ipAddress = self:_getCurrentIpAddress()
						local uuid = System:getUUID()
						if uuid then
							uuid = string.upper(string.sub(uuid,1,8)).."-"..string.upper(string.sub(uuid,9,12)).."-"..string.upper(string.sub(uuid,13,16)).."-"..string.upper(string.sub(uuid,17,20)).."-"..string.upper(string.gsub(System.getMacAddress(),":",""))
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
							self.usingDaemon = 1
						else
							log:warn("No IP detected")
						end
						self.socket:t_removeWrite()
					end,
					10)
end

function openMenu(self,transition)
	local window = Window("text_list",self:string("ICKSTREAM"), 'settingstitle')
	local menu = SimpleMenu("menu")
	
	if self:getSettings()["accessToken"] then
		menu:addItem( {
			text = self:string('ICKSTREAM_REGISTERED'), 
			iconStyle = 'item_info',
			weight = 2
		})
	else
		menu:addItem( {
			text = self:string('ICKSTREAM_NOT_REGISTERED'), 
			iconStyle = 'item_info',
			weight = 2
		})
	end
	for i,existingDeviceId in pairs(self.serviceInformationRequests) do
		local name = existingDeviceId
		if self.localServiceNames[existingDeviceId] then
			name = self.localServiceNames[existingDeviceId]
		end
		if self.localServices[existingDeviceId] then
			menu:addItem({
				text = name, 
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:openServer(menuItem.text,existingDeviceId,transition)
					return EVENT_CONSUME
				end
			})
		elseif not self:getSettings()["localServices"] and not self:getSettings()["localServices"][existingDeviceId] then
			name = "Waiting: "..name
			menu:addItem({
				text = name, 
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:openServer(menuItem.text,existingDeviceId,transition)
					return EVENT_CONSUME
				end
			})
		end
	end
	if self:getSettings()["localServices"] then
		for existingDeviceId,url in pairs(self:getSettings()["localServices"]) do
			if not self.localServices[existingDeviceId] then
				local name = "Cached: "..existingDeviceId
				if self.localServiceNames[existingDeviceId] then
					name = "Cached: "..self.localServiceNames[existingDeviceId]
				end
				menu:addItem({
					text = name, 
					sound = "WINDOWSHOW",
					callback = function(event, menuItem)
						self:openServer(menuItem.text,existingDeviceId,transition)
						return EVENT_CONSUME
					end
				})
			end
		end
	end
	for existingDeviceId,url in pairs(self.localServices) do
		local name = existingDeviceId
		if self.localServiceNames[existingDeviceId] then
			name = self.localServiceNames[existingDeviceId]
		end
		menu:addItem({
			text = name, 
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
				self:openServer(menuItem.text,existingDeviceId,transition)
				return EVENT_CONSUME
			end
		})
	end
	window:addWidget(menu)
	self:tieAndShowWindow(window)
end

function openServer(self,name, deviceId,transition)
	local window = Window("text_list",name, 'settingstitle')
	local menu = SimpleMenu("menu")
	if self.localServices[deviceId] ~= nil then
		menu:addItem( {
			text = self:string('ICKSTREAM_SERVER_AVAILABLE'), 
			iconStyle = 'item_info',
			weight = 2
		})
		menu:addItem( {
			text = self.localServices[deviceId], 
			iconStyle = 'item_info',
			weight = 3
		})
	else
		menu:addItem( {
			text = self:string('ICKSTREAM_SERVER_UNAVAILABLE'), 
			iconStyle = 'item_info',
			weight = 2
		})
		if self:getSettings()["localServices"] and self:getSettings()["localServices"][deviceId] then
			menu:addItem( {
				text = self:getSettings()["localServices"][deviceId], 
				iconStyle = 'item_info',
				weight = 3
			})
		end
		window:addTimer(1000,
			function() 
				self:_getServiceInformation(deviceId)
				window:hide(Window.transitionNone)
				window=nil
				self:openServer(name,deviceId,Window.transitionNone)
			end)
	end
	window:addWidget(menu)
	self:tieAndShowWindow(window,transition)
end

function _getServiceInformation(self, deviceId)
	local id = self.serviceInformationRequestId
	local alreadySent = false
	for i,existingDeviceId in pairs(self.serviceInformationRequests) do
		if deviceId == existingDeviceId then
			alreadySent = true
		end
	end
	if not alreadySent then
		self.serviceInformationRequestId = self.serviceInformationRequestId + 1
		self.serviceInformationRequests[id] = deviceId
		self:_sendJsonRpcRequest(deviceId,"4", "2.0",id,"getServiceInformation",nil)
		Timer(15000,
			function() 
				if self.serviceInformationRequests[tonumber(id)] and self.localServices[self.serviceInformationRequests[tonumber(id)]] == nil then
					local deviceId = self.serviceInformationRequests[tonumber(id)]
					self.serviceInformationRequests[tonumber(id)] = nil
					self:_getServiceInformation(deviceId);
				end
			end,
			true
			):start()
	end
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

function _sendJsonRpcResponse(self, deviceId, services, version, id, result, err)
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
	local socket = SocketTcp(jnt, "127.0.0.1", 20530, "ickstream")
	socket:t_connect();
	socket:t_addWrite(function(err)
					if (err) then
						log:warn(err)
						socket:t_removeWrite()
						sock:close()
						return
					end
					log:debug("Writing to "..deviceId.."("..services.."): "..jsonString)
					local message = "MESSAGE\n"..deviceId.."\n"..services.."\n"..jsonString.."\0"
					local sent = 0
					local err
					local lastSent
					sent,err,lastSent = socket.t_sock:send(message)
					while sent==nil and lastSent<string.len(message) do
						log:debug(err..", sending additional chunk starting with byte: "..lastSent)
						local additional_sent
						sent,err,additional_sent = socket.t_sock:send(string.sub(message,lastSent))
						if sent == nil then
							lastSent = lastSent + additional_sent
						end
					end
					socket:t_removeWrite()
					socket:close()
				end,
				10)

end

function _sendJsonRpcRequest(self, deviceId, services, version, id, method, params)
	local request = {}
	request.jsonrpc = version
	if id then
		request.id = id
	end
	request.method = method
	if params ~= nil then
		request.params = params
	end
	if not deviceId then
		deviceId = 'ALL'
	end
	local jsonString = json.encode(request)
	local socket = SocketTcp(jnt, "127.0.0.1", 20530, "ickstream")
	socket:t_connect();
	socket:t_addWrite(function(err)
					if (err) then
						log:warn(err)
						socket:t_removeWrite()
						sock:close()
						return
					end
					log:debug("Writing to "..deviceId.."("..services.."): "..jsonString)
					socket.t_sock:send("MESSAGE\n"..deviceId.."\n"..services.."\n"..jsonString.."\0")
					socket:t_removeWrite()
					socket:close()
				end,
				10)

end

function _handleJSONRPCResponse(self, deviceId, services, json)
	if not json.error then
		if json.id and self.serviceInformationRequests[tonumber(json.id)] then
			log:info("Storing serviceUrl of "..self.serviceInformationRequests[tonumber(json.id)].."="..json.result.serviceUrl)
			self.localServices[self.serviceInformationRequests[tonumber(json.id)]] = json.result.serviceUrl
			if not self:getSettings()["localServices"] then
				self:getSettings()["localServices"] = {}
			end
			self:getSettings()["localServices"][self.serviceInformationRequests[tonumber(json.id)]] = json.result.serviceUrl
			self.localServiceNames[self.serviceInformationRequests[tonumber(json.id)]] = json.result.name
			self.serviceInformationRequests[tonumber(json.id)] = nil
			self:storeSettings()
		end
	else
		if json.error.data then
			log:warn("JSON-RPC Response with error: "..json.error.code..": "..json.error.message.."\n"..json.error.data)
		else
			log:warn("JSON-RPC Response with error: "..json.error.code..": "..json.error.message)
		end
	end
end

function _handleJSONRPCRequest(self, deviceId, services, json)
	if json.method == 'setPlayerConfiguration' then
		self:_setPlayerConfiguration(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlayerConfiguration' then
		self:_getPlayerConfiguration(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getProtocolVersions' then
		self:_getProtocolVersions(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlayerStatus' then
		self:_getPlayerStatus(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)		
	elseif json.method == 'setPlaylistName' then
		self:_setPlaylistName(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setPlaybackQueueMode' then
		self:_setPlaybackQueueMode(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'shuffleTracks' then
		self:_shuffleTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getPlaybackQueue' then
		self:_getPlaybackQueue(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'addTracks' then
		self:_addTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'removeTracks' then
		self:_removeTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'moveTracks' then
		self:_moveTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTracks' then
		self:_setTracks(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, serivces, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'play' then
		self:_play(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, serivces, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getSeekPosition' then
		self:_getSeekPosition(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setSeekPosition' then
		self:_setSeekPosition(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getTrack' then
		self:_getTrack(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTrack' then
		self:_setTrack(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setTrackMetadata' then
		self:_setTrackMetadata(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'getVolume' then
		self:_getVolume(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
		end)
	elseif json.method == 'setVolume' then
		self:_setVolume(json.params,function(result,err)
			self:_sendJsonRpcResponse(deviceId, services, json.jsonrpc, json.id, result, err)
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

function _updatePlaybackQueueTimestamp(self)
	local timestamp = os.time()
	if self.playlistTimestamp == timestamp then
		timestamp = timestamp + 1
	end
	self.playlistTimestamp = timestamp
	log:info("Open file "..self.playlistStorage)
	local fh = io.open(self.playlistStorage, "w")
	if fh then
		log:info("Writing to "..self.playlistStorage)
		fh:write(json.encode(self.playlistTracks))
		fh:close()
	end
end

function _updatePlayerStatusTimestamp(self)
	local timestamp = os.time()
	if self.playerStatusTimestamp == timestamp then
		timestamp = timestamp + 1
	end
	self.playerStatusTimestamp = timestamp
	self:getSettings()["playlistIndex"] = self.playlistIndex
	self:storeSettings()
end

function _playCurrentTrack(self, sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
			local currentTrack = self.playlistTracks[self.playlistIndex + 1];
			local streamingUrl = nil
			local intermediate = false
			if currentTrack and currentTrack.streamingRefs and currentTrack.streamingRefs[1] then
				if currentTrack.streamingRefs[1].intermediate then
					intermediate = currentTrack.streamingRefs[1].intermediate
				end
				if string.sub(currentTrack.streamingRefs[1].url,1,10) == "service://" then
					local startPos,endPos,text = string.find(currentTrack.streamingRefs[1].url,'service://([^/]*)')
					if text and self.localServices[text] then
						log:debug("Replacing: "..currentTrack.streamingRefs[1].url.."\nWith: "..self.localServices[text])
						streamingUrl = string.gsub(currentTrack.streamingRefs[1].url,"service://[^/]*",self.localServices[text])
						log:debug("Resulting in: "..streamingUrl)
					elseif text and self:getSettings()["localServices"] and self:getSettings()["localServices"][text] then
						log:debug("Replacing: "..currentTrack.streamingRefs[1].url.."\nWith cached: "..self:getSettings()["localServices"][text])
						streamingUrl = string.gsub(currentTrack.streamingRefs[1].url,"service://[^/]*",self:getSettings()["localServices"][text])
						log:debug("Resulting in: "..streamingUrl)
					else
						log:warn("Can't resolve "..text)
					end
				else
					streamingUrl = currentTrack.streamingRefs[1].url
				end
			elseif currentTrack and not currentTrack.streamingRefs then
				log:debug("No streaming references, we need to retrieve it from content service based on track: "..currentTrack.id)
				local startPos,endPos,serviceId = string.find(currentTrack.id,'([^:]*):.*')
				if serviceId and self.localServices[serviceId] then
					-- TODO: Implement support for getItemStreamingRef for local services
				elseif serviceId and self.cloudServices[serviceId] then
					log:debug("Using previously retrieved content service: "..serviceId..": "..self.cloudServices[serviceId])
					self:_getStreamingRefAndPlay(self.cloudServices[serviceId],currentTrack,sink)
				elseif serviceId then
					self:_refreshCloudContentServices(function (success) 
						if self.cloudServices[serviceId] then
							log:debug("Using retrieved content service: "..serviceId..": "..self.cloudServices[serviceId])
							self:_getStreamingRefAndPlay(self.cloudServices[serviceId],currentTrack,sink)
						else
							sink(false)
							return
						end
					end)
				else
					sink(false)
					return
				end
			end
			if streamingUrl then
				if intermediate then
					if self:getSettings()["accessToken"] then
						local body, code, headers, status = http.request {
							url = streamingUrl,
	  						headers = { Authorization = "Bearer " .. self:getSettings()["accessToken"] },
	  						redirect = false
						}
						if (code == 301 or code == 302) and headers["location"] then
							self:_playUrl(headers["location"],currentTrack,sink)
						else 
							log:warn("Unable to get redirected url for: "..streamingUrl..", Error: "..code)
							sink(false)
						end
					else
						log:warn("No access token found, player must be registered for this stream")
					end
				else 
					self:_playUrl(streamingUrl,currentTrack,sink)
				end
			else
				sink(false)
			end
	else
		sink(false)
	end	
end

function _getStreamingRefAndPlay(self, serviceUrl, item, sink)
	local accessToken = self:getSettings()["accessToken"]
	if accessToken then
		local parsedUrl = url.parse(serviceUrl)
		if parsedUrl.port == nil then
			parsedUrl.port = 80
		end

		log:debug("Retrieve streaming reference from "..parsedUrl.host..":"..parsedUrl.port..parsedUrl.path)
		local http = SocketHttp(jnt, parsedUrl.host, parsedUrl.port)
		local req = RequestHttp(function(chunk, err)
				if err then
					log:warn(err)
				elseif chunk then
					chunk = json.decode(chunk)
					if chunk.error then
						log:warn("Unable to retrieve streaming reference: "..chunk.error.code..": "..chunk.error.message)
						sink(false)
					elseif not chunk.result then
						log:warn("Unable to retrieve streaming reference")
						sink(false)
					else
						self:_playUrl(chunk.result.url,item,sink)
					end
				end
			end,
			'POST', parsedUrl.path,
			{
				t_bodySource = _getBodySource(
					{
						jsonrpc = "2.0",
						id = 1,
						method = "getItemStreamingRef",
						params = {
							itemId = item.id
						}
					}),
				headers = {
					Authorization = 'Bearer '..accessToken
				}
			})
			http:fetch(req)
	else
		log:warn("No access token, can not retrieve streaming reference")
		sink(false)
	end
end

function _playUrl(self, streamingUrl,item, sink)
	log:debug("Playing "..streamingUrl)
	local player = Player:getLocalPlayer()
	local ip, port = player:getSlimServer():getIpPort();
	if string.find(streamingUrl,ip) then
			local body, code, headers, status = http.request {
				url = streamingUrl,
				redirect = false
			}
			if (code == 301 or code == 302) and headers["location"] and string.match(headers["location"], '/%d+/') then
				local track_id = string.match(headers["location"], '/%d+/');
				track_id = string.match(track_id,"%d+");
				
				player:getSlimServer():userRequest(function(chunk,err)
						if err then
							sink(false)
						else
							self:_updatePlayerStatusTimestamp()
							self:_sendPlayerStatusChangedNotification()
							sink(true)
						end
					end,
					player and player:getId(),
					{'playlistcontrol','cmd:load','track_id:'..track_id}
				)
				return;
			end
	end
	player:getSlimServer():userRequest(function(chunk,err)
			if err then
				sink(false)
			else
				self:_updatePlayerStatusTimestamp()
				self:_sendPlayerStatusChangedNotification()
				sink(true)
			end
		end,
		player and player:getId(),
		{'playlist','play',streamingUrl,item.text}
	)
end

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
						log:info("Successfully updated device access in cloud")
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
					Authorization = 'Bearer '..accessToken
				}
			})
			http:fetch(req)
	end
end

function _refreshCloudContentServices(self, sink)
	local accessToken = self:getSettings()["accessToken"]
	if accessToken then
		local cloudCoreUrl = self:getSettings()["cloudCoreUrl"]
		if cloudCoreUrl == nil then
			cloudCoreUrl = 'http://api.ickstream.com/ickstream-cloud-core/jsonrpc'
		end

		local parsedUrl = url.parse(cloudCoreUrl)
		if parsedUrl.port == nil then
			parsedUrl.port = 80
		end

		log:debug("Retrieve available content services from "..parsedUrl.host..":"..parsedUrl.port..parsedUrl.path)
		local http = SocketHttp(jnt, parsedUrl.host, parsedUrl.port)
		local req = RequestHttp(function(chunk, err)
				if err then
					log:warn(err)
				elseif chunk then
					chunk = json.decode(chunk)
					if chunk.error then
						log:warn("Unable to retrieve content services from cloud: "..chunk.error.code..": "..chunk.error.message)
					else
						for _,item in ipairs(chunk.result.items) do
							log:debug("Got "..item.id..": "..item.url)
							self.cloudServices[item.id] = item.url
						end
						sink(true)
					end
				end
			end,
			'POST', parsedUrl.path,
			{
				t_bodySource = _getBodySource(
					{
						jsonrpc = "2.0",
						id = 1,
						method = "findServices",
						params = {
							type = 'content'
						}
					}),
				headers = {
					Authorization = 'Bearer '..accessToken
				}
			})
			http:fetch(req)
	else
		log:warn("No access token, can not retrieve available content services")
		sink(false)
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

function _sendPlayerStatusChangedNotification(self)
	self:_getPlayerStatus(undef,function(result,err) 
		if not err then
			self:_sendJsonRpcRequest(nil, "15", "2.0", nil, 'playerStatusChanged', result)
		end
	end)
end

function _sendPlaybackQueueChangedNotification(self)
	local params = {}
	if self.playlistId ~= nil then
		params.playlistId = self.playlistId
	end
	if self.playlistName ~= nil then
		params.playlistName = self.playlistName
	end
	params.countAll = #self.playlistTracks
	params.lastChanged = self.playlistTimestamp
	self:_sendJsonRpcRequest(nil, "15", "2.0", nil, 'playbackQueueChanged', params)
end

function _setPlayerConfiguration(self,params,sink)
	if params.cloudCoreUrl ~= nil and ((self:getSettings()["cloudCoreUrl"] == nil and params.cloudCoreUrl ~= 'http://api.ickstream.com/ickstream-cloud-core/jsonrpc') or params.cloudCoreUrl ~= self:getSettings()["cloudCoreUrl"]) then
		local parsedUrl = url.parse(params.cloudCoreUrl)
		if parsedUrl ~= nil then
			self:getSettings()["cloudCoreUrl"] = params.cloudCoreUrl
			self:getSettings()["accessToken"] = nil
			self:storeSettings()
		else
			sink(undef,{
				code = -32602,
				message = 'Invalid parameter cloudCoreUrl='..params.cloudCoreUrl
			})
			return
		end
	end
	local sendNotification = false
	if params.deviceRegistrationToken ~= nil and string.len(params.deviceRegistrationToken)>0 then
		self:getSettings()["accessToken"] = nil
		self:storeSettings()
		self:_registerDeviceUsingDeviceRegistrationToken(params);
	elseif params.deviceRegistrationToken ~= nil then
		self:getSettings()["accessToken"] = nil
		self:storeSettings()
		sendNotification = true
	elseif params.accessToken ~= nil and string.len(params.accessToken)>0 then
		self:getSettings()["accessToken"] = params.accessToken
		self:storeSettings()
		self:_updateIpAddressInCloud()
		sendNotification = true
	elseif params.accessToken ~= nil then
		self:getSettings()["accessToken"] = nil
		self:storeSettings()
		sendNotification = true
	end
	self:_setPlayerConfigurationName(params,sink)
	if sendNotification then
		self:_sendPlayerStatusChangedNotification()
	end
end

function _registerDeviceUsingDeviceRegistrationToken(self,params)
	local cloudCoreUrl = self:getSettings()["cloudCoreUrl"]
	if cloudCoreUrl == nil then
		cloudCoreUrl = 'http://api.ickstream.com/ickstream-cloud-core/jsonrpc'
	end

	local parsedUrl = url.parse(cloudCoreUrl)
	if parsedUrl.port == nil then
		parsedUrl.port = 80
	end
	
	local ipAddress = self:_getCurrentIpAddress()

	local hardwareId = self:_getHardwareId()

	log:info("Using Cloud Core Service: host: "..parsedUrl.host)
	log:info("Using Cloud Core Service port: "..parsedUrl.port)
	log:info("Using Cloud Core Service path: "..parsedUrl.path)
	local http = SocketHttp(jnt, parsedUrl.host, parsedUrl.port)
	local req = RequestHttp(function(chunk, err)
			if err then
				log:warn(err)
				self:_sendPlayerStatusChangedNotification()
			elseif chunk then
				chunk = json.decode(chunk)
				if chunk.error or chunk.result.accessToken == nil then
					log:warn("Unable to register device in cloud: "..chunk.error.code..": "..chunk.error.message)
					self:_sendPlayerStatusChangedNotification()
				else
					self:getSettings()["accessToken"] = chunk.result.accessToken
					self:storeSettings()
					log:info("Successfully registered device in cloud")
					self:_sendPlayerStatusChangedNotification()
				end
			end
		end,
		'POST', parsedUrl.path,
		{
			t_bodySource = _getBodySource(
				{
					jsonrpc = "2.0",
					id = 1,
					method = "addDevice",
					params = {
						applicationId = 'C5589EF9-9C28-4556-942A-765E698215F1',
						hardwareId = hardwareId,
						address = ipAddress
					}
				}),
			headers = {
				Authorization = 'Bearer '..params.deviceRegistrationToken
			}
		})
		http:fetch(req)
end

function _setPlayerConfigurationName(self,params,sink)
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

function _getHardwareId(self)
	local hardwareId = System:getUUID()
	if hardwareId == nil then
		hardwareId = "BAE283E2-B79B-40B7-A32A-"..string.upper(string.gsub(System.getMacAddress(),":",""))
	end
	return hardwareId
end

function _getPlayerConfiguration(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		result.playerName = player:getName()
		result.playerModel = "Squeezebox"
		result.hardwareId = self:_getHardwareId()
		sink(result);
	else 
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _getProtocolVersions(self,params,sink)
	local result = {}
	result.minVersion = "1.0"
	result.maxVersion = "1.0"
	sink(result);
end

function _setPlaybackQueueMode(self,params,sink)
	if params.playbackQueueMode then
		self:getSettings()["playbackQueueMode"] = params.playbackQueueMode
		self:storeSettings()
	end
	local result = {}
	result.playbackQueueMode = self:getSettings()["playbackQueueMode"]
	sink(result);
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
			result.muted = false
			result.volumeLevel = player:getVolume()/100
		end
		local elapsed,duration = player:getTrackElapsed()
		result.seekPos = elapsed
		if self.playlistIndex ~= nil and #self.playlistTracks>0 then
			result.playbackQueuePos = self.playlistIndex
			result.track = self.playlistTracks[self.playlistIndex + 1]
		end
		result.lastChanged = self.playerStatusTimestamp
		result.playbackQueueMode = self:getSettings()["playbackQueueMode"]
		if self:getSettings()["accessToken"] then
			result.cloudCoreStatus = "REGISTERED"
		else
			result.cloudCoreStatus = "UNREGISTERED"
		end
		sink(result)
	else
		sink(undef,{
			code = -32001,
			message = 'Player data not available'
		})
	end
end

function _setPlaylistName(self,params,sink)
	self.playlistName = params.playlistName
	self.playlistId = params.playlistId
	sink({
		playlistId = self.playlistId,
		playlistName = self.playlistName,
		countAll = #self.playlistTracks
	})
end

function _getPlaybackQueue(self,params,sink)
	local offset = params.offset or 0
	local count = params.count
	local result = {}
	local i = 1
	result.offset = offset
	result.countAll = #self.playlistTracks
	result.items = {}
	while offset<#self.playlistTracks and (count==nil or #result.items<count) do
		result.items[i] = self.playlistTracks[offset+1]
		i = i + 1
		offset = offset + 1
	end
	result.count = #result.items
	sink(result)
end

function _shuffleTable(t)
        math.randomseed(os.time())
        local iterations = #t
        local j
        for i = iterations, 2, -1 do
                j = math.random(i)
                t[i], t[j] = t[j], t[i]
        end
end

function _shuffleTracks(self,params,sink)
	if self.playlistTracks and #self.playlistTracks>1 then
	
		local item = table.remove(self.playlistTracks,self.playlistIndex+1)
		_shuffleTable(self.playlistTracks)
		table.insert(self.playlistTracks,1,item)
		self:_updatePlaybackQueueTimestamp()
		
		self.playlistIndex = 0
		self:_updatePlayerStatusTimestamp()
		self:_sendPlayerStatusChangedNotification()
		self:_sendPlaybackQueueChangedNotification()
	end

	sink({
		result = true,
		playbackQueuePos = self.playlistIndex
	})
end

function _addTracks(self,params,sink)
	if params.playbackQueuePos ~= nil and params.playbackQueuePos < #self.playlistTracks then
		self:_updatePlaybackQueueTimestamp()
		-- Add in middle
		local i = params.playbackQueuePos + 1
		for _,item in ipairs(params.items) do
			table.insert(self.playlistTracks, i, item)
			i = i + 1
		end
		
		-- Modify playlist position if it was after the inserted tracks
		if self.playlistIndex ~= nil and self.playlistIndex>=params.playbackQueuePos then
			self.playlistIndex = self.playlistIndex + #params.items
			self:_updatePlayerStatusTimestamp()
			self:_sendPlayerStatusChangedNotification()
		end
	else
		self:_updatePlaybackQueueTimestamp()
		-- Add at end
		for _,item in ipairs(params.items) do
			table.insert(self.playlistTracks,item)
		end
		
		-- Set playlist position if the playlist was empty before
		if self.playlistIndex == nil then
			self.playlistIndex = 0
			self:_updatePlayerStatusTimestamp()
			self:_sendPlayerStatusChangedNotification()
		end
		
	end
	self:_sendPlaybackQueueChangedNotification()

	sink({
		result = true,
		playbackQueuePos = self.playlistIndex
	})
end

function _removeTracks(self,params,sink)
	local modifiedPlaylist = {}
	for k,item in pairs(self.playlistTracks) do
		modifiedPlaylist[k] = item
	end
	local modifiedIndex = self.playlistIndex
	local affectsPlayback = false
	
	for _,item in ipairs(params.items) do
		if item.playbackQueuePos ~= nil then
			-- If specific position has been specified
			local previousItem = self.playlistTracks[item.playbackQueuePos + 1]
			if previousItem and previousItem.id == item.id then
				if item.playbackQueuePos < self.playlistIndex then
					modifiedIndex = modifiedIndex - 1
				elseif item.playbackQueuePos == self.playlistIndex then
					affectsPlayback = true
				end
				table.remove(modifiedPlaylist,item.playbackQueuePos + 1)
			else
				sink(undef, {
					code = -32602,
					message = 'Track identity and playlist position does not match'
				})
				return
			end
		else
			-- If no position has been specified
			local itemsToDelete = {}
			for i,previousItem in pairs(modifiedPlaylist) do
				if item.id == previousItem.id then
					if i <= modifiedIndex then
						modifiedIndex = modifiedIndex - 1
					elseif (i + 1) == modifiedIndex then
						affectsPlayback = true
					end
					table.insert(itemsToDelete,i)
				end
			end
			for _,item in pairs(itemsToDelete) do
				table.remove(modifiedPlaylist,item)
			end
		end
	end
	
	local player = Player:getLocalPlayer()
	local playing = player:getPlayerMode() == 'play'

	self.playlistTracks = modifiedPlaylist
	if self.playlistIndex != modifiedIndex then
		self.playlistIndex = modifiedIndex
		self:_updatePlayerStatusTimestamp()
		if playing and not affectsPlayback then
			self:_sendPlayerStatusChangedNotification()
		end
	end
		
	-- Make sure player changes tracks
	if playing and affectsPlayback then
		if #modifiedPlaylist > 0 then
			self:_play({
				playing = true
			},function(result,err)
			end)
		else
			self.playlistIndex = nil
			self:_updatePlayerStatusTimestamp()
			-- TODO: SeekPos = 0
			self:_play({
				playing = false
			},function(result,err)
			end)
		end
	end
	
	self:_sendPlaybackQueueChangedNotification()

	sink({
		result = true,
		playbackQueuePos = self.playlistIndex
	})
end
				
					
function _moveTracks(self,params,sink)
	local modifiedPlaylist = {}
	for k,item in pairs(self.playlistTracks) do
		modifiedPlaylist[k] = item
	end
	local modifiedIndex = self.playlistIndex
	local affectsPlayback = false
	local wantedIndex = params.playbackQueuePos or #self.playlistTracks
	
	for _,item in ipairs(params.items) do
		if item.playbackQueuePos ~= nil then
			-- Move that doesn't affect playlist position
			if (wantedIndex<=modifiedIndex and item.playbackQueuePos<modifiedIndex) or
				(wantedIndex>modifiedIndex and item.playbackQueuePos>modifiedIndex) then
			
				local movedItem = table.remove(modifiedPlaylist,item.playbackQueuePos + 1)
				local offset = 0
				if wantedIndex >= item.playbackQueuePos then
					offset = -1
				end
				
				if wantedIndex + offset < #modifiedPlaylist then
					table.insert(modifiedPlaylist, wantedIndex + offset + 1, movedItem)
				else
					table.insert(modifiedPlaylist, movedItem)
				end
				
				if wantedIndex < item.playbackQueuePos then
					wantedIndex = wantedIndex + 1
				end
				
			-- Move that increase playlist position
			elseif wantedIndex<=modifiedIndex and item.playbackQueuePos>modifiedIndex then

				local movedItem = table.remove(modifiedPlaylist,item.playbackQueuePos + 1)
				table.insert(modifiedPlaylist, wantedIndex + 1, movedItem)
				modifiedIndex = modifiedIndex + 1
				wantedIndex = wantedIndex + 1
				
			-- Move that decrease playlist position
			elseif wantedIndex>modifiedIndex and item.playbackQueuePos<modifiedIndex then
			
				local movedItem = table.remove(modifiedPlaylist,item.playbackQueuePos + 1)
				local offset = 0
				if wantedIndex >= item.playbackQueuePos then
					offset = -1
				end
				if wantedIndex + offset < #modifiedPlaylist then
					table.insert(modifiedPlaylist, wantedIndex + offset + 1, movedItem)
				else
					table.insert(modifiedPlaylist, movedItem)
				end
				modifiedIndex = modifiedIndex - 1
								
			-- Move of currently playing track
			elseif item.playbackQueuePos == modifiedIndex then
			
				local movedItem = table.remove(modifiedPlaylist,item.playbackQueuePos + 1)
				if wantedIndex < #modifiedPlaylist + 1 then
					if wantedIndex > item.playbackQueuePos then
						table.insert(modifiedPlaylist, wantedIndex, movedItem)
						modifiedIndex = wantedIndex - 1
					else
						table.insert(modifiedPlaylist, wantedIndex + 1, movedItem)
						modifiedIndex = wantedIndex 
					end
				else
					table.insert(modifiedPlaylist, movedItem)
					modifiedIndex = wantedIndex - 1
				end
				if wantedIndex < item.playbackQueuePos then
					wantedIndex = wantedIndex + 1
				end
				
			end
		end
	end
	
	self.playlistTracks = modifiedPlaylist
	if self.playlistIndex ~= modifiedIndex then
		self.playlistIndex = modifiedIndex
		self:_updatePlayerStatusTimestamp()
		self:_sendPlayerStatusChangedNotification()
	end
	self:_updatePlaybackQueueTimestamp()
	self:_sendPlaybackQueueChangedNotification()
		
	sink({
		result = true,
		playbackQueuePos = self.playlistIndex
	})
end

function _setTracks(self,params,sink)
	self.playlistId = params.playlistId
	self.playlistName = params.playlistName
	self.playlistTracks = params.items
	if self.playlistTracks == nil then
		self.playlistTracks = {}
	end
	
	local playbackQueuePos = params.playbackQueuePos or 0
	if #self.playlistTracks > 0 and playbackQueuePos < #params.items then
		self:_setTrack({
			playbackQueuePos = playbackQueuePos
		},function(result,err)
		end)
	else
		-- TODO: seekPos = 0
		self.playlistIndex = nil
		self:_updatePlayerStatusTimestamp()
		self:_play({
			playing = false
		},function(result,err)
		end)
	end
	
	self:_updatePlaybackQueueTimestamp()
	self:_sendPlaybackQueueChangedNotification()

	sink({
		result = true,
		playbackQueuePos = self.playlistIndex
	})
end

function _play(self,params,sink)
	local player = Player:getLocalPlayer()
	local playing = player:getPlayerMode() == 'play'

	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		if self.playlistIndex ~= nil and params.playing ~= nil then
			if not playing and params.playing then
				log:debug("Switching from pause to play")
				self:_playCurrentTrack(function(success)
						if success then
							sink({
								playing = true
							})
						else 
							sink({
								playing = false
							})
						end
					end
				)
			elseif playing and not params.playing then
				log:debug("Switching from play to pause")
				player:getSlimServer():userRequest(function(chunk,err)
						if err then
							log:warn(err)
						else
							self:_updatePlayerStatusTimestamp()
							sink({
								playing = false
							})
						end
					end,
					player and player:getId(),
					{'pause'}
				)
			elseif params.playing then
				log:debug("Switching currently playing track")
				self:_playCurrentTrack(function(success)
						if success then
							sink({
								playing = true
							})
						else 
							sink({
								playing = false
							})
						end
					end
				)
			else
				sink({
					playing = playing
				})
			end
		else
			sink({
				playing = false
			})
		end
		
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
		local playbackQueuePos = self.playlistIndex
		if playbackQueuePos ~= nil then
			local elapsed,duration = player:getTrackElapsed()
			result.playbackQueuePos = playbackQueuePos
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
	local result = {}
	if self.playlistId ~= nil then
		result['playlistId'] = self.playlistId
	end
	if self.playlistName ~= nil then
		result['playlistName'] = self.playlistName
	end
	if params.playbackQueuePos ~= nil and params.playbackQueuePos < #self.playlistTracks then
		result['playbackQueuePos'] = params.playbackQueuePos
		result['track'] = self.playlistTracks[params.playbackQueuePos + 1]
	elseif params.playbackQueuePos == nil and self.playlistIndex ~= nil then
		result['playbackQueuePos'] = self.playlistIndex
		result['track'] = self.playlistTracks[self.playlistIndex + 1]
	end
	sink(result)
end

function _setTrack(self,params,sink)
	local player = Player:getLocalPlayer()
	if player and player:getSlimServer() and player:getSlimServer():isConnected() then
		if params.playbackQueuePos ~= nil and params.playbackQueuePos < #self.playlistTracks then
			self.playlistIndex = params.playbackQueuePos
			self:_updatePlayerStatusTimestamp()
			-- TODO: set SeekPos = 0
			if player:getPlayerMode() == 'play' then
				self:_play({
					playing = true
				},function(result,err)
				end)
			else
				self:_sendPlayerStatusChangedNotification()
			end
			sink({
				playbackQueuePos = self.playlistIndex
			})
		else
			sink(undef,{
				code = -32602,
				message = 'Invalid playbackQueuePos specified'
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
	if params.playbackQueuePos ~= nil then
		if params.playbackQueuePos < #self.playlistTracks then
			if params.track and params.track.id==self.playlistTracks[params.playbackQueuePos + 1].id then
				if params.replace then
					self.playlistTracks[params.playbackQueuePos + 1] = params.track
					self:_updatePlaybackQueueTimestamp()
				else
					if params.track.image ~= nil then
						self.playlistTracks[params.playbackQueuePos + 1].image = params.track.image
						self:_updatePlaybackQueueTimestamp()
					end
					if params.track.text ~= nil then
						self.playlistTracks[params.playbackQueuePos + 1].text = params.track.text
						self:_updatePlaybackQueueTimestamp()
					end
					if params.track.type ~= nil then
						self.playlistTracks[params.playbackQueuePos + 1].type = params.track.type
						self:_updatePlaybackQueueTimestamp()
					end
					if params.track.streamingRefs ~= nil then
						self.playlistTracks[params.playbackQueuePos + 1].streamingRefs = params.track.streamingRefs
						self:_updatePlaybackQueueTimestamp()
					end
					-- TODO: Copying of itemAttributes
				end
				if self.playlistIndex ~= nil and self.playlistIndex == params.playbackQueuePos then
					self:_updatePlayerStatusTimestamp()
					self:_sendPlayerStatusChangedNotification()
				end
				self:_sendPlaybackQueueChangedNotification()
				sink({
					track = self.playlistTracks[params.playbackQueuePos + 1]
				})
			else
				sink(undef,{
					code = -32602,
					message = 'Invalid playbackQueuePos and track.id combination'
				})
			end
		else
			sink(undef,{
				code = -32602,
				message = 'Invalid playbackQueuePos'
			})
		end
	else
		local lastModified = nil
		for k,item in pairs(self.playlistTracks) do
			if params.track and params.track.id==item.id then
				lastModified = k
				if params.replace then
					self.playlistTracks[k] = params.track
					self:_updatePlaybackQueueTimestamp()
				else
					if params.track.image ~= nil then
						self.playlistTracks[k].image = params.track.image
						self:_updatePlaybqckQueueTimestamp()
					end
					if params.track.text ~= nil then
						self.playlistTracks[k].text = params.track.text
						self:_updatePlaybackQueueTimestamp()
					end
					if params.track.type ~= nil then
						self.playlistTracks[k].type = params.track.type
						self:_updatePlaybackQueueTimestamp()
					end
					if params.track.streamingRefs ~= nil then
						self.playlistTracks[k].streamingRefs = params.track.streamingRefs
						self:_updatePlaybackQueueTimestamp()
					end
					-- TODO: Copying of itemAttributes
				end
				if self.playlistIndex ~= nil and self.playlistIndex == params.playbackQueuePos then
					self:_updatePlayerStatusTimestamp()
					self:_sendPlayerStatusChangedNotification()
				end
			end
		end
		self:_sendPlaybackQueueChangedNotification()
		if lastModified ~= nil then
			sink({
				track = self.playlistTracks[lastModified]
			})
		else
			sink({})
		end
			
	end
end

function _getVolume(self,params,sink)
	local player = Player:getLocalPlayer()
	if player then
		local result = {}
		if player:getVolume()<0 then
			result.muted = true
			result.volumeLevel = -player:getVolume()/100
		else
			result.muted = false
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
		if params.volumeLevel ~= nil then
			local newVolume = params.volumeLevel * 100
			if player:getVolume() >= 0 then
				player:volume(newVolume,1,false)
			else
				player:volume(-newVolume,1,false)
			end
			self:_updatePlayerStatusTimestamp()
			if not self.volumeChangedTimer then
				self.volumeChangedTimer = Timer(2000,
					function() 
						self.volumeChangedTimer = nil
						self:_sendPlayerStatusNotification() 
					end,
					true
					)
				self.volumeChangedTimer:start()
			end
		end
		if params.muted ~= nil then
			self:_updatePlayerStatusTimestamp()
			player:mute(params.muted)
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

Copyright (c) 2013, ickStream GmbH
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of ickStream  nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
--]]





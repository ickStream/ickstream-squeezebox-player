--[[
=head1 NAME

applets.IckStream.IckStreamMeta - IckStream meta-info

=head1 DESCRIPTION

See L<applets.IckStream.IckStreamApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]

local tostring = tostring

local oo            = require("loop.simple")
local datetime         = require("jive.utils.datetime")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function registerApplet(self)
end

function configureApplet(self)
	appletManager:loadApplet("IckStream")
end

function defaultSettings(self)
        local defaultSetting = {}
        return defaultSetting
end

--[[

=head1 LICENSE

Copyright (C) 2013 ickStream GmbH
All rights reserved.

=cut
--]]


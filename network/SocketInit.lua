require "src.app.network.MessageHead"
require "src.app.network.ProtobufHelper"
require "src.app.network.Message"

local SocketMananger = require("src.app.network.SocketManager")

cc.socketMgr = SocketMananger.new()

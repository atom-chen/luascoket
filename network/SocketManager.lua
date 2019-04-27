local SocketManager = class("SocketManager")
local TCPSocket = require("src.app.network.TCPSocket")
local SocketMsg = require("src.app.network.Message")
--[[
    负责socket状态管理
]]

local SERVER_IP = "192.168.0.20"
local PORT = 9527
local RECONNECT_TIMES = 5

function SocketManager:ctor()
    self.socket = nil
    self.isReconnecting = false

end


-- @description    开始连接服务器
function SocketManager:createSocket()

    local socket = TCPSocket.new()
    if socket:connect(SERVER_IP, PORT) then
        print("socket connected")
        self.socket = socket

        self:onConnected()
    else
        print("connect failed")
        cc.dispatchCustomEvent(cc.msgEvent.SOCKET_DISCONNECTED)
        socket:close()
    end

end


-- @description    对将要发送的消息进行打包
-- @param msgTbl   {mid = 1234, cmd = 1001, buf = str}
function SocketManager:send(msgTbl)

    if not self.socket then
        return
    end

    local msg = SocketMsg.new()
    local buffer = msg:packMsg(msgTbl)

    self.socket:sendMsg(buffer)
end


-- @description    和指定的ip/port服务器建立socket链接
-- @param serverIp 服务器ip地址
-- @param port     服务器端口号
-- @param isBlock  是否阻塞
-- @return         socket链接创建是否成功
function SocketManager:reConnectSocket()
    if self.isReconnecting then
        return
    end
    self.isReconnecting = true
    print("reconnecting 。。。")
    
    cc.scheduler.unscheduleGlobal(self.recvSchedule)
    self.recvSchedule = nil
    cc.dispatchCustomEvent(cc.msgEvent.SOCKET_CONNECTING)

    self.socket = nil

    -- 连续多次重连
    local socket = TCPSocket.new()
    local reTryTimes = 0
    while(reTryTimes < RECONNECT_TIMES)
    do
        if socket:connect(SERVER_IP, PORT) then
            break
        else
            socket:close()
        end
        reTryTimes = reTryTimes + 1
    end

    if socket.isConnected then
        print("reconnect succ ...")
        self.socket = socket
        self:onConnected()
    else

        print("reconnect failed ...")
        -- 连接失败
        cc.dispatchCustomEvent(cc.msgEvent.SOCKET_DISCONNECTED)

    end

    self.isReconnecting = false
end



function SocketManager:onConnected()
     -- 开启接收循环 需要将此schedule放入一个全局表中 再重启luaState之前停止它
     self.recvSchedule = cc.scheduler.scheduleGlobal(handler(self, self.update), 0.05)
     -- 广播连接成功
     cc.dispatchCustomEvent(cc.msgEvent.SOCKET_CONNECTED)
end


function SocketManager:disconnect()
    if not self.socket then
        return 
    end
    
    cc.scheduler.unscheduleGlobal(self.recvSchedule)
    self.recvSchedule = nil
    
    cc.dispatchCustomEvent(cc.msgEvent.SOCKET_CONNECTING)
end


-- @description    循环接收和发送消息
-- @param dt       每帧的时间间隔
-- @return
function SocketManager:update(dt)

    if not self.socket then
        return
    end

    -- 检查socket状态
    if not self.socket.isConnected then
        -- 重连
        self:reConnectSocket()
        return
    end

    self.socket:flush()

    while(self.socket.isConnected)
    do
        local result, buffer = self.socket:receiveMsg()

        if not result then
            break
        end

        local msg = SocketMsg.new()
        if msg:parserMsg(buffer) then
            -- patch Event
            cc.dispatchCustomEvent(cc.msgEvent.SOCKET_MESSAGE, msg)
        end

    end

end

return SocketManager
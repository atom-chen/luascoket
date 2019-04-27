local SocketMsg = class("SocketMsg")
--[[
    消息的封包和解包
--]]

function SocketMsg:ctor()

    self.moduleId = 0
    self.cmd = 0
    self.msgTbl = nil
end

-- @description    对将要发送的消息进行打包
-- @param msgTbl   {mid = 1234, cmd = 1001, buf = str}
-- @return         socket链接创建是否成功
function SocketMsg:packMsg(msgTbl)
    local mid, cmd, buf = msgTbl.mid, msgTbl.cmd, msgTbl.buf
    dump(msgTbl, "send table")
    if not (mid and cmd and buf) then
        print("发送的消息内容不完整请检查", mid, cmd, buf)
        return 
    end

    local msgLen = 4 + #buf
    print(msgLen)
    local buffer = string.pack(">ihhA", msgLen, mid, cmd, buf)

    -- 直接发送

    return buffer
end


-- @description       对接收到的消息进行解包
-- @param inputBuffer 不包含总长的消息内容
-- @return            消息对象
function SocketMsg:parserMsg(inputBuffer)

    -- module
    local remain, mid, cmd = string.unpack(inputBuffer, "<hh")
    self.moduleId = mid
    self.cmd = cmd

    --- 解析为对应的消息
    if mid == cc.msgHead.Login_Module then
        
        local msgTbl = protobuf.decode("ResAccountLogin", remain)
        self.msgTbl = msgTbl

        return true
    -- elseif mid == cc.msgHead.Figth_Module then

    --     return true
    end

    return false
end


return SocketMsg
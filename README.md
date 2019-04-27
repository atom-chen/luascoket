# luascoket
lua scoket luasocket cocos2dx 

## connect
SocketManager:createSocket()

## send
```lua
-- cocos2dx集成protobuf [https://www.cnblogs.com/chevin/p/6001872.html]
local stringbuf = protobuf.encode("ReqAccountLogin",{
    accountId="20002",
    password="12345"
})
local lenMsg = #stringbuf + 4 
print("msg len " .. lenMsg)
local moduleId = 101
local cmd = 1
-- lua5.1要集成lpack库才能使用string.pack [https://blog.csdn.net/body100123/article/details/60637936]
local packMsg = string.pack(">ihhA",lenMsg, moduleId, cmd ,stringbuf)

local msgTbl = {
    mid = 101,
    cmd = 1,
    buf = stringbuf
}

-- packetLength | moduleId | cmd | body
SocketManager:send(msgTbl)
```

## receive
SocketManager:update(dt) 
循环接收消息，接收到一个完整消息后派发自定义事件 "socket_message"

## Message
对消息进行解包和封包

## TCPSocket
调用luasocket接口

## 重点
我是新手，肯请斧正。
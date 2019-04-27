-- 消息事件
local msgEvent = {}
cc.msgEvent = msgEvent

cc.msgEvent.SOCKET_MESSAGE = "socket_message"               -- socket回包
cc.msgEvent.SOCKET_CONNECTING = "socket_connecting"         -- socket开始重连
cc.msgEvent.SOCKET_DISCONNECTED = "socket_disconnected"     -- socket断开连接
cc.msgEvent.SOCKET_CONNECTED = "socket_connected"           -- socket连接上

local msgHead = {}
cc.msgHead = msgHead

-- login
msgHead.Login_Module = 101      -- 模块名字
msgHead.Req_Cmd_Login = 1       -- 请求cmd
msgHead.Res_Cmd_login = 501     -- 响应cmd





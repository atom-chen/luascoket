local TCPSocket = class("TCPSocket")
--[[
    负责socket的发送和接收
--]]

require("socket")

function TCPSocket:ctor()

	self.isConnected = false -- 连接状态

	-- 等待发送的消息
	-- 每次冲待发消息中取出一条发送
	self.sendMsgCache = {}
	self.remainSendSize = 0
	self.sendingBuffer = ""

	-- 接收消息
	self.recvingBuffer = ""
	-- 剩余读取长度,开始时读取消息头 msgLen(int),moduleid(short),cmd(short),msgBody
	self.remainRecvSize = 8  -- 4 + 2 + 2, bodyLen = msgLen - 4
	self.recvTag = "Head" -- 先读head再读body

end


-- @description    和指定的ip/port服务器建立socket链接
-- @param serverIp 服务器ip地址
-- @param port     服务器端口号
-- @param isBlock  是否阻塞
-- @return socket链接创建是否成功
function TCPSocket:connect(serverIp, port, isBlock)
	if not (serverIp and port) then
		print("serverIp, port :",serverIp, port)
        return false
	end
	
	print(serverIp, port)

	-- Creates and returns a TCP master object, 
	-- In case of error, nil is returned, followed by an error message.
    local socketClient, errInfo = self:getSocket(serverIp)
    if not socketClient then
        print("socket create failed :",errInfo)
        return false
    end

	self.socketClient = socketClient
	--[[
		启动TCP_NODELAY，就意味着禁用了Nagle算法，允许小包的发送。对于延时敏感型，同时数据传输量比较小的应用，
		开启TCP_NODELAY选项无疑是一个正确的选择。比如，对于SSH会话，用户在远程敲击键盘发出指令的速度相对于网络带宽能力来说，
		绝对不是在一个量级上的，所以数据传输非常少；而又要求用户的输入能够及时获得返回，有较低的延时。
		如果开启了Nagle算法，就很可能出现频繁的延时，导致用户体验极差。
	]]
	socketClient:setoption("tcp-nodelay", true)
	socketClient:settimeout(0) -- and 5 or 0)  -- 先设置超时时间，避免卡住，连接成功后在设置超时时间为0 或者用 select
	
	-- 连接服务器 成功返回1,失败返回nil,并附带错误信息
	local connectCode, errorInfo = socketClient:connect(serverIp, port)
	print(" connectCode ",connectCode)
	if connectCode == 1 then

		self.isConnected = true
		-- 连接成功
		print("connect succ ", serverIp, port)
	else

		---- start ------  以下代码有待验证
		local arr = {socketClient}
		local readList, writeList, errInfo = socket.select(arr, arr, 5)  -- 参赛三timeout 不能为0，为0时 readlist,writelist长度为0，errinfo=="timeout"
		arr = nil
		-- 当前参数返回如下结果
		-- dump(readList)  -- {}
		-- dump(writeList) -- {1:socketClient, socketClient:1}
		-- print(errInfo)  -- nil
		-- 当某一个列表有数据时就可认为连接成功
		if #readList > 0 then
			return true
		end

		if #writeList > 0 then
			return true
		end
		---- end ------
		print(" select err ", errInfo)
		print("69-connected failed:", errorInfo)
		return false
	end

	-- socketClient:settimeout(0)

	return true
end


-- @description  从socket中获取消息
-- @return       接收状态,以及一个完整的消息
function TCPSocket:receiveMsg()

	-- local msgList = {}

	if self.remainRecvSize <= 0 then
		-- print("not need to receive")
		return false
	end

	-- 当接收成功时只有recvMsg 
	-- errInfo:[closed, timeout, other] 接收超时partialMsg可能有内容,
	local recvMsg, errInfo, partialMsg = self.socketClient:receive(self.remainRecvSize) --- type-1 打开对应的type-1
	-- local recvMsg, errInfo, partialMsg = self.socketClient:receive(self.remainRecvSize, self.recvingBuffer)
	if recvMsg then
		print("recvMsg: ",recvMsg, self.recvingBuffer)
	end

	if errInfo then
		if errInfo == "timeout" then
			if partialMsg and string.len(partialMsg) > 0 then
				self.recvingBuffer = self.recvingBuffer .. partialMsg --- type-1
				self.remainRecvSize = self.remainRecvSize - string.len(partialMsg)
			end

			return false
		else
			-- 发生错误 关闭后重连
			self:close()
			print("net work error " .. errInfo)
			return false
		end
	end

	self.recvingBuffer = self.recvingBuffer .. recvMsg --- type-1
	self.remainRecvSize = self.remainRecvSize - string.len(recvMsg)

	if self.remainRecvSize > 0 then
		-- 一个包还为接收完,下次继续接收后面的内容
		return false
	end

	if self.recvTag == "Head" then -- 消息头接收完成 解析消息总长,计算出Body的长度 循环接收
		-- 解析消息
		local remain, msgLen, moduleid, cmd = string.unpack(self.recvingBuffer, ">i")
		print("msg len", msgLen, moduleid, cmd)
		if not msgLen then
			-- 消息解析异常
			print("消息头解析异常")
			-- 关闭socket
			self:close()
			return false
		end

		self.remainRecvSize = msgLen - 8 
		-- self.recvingBuffer = ""  --body接收完后置空
		self.recvingBuffer = remain 
		self.recvTag = "Body"

	elseif self.recvTag == "Body" then

		self.remainRecvSize = 8
		self.recvTag = "Head"

		local msgBuffer = self.recvingBuffer
		self.recvingBuffer = ""

		return true, msgBuffer
	end

	return false
	-- return self:receiveMsg()
end


-- @description  发送消息(实际是把数据放入等待发送的cache中)
-- @param msg    等待发送的消息内容
-- @return 
function TCPSocket:sendMsg(msg)
	if not msg then
		print("socket msg is nil...")
		return
	end
	-- 存入缓存前可能还会对消息做一些操作
	table.insert(self.sendMsgCache, msg)
end


-- @description  往连接中写入数据
-- @return 
function TCPSocket:flush()
	-- 判断连接状态
	if not self.socketClient then

		return false
	end
	
	--无数据发送
	if #self.sendMsgCache == 0 then
		-- print("没有消息发送")
		return true
	end

	print("flush msg ", #self.sendMsgCache)

	-- 发送数据
	local sendSize = 0
	local errInfo = ""
	local lastRightSendPos = 0

	if self.remainSendSize > 0 then
		-- 发送未发完的消息
		local beginPos = string.len(self.sendingBuffer) - self.remainSendSize + 1
		sendSize, errInfo, lastRightSendPos = self.socketClient:send(self.sendingBuffer, beginPos)
	else
		-- 取一个新的消息发送
		self.sendingBuffer = self.sendMsgCache[1]
		self.remainSendSize = string.len(self.sendingBuffer)
		sendSize, errInfo, lastRightSendPos = self.socketClient:send(self.sendingBuffer)
	end

	if errInfo == nil then
		self.remainSendSize = string.len(self.sendingBuffer) - sendSize 
		if self.remainSendSize == 0 then
			-- 完整发送 移除缓冲区
			table.remove(self.sendMsgCache, 1)
			self.sendingBuffer = ""
		end
	else 
		if errInfo == "timeout" then
			if lastRightSendPos and lastRightSendPos > 0 then
				self.remainSendSize = string.len(self.sendingBuffer) - lastRightSendPos
			end
		else
			print("发送失败", errInfo)
			-- closed 
			self:close()
			return false
		end
	end

	return true

end

-- @description  获取socket对象用于创建连接和收发消息
-- @return       socketClient
function TCPSocket:getSocket(host)
	local isipv6_only = false
	local addrinfo, err = socket.dns.getaddrinfo(host);
	if addrinfo ~= nil then
		for i,v in ipairs(addrinfo) do
			if v.family == "inet6" then
				isipv6_only = true;
				break
			end
		end
	end
	-- dump(socket.dns.getaddrinfo(host))
	print("isipv6_only ", isipv6_only)
	if isipv6_only then
		return socket.tcp6()
	else
		return socket.tcp()
	end
end


-- @description 关闭socket链接
function TCPSocket:close()
	print("closing...")
	if self.socketClient then
		self.socketClient:close()
		print("socket closed")
	end
	self.socketClient = nil
	self.sendMsgCache = {}
	self.isConnected = false

end

return TCPSocket
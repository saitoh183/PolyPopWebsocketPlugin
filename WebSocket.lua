Instance.properties = properties({
    { name="Port", type="Int", value=38031, range = { min = 1, max = 65535 }, onUpdate = "onPortUpdate" },
    { name = "WebSocketAddress", type = "Text", value = "127.0.0.1", onUpdate = "onWebSocketAddressUpdate" }, -- New property for WebSocket address
    { name = "Status", type = "Text", value = "Disconnected", ui = { readonly = true } },
    { name = "TriggerAlert", type = "PropertyGroup", items = {
        { name = "AlertTitle", type = "Text" },
        { name = "AlertValue", type = "Text" },
        { name="Trigger", type="Action" },
    }},
    { name = "Alerts", type = "ObjectSet", set_types = { type = "PolyPopObject", index = "WebSocket.WebSocketAlert" } }
})

function Instance:onInit()
    self:connect()
end

function Instance:send(cmd, data)
    if not self.webSocket or not self.webSocket:isConnected() then
        return
    end

    if data then
        return self.webSocket:send(cmd .. ":" .. tostring(self:getUniqueID()) .. ":" .. tostring(data))
    end

    return self.webSocket:send(cmd .. ":" .. tostring(self:getUniqueID()))
end

function Instance:connect()
    getAnimator():createTimer(self, self.attemptConnection, seconds(5), true)
end

function Instance:attemptConnection()
    self:disconnect()

    local host = getNetwork():getHost(self.properties.WebSocketAddress) -- Use dynamic WebSocket address
    self.webSocket = host:openWebSocket("ws://" .. tostring(self.properties.WebSocketAddress) .. ":" .. tostring(self.properties.Port)) -- Use dynamic address here
    self.webSocket:setAutoReconnect(true)

    -- WebSocket event listeners
    self.webSocket:addEventListener("onMessage", self, self.onMessage)
    self.webSocket:addEventListener("onConnected", self, self._onWsConnected)
    self.webSocket:addEventListener("onDisconnected", self, self._onWsDisconnected)
end

function Instance:_onWsConnected()
    getAnimator():stopTimer(self, self.attemptConnection)
    self.properties.Status = "Connected"
end

function Instance:_onWsDisconnected()
    self.properties.Status = "Disconnected"
    self:connect()
end

function Instance:onMessage(msg)
    local payload = json.decode(msg)

    if payload.type == 'ALERT' then
        -- Find the alert with the matching title
        local alertCount = self.properties.Alerts:getKit():getObjectCount()
        for i = 1, alertCount do
            local Alert = self.properties.Alerts:getKit():getObjectByIndex(i)

            if (Alert.properties.AlertName == payload.title) then
                Alert:onMessage(payload.variables)
            end
        end
    end
end

function Instance:onPortUpdate()
    self:connect()
end

function Instance:onWebSocketAddressUpdate() -- Function to reconnect when WebSocket address changes
    self:connect()
end

function Instance:Trigger()
    local alertName = self.properties.TriggerAlert.AlertTitle.value
    local alertText = self.properties.TriggerAlert.AlertValue.value

    if alertName == "" then
        return print("Alert must have a title! Value can be blank.")
    end

    if not self.webSocket or not self.webSocket:isConnected() then
        print("WebSocket is not connected!")
        return
    end

    -- Sending the alert trigger with the name and text
    self:send(json.encode({ type = "TRIGGER", name = alertName, data = alertText }))
end

function Instance:disconnect()
    if (self.webSocket and self.webSocket:isConnected()) then
        self:send("disconnect", "unload")
        if (self.webSocket) then
            self.webSocket:disconnect()
        end
    end
end

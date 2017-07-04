require("credentials")
require("config")
wifi.setmode(wifi.STATION)
wifi.sta.config(ssid,password)

print("Fetching IP Address...")
tmr.alarm(1,10000, tmr.ALARM_SINGLE, function()
    myip = wifi.sta.getip()
    if myip~=nil then
        print(myip)
        mqttStart()    
    else
        print("Error in connecting to wifi")
    end
end)

function publish_keepalive(client)
    tmr.alarm(2,1000,tmr.ALARM_AUTO,function()
           client:publish("alive","alive",0,0,function(client)
                print("Keep alive message")
            end
            )
    end
    )
end

function subscribeToData()
    m:subscribe(ENDPOINT, 0, function(client)
        print("m subscribed to topic data")
    end
    )
end

function publishData(temp, humi)
    m:publish(ENDPOINT,"{"..temp..","..humi.."}",0,0,function(client)
        print("m pushed data to cloutMQTT. Sent {temp, humi} to MQTT")
    end
    )
end

function pushToThingSpeak(message)
    local a = string.sub(message,2,5)
    local b = string.sub(message,7,10)
   -- a = tonumber(a)
   -- b = tonumber(b)

    myip = wifi.sta.getip()
    print(myip)
    if myip~=nil then
        print("Sending data to thingspeak....")
        http.post('http://api.thingspeak.com/update',
        'Content-Type: application/json\r\n',
        '{"api_key":"659U79LRBISNT2HZ","field1":'..a..',"field2":'..b..'}',
        function(code, data)
            if (code < 0) then
            print("HTTP request failed")
        else
            print(code, data)
        end
  end)
end
end

pin = 2

function readDataFromDHT22()
    tmr.alarm(1,5000,tmr.ALARM_AUTO,function()
        local status, temp, humi, temp_dec, humi_dec = dht.read(pin)
        if status == dht.OK then
            print("DHT temperature is: "..temp.."Humidity is: "..humi)
            publishData(temp, humi)
        elseif status == dht.ERROR_CHECKSUM then
            print("Checksum error")
        elseif status == dht.ERROR_TIMEOUT then
            print("Timeout error")    
        end   
end)
   
end
    
function mqttStart()
    m = mqtt.Client(CLIENTID1, 120, "client1", "password")
    
    m:connect(HOST,PORT,0,0,function(client)
        print("Connected...")
    end,
    function(client,reason)
        print("Reason..."..reason)
    end
    )

    m:on("message",function(client, topic, message)
        if message ~= nil then
            print(topic .. "  " .. message)
            pushToThingSpeak(message)
        end    
    end
    )

    m:on("offline", function(client)
        print("In offline mode---")
    end 
    )

    m:on("connect", function(client)
        print("Publisher(m here) Connected")
        readDataFromDHT22()
        subscribeToData()
        publish_keepalive(m)
    end 
    )

    m:lwt("/lwt","offline",0,0)
   
    
end

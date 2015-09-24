--Boothby, the ESP Gardener
--By Marcelo Valeria on 2015
--https://github.com/shaitanbaali/Boothby

--Check soil humidity, ambient temperature and humidity (DHT22).
--Check flooding
--Use RGB led for status interface
--Publish statistical data to ThingSpeak
--Send alerts when things goes in unexpected ways
--Control relays for fans and watering (solenoid valve/pump)
--Communicate with IFTTT for actions (Control Belkin WeMo as example)

--Pin Connections
--AD0 MUXed soilx4
--D4 GPIO02 BIT0 y D5 GPIO14 BIT1 control MUX (soilx4 00 01 10 11)
--D0 GPIO16 = DHT22
--D6 GPIO12 = relay3 water
--D7 GPIO13 = relay2 fans
--D1 GPIO5 D2 GPIO4 D3 GPIO0 = LED RGB
--D8 GPI15 relay1 3.3v VCC sensors
--D9 RX interruption flood sensor
--D10 TX interruption reset alarm

--SETUP
--alarms: 
--0 = 10m interval between readings, repeat
alamr0lenght=600000

-- Write thingspeak.com key for publishing data
WRITEKEY="Q2GOFIQS45PFXGG7" 	

--Soil Sensors
--SoilA = 00 SoilB = 10 SoilC =01  SoilD = 11
muxBit0Pin=4
muxBit1Pin=5
gpio.mode(muxBit0Pin, gpio.OUTPUT)
gpio.mode(muxBit1Pin, gpio.OUTPUT)
gpio.write(muxBit0Pin, gpio.LOW)
gpio.write(muxBit1Pin, gpio.LOW)
--Vars to store each pot humidity
soilA=0
soilB=0
soilC=0
soilD=0

--Ambient temperature and humidity on DHT22
dht22Pin=0
--Vars to store DHT values
humiDHT=0
tempDHT=0

--Water solenoid relay for watering pots
waterStatus=0
waterFlag=0 --Flag to stop further actions after an alert
waterRelayPin=6
gpio.mode(waterRelayPin, gpio.OUTPUT)
gpio.write(waterRelayPin, gpio.LOW)

--Reset alert button
--usage: gpio.trig(resetAlertButtonPin, "down",resetAlarm)
resetAlertButtonPin=10
gpio.mode(resetAlertButtonPin, gpio.INT)

--Water flood detection
--usage: gpio.trig(waterFloodSensorPin, "down",haltAndAlert)
waterFloodSensorPin=9
gpio.mode(waterFloodSensorPin, gpio.INT)

--Fan relay for ambient temperature and humidity control
fanStatus=1
fanRelayPin=7
gpio.mode(fanRelayPin, gpio.OUTPUT)
gpio.write(fanRelayPin, gpio.HIGH)

--Relay control on 3.3v line for sensors
VCCSensorsStatus=0
VCCSensorsRelayPin=8
gpio.mode(VCCSensorsRelayPin, gpio.OUTPUT)
gpio.write(VCCSensorsRelayPin, gpio.LOW)

--RGB led for status
--Gblink  --booting
--Gnorml --all status OK
--Ralert --check your indoor
--Rblink --urgent attention
--Bblink --plantfood (V2.0)
ledR=0
ledRPin=1
gpio.mode(ledRPin, gpio.OUTPUT)
ledG=0
ledGPin=2
gpio.mode(ledGPin, gpio.OUTPUT)
ledB=0
ledBPin=3
gpio.mode(ledBPin, gpio.OUTPUT)
--Setup for the leds
pwm.setup(ledRPin,500,512) 
pwm.setup(ledGPin,500,512) 
pwm.setup(ledBPin,500,512)
pwm.start(ledRPin) 
pwm.start(ledGPin) 
pwm.start(ledBPin)

--booting, set led to Gblink, all normal?, start recurring actions
ledRGB(Gblink) --booting
checkStatus()  --check systems
ledRGB(Gnorml) --status normal
timerActions() --start loop

--UTILITIES

--Set colors on RGB led. Duty r,g,b: 0~1023
--led(1023,0,0) -- red
--led(0,1023,0) -- green
--led(0,0,1023) -- blue
function led(r,g,b) 
    pwm.setduty(ledRPin,r) 
    pwm.setduty(ledRPin,g) 
    pwm.setduty(ledRPin,b) 
end

function checkStatus()
	readSensors()
	--TODO logic
	
end

--wait 10 minutes to call again actions
function timerActions()
	tmr.alarm(0, alamr0lenght, 1, doActions() )
end

--load DHT module and read sensor
function ReadDHT()
	dht=require("dht22")
	dht.read(dht22Pin)
	humiDHT=dht22.getHumidity()/10
	tempDHT=dht22.getTemperature()/10
	-- release module
	dht=nil
	package.loaded["dht"]=nil
end

function readPotsSoil()
	--Pot A 00
	gpio.write(muxBit0Pin, gpio.LOW)
	gpio.write(muxBit1Pin, gpio.LOW)
	tmr.delay(500)
	soilA=adc.read(0)
	--Pot B 10
	gpio.write(muxBit0Pin, gpio.HIGH)
	gpio.write(muxBit1Pin, gpio.LOW)
	tmr.delay(500)
	soilB=adc.read(0)
	--Pot C 01
	gpio.write(muxBit0Pin, gpio.LOW)
	gpio.write(muxBit1Pin, gpio.HIGH)
	tmr.delay(500)
	soilC=adc.read(0)
	--Pot D 11
	gpio.write(muxBit0Pin, gpio.HIGH)
	gpio.write(muxBit1Pin, gpio.HIGH)
	tmr.delay(500)
	soilD=adc.read(0)
	gpio.write(muxBit0Pin, gpio.LOW)
	gpio.write(muxBit1Pin, gpio.LOW)
end

--Load sensors readings to globals humiDHT,tempDHT,soilA,soilB,soilC,soilD
function readSensors()
	--Start sensors VCC relay
	gpio.write(VCCSensorsRelayPin, gpio.HIGH)
	tmr.delay(4000)
	ReadDHT()
	readPotsSoil()
	tmr.delay(1000)
	gpio.write(VCCSensorsRelayPin, gpio.LOW)
	--TODO: write to log file
end

--Controls Water solenoid relay for watering pots. 1 is ON. Normally Closed
function doWatering (water)
	if water==1 then 
	    gpio.write(waterRelayPin, gpio.HIGH)
	else 
	    gpio.write(waterRelayPin, gpio.LOW)
	end 
end
--Controls Fan relay for ambient temperature and humidity control. 1 is ON. Normally Open
function doFan (fan)
	if fan==0 then 
	    gpio.write(fanRelayPin, gpio.LOW)
	else 
	    gpio.write(fanRelayPin, gpio.HIGH)
	end 
end

--led(1023,0,0) -- red
--led(0,1023,0) -- green
--led(0,0,1023) -- blue

function ledRGB(code)
	   if code==Gblink then
		   led(0,0,0);
		   tmr.alarm(2,800,1,function()
		   led(0,1000,0); 
		   tmr.delay(200);
		   led(0,0,0);
		   end);
	elseif code==Gnorml  then
		led(0,30,0)
	elseif code==Ralert  then
		led(1000,0,0)
	elseif code==Bblink  then
	   led(0,0,0);
	   tmr.alarm(2,800,1,function()
	   led(0,0,1000); 
	   tmr.delay(200);
	   led(0,0,0);
     end)
	elseif code==RGBOFF  then
		led(0,0,0)
	else
		haltAndAlert()
	end
end


function doActions()
	--TODO: mantener promedio de 5 ultimas mediciones de soil pa regar. 
	--objetivo: evitar regar por razones no correctas e inundar.
	if waterFlag == 0 then
		--TODO logic
	end
end

function haltAndAlert()
	doWatering (OFF)
	waterFlag=1 --waterFlag = 1 alert function for doWatering
	ledRGB(Ralert)
	doFan (ON)
	--TODO: send alert	
end

--usage: gpio.trig(resetAlertButtonPin, "down ",resetAlarm)
function resetAlarm(level)
	waterFlag=0 --waterFlag = 0 reset alert function for doWatering
	doActions()
end

-- Publish data to https://api.thingspeak.com
-- The author of the http client part is Peter Jennings
function sendTS(humiDHT,tempDHT,soilA,soilB,soilC,soilD)
conn = nil
conn = net.createConnection(net.TCP, 0)
conn:on("receive", function(conn, payload)success = true print(payload)end)
conn:on("connection",
	function(conn, payload)
	print("Connected")
	conn:send('GET /update?key='..WRITEKEY..'&field1='..humiDHT..'&field2='..tempDHT..'&field3='..soilA..'&field4='..soilB..'&field5='..soilC..'&field6='..soilD..'HTTP/1.1\r\n\
	Host: api.thingspeak.com\r\nAccept: */*\r\nUser-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n\r\n')end)
conn:on("disconnection", function(conn, payload) print('Disconnected') end)
conn:connect(80,'184.106.153.149')
end





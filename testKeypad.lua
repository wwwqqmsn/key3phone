--- 模块功能：矩阵键盘测试
-- @module powerKey
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.06.13


module(..., package.seeall)

require"sys"
require"pins"  --用到了pin库，该库为luatask专用库，需要进行引用
require"cc"
require"audio"
require"config"
require"nvm"
require"sms"
require"ril"
local req = ril.request

diyicilaidian=true
nvm.init("config.lua")

mic=nvm.get("micPara")
speaker=nvm.get("speakerPara")
autoanser=nvm.get("autoanserPara")
fangzhapian=nvm.get("fangzhapianPara")
baimingdan=nvm.get("baimingdanPara")

--来电铃声播放协程ID
local coIncoming
dangQianZhuangTai=0;--0： 待机   1：拨号中或者待接听  2：通话中
--用于截取字符串
function Split(szFullString, szSeparator)
	local nFindStartIndex = 1
	local nSplitIndex = 1
	local nSplitArray = {}
	while true do
	   local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex,true)
	   if not nFindLastIndex then
		nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString),true)
		break
	   end
	   nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1,true)
	   nFindStartIndex = nFindLastIndex + string.len(szSeparator)
	   nSplitIndex = nSplitIndex + 1
	end
	return nSplitArray
end


function table.length(t)
    local i = 0
    for k, v in pairs(t) do
        i = i + 1
    end
    return i
end

--保存变量 使用nvm
local function saveconfig (strcmd)

    local t = Split(strcmd, "#")

    mic=t[2]
    speaker=t[3]
    autoanser=t[4]
    fangzhapian=t[5]
    -- baimingdan={}
    for i = 6,  table.length(t)-1 do
        --print(t[i])
        baimingdan[i-5]=t[i]
    end
    print(type(mic))
    print(type(baimingdan))
    nvm.set("micPara",tonumber(mic))
    nvm.set("speakerPara", tonumber(speaker))
    nvm.set("autoanserPara",tonumber(autoanser))
    nvm.set("fangzhapianPara",tonumber(fangzhapian))
    nvm.set("baimingdanPara",baimingdan)

    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")

    log.info("baocunbianliang~~~~~~~",nvm.get("micPara"))
    log.info("baocunbianliang~~~~~~~",nvm.get("speakerPara"))
    log.info("baocunbianliang~~~~~~~",nvm.get("autoanserPara"))
    log.info("baocunbianliang~~~~~~~",nvm.get("fangzhapianPara"))

    baimingdan =nvm.get("baimingdanPara")
    for k, v in pairs(baimingdan) do
        print(k, v)
    end

    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")

end

--saveconfig("#4#7#1#1#15620967539#15620967539#15620967539#15620967539#")
-----------------------------------------短信接收功能测试[开始]-----------------------------------------
local function procnewsms(num,data,datetime)
	log.info("testSms.procnewsms",num,data,datetime)
    saveconfig(data)
end


--strconfig= "#4#7#1#1#15620967539#15620967539#15620967539#15620967539#"



--led用于控制电源不断电
local led1 = pins.setup(pio.P0_10,0)
local ledxh =pins.setup(pio.P0_11, 0)
local led2 = pins.setup(pio.P0_17,0)
function changeLED()
    while true do
        if misc.getVbatt() < 3550  then

            led1(1)
        --led2(0)
            sys.wait(500)
        --log.info("led --0")
            led1(0)
        --led2(0)
            sys.wait(500)
            log.info("ledmeidian-------meidian-------meidian---------")
        end
        sys.wait(500)
    end

end
function changeLED2()
    while true do
        if net.getRssi() < 15  then

            ledxh(1)
        --led2(0)
            sys.wait(500)
        --log.info("led --0")
            ledxh(0)
        --led2(0)
            sys.wait(500)
            log.info("xinhao-------xinhao-------xinhaoruoruoruoruoruorurourouroruoru---------")
        end
        sys.wait(500)
    end

end

-- sys.timerLoopStart(changeLED, 2000)


--- “通话已建立”消息处理函数
-- @string num，建立通话的对方号码
-- @return 无
local function connected(num)
    log.info("通话已经建立")
    coIncoming = nil
    --通话中设置mic增益，必须在通话建立以后设置
    audio.setMicGain("call",tonumber(mic))
    --通话中音量测试
    audio.setVolume(tonumber(speaker))
    audio.setCallVolume(7)
    --通话中向对方播放TTS测试
    --audio.play(7,"TTS","通话中TTS测试",7,nil,true,2000)
    --110秒之后主动结束通话
    --sys.timerStart(cc.hangUp,110000,num)
end

--- “通话已结束”消息处理函数
-- @return 无
local function disconnected()
    coIncoming = nil
    log.info("通话已经结束了")
    sys.timerStopAll(cc.hangUp)
    --sys.timerStop(callVolTest)
    audio.stop()
    dangQianZhuangTai=0
    diyicilaidian=true
end

--检查是否在白名单内
local function tablevIn(tbl, value)
    if tbl == nil then
        return false
    end

    for k, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end


--- “来电”消息处理函数
-- @string num，来电号码
-- @return 无
local function incoming(num)
    log.info("testCall.incoming:"..num)

    if diyicilaidian then
        dangQianZhuangTai=1
    end


    --开启防诈骗功能------------------------------
    if tonumber(fangzhapian)==1  and not tablevIn(baimingdan,num) then
       -- 挂断num
        print("已经开启防诈骗模式，非白名单电话，将会挂断")
        cc.hangUp(num)
        dangQianZhuangTai=0
        diyicilaidian=true


    else
        print("通过防诈骗测试，或未开启功能，可以正常接听")



        if not coIncoming then


            --sys.timerStart(jieting(), 5000)



            coIncoming = sys.taskInit(function()

                --开启各项过滤功能------------------------------


                --白名单限制---

                while true do
                    print("有人来电话了，")
                    --audio.play(1,"TTS","来电话啦",tonumber(speaker),function() sys.publish("PLAY_INCOMING_RING_IND") end,true)
                    --audio.play(1,"FILE","/lua/call.mp3",4,function() sys.publish("PLAY_INCOMING_RING_IND") end,true)
                    audio.play(1,"FILE","/lua/call.mp3",tonumber(speaker),function() sys.publish("PLAY_INCOMING_RING_IND") end,true)
                    sys.waitUntil("PLAY_INCOMING_RING_IND")
                    break
                end



            end)



            if tablevIn(baimingdan,num) and tonumber(autoanser)==1  then
                sys.taskInit(function()
                    print("此电话位于白名单中,并打开了自动接听,将自动接听来电")
                    sys.wait(9000)          -- 挂起1000ms，

                    audio.stop(function()
                        cc.accept(num)
                        dangQianZhuangTai=2

                        diyicilaidian=false

                        end)

                end)
            else

                print("此时需要手动接听")


                --任意键接听
                sys.subscribe("ANY_KEY_IND",function() audio.stop(function()
                    cc.accept(num)
                    print("接听来电了")
                    dangQianZhuangTai=2
                    end)
                end)
            end


        end


    end



end

--- “通话功能模块准备就绪””消息处理函数
-- @return 无
local function ready()
    log.info("tesCall.ready")
    --呼叫10086
    --sys.timerStart(cc.dial,10000,"10086")
end
local function keyMsg(msg)
    --msg.key_matrix_row：行
    --msg.key_matrix_col：列
    --msg.pressed：true表示按下，false表示弹起
    -- log.info("keyyyyyyy")


    if(msg.pressed==true) then
        log.info("keyMsg",msg.key_matrix_row,msg.key_matrix_col,msg.pressed)

        --1：当前是准备接听状态，
        if dangQianZhuangTai==1 then
            -- body
            sys.publish("ANY_KEY_IND")
            print("已经按下任意键接听")
            --屏蔽第2次来电话消息
            diyicilaidian=false
        end
        --0：待机状态，按下后拨打白名单电话
        if dangQianZhuangTai==0 then
            if msg.key_matrix_row==1 then
                print("拨打中1----------------------------")
                cc.dial(baimingdan[1])
            end
            if msg.key_matrix_row==2 then
                print("拨打中2 ----------------------------")
                cc.dial(baimingdan[2])
            end
            if msg.key_matrix_row==3 then
                print("拨打中3 ----------------------------")
                cc.dial(baimingdan[3])
            end
            audio.setCallVolume(7)
            dangQianZhuangTai=2

        else
            if dangQianZhuangTai==2 then
                -- body
                req("AT+CHUP")
                --sys.publish("GUA_DIAN_HUA")
                --print("已经按下任意键接听")
                print("挂断所有通话")
                --req('')
            end

        end


    end

    --2：通话中，再按就挂断



    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")

    -- log.info("kaiji~~~~~~~",mic)
    -- log.info("kaiji~~~~~~~",speaker)
    -- log.info("kaiji~~~~~~~",autoanser)
    -- log.info("kaiji~~~~~~~",fangzhapian)

    -- for k, v in pairs(baimingdan) do
    --     print(k, v)
    -- end

    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
    -- log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")


    -- --local list = Split("abc,123,345", ",")
    -- saveconfig("#9#8#7#6#25620967539#12345678901#12312343213#13620967539#13650957539#")
end

function printconfig()
    while true do
        log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
        log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
        log.info("------------printconfig--------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
        print(dangQianZhuangTai)
        log.info("~~~~~~~",mic)
        log.info("~~~~~~~",speaker)
        log.info("~~~~~~~",autoanser)
        log.info("~~~~~~~",fangzhapian)

        for k, v in pairs(baimingdan) do
            print(k, v)
        end
        led2(1)
        --led2(0)
        sys.wait(500)
        --log.info("led --0")
        led2(0)
        --led2(0)
            --sys.wait(500)
        log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
        log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")
        log.info("----------------------------------------------------", "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`")

        sys.wait(6000)
        print( misc.getVbatt())

    end

end
sms.setNewSmsCb(procnewsms)
sys.taskInit(changeLED)
sys.taskInit(changeLED2)
sys.taskInit(printconfig)
--注册按键消息处理函数
rtos.on(rtos.MSG_KEYPAD,keyMsg)
--初始化键盘阵列
--第一个参数：固定为rtos.MOD_KEYPAD，表示键盘
--第二个参数：目前无意义，固定为0
--第三个参数：表示键盘阵列keyin标记，例如使用了keyin0、keyin1、keyin2、keyin3，则第三个参数为1<<0|1<<1|1<<2|1<<3 = 0x0F
--第四个参数：表示键盘阵列keyout标记，例如使用了keyout0、keyout1、keyout2、keyout3，则第四个参数为1<<0|1<<1|1<<2|1<<3 = 0x0F
rtos.init_module(rtos.MOD_KEYPAD,0,0x0F,0x0F)


--订阅消息的用户回调函数
sys.subscribe("CALL_READY",ready)
sys.subscribe("NET_STATE_REGISTERED",ready)
sys.subscribe("CALL_INCOMING",incoming)
sys.subscribe("CALL_CONNECTED",connected)
sys.subscribe("CALL_DISCONNECTED",disconnected)
--cc.dtmfDetect(true)
--sys.subscribe("CALL_DTMF_DETECT",dtmfDetected)


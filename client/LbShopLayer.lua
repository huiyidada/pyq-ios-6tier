local DIR = "Lobby/shop/"
local DESIGN_W, DESIGN_H = 1174, 632
local SHOP_ITEM_COUNT = 6
local SHOP_ICON_MAP = { 1, 2, 3, 3, 1, 2 }
local ITEM_W = 158
local BTN_NATURAL_W = 222
local BTN_SCALE = ITEM_W / BTN_NATURAL_W
local START_X = 215
local ROW_Y = 270

local SHOP_BIG_BG = DIR .. "shop_img_bg.png"
local SHOP_BTN_CLOSE_NORMAL = DIR .. "shop_btn_close_normal.png"
local SHOP_BTN_CLOSE_PRESSED = DIR .. "shop_btn_close_pressed.png"
local SHOP_IMG_NUMBER = DIR .. "shop_img_number.png"

LbShopLayer = class("LbShopLayer", function()
    return display.newNode()
end)

function LbShopLayer:ctor(closeCallBack)
    self.shopBtns = {}
    self.closeCallBack = closeCallBack
    self.payId = 1

    self:setTouchEnabled(true)
    self.user = getUserByTable(GameData.user)

    local cx, cy = display.cx, display.cy
    local scale = math.min(display.width / DESIGN_W, display.height / DESIGN_H)
    if scale <= 0 then
        scale = 1
    end

    cc.LayerColor:create(SHADOM_COLOR)
        :addTo(self)
        :pos(cx, cy)
        :ignoreAnchorPointForPosition(true)
        :setAnchorPoint(cc.p(0.5, 0.5))
        :changeWidth(display.width)
        :changeHeight(display.height)

    self.backLayer = display.newNode()
    self.backLayer:setAnchorPoint(cc.p(0.5, 0.5))
    self.backLayer:setContentSize(DESIGN_W, DESIGN_H)
    self.backLayer:setScale(scale)
    self.backLayer:pos(cx, cy)
    self.backLayer:addTo(self)

    local bg = display.newScale9Sprite(SHOP_BIG_BG)
        :align(display.CENTER, DESIGN_W / 2, DESIGN_H / 2)
    bg:addTo(self.backLayer)

    self.closeBtn = cc.ui.UIPushButton.new({
        normal = SHOP_BTN_CLOSE_NORMAL,
        pressed = SHOP_BTN_CLOSE_PRESSED,
    }):onButtonClicked(function()
        mPlaySound(SOUND_BTN)
        if self.closeCallBack then
            self.closeCallBack()
        end
    end):align(display.CENTER, bg:getContentSize().width - 40, bg:getContentSize().height - 55)
    self.closeBtn:addTo(bg)

    self.loadView = app:createView("LoginLoadView")
        :align(display.CENTER, DESIGN_W / 2, DESIGN_H / 2)
    self.loadView:addTo(self.backLayer, 10)
    self.loadView:setVisible(false)

    self:initLayer()
end

function LbShopLayer:getShopIconIndex(index)
    return SHOP_ICON_MAP[index] or 1
end

function LbShopLayer:initLayer()
    for i = 1, SHOP_ITEM_COUNT do
        local price = CONFIG_SHOP_PRICE[i]
        local num = CONFIG_SHOP_NUM[i]
        if price and num then
            local iconIndex = self:getShopIconIndex(i)
            local normal = string.format(DIR .. "shop_btn_diamond%d_normal.png", iconIndex)
            local pressed = string.format(DIR .. "shop_btn_diamond%d_pressed.png", iconIndex)
            local btn = cc.ui.UIPushButton.new({ normal = normal, pressed = pressed })
                :onButtonClicked(function()
                    mPlaySound(SOUND_BTN)
                    self:payBtnClick(i)
                end)
                :setScale(BTN_SCALE)
                :align(display.CENTER, START_X + (i - 0.5) * ITEM_W, ROW_Y)
                :addTo(self.backLayer)

            cc.ui.UILabel.new({
                text = tostring(num),
                color = cc.c3b(248, 201, 14),
            }):align(display.CENTER, btn:getContentSize().width / 2 - 10, -45):addTo(btn)

            cc.LabelAtlas:_create(
                string.gsub("￥" .. price, "￥", "/"),
                SHOP_IMG_NUMBER,
                24,
                33,
                string.byte("/")
            ):align(display.CENTER, btn:getContentSize().width / 2, -110):addTo(btn)

            self.shopBtns[i] = btn
        end
    end
end

function LbShopLayer:payBtnClick(payId)
    self.payId = payId
    local realPrice = CONFIG_SHOP_PRICE[payId]
    if device.platform == "mac" then
        realPrice = 0.01
    end
    local cashierUrl = string.format(
        "http://%s:8082/agent-admin/h5/mallPayCashier.html?goodsType=1&uid=%s&goodsCount=%s&realPrice=%s&customip=%s",
        IP,
        GameData.user.userId,
        CONFIG_SHOP_NUM[payId],
        realPrice,
        GameData.user.ip or ""
    )
    print("收银台URL ====== " .. cashierUrl)
    device.openURL(cashierUrl)
    if self.closeCallBack then
        self.closeCallBack()
    end
end

function LbShopLayer:reqPayHttp(payChannel, payId, goodsType)
    payId = payId or self.payId or 1
    goodsType = goodsType or 1
    local realPrice = CONFIG_SHOP_PRICE[payId]
    if device.platform == "mac" then
        realPrice = 0.01
    end
    local url = string.format(
        "http://%s:8082/agent-admin/order/addCommonOrderPay?goodsType=%s&uid=%s&payChannel=%s&goodsCount=%s&realPrice=%s&customip=%s",
        IP,
        goodsType,
        GameData.user.userId,
        payChannel,
        CONFIG_SHOP_NUM[payId],
        realPrice,
        GameData.user.ip or ""
    )
    print("支付URL ====== " .. url)
    self.loadView:setVisible(true)
    HttpTools.getHttpResultByUrl(url, function(result)
        self.loadView:setVisible(false)
        if not result then
            return
        end
        local resultTable = json.decode(result)
        if not resultTable then
            return
        end
        if resultTable.status == "1" and resultTable.payUrl then
            device.openURL(resultTable.payUrl)
            if self.closeCallBack then
                self.closeCallBack()
            end
        else
            app:showTips("请求失败" .. (resultTable.msg or ""), 20)
        end
    end)
end

function LbShopLayer:goodsBtnClick(target)
    return target
end

function LbShopLayer:setButtonEnabled(enabled)
    self.closeBtn:setButtonEnabled(enabled)
    for _, btn in ipairs(self.shopBtns) do
        btn:setButtonEnabled(enabled)
    end
end

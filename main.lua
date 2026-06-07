-- main.lua

local game_active = false
local dead_state = false
local score = 0
local high_score = 0

local SCREEN_WIDTH = 800
local SCREEN_HEIGHT = 600
local GROUND_Y = 595

local function render_with_outline(text, x, y, font, text_color)
    love.graphics.setFont(font)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(text, x - 2, y)
    love.graphics.print(text, x + 2, y)
    love.graphics.print(text, x, y - 2)
    love.graphics.print(text, x, y + 2)

    love.graphics.setColor(text_color)
    love.graphics.print(text, x, y)
end 

local function check_collision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end 

local Background = {}
Background.__index = Background

function Background.new(image_path, speed)
    local self = setmetatable({}, Background)
    self.img = love.graphics.newImage(image_path)
    self.x1 = 0
    self.x2 = SCREEN_WIDTH
    self.speed = speed
    return self
end 

function Background:update(dt)
    if not game_active then return end
    self.x1 = self.x1 - self.speed * dt
    self.x2 = self.x2 - self.speed * dt

    if self.x1 <= -SCREEN_WIDTH then self.x1 = self.x2 + SCREEN_WIDTH end
    if self.x2 <= -SCREEN_WIDTH then self.x2 = self.x1 + SCREEN_WIDTH end
end 

function Background:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.img, self.x1, 0, 0, SCREEN_WIDTH / self.img:getWidth(), SCREEN_HEIGHT / self.img:getHeight())
    love.graphics.draw(self.img, self.x2, 0, 0, SCREEN_WIDTH / self.img:getWidth(), SCREEN_HEIGHT / self.img:getHeight())
end 

local Bee = {}
Bee.__index = Bee

function Bee.new()
    local self = setmetatable({}, Bee)
    self.wingsUp = love.graphics.newImage("Bumble_1.png")
    self.wingsDown = love.graphics.newImage("Bumble_2.png")
    self.x = 150
    self.y = 200
    self.width = 80
    self.height = 75
    self.velocity = 0
    self.gravity = 1000
    self.jump_strength = -380
    self.anim_timer = 0
    self.use_wings_up = true
    return self
end 

function Bee:reset()
    self.y = 200
    self.velocity = 0
end

function Bee:jump()
    self.velocity = self.jump_strength
end 

function Bee:update(dt)
    if not game_active then
        self.anim_timer = self.anim_timer + dt
        if self.anim_timer > 0.15 then
            self.use_wings_up = not self.use_wings_up
            self.anim_timer = 0
        end
        return
    end

    self.velocity = self.velocity + self.gravity * dt
    self.y = self.y + self.velocity * dt

    if self.y < 0 then
        self.y = 0
        self.velocity = 0
    end

    self.anim_timer = self.anim_timer + dt
    if self.anim_timer > 0.08 then
        self.use_wings_up = not self.use_wings_up
        self.anim_timer = 0
    end
end

function Bee:get_rect()
    return self.x + 18, self.y + 14, self.width - 36, self.height - 28
end 

function Bee:draw()
    love.graphics.setColor(1, 1, 1, 1)
    local current_img = self.use_wings_up and self.wingsUp or self.wingsDown
    local sx = self.width / current_img:getWidth()
    local sy = self.height / current_img:getHeight()
    love.graphics.draw(current_img, self.x, self.y, 0, sx, sy)
end 

local FlowerManager = {}

function FlowerManager.init()
    FlowerManager.short_flower = love.graphics.newImage("flower_1.png")
    FlowerManager.tall_flower = love.graphics.newImage("Flower_2.png")
    FlowerManager.active_flowers = {}
    FlowerManager.spawn_timer = 0
    FlowerManager.current_spawn_interval = 2.3
    FlowerManager.game_speed = 300
end

function FlowerManager.reset()
    FlowerManager.active_flowers = {}
    FlowerManager.spawn_timer = 0
    FlowerManager.current_spawn_interval = 2.3
end 

function FlowerManager.spawn(start_x, is_tall)
    local f = {}
    f.x = start_x 
    f.is_tall = is_tall
    f.passed = false
    f.width = 180
    f.height = is_tall and 500 or 380

    local visual_y_offset = is_tall and 130 or 170
    f.y = (SCREEN_HEIGHT - f.height) + visual_y_offset

    table.insert(FlowerManager.active_flowers, f)
end 

function FlowerManager.update(dt, player)
    if not game_active then return end

    FlowerManager.spawn_timer = FlowerManager.spawn_timer + dt
    if FlowerManager.spawn_timer >= FlowerManager.current_spawn_interval then
        local pick_tall = (love.math.random(0, 1) == 0)
        FlowerManager.spawn(SCREEN_WIDTH + 150, pick_tall)
        
        FlowerManager.current_spawn_interval = 2.0 + love.math.random(0, 50) / 100
        FlowerManager.spawn_timer = 0
    end

    -- Process list backward so we can safely delete objects inside loop execution
    for i = #FlowerManager.active_flowers, 1, -1 do
        local f = FlowerManager.active_flowers[i]
        f.x = f.x - FlowerManager.game_speed * dt

        -- Scoring Boundary
        local px, _, _, _ = player:get_rect()
        if not f.passed and (f.x + 80) < px then
            score = score + 1
            if score > high_score then high_score = score end
            f.passed = true
        end

        -- Cleanup offscreen items
        if f.x + f.width < 0 then
            table.remove(FlowerManager.active_flowers, i)
        end
    end
end

function FlowerManager.draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, f in ipairs(FlowerManager.active_flowers) do
        local current_img = f.is_tall and FlowerManager.tall_flower or FlowerManager.short_flower
        local sx = f.width / current_img:getWidth()
        local sy = f.height / current_img:getHeight()
        love.graphics.draw(current_img, f.x, f.y, 0, sx, sy)
    end
end

function love.load()
    love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT, { fullscreen = false, vsync = true })
    love.window.setTitle("Flappy Bee (Lua Port)")

    font = love.graphics.newFont("OpenSans_Condensed-SemiBoldItalic.ttf", 28)
    large_font = love.graphics.newFont("OpenSans_Condensed-SemiBoldItalic.ttf", 48)

    background = Background.new("background.png", 140)
    player = Bee.new()
    FlowerManager.init()
end 

function love.update(dt)
    if dt > 0.1 then dt = 0.1 end
    
    background:update(dt)
    player:update(dt)
    FlowerManager.update(dt, player)

    if game_active then
        local px, py, pw, ph = player:get_rect()
        
        if check_collision(px, py, pw, ph, 0, GROUND_Y, SCREEN_WIDTH, SCREEN_HEIGHT - GROUND_Y) then
            game_active = false
            dead_state = true
        end

        for _, f in ipairs(FlowerManager.active_flowers) do
            local fx, fy, fw, fh = f.x + 20, f.y + 10, f.width - 40, f.height - 20
            if check_collision(px, py, pw, ph, fx, fy, fw, fh) then
                game_active = false
                dead_state = true
            end
        end
    end
end 

function love.keypressed(key)
    if key == "space" then
        if not game_active and not dead_state then
            score = 0
            player:reset()
            FlowerManager.reset()
            game_active = true
        elseif dead_state then
            dead_state = false
            score = 0;
            player:reset()
            FlowerManager.reset()
            game_active = true
        else
            player:jump()
        end
    end
end

function love.draw()
    background:draw()
    FlowerManager.draw()
    player:draw()

    if not game_active and not dead_state then
        render_with_outline("FLAPPY BEE", 290, 180, large_font, {1, 0.84, 0, 1})
        render_with_outline("PRESS SPACE TO START AND FLAP", 240, 260, font, {1, 1, 1, 1})
        render_with_outline("HIGH SCORE: " .. tostring(high_score), 325, 340, font, {0.78, 0.78, 0.78, 1})
    elseif dead_state then 
        render_with_outline("GAME OVER", 300, 180, large_font, {0.86, 0.08, 0.23, 1})
        render_with_outline("FINAL SCORE: " .. tostring(score), 325, 250, font, {1, 1, 1, 1})
        render_with_outline("BEST DISTANCE: " .. tostring(high_score), 315, 290, font, {1, 0.84, 0, 1})
        render_with_outline("PRESS SPACE TO TRY AGAIN", 270, 370, font, {0.78, 0.78, 0.78, 1})
    else 
        render_with_outline("Score: " ..tostring(score), 25, 20, font, {1, 1, 1, 1})
    end
end 
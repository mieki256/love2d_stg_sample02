-- love2d STG sample 02
-- Last updated: <2018/04/29 06:06:13 +0900>
--
-- how to play
-- WASD or cursor : move
-- Z   : Toggle change gun angle
-- F11 : Toggle fullscreen mode
-- F10 : Toggle using palette change shader
-- F9  : Toggle blend mode when drawing bullets
-- P   : Pause
-- ESC : Exit to game
--
-- Author : mieki256
-- License : main.lua ... CC0 / Public Domain
--           (use sti library ... MIT/X11 Open Source License)

local sti = require "sti"

-- work
player_bullets = {}
enemys = {}
enemy_bullets = {}
explosions = {}
explosions_top = {}
sounds = {}

angle_change_key = false
pause_fg = false
palette_shader_enable = true
bullet_blend_mode_add = true

scr_flash = 0
scr_flash_duration = 0.7
scr_flash_kind = 0

function setFlash(duration, kind)
  scr_flash_kind = kind or 0
  scr_flash_duration = duration or 0.7
  scr_flash = scr_flash_duration
end

function playSe(name)
  local src = sounds[name].src
  if src:isPlaying() then src:stop() end
  src:play()
end

function playSeExplosion()
  playSe("se_explo")
end

-- define explosion effect class
Explosion = {}
Explosion.new = function(x, y, img, quads, duration, scale)
  local obj = {
    activate = true, x = x, y = y, img = img, quads = quads,
    timer = 0, ox = 128 / 2, oy = 128 / 2
  }
  obj.ang = math.random(360)
  obj.duration = duration or 0.6
  obj.scale = scale or (math.random(100, 200) / 100)
  setmetatable(obj, {__index = Explosion})
  return obj
end

Explosion.update = function(self, dt)
  self.timer = self.timer + dt
  if self.timer >= self.duration then self.activate = false end
end

Explosion.draw = function(self)
  local n = math.floor(self.timer / self.duration * #self.quads) + 1
  n = math.min(n , #self.quads)
  love.graphics.setColor(1.0, 1.0, 1.0)
  love.graphics.draw(self.img, self.quads[n], self.x, self.y,
                     math.rad(self.ang), self.scale, self.scale, self.ox, self.oy)
end

function bornExplosion(x, y, w, h, pri_fg)
  local draw_top = pri_fg or false
  local sw = w or 24
  local sh = h or 24
  for j=0,2 do
    local sx = x + math.random(-sw, sw)
    local sy = y + math.random(-sh, sh)
    local obj = Explosion.new(sx, sy, explo_img, explo_quads)
    if draw_top then
      table.insert(explosions_top, obj)
    else
      table.insert(explosions, obj)
    end
  end
end

-- define explosion ring effect class
ExplosionRing = {}
ExplosionRing.new = function(x, y, img, duration, r, g, b, scale, ratio)
  local obj = {
    activate = true, x = x, y = y,
    img = img, timer = 0
  }
  obj.ang = math.random(-45, 45)
  obj.duration = duration or 0.75
  obj.r = r or 1.0
  obj.g = g or 1.0
  obj.b = b or 1.0
  obj.last_scale = scale or 1.0
  obj.ratio = ratio or 1.0
  obj.ox = obj.img:getWidth() / 2
  obj.oy = obj.img:getHeight() / 2
  setmetatable(obj, {__index = ExplosionRing})
  return obj
end

ExplosionRing.update = function(self, dt)
  self.timer = self.timer + dt
  if self.timer >= self.duration then self.activate = false end
end

ExplosionRing.draw = function(self)
  local d = self.timer / self.duration
  local alpha = 1.0 - d
  -- local scale = 2.0 * (-math.pow( 2, -10 * self.timer / self.duration ) + 1)
  d = d - 1.0
  local scale = self.last_scale * (d * d * d + 1.0)
  love.graphics.setColor(self.r, self.g, self.b, alpha)
  love.graphics.setBlendMode("add")
  love.graphics.draw(self.img, self.x, self.y,
                     math.rad(self.ang), scale, scale * self.ratio,
                     self.ox, self.oy)
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
end

function bornExplosionRing(x, y, duration, r, g, b, scale, ratio)
  local dur = duration or 0.75
  local lscale = scale or 1.0
  local lratio = ratio or 1.0
  local cr = r or 1.0
  local cg = g or 1.0
  local cb = b or 1.0
  local obj = ExplosionRing.new(x, y, flash_img, dur, cr, cg, cb, lscale, lratio)
  table.insert(explosions, obj)
end

-- define player class
Player = {}
Player.new = function(x, y, img_a, img_b)
  local obj = {}
  obj.step = 0
  obj.timer = 0
  obj.activate = true
  obj.bg_hit_id = 0
  obj.enemy_hit = false
  obj.hit_enable = true
  obj.deading = false
  obj.blink = 0
  obj.speed = 300
  obj.x = x
  obj.y = y
  obj.scale = 1.0
  obj.gun_angle = -90
  obj.gun_angle_change_mode = false
  obj.demo = false
  obj.tx = 0
  obj.ty = 0
  obj.tscale = 1.0
  obj.start_x = 0
  obj.start_y = 0
  obj.start_scale = 1.0
  obj.duration = 0
  obj.shot_timer = 0
  obj.img_a = img_a
  obj.img_b = img_b
  obj.w = img_a:getWidth()
  obj.h = img_a:getHeight()
  obj.ox = obj.w / 2
  obj.oy = obj.h / 2
  setmetatable(obj, {__index = Player})
  return obj
end

Player.move = function(self, dt)
  if angle_change_key then
    self.gun_angle_change_mode = not(self.gun_angle_change_mode)
    angle_change_key = false
  end

  -- key check
  local ang = -1
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    ang = 180
  elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    ang = 0
  end
  if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
    if ang < 0 then ang = 270
    elseif ang == 0 then ang = 270 + 45
    else ang = 180 + 45
    end
  elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
    if ang < 0 then ang = 90
    elseif ang == 0 then ang = 45
    else ang = 180 - 45
    end
  end

  if ang >= 0 then
    local spd = self.speed * dt
    local ra = math.rad(ang)
    self.x = self.x + (spd * math.cos(ra))
    self.y = self.y + (spd * math.sin(ra))

    if self.gun_angle_change_mode then
      -- gun angle change
      local tgt_ang = (ang + 180) % 360
      if self.gun_angle ~= tgt_ang then
        local a = (tgt_ang - self.gun_angle) % 360
        if a > 180 then a = a - 360 end
        local spd = 45 / 6
        if a > 0 then
          if a < spd then
            self.gun_angle = tgt_ang
          else
            self.gun_angle = (self.gun_angle + spd) % 360
          end
        elseif a < 0 then
          if a > -spd then
            self.gun_angle = tgt_ang
          else
            self.gun_angle = (self.gun_angle - spd) % 360
          end
        end
      end
    end
  end
end

Player.update = function(self, dt)
  if not self.activate then return end

  if not self.deading then
    -- hit check
    if self.hit_enable and (self.bg_hit_id > 1 or self.enemy_hit) then
      self.deading = true
      self.hit_enable = false
      self.timer = 0
      self.duration = 2.0
      setFlash(0.7, 1)
      bornExplosion(self.x, self.y, 16, 16)
      bornExplosionRing(self.x, self.y, 0.9, 0, 128, 255, 1.0, 0.2)
      bornExplosionRing(self.x, self.y, 0.6, 0, 200, 255, 1.6, 0.4)
      bornExplosionRing(self.x, self.y, 0.3, 0, 255, 255, 2.0, 0.6)
      playSe("se_explo2")
    else
      if self.demo then
        -- demo. reborn move
        self.timer = self.timer + dt
        if self.timer >= self.duration then
          -- demo end
          self.demo = false
          self.duration = 3.0
          self.timer = 0
          self.blink_enable = true
          self.x = self.tx
          -- self.y = self.ty
          self.scale = self.tscale
        else
          local d = self.timer / self.duration
          local t = d - 1
          local w = self.tx - self.start_x
          self.x = -w * d * (d - 2) + self.start_x
          self.y = -1800 * d + 0.5 * 3200 * d * d + self.start_y
          local s = self.tscale - self.start_scale
          self.scale = -s * d * (d - 2) + self.start_scale
        end
      else
        if self.blink_enable then
          -- invincible move
          self.timer = self.timer + dt
          if self.timer >= self.duration then
            self.blink_enable = false
            self.hit_enable = true
            self.enemy_hit = false
          end
        end

        -- normal move
        self:move(dt)

        if not stage_clear_fg then
          self.shot_timer = self.shot_timer + dt
          local chktime = 0.1
          if self.shot_timer >= chktime then
            self.shot_timer = self.shot_timer - chktime
            born_player_bullet(self.x, self.y, self.gun_angle)
          end
        else
          self.shot_timer = 0
        end
      end
    end
  else
    -- deading
    self.timer = self.timer + dt
    if self.timer >= self.duration then
      -- set reborn
      self.deading = false
      self.demo = true
      self.timer = 0
      self.duration = 1.0
      self.tx = scr_w * 0.5
      self.ty = scr_h * 0.8
      self.tscale = 1.0
      self.start_x = scr_w * 0.2
      self.start_y = self.ty + 200
      self.start_scale = 2.5
      self.x = self.start_x
      self.y = self.start_y
      self.scale = self.start_scale
      playSe("se_jet")
    end
  end

  -- move area check
  if not self.demo then
    local xmin, ymin = self.ox, self.oy
    local xmax, ymax = scr_w - self.ox, scr_h - self.oy
    self.x = math.min(math.max(self.x, xmin), xmax)
    self.y = math.min(math.max(self.y, ymin), ymax)
  end

end

Player.draw = function(self)
  if not self.activate then return end
  local ang = math.rad(math.floor(self.gun_angle))
  local scale = 1.0

  if not self.deading then
    local fg = true
    if self.blink_enable then
      self.blink = self.blink + 1
      if math.floor(self.blink / 2) % 2 == 0 then fg = true else fg = false end
    end
    if fg then
      love.graphics.setColor(1.0, 1.0, 1.0)
      love.graphics.draw(self.img_a, self.x, self.y,
                         0, self.scale, self.scale, self.ox, self.oy)
      love.graphics.draw(self.img_b, self.x, self.y,
                         ang, self.scale, self.scale, self.ox, self.oy)
    end
  end
end

-- define player bullet explosion class
BulletExplosion = {}
BulletExplosion.new = function(x, y, img, quads, duration)
  local obj = {
    activate = true, x = x, y = y,
    img = img, quads = quads, timer = 0
  }
  obj.ang = math.random(360)
  obj.duration = duration or (1 / 60 * 7 * 3)
  obj.w, obj.h = 64, 64
  obj.ox, obj.oy = obj.w / 2, obj.h / 2
  setmetatable(obj, {__index = BulletExplosion})
  return obj
end

BulletExplosion.update = function(self, dt)
  self.y = self.y + bg_diff_y
  self.timer = self.timer + dt
  if self.timer >= self.duration then self.activate = false end
end

BulletExplosion.draw = function(self)
  local n = math.floor(self.timer / self.duration * #self.quads) + 1
  love.graphics.setBlendMode("add")
  love.graphics.draw(self.img, self.quads[n], self.x, self.y,
                     math.rad(self.ang), 1.0, 1.0, self.ox, self.oy)
  love.graphics.setBlendMode("alpha")
end

function born_bullet_explosion(x, y)
  local obj = BulletExplosion.new(x, y,
                                  bulletexplo_img, bulletexplo_quads)
  table.insert(explosions, obj)
end

-- define player bullet class
PlayerBullet = {}
PlayerBullet.new = function(x, y, ang, img)
  local obj = {
    speed = 600, activate = true,
    x = x, y = y, ang = ang, img = img,
    hit_enemy = false
  }
  obj.w, obj.h = img:getWidth(), img:getHeight()
  obj.ox, obj.oy = obj.w / 2, obj.h / 2
  setmetatable(obj, {__index = PlayerBullet})
  return obj
end

PlayerBullet.update = function(self, dt)
  if self.hit_enemy then
    self.activate = false
  else
    local ra = math.rad(self.ang)
    local d = self.speed * dt
    self.x = self.x + (math.cos(ra) * d)
    self.y = self.y + (math.sin(ra) * d)

    local x, y = self.x, self.y
    local xmin, ymin = -self.ox, -self.oy
    local xmax, ymax = scr_w + self.ox, scr_h + self.oy
    if x < xmin or x > xmax or y < ymin or y > ymax then
      self.activate = false
    else
      local bg_id = map:getGid(self.x, self.y)
      if bg_id > 1 then
        self.activate = false
        born_bullet_explosion(self.x, self.y)
      end
    end
  end
end

PlayerBullet.draw = function(self)
  love.graphics.draw(self.img, self.x, self.y,
                     math.rad(self.ang), 1.0, 1.0, self.ox, self.oy)
end

function born_player_bullet(x, y, ang)
  ang = ang + math.random(-20, 20) / 10
  local obj = PlayerBullet.new(x, y, ang, bullet_img, bullet_quads)
  table.insert(player_bullets, obj)
end

-- define enemy bullet class
EnemyBullet = {}
EnemyBullet.new = function(x, y, spd, ang, ang_spd, img, quads, duration)
  local obj = {
    speed = spd, disp_ang = 0, ang_spd = ang_spd,
    activate = true, x = x, y = y, ang = ang,
    img = img, quads = quads, timer = 0
  }
  obj.w, obj.h = 16, 16
  obj.ox, obj.oy = obj.w / 2, obj.h / 2
  obj.duration = duration or (1 / 60 * 8)
  setmetatable(obj, {__index = EnemyBullet})
  return obj
end

EnemyBullet.update = function(self, dt)
  local ra = math.rad(self.ang)
  local d = self.speed * dt
  self.x = self.x + (math.cos(ra) * d)
  self.y = self.y + (math.sin(ra) * d)

  self.disp_ang = self.disp_ang + self.ang_spd * dt

  self.timer = self.timer + dt
  if self.timer >= self.duration then
    self.timer = self.timer - self.duration
  end

  local xmin, ymin = -self.ox, -self.oy
  local xmax, ymax = scr_w + self.ox, scr_h + self.oy
  if self.x < xmin or self.x > xmax or self.y < ymin or self.y > ymax then
    self.activate = false
  else
    local bg_id = map:getGid(self.x, self.y)
    if bg_id > 1 then
      self.activate = false
      born_bullet_explosion(self.x, self.y)
    end
  end
end

EnemyBullet.draw = function(self)
  local n = math.floor(self.timer / self.duration * #self.quads) % #self.quads + 1
  love.graphics.draw(self.img, self.quads[n], self.x, self.y,
                     math.rad(self.disp_ang), 1.0, 1.0, self.ox, self.oy)
end

function born_zako_enemy_bullet(x, y)
  local dx = player.x - x
  local dy = player.y - y
  local dd = scr_h / 3
  if dx * dx + dy * dy > dd * dd then
    local spd = 160
    local ang = math.deg(math.atan2(dy, dx))
    local obj = EnemyBullet.new(x, y, spd, ang, 0,
                                enemybullet_img, enemybullet_quads)
    table.insert(enemy_bullets, obj)
    return true
  end
  return false
end

function born_zako_enemy_bullet_with_angle(x, y, ang)
  local spd = 160
  local obj = EnemyBullet.new(x, y, spd, ang, 0,
                              enemybullet_img, enemybullet_quads)
  table.insert(enemy_bullets, obj)
  return true
end

-- define enemy class
Enemy = {}
Enemy.new = function(x, y, dx, dy, xw, ang, angspd, img)
  local obj = {
    activate = true, x = x, y = y, dx = dx, dy = dy, bx = x, by = y,
    xw = xw, ang = ang, angspd = angspd, img = img,
    hit_bullet = false, shot_interval = 2.0
  }
  obj.shot_timer = obj.shot_interval
  obj.w, obj.h = img:getWidth(), img:getHeight()
  obj.ox, obj.oy = obj.w / 2, obj.h / 2
  obj.collsion_r = obj.ox - 2
  setmetatable(obj, {__index = Enemy})
  return obj
end

Enemy.update = function(self, dt)
  if self.hit_bullet then
    self.activate = false
    bornExplosion(self.x, self.y, 24, 24)
    bornExplosionRing(self.x, self.y)
    playSeExplosion()
  else
    self.ang = (self.ang + self.angspd * dt) % 360.0
    self.bx = self.bx + self.dx * dt
    self.y = self.y + self.dy * dt
    self.x = self.bx + self.xw * math.sin(math.rad(self.ang))
    if self.y - self.h > scr_h then
      self.activate = false
    else
      self.shot_timer = self.shot_timer - dt
      if self.shot_timer <= 0 then
        if born_zako_enemy_bullet(self.x, self.y) then
          self.shot_timer = self.shot_interval
        end
      end
    end
  end
end

Enemy.draw = function(self)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.draw(self.img, self.x, self.y, math.rad(self.ang),
                     1.0, 1.0, self.ox, self.oy)
end

Enemy.check = function(self, x, y)
  if self.activate then
    local dw = math.floor(self.x - x)
    local dh = math.floor(self.y - y)
    local dd = self.collsion_r
    if dw * dw + dh * dh <= dd * dd then return true end
  end
  return false
end

function bornZakoEnemy(x, y)
  local dx = 0
  local dy = 100
  local xw = 64
  local ang = math.random(360)
  local angspd = 240
  local obj = Enemy.new(x, y, dx, dy, xw, ang, angspd, enemy_img)
  table.insert(enemys, obj)
end

-- define Beam class
Beam = {}
Beam.new = function(x, y, img, angle, speed)
  local obj = {
    activate = true, bx = x, by = y, img = img,
    angle = angle, speed = speed,
    collsion_r = 16, hit_bullet = false
  }
  obj.x = x - bg_a_x
  obj.y = y - bg_a_y
  obj.ox = img:getWidth() / 2
  obj.oy = img:getHeight() / 2
  setmetatable(obj, {__index = Beam})
  return obj
end

Beam.update = function(self, dt)
  local spd = self.speed * dt
  local radv = math.rad(self.angle)
  self.bx = self.bx + spd * math.cos(radv)
  self.by = self.by + spd * math.sin(radv)
  self.x = self.bx - bg_a_x
  self.y = self.by - bg_a_y

  local bg_id = map:getGid(self.x, self.y)
  if bg_id > 1 or self.y - self.oy > scr_h then
    self.activate = false
    born_bullet_explosion(self.x, self.y)
  elseif self.y - self.oy > scr_h then
    self.activate = false
  end
end

Beam.draw = function(self)
  local x = math.floor(self.bx - bg_a_x)
  local y = math.floor(self.by - bg_a_y)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.draw(self.img, x, y, math.rad(self.angle), 1.0, 1.0, self.ox, self.oy)
end

Beam.check = function(self, x, y)
  if self.activate then
    local dw = math.floor(self.x - x)
    local dh = math.floor(self.y - y)
    local dd = self.collsion_r
    if dw * dw + dh * dh <= dd * dd then return true end
  end
  return false
end

function bornBeam(x, y, angle, speed)
  local obj = Beam.new(x, y, beam_img, angle, speed)
  table.insert(enemys, obj)
end

-- define EnemyLargeCanon class
EnemyLargeCanon = {}
EnemyLargeCanon.new = function(x, y, img, angle)
  local obj = {
    activate = true, bx = x, by = y, img = img,
    angle = angle, timer = 0,
    collsion_r = 48, hit_bullet = false, life = 8, flash_timer = 0
  }
  obj.x = x - bg_a_x
  obj.y = y - bg_a_y
  obj.ox = img:getWidth() / 2
  obj.oy = img:getHeight() / 2
  setmetatable(obj, {__index = EnemyLargeCanon})
  return obj
end

EnemyLargeCanon.update = function(self, dt)
  self.x = self.bx - bg_a_x
  self.y = self.by - bg_a_y

  if self.flash_timer > 0 then
    self.flash_timer = self.flash_timer - 1
  end

  if self.hit_bullet then
    self.life = self.life - 1
    self.flash_timer = 1
    self.hit_bullet = false
    if self.life <= 0 then
      self.activate = false
      bornExplosion(self.x, self.y, 24, 24)
      bornExplosionRing(self.x, self.y)
      playSeExplosion()
    end
  end

  if self.activate then
    self.timer = self.timer + dt
    local t = 0.8
    if self.timer >= t then
      self.timer = self.timer - t
      local radv = math.rad(self.angle)
      local d = 48
      local x = self.bx + d * math.cos(radv)
      local y = self.by + d * math.sin(radv)
      bornBeam(x, y, self.angle, 320)
    end

    if self.y - self.oy > scr_h then
      self.activate = false
    end
  end
end

EnemyLargeCanon.draw = function(self)
  local x = math.floor(self.bx - bg_a_x)
  local y = math.floor(self.by - bg_a_y)
  if self.flash_timer > 0 then
    love.graphics.setColor(1.0, 0, 0, 1.0)
  else
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  end
  love.graphics.draw(self.img, x, y, math.rad(self.angle), 1.0, 1.0, self.ox, self.oy)
end

EnemyLargeCanon.check = function(self, x, y)
  if self.activate then
    local dw = math.floor(self.x - x)
    local dh = math.floor(self.y - y)
    local dd = self.collsion_r
    if dw * dw + dh * dh <= dd * dd then return true end
  end
  return false
end

-- define EnemyBlock class
EnemyBlock = {}
EnemyBlock.new = function(x, y, img, angle, speed)
  local obj = {
    activate = true, bx = x, by = y, img = img,
    angle = angle, speed = speed,
    collsion_r = 32, hit_bullet = false, life = 10, flash_timer = 0
  }
  obj.x = x - bg_a_x
  obj.y = y - bg_a_y
  obj.ox = img:getWidth() / 2
  obj.oy = img:getHeight() / 2
  setmetatable(obj, {__index = EnemyBlock})
  return obj
end

EnemyBlock.update = function(self, dt)
  if self.flash_timer > 0 then
    self.flash_timer = self.flash_timer - 1
  end

  if self.hit_bullet then
    self.life = self.life - 1
    self.flash_timer = 1
    self.hit_bullet = false
    if self.life <= 0 then
      self.activate = false
      bornExplosion(self.x, self.y, 24, 24)
      bornExplosionRing(self.x, self.y)
      playSeExplosion()
    end
  end

  if self.activate then
    local spd = self.speed * dt
    local radv = math.rad(self.angle)
    local dx = math.cos(radv)
    local dy = math.sin(radv)
    self.bx = self.bx + spd * dx
    self.by = self.by + spd * dy
    self.x = self.bx - bg_a_x
    self.y = self.by - bg_a_y

    local x = self.x + 32 * dx
    local y = self.y + 32 * dy
    if map:getGid(x, y) > 1 then
      self.angle = (self.angle + 180) % 360
    end

    if self.y - self.oy > scr_h then
      self.activate = false
    end
  end
end

EnemyBlock.draw = function(self)
  local x = math.floor(self.bx - bg_a_x)
  local y = math.floor(self.by - bg_a_y)
  if self.flash_timer > 0 then
    love.graphics.setColor(1.0, 0, 0, 1.0)
  else
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  end
  love.graphics.draw(self.img, x, y, 0, 1.0, 1.0, self.ox, self.oy)
end

EnemyBlock.check = function(self, x, y)
  if self.activate then
    local dw = math.floor(self.x - x)
    local dh = math.floor(self.y - y)
    local dd = self.collsion_r
    if dw * dw + dh * dh <= dd * dd then return true end
  end
  return false
end

-- define enemy boss class
EnemyBoss = {}
EnemyBoss.new = function(img, dispdata)
  local obj = {}
  obj.activate = true
  obj.img = img
  obj.dispdata = dispdata
  obj.x = scr_w / 2
  obj.y = -obj.img:getHeight()
  obj.bx = obj.x
  obj.by = 0
  obj.step = 0
  obj.hit_enable = false
  obj.hit_bullet = false
  obj.x_ang = 0
  obj.y_ang = 0
  obj.ring_ang = 0
  obj.hp_init = 15 * 6
  obj.hp = obj.hp_init
  obj.damage_wait = 0
  obj.damage_wait_init = 6 * 1 / 60
  -- obj.damage_wait_init = 1.0
  obj.gun_l_ang = math.rad(90)
  obj.gun_r_ang = math.rad(90)
  obj.timer = 0
  obj.shot_timer = 0
  obj.shot_interval = 2.0
  setmetatable(obj, {__index = EnemyBoss})
  return obj
end

EnemyBoss.update = function(self, dt)
  local hpdiv = 1.0 - (self.hp / self.hp_init)
  self.ring_ang = self.ring_ang + (20 + 340 * hpdiv) * dt

  if self.step == 0 then
    if self.y < 160 then
      self.y = self.y + 120 * dt
    else
      self.hit_enable = true
      self.by = self.y
      self.step = 1
    end
  elseif self.step == 1 or self.step == 2 then

    if self.step == 1 then
      -- move
      self.x_ang = self.x_ang + (90 + 220 * hpdiv) * dt
      self.y_ang = self.y_ang + (200 + 100 * hpdiv) * dt
      local w = 100
      local h = 32 + 96 * hpdiv
      self.x = self.bx + w * math.sin(math.rad(self.x_ang))
      self.y = self.by + h * math.sin(math.rad(self.y_ang))
    end

    -- get gun position
    local v = self.dispdata[4]
    local gun0_x = self.x + v.px
    local gun0_y = self.y + v.py

    v = self.dispdata[5]
    local gun1_x = self.x + v.px
    local gun1_y = self.y + v.py

    if self.step == 1 then
      -- set gun angle
      local gun0_dx = player.x - gun0_x
      local gun0_dy = player.y - gun0_y
      local gun1_dx = player.x - gun1_x
      local gun1_dy = player.y - gun1_y
      self.gun_l_ang = math.atan2(gun0_dy, gun0_dx)
      self.gun_r_ang = math.atan2(gun1_dy, gun1_dx)

      self.shot_timer = self.shot_timer + dt
      if self.shot_timer >= self.shot_interval then
        self.step = 2
        self.shot_timer = self.shot_timer - self.shot_interval
        self.shot_timer = self.shot_timer - 0.8
        playSe("se_boss_shot")
      end
    elseif self.step == 2 then
      self.shot_timer = self.shot_timer + dt
      if self.shot_timer >= 0 then
        -- exit firing
        self.step = 1
        self.shot_timer = 0
      else
        -- firing
        self.timer = self.timer + dt
        local chktime = 5 * 1 / 60
        if self.timer >= chktime then
          self.timer = self.timer - chktime
          local r = 40
          local x0 = gun0_x + r * math.cos(self.gun_l_ang)
          local y0 = gun0_y + r * math.sin(self.gun_l_ang)
          local x1 = gun1_x + r * math.cos(self.gun_r_ang)
          local y1 = gun1_y + r * math.sin(self.gun_r_ang)
          local ang0 = math.deg(self.gun_l_ang)
          local ang1 = math.deg(self.gun_r_ang)
          born_zako_enemy_bullet_with_angle(x0, y0, ang0)
          born_zako_enemy_bullet_with_angle(x1, y1, ang1)
        end
      end
    end

    if self.damage_wait > 0 then
      self.damage_wait = self.damage_wait - dt
      if self.damage_wait <= 0 then
        self.hit_enable = true
        self.damage_wait = 0
      else
        self.hit_enable = false
      end
    else
      if self.hit_bullet then
        self.hit_bullet = false
        self.hp = self.hp - 1
        if self.hp > 0 then
          self.damage_wait = self.damage_wait_init
        else
          -- dead
          self.step = 3
          self.hp = 0
          self.hit_enable = false
          self.bx = self.x
          self.by = self.y
          self.timer = 3.0
          self.shot_timer = 0
          self.damage_wait = 0
          clearAllEnemyBullets()
          bgm:setFadeout(3.0)
        end
      end
    end

  elseif self.step == 3 then
    -- dead demo
    self.timer = self.timer - dt
    if self.timer > 0 then
      local d = 6
      self.x = self.bx + math.random(-d, d)
      self.y = self.by + math.random(-d, d)

      self.shot_timer = self.shot_timer + dt
      local chktime = 0.15
      if self.shot_timer >= chktime then
        self.shot_timer = self.shot_timer - chktime
        bornExplosion(self.bx, self.by, 160, 90, true)
        playSeExplosion()
      end
    else
      self.activate = false
      self.timer = 0
      for i=1,4 do
        bornExplosion(self.bx, self.by, 160, 90, true)
      end
      bornExplosionRing(self.bx, self.by, 1.2, 255, 255, 255, 3.5, 1.0)
      playSe("se_boss_dead")
      setFlash(2.5, 0)
      stage_clear_fg = true
    end
  end
end

EnemyBoss.draw = function(self)
  local shake_x, shake_y = 0, 0
  if self.damage_wait > 0 then
    local a = 1.0 - (self.damage_wait / self.damage_wait_init)
    love.graphics.setColor(1.0, a, a, 1.0)
    shake_x = math.random(-2, 2)
    shake_y = math.random(-2, 2)
  else
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  end

  for i, v in ipairs(self.dispdata) do
    local name = v.name
    local x = self.x + v.px + shake_x
    local y = self.y + v.py + shake_y
    local quad = v.quad
    local ang = 0
    if name == "corering" then
      ang = math.rad(self.ring_ang)
    elseif name == "gun_l" then
      ang = self.gun_l_ang
    elseif name == "gun_r" then
      ang = self.gun_r_ang
    end
    love.graphics.draw(self.img, quad, x, y, ang, 1.0, 1.0, v.ox, v.oy)
  end
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
end

EnemyBoss.check = function(self, x, y)
  if self.activate and self.hit_enable and self.damage_wait <= 0 then
    local dd = 32
    local dw = math.floor(self.x - x)
    local dh = math.floor(self.y - y)
    if dw * dw + dh * dh <= dd * dd then return true end
  end
  return false
end

-- born enemy
function bornEnemy(bg_x, bg_y)
  while born_enemy_index <= #enemy_set_tbl do
    local tbl = enemy_set_tbl[born_enemy_index]
    if bg_y - 64 > tbl.y then break end

    local obj = nil
    if tbl.name == "canon" then
      -- canon
      local ang = tonumber(tbl.type)
      obj = EnemyLargeCanon.new(tbl.x, tbl.y, canon_img, ang)
    elseif tbl.name == "block" then
      -- block
      local ang = tonumber(tbl.type)
      local spd = tbl.properties["speed"]
      obj = EnemyBlock.new(tbl.x, tbl.y, block_img, ang, spd)
    elseif tbl.name == "zako" then
      -- zako ufo
      local x, y = tbl.x - bg_x, tbl.y - bg_y
      local dx, dy = 0, 100
      local xw = 64
      local ang = math.random(360)
      local angspd = 240
      obj = Enemy.new(x, y, dx, dy, xw, ang, angspd, enemy_img)
    end
    table.insert(enemys, obj)
    born_enemy_index = born_enemy_index + 1
  end
end

-- define BGM control class

BgmControl = {}
BgmControl.new = function()
  local obj = {}
  obj.step = 0
  obj.src = nil
  obj.next_bgm = ""
  obj.fadeout = false
  obj.vol = 0
  obj.vol_init = 0
  obj.duration = 1.0
  obj.timer = 0

  obj.update = function(self, dt)
    if self.step == 0 then
      if self.next_bgm ~= "" or self.fadeout then
        if self.vol > 0 then
          self.step = 1
          self.fadeout = false
          self.timer = 0
        else
          self.step = 2
        end
      end
    elseif self.step == 1 then
      if self.vol > 0 then
        self.timer = self.timer + dt
        if self.timer >= self.duration then
          self.vol = 0
          self.step = 2
        else
          self.vol = (1.0 - self.timer / self.duration) * self.vol_init
          self.vol = math.max(math.min(self.vol, 1.0), 0.0)
        end
        self.src:setVolume(self.vol)
        if self.vol == 0 then self.src:stop() end
      else
        self.step = 2
      end
    elseif self.step == 2 then
      if self.next_bgm == "" then
        self.step = 0
      else
        local snd = sounds[self.next_bgm]
        self.src = snd.src
        self.vol_init = snd.vol
        self.vol = self.vol_init
        self.src:setVolume(self.vol)
        if self.src:isPlaying() then self.src:stop() end
        self.src:play()
        self.next_bgm = ""
        self.step = 0
      end
    end
  end

  obj.setNextBgm = function(self, next_bgm, duration)
    self.next_bgm = next_bgm
    self.duration = duration or 3.0
  end

  obj.setFadeout = function(self, duration)
    self.fadeout = true
    self.duration = duration or 3.0
  end

  return obj
end

-- get quads
function getQuads(img, w, h)
  local sw, sh = img:getDimensions()
  local quads = {}
  for y=0, sh - h, h do
    for x=0, sw - w, w do
      table.insert(quads, love.graphics.newQuad(x, y, w, h, sw, sh))
    end
  end
  return quads
end

function getQuadsCustom(img, poslist)
  local sw, sh = img:getDimensions()
  local quads = {}
  for i,v in ipairs(poslist) do
    local qd = love.graphics.newQuad(v.x, v.y, v.w, v.h, sw, sh)
    local data = {
      name = v.name, quad = qd,
      w = v.width, h = v.height,
      ox = v.ox, oy = v.oy,
      px = v.px, py = v.py
    }
    table.insert(quads, data)
  end
  return quads
end

function updateSprites(objs, dt)
  for i, spr in ipairs(objs) do
    if spr.activate then
      spr:update(dt)
    end
  end
end

function removeSprites(objs)
  local elen = #objs
  for i=elen,1,-1 do
    if not objs[i].activate then
      table.remove(objs, i)
    end
  end
end

function clearAllObjs(objs)
  local elen = #objs
  for i=elen,1,-1 do
    table.remove(objs, i)
  end
end

function clearAllEnemyBullets()
  clearAllObjs(enemy_bullets)
end

function clearAllPlayerBullets()
  clearAllObjs(player_bullets)
end

function drawSprites(tbl)
  for i, spr in ipairs(tbl) do
    if spr.activate then spr:draw() end
  end
end

-- ============================================================
-- init
function love.load()

  love.setDeprecationOutput(true)
  
  -- set filter
  love.graphics.setDefaultFilter("nearest", "nearest")

  -- define screen size
  scr_w = 640
  scr_h = 480
  canvas = love.graphics.newCanvas(scr_w, scr_h)
  fullscreen_fg = false

  -- load image
  player_img_a = love.graphics.newImage("images/airplane_05_48x48_000.png")
  player_img_b = love.graphics.newImage("images/airplane_05_48x48_001.png")
  bullet_img = love.graphics.newImage("images/airplane_05_48x48_002.png")

  bulletexplo_img = love.graphics.newImage("images/flash5_64x64x4x2.png")
  enemy_img = love.graphics.newImage("images/enemy03_48x48.png")
  explo_img = love.graphics.newImage("images/explosion1.png")
  flash_img = love.graphics.newImage("images/ring03_512x512.png")
  enemybullet_img = love.graphics.newImage("images/enemy_bullet04.png")
  enemyboss_img = love.graphics.newImage("images/enemy_boss01_448x256_all.png")
  canon_img = love.graphics.newImage("images/enemy_large_canon.png")
  block_img = love.graphics.newImage("images/enemy_block_64x64_01.png")
  beam_img = love.graphics.newImage("images/enemy_beam01_64x64.png")

  -- make Quad (split texture)
  bulletexplo_quads = getQuads(bulletexplo_img, 64, 64)
  explo_quads = getQuads(explo_img, 160, 160)
  enemybullet_quads = getQuads(enemybullet_img, 16, 16)

  enemyboss_quads_list = {
    {name = "base", x = 0, y = 0, w = 448, h = 256, ox = 224, oy = 160, px = 0, py = 0 },
    {name = "core", x = 448, y = 0, w = 64, h = 64, ox = 32, oy = 32, px = 0, py = 0 },
    {name = "corering", x = 448, y = 64, w = 64, h = 64, ox = 32, oy = 32, px = 0, py = 0 },
    {name = "gun_l", x = 448, y = 128, w = 64, h = 64, ox = 22, oy = 32, px = -104, py = 16 },
    {name = "gun_r", x = 448, y = 128, w = 64, h = 64, ox = 22, oy = 32, px = 104, py = 16 }
  }
  enemyboss_quads = getQuadsCustom(enemyboss_img, enemyboss_quads_list)

  -- load tilemap
  map = sti("bg/mecha_bg2_map.lua")

  map.getGidByPixel = function(self, x, y, layerindex)
    local tilex, tiley = self:convertPixelToTile(math.floor(x), math.floor(y))
    tilex, tiley = math.floor(tilex), math.floor(tiley)
    local layer = map.layers[layerindex]
    local tilew, tileh = layer.width, layer.height
    local gid = -2
    if tilex >= 0 and tiley >= 0 and tilex < tilew and tiley < tileh then
      local tile = layer.data[tiley + 1][tilex + 1]
      if tile == nil then
        gid = -1
      else
        gid = tile.gid
      end
    end
    return gid
  end

  map.getGid = function(self, x, y)
    x = x + bg_a_x
    y = y + bg_a_y
    return map:getGidByPixel(x, y, "bg_a")
  end

  -- get map objects
  enemy_set_tbl = {}
  for k, obj in pairs(map.objects) do
    local x, y, w, h = obj.x, obj.y, obj.width, obj.height
    x = math.floor(x + w / 2)
    y = math.floor(y + h / 2)
    local data = {
      name=obj.name, type=obj.type,
      x=x, y=y, properties = obj.properties
    }
    table.insert(enemy_set_tbl, data)
  end

  -- sort objects by y
  table.sort(enemy_set_tbl, function(a, b) return (a.y > b.y) end)

  map.layers["enemy_tbl"].visible = false

  -- map.layers["bg_b"].visible = false

  -- load sound
  local srctype = ".ogg"
  local audio_list = {
    {name="bgm_stg1", fn="bgm_loop", vol=0.7, loop=true, static=false},
    {name="bgm_boss", fn="bgm_loop_boss", vol=0.7, loop=true, static=false},
    {name="se_explo", fn="se_explosion", vol=0.9, loop=false, static=true},
    {name="se_explo2", fn="se_explosion03", vol=0.9, loop=false, static=true},
    {name="se_jet", fn="se_plane_jet03", vol=0.9, loop=false, static=true},
    {name="se_boss_shot", fn="se_boss_shot02_st", vol=0.9, loop=false, static=true},
    {name="se_boss_dead", fn="se_dead02", vol=0.9, loop=false, static=true},
  }
  for i,v in ipairs(audio_list) do
    local src = nil
    local fn = "sounds/"..v.fn..srctype
    if v.static then
      src = love.audio.newSource(fn, "static")
    else
      -- When playing stream audio data with love 2d 11.1, noise mixes when playing loops.
      -- src = love.audio.newSource(fn, "stream")
      src = love.audio.newSource(fn, "static")
    end
    src:setLooping(v.loop)
    src:setVolume(v.vol)
    sounds[v.name] = {src = src, vol = v.vol}
  end

  bgm = BgmControl.new()

  -- make shader
  local shadercode = [[
      extern number factor;
      extern number checkcolor;
      extern vec4 replacecolor;

      vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
        vec4 pixel = Texel(texture, texture_coords);
        float nowcol = ((pixel.r * 65536.0) + (pixel.g * 256.0) + pixel.b) * 255.0;
        float fac = (1.0 - sign(abs(nowcol - checkcolor))) * factor;
        return mix(pixel, replacecolor, fac) * color;
      }
  ]]
  palchg_shader = love.graphics.newShader(shadercode)

  -- checkcolor : 0xRRGGBB = (R << 16) + (G << 8) + B
  local checkcolor = ((1.0 * 65536) + (0.0 * 256) + 0.0) * 255.0
  palchg_shader:send("checkcolor", checkcolor)
  palchg_shader:send("replacecolor", {0.0, 0.0, 0.0, 1.0})  -- R,G,B,A
  palchg_angle = 0

  -- work init
  math.randomseed(0)
  player = Player.new(scr_w * 0.5, scr_h * 0.8, player_img_a, player_img_b)

  layers = {}
  for i,layer in ipairs(map.layers) do
    layers[i] = layer
  end

  stage_ctl_step = 0
  stage_clear_fg = false
  stage_clear_timer = 0

  bg_a_x, bg_a_y = 0, 0
  bg_b_x, bg_b_y = 0, 0
  bg_diff_x, bg_diff_y = 0, 0
  bg_speed = 60
  enemy_timer = 0
  boss_born_fg = false
  born_enemy_index = 1

  -- framerate steady
  min_dt = 1.0 / 60
  next_time = love.timer.getTime()
end

-- ============================================================
-- update
function love.update(dt)
  next_time = next_time + min_dt

  -- stage init, clear, clear wait
  if stage_ctl_step == 0 then
    player.x = scr_w * 0.5
    player.y = scr_h * 0.8
    player.shot_timer = -0.25

    -- bg_a_x, bg_a_y = 32, 1200
    bg_a_x, bg_a_y = 32, 480 * 9
    bg_b_x, bg_b_y = 32, bg_a_y
    bg_diff_x, bg_diff_y = 0, 0
    bg_speed = 60

    enemy_timer = 0
    boss_born_fg = false
    born_enemy_index = 1

    bgm:setNextBgm("bgm_stg1")
    stage_ctl_step = 1
    stage_clear_fg = false
  elseif stage_ctl_step == 1 then
    if stage_clear_fg then
      stage_clear_timer = 5
      stage_ctl_step = 2
    end
  elseif stage_ctl_step == 2 then
    stage_clear_timer = stage_clear_timer - dt
    if stage_clear_timer <= 0 then
      stage_clear_timer = 0
      stage_ctl_step = 0
      clearAllPlayerBullets()
    end
  end

  if dt > 0.75 then return end
  if pause_fg then return end

  -- palette change
  palchg_angle = (palchg_angle + 180 * dt) % 360.0
  local v = 1.0 - math.abs(math.sin(math.rad(palchg_angle)))
  palchg_shader:send("factor", v)  -- set 0.0 - 1.0

  -- screen flash
  if scr_flash > 0 then
    scr_flash = scr_flash - dt
    if scr_flash <= 0 then scr_flash = 0 end
  end

  -- scroll bg
  bg_diff_x = 0
  bg_diff_y = bg_speed * dt
  bg_a_y = bg_a_y - bg_diff_y
  bg_b_y = bg_b_y - bg_diff_y * 0.25
  if bg_a_y < 0 then bg_a_y = bg_a_y + 480 end
  if bg_b_y < 0 then bg_b_y = bg_b_y + 480 * 2 end
  map.layers["bg_a"].x = math.floor(-bg_a_x)
  map.layers["bg_a"].y = math.floor(-bg_a_y)
  map.layers["bg_b"].x = math.floor(-bg_b_x)
  map.layers["bg_b"].y = math.floor(-bg_b_y)

  map:update(dt)

  -- bgm
  bgm:update(dt)

  if bg_a_y <= scr_h * 2 and boss_born_fg == false then
    -- born boss
    local obj = EnemyBoss.new(enemyboss_img, enemyboss_quads)
    table.insert(enemys, obj)
    bgm:setNextBgm("bgm_boss")
    boss_born_fg = true
  end

  -- move player
  player.bg_hit_id = map:getGid(player.x, player.y)
  player:update(dt)

  function bornZakoEnemy(x, y)
    local dx = 0
    local dy = 100
    local xw = 64
    local ang = math.random(360)
    local angspd = 240
    local obj = Enemy.new(x, y, dx, dy, xw, ang, angspd, enemy_img)
    table.insert(enemys, obj)
  end

  -- born enemy
  if bg_a_y > scr_h * 2 then
    bornEnemy(bg_a_x, bg_a_y)
  end

  -- move objects
  updateSprites(player_bullets, dt)
  updateSprites(enemy_bullets, dt)
  updateSprites(enemys, dt)
  updateSprites(explosions, dt)
  updateSprites(explosions_top, dt)

  -- remove objects
  removeSprites(player_bullets)
  removeSprites(enemy_bullets)
  removeSprites(enemys)
  removeSprites(explosions)
  removeSprites(explosions_top)

  -- hit check
  for i, bullet in ipairs(player_bullets) do
    if bullet.activate then
      for j, enemy in ipairs(enemys) do
        if enemy.activate then
          if enemy:check(bullet.x, bullet.y) then
            enemy.hit_bullet = true
            bullet.hit_enemy = true
          end
        end
      end
    end
  end

  if player.hit_enable then
    for i, enemy in ipairs(enemys) do
      if enemy.activate then
        if enemy:check(player.x, player.y) then player.enemy_hit = true end
      end
    end

    for i, bullet in ipairs(enemy_bullets) do
      if bullet.activate then
        local dx = player.x - bullet.x
        local dy = player.y - bullet.y
        local d = 3
        if dx * dx + dy * dy <= d * d then player.enemy_hit = true end
      end
    end
  end

end

-- ============================================================
-- draw
function love.draw()
  -- set canvas
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1.0)

  -- draw tilemap BG
  if palette_shader_enable then love.graphics.setShader(palchg_shader) end
  love.graphics.setColor(1.0, 1.0, 1.0)
  map:draw()
  if palette_shader_enable then love.graphics.setShader() end

  -- draw flash
  if scr_flash > 0 then
    local d = scr_flash / scr_flash_duration
    if scr_flash_kind == 0 then
      love.graphics.setColor(1.0, 1.0, 1.0, d)
    elseif scr_flash_kind == 1 then
      d = d * 200 / 255
      love.graphics.setColor(1.0, 0.625, 0.25, d)
    end
    love.graphics.rectangle("fill", 0, 0, scr_w, scr_h)
  end

  -- draw objects
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  drawSprites(explosions)

  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.setBlendMode("alpha")
  drawSprites(enemys)

  player:draw()

  if bullet_blend_mode_add then love.graphics.setBlendMode("add") end
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  drawSprites(player_bullets)

  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  drawSprites(enemy_bullets)

  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  drawSprites(explosions_top)

  -- unset canvas
  love.graphics.setCanvas()

  -- get window width and window height
  wdw_w, wdw_h = love.graphics.getDimensions()
  scr_scale = math.min((wdw_w / scr_w), (wdw_h / scr_h))
  scr_ofsx = (wdw_w - (scr_w * scr_scale)) / 2
  scr_ofsy = (wdw_h - (scr_h * scr_scale)) / 2

  -- draw canvas to window
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.draw(canvas, scr_ofsx, scr_ofsy, 0, scr_scale, scr_scale)

  local tx = 8
  local ty = 8
  love.graphics.print("FPS: "..tostring(love.timer.getFPS()), tx, ty)
  ty = ty + 20
  love.graphics.print("env: "..tostring(love.system.getOS()), tx, ty)
  ty = ty + 20
  love.graphics.print("bg y: "..tostring(math.floor(bg_a_y)), tx, ty)

  if love.system.getOS() == "Windows" then
    -- wait
    local cur_time = love.timer.getTime()
    if next_time <= cur_time then
      next_time = cur_time
    else
      love.timer.sleep(next_time - cur_time)
    end
  end
end

function love.keypressed(key, isrepeat)
  if key == "escape" then
    -- ESC to exit
    love.event.quit()
  elseif key == "z" then
    -- gun angle change mode
    angle_change_key = true
  elseif key == "f11" then
    -- toggle fullscreen mode
    if fullscreen_fg then
      local success = love.window.setFullscreen(false)
      if success then fullscreen_fg = false end
    else
      local success = love.window.setFullscreen(true)
      if success then fullscreen_fg = true end
    end
  elseif key == "f10" then
    -- toggle palette shader
    palette_shader_enable = not palette_shader_enable
  elseif key == "f9" then
    -- toggle bullet draw mode
    bullet_blend_mode_add = not bullet_blend_mode_add
  elseif key == "p" then
    -- pause
    pause_fg = not pause_fg
  end
end

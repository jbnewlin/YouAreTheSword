local entity = ...

Effects = require "enemies/effect"

function entity:on_created()
end

function entity:start(tox, toy)
	self.bomb_sprite = self:create_sprite("entities/bomb")
	self.bomb_sprite:set_animation("stopped")
	self.bomb_sprite:set_paused(false)
	
	self.isbomb = true
	self.exploded = false
	
	self.timer = Effects.SimpleTimer:new(self.ability.entitydata, 1000, function() self:startwarning() end)
	
	dist = self:get_distance(tox, toy)
	if dist > RANGE then
		dist = RANGE
	end
	
	local x, y = self:get_position()
	local angle = self:get_angle(tox, toy)-- + math.pi
	local movement = sol.movement.create("straight")
	movement:set_speed(300)
	movement:set_angle(angle)
	movement:set_max_distance(dist)
	movement:set_smooth(true)
	movement:start(self)
end

function entity:startwarning()
	self.bomb_sprite:set_animation("stopped_explosion_soon")
	
	self.timer = Effects.SimpleTimer:new(self.ability.entitydata, 1000, function() self:explode() end)
end

function entity:explode()
	self.exploded = true
	
	self:remove_sprite(self.bomb_sprite)
	
	self.collided = {}
	self:add_collision_test("sprite", self.oncollision)
	
	self.explode_sprite = self:create_sprite("entities/explosion")
	self.explode_sprite:set_paused(false)
	function self.explode_sprite.on_animation_finished(explode_sprite, animation)
		self:remove()
	end
end

function entity:oncollision(entity2, sprite1, sprite2)
	if self.collided[entity2] == nil then
		self.collided[entity2] = true
			
		self.ability:attack(entity2, self)
	end
end

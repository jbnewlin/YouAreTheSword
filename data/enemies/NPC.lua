local enemy = ...

-- Generic script for an enemy with a sword
-- that goes towards the hero if he sees him
-- and walks randomly otherwise.

-- Example of use from an enemy script:

-- sol.main.load_file("enemies/generic_soldier")(enemy)
-- enemy:set_properties({
--	 main_sprite = "enemies/green_knight_soldier",
--	 sword_sprite = "enemies/green_knight_soldier_sword",
--	 life = 4,
--	 damage = 2,
--	 play_hero_seen_sound = false,
--	 normal_speed = 32,
--	 faster_speed = 64,
--	 hurt_style = "normal"
-- })

-- The parameter of set_properties() is a table.
-- Its values are all optional except main_sprite
-- and sword_sprite.

-- local properties = {}
-- local going_hero = false
-- local being_pushed = false
-- local main_sprite = nil

local class = require "middleclass"
require "math"

-- constants:
--[[
RANDOM = "random"
GOHERO = "go_towards"
--ATTACK = "attack"
PUSHED = "being_pushed"
FROZEN = "frozen"
GOPICKUP = "pickup"
--]]
play_hero_seen_sound = false
normal_speed = 32
faster_speed = 64

enemy.hasbeeninitialized = false

State = class("State")

function State:initialize(npc)
	self.npc = npc
end

function State:ontick(changedstates)
	if changedstates then
		self:start()
	end
	self:tick()
end

function State:cleanup()
	self.npc:reset_everything()
end

function State:vartorecord()
end

function State:prevvar()
	self.prev_var = self:vartorecord()
end

function State:requiresupdate()
	if self.prev_var ~= self:vartorecord() then
		return true
	end
	return false
end

NilState = State:subclass("NilState")
function NilState:start()
end
function NilState:tick()
end

RandomState = State:subclass("RandomState")

function RandomState:start()
	self.npc.entitydata:log("random", changedstates)
	local movement = sol.movement.create("random_path")
	movement:set_speed(normal_speed)
	movement:start(self.npc)
end

function RandomState:tick()
end

PushedState = State:subclass("PushedState")

function PushedState:start()
	local x, y = self.npc:get_position()
	local angle = self.npc:get_angle(self.npc.hitbyentity) + math.pi
	local movement = sol.movement.create("straight")
	movement:set_speed(128)
	movement:set_angle(angle)
	movement:set_max_distance(26)
	movement:set_smooth(true)
	movement:start(self.npc)
end

function PushedState:tick()
end

FrozenState = State:subclass("FrozenState")

function FrozenState:start()
end

function FrozenState:tick()
end

GoTowardsState = State:subclass("GoTowardsState")

function GoTowardsState:start()
	if self.npc.entitytoattack ~= nil then
		local movement = sol.movement.create("target") -- "path_finding")
		movement:set_speed(faster_speed)
		movement:set_target(self.npc.entitytoattack.entity)
		movement:start(self.npc)
	end
end

function GoTowardsState:tick()
	if self.npc.entitytoattack ~= nil then
		if self.npc.entitydata:withinrange("sword", self.npc.entitytoattack) then
			self.npc.entitydata:startability("sword")
		end
	end
end

function GoTowardsState:vartorecord()
	return self.npc.entitytoattack
end

PickupState = State:subclass("PickupState")

function PickupState:start()
	local movement = sol.movement.create("target")
	movement:set_speed(faster_speed)
	movement:set_target(self.npc.target)
	movement:start(self.npc)
end

function PickupState:tick()
	if self.npc:get_distance(self.npc.target) < 20 then
		self.npc.entitydata:bepossessedbyhero()
	end
end

function PickupState:vartorecord()
	return self.npc.target
end



function enemy:on_created()
	-- initialize
	
	self:set_life(9999) -- life is now managed by entitydata not by solarus
	self:set_damage(0)
	self:set_hurt_style("normal")
	self.direction = 0
	self:set_invincible()
	
	self.ishero = false
	
	self.is_swinging_sword = false
	self.state = nil
	self.hitbyentity = nil
	
	self:set_size(16, 16)
	self:set_origin(8, 13)
	
	self.nilstate = NilState:new(self)
	self.randomstate = RandomState:new(self)
	self.gotowardsstate = GoTowardsState:new(self)
	self.pushedstate = PushedState:new(self)
	self.frozenstate = FrozenState:new(self)
	self.pickupstate = PickupState:new(self)
end

function enemy:load_entitydata()
	self.main_sprite = self:create_sprite(self.entitydata.main_sprite)
end

function enemy:on_restarted()
	self:tick()
end

function enemy:close_to(entity)
	local _, _, layer = self:get_position()
	local _, _, hero_layer = entity:get_position()
	return layer == hero_layer and self:get_distance(entity) < 40
end

function enemy:targetenemy()
	entitieslist = {}
	
	local hero = self:get_map():get_entity("hero")
	if self:cantargetentity(hero) then
		entitieslist[#entitieslist+1] = hero.entitydata
	end
	
	if hero.isdropped then
		return hero
	end
	
	map = self:get_map()
	for entity in map:get_entities("") do
		if self:cantargetentity(entity) and entity ~= hero then
			entitieslist[#entitieslist+1] = entity.entitydata
		end
	end
	
	function entitieslist.contains(table, element)
	  for _, value in pairs(table) do
	    if value == element then
	      return true
	    end
	  end
	  return false
	end
	
	if entitieslist:contains(self.entitytoattack) then
		return self.entitytoattack
	end
	
	return entitieslist[math.random(#entitieslist)]
end

function enemy:cantargetentity(entity)
	if entity.entitydata == nil then return false end
	if entity.entitydata.team == self.entitydata.team then return false end
	if not entity.entitydata:isvisible() then return false end
	if self:get_distance(entity) > 200 then return false end
	
	return true
end


function enemy:determinenewstate(entitytoattack, currentstate)
	if currentstate == self.pushedstate then
		return currentstate
	end
	
	if currentstate == self.frozenstate then
		return currentstate
	end
	
	if entitytoattack == nil then
		return self.randomstate
	end
	
	if entitytoattack.isdropped then
		return self.pickupstate
	end
	
	return self.gotowardsstate
end

function enemy:resetstate()
	if self.entitydata ~= nil then
		self.entitydata:log("reset state")
		self.prevstate = nil
		self.state = nil
		self:tick(self.nilstate)
	end
end

function enemy:tick(newstate)
	if self.entitydata ~= nil and not game:is_paused() and not game:is_suspended() then
	
	self.hasbeeninitialized = true
	
	prevstate = self.state
	if prevstate == nil then prevstate = self.nilstate end
--	preventitytoattack = self.entitytoattack
	prevstate:prevvar()
	
	self.entitytoattack = self:targetenemy()
	if (self.entitytoattack ~= nil) then
		if self.entitytoattack.isdropped then
			target = self.entitytoattack
			self.entitytoattack = nil
		else
			target = self.entitytoattack.entity
		end
	else
		target = nil
	end
	self.target = target
	
	if (newstate == nil) then
		self.state = self:determinenewstate(target, self.state)
	else
		self.state = newstate
	end
	if self.state == nil then self.state = self.NilState end
	
	changedstates = (prevstate ~= self.state or self.state:requiresupdate())
	
	if changedstates then
		prevstate:cleanup()
		self.entitydata:log("changed states from", prevstate, "to", self.state, self.entitytoattack and "Target: "..self.entitytoattack.team or "")
	end
	self.state:ontick(changedstates)
--[[
	if changedstates then
		-- changed states
		self:reset_everything()
		self.entitydata:log("changed states from", prevstate, "to", self.state, self.entitytoattack and "Target: "..self.entitytoattack.team or "")

--		if prevstate == ATTACK then
--			self:dont_attack(target)
--		end
	end
	
--	if self.state == ATTACK then
--		self:go_attack(changedstates, target)
	if self.state == GOHERO then
		self:go_hero(changedstates)
	elseif self.state == RANDOM then
		self:go_random(changedstates)
	elseif self.state == PUSHED then
		self:go_pushed(changedstates)
	elseif self.state == GOPICKUP then
		self:go_pickup(changedstates, target)
	end
--]]
	
	end
	
	if self:exists() then
		sol.timer.start(self, 100, function() self:tick() end)
	end
end

function enemy:on_movement_changed(movement)
	if self.state ~= self.pushedstate then
		self:setdirection(movement:get_direction4())
	end
end

function enemy:setdirection(d)
	self.direction = d
	self.main_sprite:set_direction(d)
--	self.sword_sprite:set_direction(d)
end

function enemy:on_movement_finished(movement)
	if self.state == self.pushedstate then
		self.state = nil
		self:tick()
	end
end

function enemy:on_obstacle_reached(movement)
	if self.state == self.pushedstate then
		self.state = nil
		self:tick()
	end
end

function enemy:on_custom_attack_received(attack, sprite)
--	if attack == "sword" and sprite == self.sword_sprite then
--		sol.audio.play_sound("sword_tapping")
--		self:receive_attack_animation(self:get_map():get_entity("hero"))
--	end
end

function enemy:receive_attack_animation(entity)
	self.hitbyentity = entity
	self:tick(self.pushedstate)
end

--[[
function enemy:go_pushed(changedstates)
	if changedstates then
		local x, y = self:get_position()
		local angle = self:get_angle(self.hitbyentity) + math.pi
		local movement = sol.movement.create("straight")
		movement:set_speed(128)
		movement:set_angle(angle)
		movement:set_max_distance(26)
		movement:set_smooth(true)
		movement:start(self)
	end
end

function enemy:go_random(changedstates)
	if changedstates then
		self.entitydata:log("random", changedstates)
		local movement = sol.movement.create("random_path")
		movement:set_speed(normal_speed)
		movement:start(self)
	end
end

function enemy:go_hero(changedstates)
	if changedstates then
		if self.entitytoattack ~= nil then
			local movement = sol.movement.create("target")
			movement:set_speed(faster_speed)
			movement:set_target(self.entitytoattack.entity)
			movement:start(self)
		end
	end
	
	if self.entitytoattack ~= nil then
		if self.entitydata:withinrange("sword", self.entitytoattack) then
			self.entitydata:startability("sword")
		end
	end
end

function enemy:go_pickup(changedstates, target)
	if changedstates then
		local movement = sol.movement.create("target")
		movement:set_speed(faster_speed)
		movement:set_target(target)
		movement:start(self)
	end
	
	if self:get_distance(target) < 20 then
		self.entitydata:log("POSSESS")
		self.entitydata:bepossessedbyhero()
	end
end
--]]

--[[
function enemy:go_attack(changedstates, hero)
	if not self.is_swinging_sword then
		self:swingsword(hero)
	end
	direction = self:get_direction4_to(hero)
	self.main_sprite:set_direction(direction)
	self.sword_sprite:set_direction(direction)
end

function enemy:swingsword(hero)
	self.is_swinging_sword = true
	self.entitydata:log("swinging sword")
	movement = self:get_movement()
	if movement ~= nil then
		movement:stop(self)
	end
	self.sword_sprite:set_animation("sword")
	self.sword_sprite:set_paused(false)
	self.main_sprite:set_animation("sword")
	self.sword_sprite:synchronize(self.main_sprite)
	sol.timer.start(self, 100, function() self:actually_attack(hero) end)
	
	function self.main_sprite.on_animation_finished (sprite, animation)
		self.is_swinging_sword = false
		self:tick()
	end
end

function enemy:dont_attack(hero)
	self.is_swinging_sword = false
end
--]]
function enemy:reset_everything()
--	self.sword_sprite:set_animation("walking")
	self.main_sprite:set_animation("walking")
--	self.sword_sprite:synchronize(nil)
	self.main_sprite:set_paused(false)
	
	if self:get_movement() ~= nil then
		self:get_movement():stop()
	end
end


function enemy:actually_attack(hero)
	-- TODO: pixel collision
	if self:close_to(hero) then
		self.entitydata:log("hit")
	end
end

function enemy:on_attacking_hero(hero, enemy_sprite)
end

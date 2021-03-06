local class = require "middleclass"
Ability = require "abilities/ability"

SwordAbility = require "abilities/sword"

ChargeAbility = Ability:subclass("ChangeAbility")

local RANGE = 200

function ChargeAbility:initialize(entitydata)
	Ability.initialize(self, entitydata, "charge", RANGE, 500, 10000, true)
end

function ChargeAbility:doability(tox, toy)
	entity = self.entitydata.entity
	map = entity:get_map()
	x,y,layer = entity:get_position()
	w,h = entity:get_size()
	entitydata = self.entitydata
	
	self.collided = {}
	
	d = entitydata:getdirection()
	
	self.swordentity = map:create_custom_entity({model="charge", x=x, y=y, layer=layer, direction=d, width=w, height=h})
	self.swordentity.ability = self
	
	self.entitydata:setanimation("sword_loading_stopped")
	
	self.swordentity:start(SwordAbility:get_appearance(self.entitydata.entity))
	
	dist = self.entitydata.entity:get_distance(tox, toy)
	if dist > RANGE then
		dist = RANGE
	end
	
	local x, y = self.entitydata.entity:get_position()
	local angle = self.entitydata.entity:get_angle(tox, toy)-- + math.pi
	local movement = sol.movement.create("straight")
	movement:set_speed(300)
	movement:set_angle(angle)
	movement:set_max_distance(dist)
	movement:set_smooth(true)
	movement:start(self.entitydata.entity)
	local ca = self
	function movement:on_position_changed()
		ca.swordentity:updatepos()
	end
	function movement:on_obstacle_reached()
		ca:finish()
	end
	function movement:on_finished()
		ca:finish()
	end
	
	self.entitydata.positionlisteners[self] = function(x, y, layer) self:updatepos(x, y, layer) end
end

function ChargeAbility:cancel()
	self:finish()
end

function ChargeAbility:finish()
	self.entitydata:setanimation("walking")
	
	self.entitydata.positionlisteners[self] = nil
	
	self.swordentity:remove()
	self.swordentity = nil
	self:finishability()
end

function ChargeAbility:blockdamage(fromentity, damage, aspects)
	aspects.donothing=true
	return 0, aspects
end

function ChargeAbility:updatepos(x, y, layer)
	entity = self.entitydata.entity
	map = entity:get_map()
	
	for entity2 in map:get_entities("") do
		if self.entitydata.entity:overlaps(entity2) then
			if self.entitydata:cantargetentity(entity2) then
				if self.collided[entity2] == nil then
					self.collided[entity2] = true
				
					self:attack(entity2.entitydata)
				end
			end
		end
	end
end

function ChargeAbility:attack(entitydata)
	damage = 2
	aspects = {stun=500, knockback=0}
	
	self:dodamage(entitydata, damage, aspects)
	
	self:finish()
	
	self.entitydata:startability("sword")
end

return ChargeAbility
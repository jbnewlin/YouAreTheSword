local class = require "middleclass"

Effect = class("Effect")

function Effect:initialize(entitydata, ...)
	self.entitydata = entitydata
	if self:get() ~= nil then
		self:alreadyexists(self:get(), ...)
	else
		self.entitydata.effects[self:getkey()] = self
		self.active = true
		self.entitydata:log("starting effect", self:getkey())
		self:start(...)
	end
end

function Effect:alreadyexists(currenteffect)
	self.entitydata:log("WARNING! tried to add a new effect when one already exists", self:getkey())
end

function Effect:start()
end

function Effect:remove()
	if not self.active then
		self.entitydata:log("timer tried to remove", self:getkey(), "but already removed!")
	else
		self:endeffect()
		self.entitydata:log("ending effect", self:getkey())
		self.entitydata.effects[self:getkey()] = nil
		self.active = false
	end
end

function Effect:forceremove()
	Effect.remove(self)
end

function Effect:endeffect()
end

function Effect:removeeffectafter(time)
	if not self.active then
		self.entitydata:log("timer tried to remove", self:getkey(), "but already removed!")
	else
		sol.timer.start(self, time, function() self:endtimer() end)
	end
end

function Effect:endtimer()
	self:remove()
end

function Effect:starttick(timestep)
	self.timestep = timestep
	sol.timer.start(self, self.timestep, function() self:dotick() end) -- starting tick immediately causes strange bugs
end

function Effect:dotick()
	if not self.active then return end
	self:tick()
	sol.timer.start(self, self.timestep, function() self:dotick() end)
end

function Effect:get(entitydata)
	if entitydata == nil then entitydata = self.entitydata end
	return entitydata.effects[self:getkey()]
end

PhysicalEffect = Effect:subclass("PhysicalEffect")

function PhysicalEffect:start(time)
	w,h = self.entitydata.entity:get_size()
	
	paentity = map:create_custom_entity({model="physicaleffect", x=x, y=y, layer=layer, direction=0, width=w, height=h})
	paentity:start(self, self:getspritename())
	self.paentity = paentity
	
	if time ~= nil then
		self:removeeffectafter(time)
	end
end

function PhysicalEffect:endeffect()
	self.paentity:finish()
end

FireEffect = PhysicalEffect:subclass("FireEffect")

function FireEffect:getspritename()
	return "fire"
end

function FireEffect:start(aspect)
	time = aspect.time
	self.firedamage = aspect.damage
	timestep = aspect.timestep
	
	self:starttick(timestep)
	
	PhysicalEffect.start(self, time)
end

function FireEffect:tick()
	self.entitydata:dodamage(self.entitydata, self.firedamage, {flame=true, natural=true})
end

function FireEffect:getkey()
	return "FireEffect"
end

ElectricalEffect = PhysicalEffect:subclass("ElectricalEffect")

function ElectricalEffect:getspritename()
	return "stun"
end

function ElectricalEffect:getkey()
	return "ElectricalEffect"
end

FreezeEffect = Effect:subclass("FreezeEffect")

function FreezeEffect:start()
	self.count = 1
	self.entitydata:log("Freeze level", self.count)
	self:freeze()
end

function FreezeEffect:freeze()
	if self.entitydata.entity.ishero then
		self.entitydata.entity:freeze()
	else
		self.entitydata.entity:tick(self.entitydata.entity.frozenstate)
	end
end

function FreezeEffect:alreadyexists(currenteffect)
	currenteffect.count = currenteffect.count + 1
	self.entitydata:log("Freeze level", currenteffect.count)
end

function FreezeEffect:remove()
	currenteffect = self:get()
	if currenteffect ~= nil then
		currenteffect.count = currenteffect.count - 1
		self.entitydata:log("Freeze level", currenteffect.count)
		if currenteffect.count == 0 then
			Effect.remove(currenteffect)
		end
	else
		self.entitydata:log("freeze tried to remove", self:getkey(), "but already removed!")
	end
end

function FreezeEffect:endeffect()
	if self.entitydata.entity.ishero then
		self.entitydata.entity:unfreeze()
	else
		self.entitydata.entity:resetstate()
	end
end

function FreezeEffect:getkey()
	return "FreezeEffect"
end

StunEffect = FreezeEffect:subclass("StunEffect")

function StunEffect:alreadyexists(currenteffect, time)
	FreezeEffect.alreadyexists(self, currenteffect)
	self:removeeffectafter(time)
end

function StunEffect:alreadyexists(currenteffect, time)
	FreezeEffect.alreadyexists(self, currenteffect)
	self:removeeffectafter(time)
end

function StunEffect:start(time)
	FreezeEffect.start(self)
	self:removeeffectafter(time)
end

ElectricalStunEffect = StunEffect:subclass("ElectricalStunEffect")

function ElectricalStunEffect:initialize(entitydata, ...)
	self.electricaleffect = ElectricalEffect:new(entitydata)
	StunEffect.initialize(self, entitydata, ...)
end
function ElectricalStunEffect:remove(...)
	self.electricaleffect:remove(...)
	StunEffect.remove(self, ...)
end

KnockBackEffect = FreezeEffect:subclass("KnockBackEffect")

function KnockBackEffect:start(fromentitydata, knockbackdist)
	self.entitydata:log("starting knockback")
	FreezeEffect.start(self, 5000) -- timeout 5 seconds
	
	local x, y = self.entitydata.entity:get_position()
	local angle = self.entitydata.entity:get_angle(fromentitydata.entity) + math.pi
	local movement = sol.movement.create("straight")
	movement:set_speed(128)
	movement:set_angle(angle)
	movement:set_max_distance(knockbackdist)
	movement:set_smooth(true)
	movement:start(self.entitydata.entity)
	local kbe = self
	self.finished = false
	function movement:on_finished()
		kbe.entitydata:log("finished knockback")
		kbe.finished = true
		kbe:remove()
	end
end

function KnockBackEffect:endtimer()
	if not self.finished then
		self:remove()
	end
end


return {Effect=Effect, PhysicalEffect=PhysicalEffect, FireEffect=FireEffect, ElectricalEffect=ElectricalEffect, FreezeEffect=FreezeEffect, StunEffect=StunEffect, ElectricalStunEffect=ElectricalStunEffect, KnockBackEffect=KnockBackEffect}
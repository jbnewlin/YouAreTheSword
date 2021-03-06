local entity = ...

function entity:on_created()
end

function entity:start(appearance)
	self.shield_sprite = self:create_sprite(appearance)
	self.shield_sprite:set_paused(false)
	self.shield_sprite:set_animation("walking")
	
	self:updatedirection()
	
	self.ability.entitydata:log("shield created")
end

function entity:updatedirection()
	if self.get_direction == 1 then
		self:bring_to_back()
		x,y,layer = self:get_position()
		self:set_position(x,y,0)
	else
		self:bring_to_front()
		x,y,layer = self:get_position()
		self:set_position(x,y,2)
	end
	
	self.shield_sprite:set_direction(self:get_direction())
end

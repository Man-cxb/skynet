local class_list = {}

-- classname 类名 supername 父类名 only 是否单例
function class(classname, supername, only)
	local cls = {}
	cls.__cname = classname
	cls.__only = only

	local typ = type(supername)
	assert(typ == "string" or typ == "nil", typ)

	local super
	if supername then
		super = assert(class_list[supername], supername)
	end
	local old = class_list[classname]
	class_list[classname] = cls

	cls.super = super
	if super then
		setmetatable(cls, {__index = super})
	end
	cls.__index = 
		function(_, key)
			return class_list[classname][key] 
		end
	if old then
		cls.__instances = old.__instances
	else
		cls.__instances = setmetatable({}, {__mode = "kv"})
	end
	return cls
end

function instance(classname, ...)
	local cls = assert(class_list[classname], classname .. " not defined!")

	local obj
	if cls.__only then
		obj = next(cls.__instances)
		if obj then
			return obj
		end
	end

	obj = {}
	setmetatable(obj, cls)

	if obj.init then
		obj:init(...)
	end

	cls.__instances[obj] = true
	return obj
end

function isclass(classname)
	if class_list[classname] then
		return true
	end
	return false
end

function get_class_instance(classname)
	return class_list[classname].__instances
end

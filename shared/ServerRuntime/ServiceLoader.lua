local ServiceLoader = {}

local function getServiceName(moduleScript)
	return moduleScript.Name
end

local function collectServices(container)
	local services = {}

	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, serviceOrErr = pcall(require, child)

			if not ok then
				error(`Failed to require service {child:GetFullName()}: {serviceOrErr}`)
			end

			if type(serviceOrErr) == "table" and type(serviceOrErr.start) == "function" then
				table.insert(services, {
					name = serviceOrErr.Name or getServiceName(child),
					order = serviceOrErr.Order or 100,
					module = serviceOrErr,
				})
			end
		end
	end

	table.sort(services, function(left, right)
		if left.order == right.order then
			return left.name < right.name
		end

		return left.order < right.order
	end)

	return services
end

function ServiceLoader.start(container)
	local services = collectServices(container)

	for _, service in services do
		local ok, err = pcall(service.module.start)

		if not ok then
			error(`Failed to start service {service.name}: {err}`)
		end
	end
end

return ServiceLoader

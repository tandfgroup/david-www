$ = jQuery

# Do this on the homepage only
$('#home-page').each ->
	
	url = $ '.badge-maker span'
	badge = $ '.badge-maker img'
	
	# Update the image when the user changes the url
	url.on('input', -> badge.attr('src', "#{url.text()}.png"))
	
	# Red text if the url isn't good for it.
	badge.error ->
		url.addClass 'nope'
		$(@).hide()
	
	# Green text if it is... wait a minute should this be tied to repo health not.
	badge.load ->
		if $(@).attr('src') is '/img/outofdate.png' then return # bail, it's the placeholder image load.
		url.removeClass 'nope'
		$(@).show()

$('#status-page').each ->
	
	$('#deps table').stacktable()
	
	$('#status').fancybox()
	
	$('#badge-embed input').each ->
		clicked = false
		$(@).click -> 
			if not clicked 
				$(@).select()
				clicked = true
	
	###
	# d3 graph
	###
	
	createNode = (dep) ->
		name: dep.name
		version: dep.version
		children: null
	
	# Transform data from possibly cyclic structure into max 10 levels deep visual structure
	transformData = (rootDep, callback) ->
		
		transformsCount = 0
		
		rootNode = createNode(rootDep)
		
		scheduleTransform = (dep, node, level, maxLevel) ->
			
			setTimeout(
				->
					transform(dep, node, level, maxLevel)
					
					transformsCount--
					
					callback(rootNode) if transformsCount is 0
				0
			)
		
		transform = (dep, parentNode, level = 0, maxLevel = 10) ->
			
			keys = Object.keys(dep.deps)
			
			console.log(keys) if keys.length
			
			for depName in Object.keys(dep.deps)
				
				
				
				node = createNode(dep.deps[depName])
				
				if level < maxLevel
					
					transformsCount++
					
					scheduleTransform(dep.deps[depName], node, level + 1, maxLevel)
				
				parentNode.children = [] if not parentNode.children
				parentNode.children.push node
			
			if parentNode.children?
				parentNode.children = parentNode.children.sort (a, b) -> if a.name < b.name then -1 else if a.name > b.name then 1 else 0
		
		transform(rootDep, rootNode)
	
	m = [20, 120, 20, 120]
	w = 1024 - m[1] - m[3]
	h = 768 - m[0] - m[2]
	i = 0
	root = null
	
	tree = d3.layout.tree().size [h, w] 
	
	diagonal = d3.svg.diagonal().projection (d) -> [d.y, d.x]
	
	vis = d3.select("#graph").append("svg:svg")
		.attr("width", w + m[1] + m[3])
		.attr("height", h + m[0] + m[2])
		.append("svg:g")
		.attr("transform", "translate(" + m[3] + "," + m[0] + ")")
	
	d3.json window.location.pathname + "/graph.json", (json) ->
		
		transformData(
			JSON.retrocycle(json)
			(node) ->
				root = node
				root.x0 = h / 2
				root.y0 = 0
				
				toggleAll = (d) ->
					if d.children
						toggleAll child for child in d.children
						toggle d
				
				# Initialize the display to show a few nodes.
				toggleAll child for child in root.children
				update root
		)
	
	update = (source) ->
		
		duration = if d3.event && d3.event.altKey then 5000 else 500
		
		# Compute the new tree layout.
		nodes = tree.nodes(root).reverse()
		
		# Normalize for fixed-depth.
		(d.y = d.depth * 180) for d in nodes
		
		# Update the nodes...
		node = vis.selectAll("g.node").data(nodes, (d) -> d.id or (d.id = ++i))
		
		# Enter any new nodes at the parent's previous position.
		nodeEnter = node.enter().append("svg:g")
			.attr("class", "node")
			.attr("transform", -> "translate(#{source.y0}, #{source.x0})")
			.on("click", (d) -> toggle d; update d)
		
		nodeEnter.append("svg:circle")
			.attr("r", 1e-6)
			.style("fill", (d) -> if d._children then "#ccc" else "#fff")
		
		nodeEnter.append("svg:text")
			.attr("x", (d) -> if d.children or d._children then -10 else 10)
			.attr("dy", ".25em")
			.attr("text-anchor", (d) -> if d.children or d._children then "end" else "start")
			.text((d) -> d.name + ' ' + d.version)
			.style("fill-opacity", 1e-6)
		
		# Transition nodes to their new position.
		nodeUpdate = node.transition()
			.duration(duration)
			.attr("transform", (d) -> "translate(#{d.y}, #{d.x})")
		
		nodeUpdate.select("circle")
			.attr("r", 4.5)
			.style("fill", (d) -> if d._children then "#ccc" else "#fff")
		
		nodeUpdate.select("text")
			.style("fill-opacity", 1)
		
		# Transition exiting nodes to the parent's new position.
		nodeExit = node.exit().transition()
			.duration(duration)
			.attr("transform", -> "translate(#{source.y}, #{source.x})")
			.remove()
		
		nodeExit.select("circle")
			.attr("r", 1e-6)
		
		nodeExit.select("text")
			.style("fill-opacity", 1e-6)
		
		# Update the links…
		link = vis.selectAll("path.link").data(tree.links(nodes), (d) -> d.target.id)
		
		# Enter any new links at the parent's previous position.
		link.enter().insert("svg:path", "g")
			.attr("class", "link")
			.attr("d", ->
				o = x: source.x0, y: source.y0
				diagonal(source: o, target: o)
			).transition()
			.duration(duration)
			.attr("d", diagonal)
		
		# Transition links to their new position.
		link.transition()
			.duration(duration)
			.attr("d", diagonal)
		
		# Transition exiting nodes to the parent's new position.
		link.exit().transition()
			.duration(duration)
			.attr("d", ->
				o = x: source.x, y: source.y
				diagonal(source: o, target: o)
			).remove()
		
		# Stash the old positions for transition.
		for d in nodes
			d.x0 = d.x
			d.y0 = d.y
		
		return
	
	# Toggle children.
	toggle = (d) ->
		
		if d.children
			d._children = d.children
			d.children = null
		else
			d.children = d._children
			d._children = null
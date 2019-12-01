function love.conf(t)
	t.author = "ACD"
	t.identity = "CAG"
	t.console = false
	--t.screen = false
	t.modules.physics = false
	t.version = "0.10.0"
	t.window.width = 480        
	t.window.height = 360
	t.window.fullscreen = true
    --t.window.fullscreentype = "exclusive"
	t.window.vsync = true
end
#!vanilla

# Margins/width/height parameters
margin = [20, 20, 20, 20]
width = 900 - margin[1] - margin[3]
height = 200 - margin[0] - margin[2]

class StockerModel

    # Piece-wise linear model
    #------------------------
    
    # For t<t0 assume 2 lines, la & lb, such that:
    # range la is [tx,ty] & range lb is [ty, t0]
    # la(tx) = 0
    # la(ty) = lb(ty) = Ey
    # lb'(t0) = E0*r (slope of Stocker'sexponential @ t0)
    # Area under la & lb, from tx to t0 = C0

    exp = (x) -> Math.exp(x)

    # Stocker's parameters
    beta = 0.002 # deg.C/GtC, climate sensitivity
    C0 = 530 # GtC, pre-existing emission cumulation
    r = 0.018 # fraction/year, per annum emission rate increase
    E0 = 9.3 # GtC/yr, intial (in 2009) emissions 
    t0 = 2009    # year, base year for calculations

    tx = 1750  # Start year
    A = [[(t0-tx)/2, -E0/2],[-1, r*E0]]
    b = [[C0-E0*t0/2],[E0*(r*t0-1)]]
    c = numeric.solve A, b
    Ey=c[0]
    ty=c[1]

    constructor: ->
        @beta = beta
        @tx = tx
        @tests()
        
    Epwl: (t,tx,ty,t0,Ey,E0) -> # PWL emissions
        switch
            when t < tx then 0
            when t >= tx and t<ty then Ey/(ty-tx)*(t-tx)
            when t >=ty and t<= t0 then Ey+(t-ty)*(E0-Ey)/(t0-ty)
            else 0
    
    Cpwl: (t,tx,ty,t0,Ey,E0) -> # PWL carbon
        switch
            when t < tx then 0
            when t >= tx and t<ty then Ey/(ty-tx)*(t-tx)*(t-tx)/2
            when t >=ty and t<= t0
                Ey*(ty-tx)/ 2 + Ey*(t-ty) + 1/ 2 *(t-ty)*(t-ty)*(E0-Ey)/(t0-ty)
            else 0
    
    # Stocker + PWL
    #--------------
    
    Et: (t, t1, s) -> # emissions
        switch
            when t < tx then 0
            when t >= tx and t<t0 then @Epwl(t,tx,ty,t0,Ey,E0)
            when t >= t0 and t<t1 then E0*exp(r*(t-t0))
            when t >= t1 then E0*exp(r*(t1-t0))*exp(-s*(t-t1))
            else 0
    
    Ct: (t, t1, s) -> # carbon
        switch
            when t < tx then 0
            when t < t0 and t>= tx then @Cpwl(t,tx,ty,t0,Ey,E0)
            when t>=t0 and t<=t1 then C0+E0/r*(exp(r*(t-t0))-1)
            else 
                if s>0
                    C0 + E0*(1/r + 1/s)*exp(r*(t1-t0)) - E0/r - # Stocker (2)
                    E0/s*exp(r*(t1-t0))*exp(-s*(t-t1)) # transient
                else
                    C0+E0/r*(exp(r*(t1-t0))-1)+E0*exp(r*(t1-t0))*(t-t1)
        
    tests: ->
        # tests (expect 0)
        
        @Epwl(tx,tx,ty,t0,Ey,E0)-0 # zero at tx
        @Epwl(ty,tx,ty,t0,Ey,E0)-Ey # Ey at ty
        @Epwl(t0,tx,ty,t0,Ey,E0)-E0 # E0 at t0
        (E0-@Epwl(ty,tx,ty,t0,Ey,E0))/(t0-ty) - E0*r # slope @ t0
        1/2*(ty-tx)*Ey+1/2*(t0-ty)*(E0-Ey)+(t0-ty)*Ey - C0 # area
        @Cpwl(t0,tx,ty,t0,Ey,E0)-C0 # area
        
        @Et(tx, 2100, 0.01)-0
        @Et(ty, 2100, 0.01)-Ey
        @Et(t0-.0001, 2100, 0.01)-E0
        @Et(t0, 2100, 0.01)-E0
        @Et(2100, 2100, 0.01)-E0*exp(r*(2100-t0))


class d3Object

    constructor: (id) ->
        @element = d3.select "##{id}"
        @element.selectAll("svg").remove()
        @obj = @element.append "svg"
        @initAxes()
        
    append: (obj) -> @obj.append obj
    
    initAxes: ->


class Road extends d3Object

    max_temp = 10

    constructor: (@beta) ->
        super "road"
        
        bg = d3.select("body").append("svg:svg")
        bg.attr "height", "0px"
        
        gradient = bg.append("svg:defs")
            .append("svg:linearGradient")
            .attr("id", "gradient")
            .attr("x1", "0%")
            .attr("y1", "0%")
            .attr("x2", "100%")
            .attr("y2", "0%")
            .attr("spreadMethod", "pad")
        
        gradient.append("svg:stop")
            .attr("offset", "0%")
            .attr("stop-color", "white")
            .attr("stop-opacity", 0.5)
        
        gradient.append("svg:stop")
            .attr("offset", "100%")
            .attr("stop-color", "orangered")
            .attr("stop-opacity", 0.75)
                
        @append("rect")
            .attr("width", width)
            .attr("height", 120)
            .style("fill", "url(#gradient)")
            .attr("transform", "translate(40, 40)")
            .attr("title","Distance along the road is analagous to anthropogenic carbon. 
                The temperature increase is proportional to carbon (and so distance)")
                
        @append("g")
            .attr("class", "axis")
            .attr("transform", "translate(40, 160)")
            .call(@c_axis)
        
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", 377)
            .attr("y", 12)
            .text("Maximum warming (\u2103)")
            .attr("title","The increase in temperature is proportional to the total (culmulative) carbon.
                That is, proportional to distance travelled down the road.")
        
        @append("g")
            .attr("class", "axis")
            .attr("transform", "translate(40, 40)")
            .call(@t_axis)
        
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", 358)
            .attr("y", height+margin[2]+margin[0]+2)
            .text("Anthropogenic carbon (GtC)")
            .attr("title","The total anthropogenic carbon is analagous to the distance your
                car travels. 'GtC' means gigatonnes of carbon. ")
                
    appendSvgObject: (svgId, objId) ->
        @append("g").attr("id", objId).append("use")
            .style("stroke", "yellow")
            .attr("xlink:href","##{svgId}")
        @obj.selectAll "##{objId}"
                
    initAxes: ->
        
        # carbon
        @c_to_px = d3.scale.linear()
            .domain([0, max_temp/@beta])
            .range([0, width])
        
        @c_axis = d3.svg.axis()
            .scale(@c_to_px)
            .ticks(6)
    
        # temperature
        @t_to_px = d3.scale.linear()
            .domain([0, max_temp])
            .range([0, width])
        
        @t_axis = d3.svg.axis() 
            .scale(@t_to_px)
            .ticks(6)
            .orient("top")

class Car

    constructor: (@road) ->
        @car = @road.appendSvgObject "svgcar", "car"

    draw: (T) ->
        # T = temperature

        # crash
        theta = if T>8 then (T-8)*(T-8)*360 else 0
            
        @car
            .transition()
            .ease("linear")
            .attr("transform", 
                "translate(" + @road.t_to_px(T) + "," + height/2 + ")," + 
                "scale(2)" +
                "rotate("+ theta + ",24,10.25)"
            )


class Speedo extends d3Object

    constructor: ->
        
        super "speedo"
                
        @gauge = iopctrl.arcslider()
            .radius(110)
            .events(false)
            .indicator(iopctrl.defaultGaugeIndicator)
        
        @gauge.axis().orient("in")
            .normalize(true)
            .ticks(13)
            .tickSubdivide(3)
            .tickSize(10, 8, 10)
            .tickPadding(5)
            .scale(d3.scale.linear()
            .domain([0, 120])
            .range([-3*Math.PI/4, 3*Math.PI/4]))
                
        @append("g")
            .attr("class", "gauge")
            .attr("transform", "translate(-40, -20)")
            .call(@gauge)
                
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", 95)
            .attr("y", 180)
            .text("GtC/yr")
            .attr("fill","grey")
            .attr("title","Gigatonnes of carbon per year.")
        
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", 50)
            .attr("y", 240)
            .text("Carbon emissions")
            .attr("fill","black")
            .attr("title","Anthropogenic carbon in gigatonnes per year.")
            
    val: (val) -> @gauge.value val


class Lights extends d3Object

    colors: ["red", "yellow", "lime"]

    constructor: (@goCallback) ->
        
        super "lights"
        
        @lights = @obj
            .append("svg")  
            .append("g")
            .attr("transform", "translate(30, 30)")
        
        tl = []
        for color, k in @colors
            tl.push 
                x: 20
                y: [5, 75 ,145][k]
                radius: 30
                fill: color
                id: color
        
        @lights.selectAll("circle").data(tl).enter()
            .append("circle")
            .attr(
                "class": "lights"
                "r": (d) -> d.radius
                "cx": (d) -> d.x
                "cy": (d) -> d.y
                "id": (d) -> d.id
            )
            .style(
                "fill": (d) -> d.fill
            )
        
        @go = @lights.append("text")
            .attr("text-anchor", "left")
            .attr("x", 6)
            .attr("y", 151)
            .attr("id","go")
            .text("GO!")
                        
        @reset()
                
    reset: ->
        @setState 0
        @enableGo true
    
    setState: (@state) ->
        color = @colors[2-@state]
        circle = @lights.selectAll "circle"
        circle.style("opacity": -> 0.1)
        circle.filter((d) -> d.fill == color).style("opacity": -> 1)
        
    enableGo: (enable=true) ->
        cursor = if enable then "pointer" else "default"
        callback = if enable then (=> @goCallback()) else (->)
        @go.attr "cursor", cursor
        #@go.attr "title", (if enable then "Start the simulation" else "Simulation running")
        @go.on "click", callback
        go2 = $ "#rerun"
        go2.css "cursor", cursor
        go2.click callback 


class Brake extends d3Object
    
    constructor: ->
        
        super "warning"

        @append("text")
            .attr("text-anchor", "left")
            .attr("x", -1)
            .attr("y", 15)
            .attr("id","brake_warn")
            .text("BRAKE!")
            .attr("fill","blue")
            .attr("opacity",0)
        
        @warning = $ "#brake_warn"
            
        @slider = $ "#brake_slider"
            
        @slider.slider
            orientation: "vertical"
            range: "min"
            min: 0
            max: 0.1
            value: 0
            step: 0.001
            
        # Make unselectable on touch devices.
        @slider[0].onselectstart = -> false 
        @slider[0].unselectable = "on"
        @slider.css {"-moz-user-select": "none", "-webkit-user-select": "none"}
            
        new BrakeScale
        @data = new BrakeData
        
        @reset()
                
    reset: ->
        @slider.slider "value", 0
        @pressed = false
        @year = 100000
        @dateDisplay 8888
        @enable false
        
    enable: (enable=true) ->
        @slider.slider(if enable then "enable" else "disable")
        @warning.css opacity: (if enable then 1 else 0)    
    
    getValue: ->
        @slider.slider "value"
    
    dateDisplay: (val) ->
        @data.val val
        
    check: (k) ->
        # Checks brakes if not already hit
        val = @getValue()
        return val unless val>0 and not @pressed
        @pressed = true
        @dateDisplay k
        @year = k
        @enable false
        val
        
class BrakeScale extends d3Object

    constructor: ->
        
        super "brake_scale"

        @append("g")
            .attr("class", "axis")
            .attr("transform", "translate(55,26)")
            .call(@s_axis)
        
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", -225)
            .attr("y", 15)
            .attr("transform","rotate(-90)")
            .text("Emissions reduction %/yr")
            .attr("fill","grey")
            .attr("title","A global mitigation scheme (GMS) causes emissions to reduce exponentially at the selected level.")        

    initAxes: ->
        # 's' in Stocker
        @s_to_px = d3.scale.linear()
            .domain([10, 0])
            .range([0, 200])
        
        @s_axis = d3.svg.axis() 
            .scale(@s_to_px)
            .ticks(6)
            .orient("left")

class BrakeData extends d3Object

    constructor: ->
        
        super "brake_data"
        
        @dateDisp = iopctrl.segdisplay()
            .width(80)
            .digitCount(4)
            .negative(false)
            .decimals(0)
        
        @append("g")
            .attr("class", "datedisplay")
            .attr("transform", "translate(210, 30)")
            .call(@dateDisp)
        
        @append("text")
            .attr("text-anchor", "left")
            .attr("x", 50)
            .attr("y", 50)
            .text("GMS braking starts:")
            .attr("title","Global mitigation scheme (GMS) starts at this date.")
            
    val: (val) -> @dateDisp.value(val)


class SimDate extends d3Object

    constructor: (@clickCallback) ->

        super "date"
        
        @disp = iopctrl.segdisplay()
            .width(300)
            .digitCount(4)
            .negative(false)
            .decimals(0)
        
        @append("g")
            .attr("class", "datedisplay")
            .attr("transform", "translate(0, 40)")
            .style("cursor", "pointer")
            .call(@disp)
            .on("click", => @clickCallback()) 
        
        @val 8888
        
    val: (val) -> @disp.value val


class Simulation

    constructor: ->
        
        @stockerModel = new StockerModel
        @beta = @stockerModel.beta
        @road = new Road @beta
        @car = new Car @road
        @speedo = new Speedo
        @lights = new Lights (=> @animateOnGo())
        @brake = new Brake
        @date = new SimDate (=> @toggleAnimate())
        
        t1 = 2000
        s = 0.2
        @compute @stockerModel.tx, t1, s
        
        @initMathJaxHandler()
        $(document).on "mathjaxPreConfig", => @initMathJaxHandler()
        
    initMathJaxHandler: ->
        @scheduleFirstAnimation() if MathJax?.Hub.queue.queue.length is 0
        MathJax?.Hub.Register.MessageHook "End Process", => @scheduleFirstAnimation()
        # Alt: MathJax.Hub.Register.StartupHook "MathMenu Ready", =>
        
    scheduleFirstAnimation: ->
        setTimeout (=> @animate 1750, 2500, 30000), 200
        
    animateOnGo: ->
        @animate(1750, 2500, 20000)
        
    toggleAnimate: ->
        unless @simulating
            @animateOnGo()
            return
        if @timer
            @resetRunTimer()
            @pauseStart = @currentTime()
        else
            @pauseTime += (@currentTime() - @pauseStart) if @pauseStart
            @startRunTimer()
    
    animate: (@from, @to, @time) ->
        @simulating = true
        @pauseTime = 0
        #@resetRunTimer()
        @lights.reset()    
        @brake.reset()
        @start = @currentTime()
        @startRunTimer()
        
    run: ->
        step = Math.min(1, (@currentTime()-@pauseTime-@start)/@time)
        k = @from + step*(@to-@from)
        @compute k
        @stop "slowed to stop" if @emis < 0.02 and @temperature > 1
        @stop "out of screen" if @temperature > 12
        @stop "step at limit" if step is 1
    
    compute: (k, t1=null, s=null) ->
                
        # ZZZ use constants here for years
        if 1909 < k < 2009 and (@lights.state is 0)
            @lights.setState 1
        else if k>=2009 and @lights.state is 1
            @lights.setState 2
            @brake.enable true
                
        s ?= @brake.check(k)
        t1 ?= @brake.year
        
        @carbon = @stockerModel.Ct(k, t1, s)
        @emis = @stockerModel.Et(k, t1, s)

        @speedo.val @emis
        @date.val k
        
        @temperature  = @beta*@carbon
        @car.draw @temperature   
            
    stop: (condition) ->
        @simulating = false
        @resetRunTimer()
        @brake.enable false
        @lights.enableGo true
        console.log "Stopping condition: #{condition}"
        console.log "Et", @emis
        console.log "temp", @temperature
        
    startRunTimer: ->
        @resetRunTimer()
        @timer = setInterval (=> @run()), 100

    resetRunTimer: ->
        return unless @timer
        clearInterval @timer
        @timer = null 
        
    currentTime: -> new Date().getTime()
        

new Simulation


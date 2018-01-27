extensions [table]

;; SETUP

;; These variables all apply to only one car
turtles-own [
  ;; Variables that other cars have access to
  current-speed        ;; the current speed of the car
                       ;; xcor is included
                       ;; ycor is included by default
  desired-speed        ;; the speed the car wants to change to
  desired-lane         ;; the lane the car wants to change to

  ;; table containing above information
  ;; [ current-speed xcor ycor desired-speed desired-lane ]
  car-information

  ;; information about surrounding cars:
  ;; current-speed, xcor and ycor, and their intentions (speed and lane)
  car-left             ;; information about car to the left
  car-front-left       ;; information about car to the front left
  car-front            ;; information about car in front
  car-front-right      ;; information about car to the front right
  car-right            ;; information about car to the right

  ;; table containing above information
  ;; [ car-left car-front-left car-front car-front-right car-right ]
  surrounding-cars
]

globals [
  ;; Global monitoring
  collision-count

  ;; Road information
  road-y-min
  road-y-max
  road-color
  road-border-color
  road-lane-separator-color
  road-lane-separator-1-ycor
  road-lane-separator-2-ycor
  road-lane-separator-1-x-distance
  road-lane-separator-2-x-distance
  road-background-color
  lane-coordinates

  ;; Car information
  car-shape
  car-heading
  initial-speed-constant
  initial-speed-variable
  car-color-range

  ;; Relative positions
  relative-left
  relative-front
  relative-right
  relative-here
]

;; CONSTANTS
to set-constants
  ;; Road information
  set road-y-min -6
  set road-y-max 6
  set road-color gray
  set road-border-color black
  set road-lane-separator-color white
  set road-lane-separator-1-ycor 2
  set road-lane-separator-2-ycor -2
  set road-lane-separator-1-x-distance 3
  set road-lane-separator-2-x-distance -3
  set road-background-color green
  set lane-coordinates [-4 0 4]

  ;; Car information
  set car-shape "car"
  set car-heading 90
  set initial-speed-constant 100
  set initial-speed-variable 30
  set car-color-range 140

  ;; Relative positions (left and right should be switched
  ;; if heading changes)
  set relative-left 4
  set relative-front 1
  set relative-right -4
  set relative-here 0
end

to setup
  ;; clear everything
  clear-all
  ;; set constants
  set-constants
  ;; reset collision counter
  set collision-count 0
  ;; draw road and surroundings
  draw-road
  ;; give cars their shape
  set-default-shape turtles car-shape
  ;; create cars
  create-turtles number [ setup-cars ]
  ;; reset tick counter
  reset-ticks
end

;; Function to draw road and surroundings
to draw-road
  ask patches [
    ;; Color all patches in background color
    set pcolor (road-background-color)
    ;; Color patches within range in road color
    if ((pycor > (road-y-min)) and
        (pycor < (road-y-max))) [
      set pcolor (road-color)
    ]
    ;; Color lane separators on road
    if ((pycor = (road-lane-separator-1-ycor)) and
        ((pxcor mod (road-lane-separator-1-x-distance)) =
         (road-lane-separator-1-ycor))) [
      set pcolor (road-lane-separator-color)
    ]
    if ((pycor = (road-lane-separator-2-ycor)) and
        ((pxcor mod (road-lane-separator-2-x-distance)) =
         (road-lane-separator-2-ycor))) [
      set pcolor (road-lane-separator-color)
    ]
    ;; Color patches with ycor 6 or -6 black for borders of road
    if ((pycor = (road-y-max)) or
        (pycor = (road-y-min))) [
      set pcolor (road-border-color)
    ]
  ]
end

to setup-cars
  ;; Give each car random color
  set color (random car-color-range)
  ;; Give each car random xcor and ycor of random lane
  setxy random-xcor one-of lane-coordinates
  ;; Set heading
  set heading car-heading
  ;; Initial speed for all cars is set
  set current-speed ((initial-speed-constant + random-float initial-speed-variable) / 100)

  ;; Put public variables in table car-information
  set car-information table:make
  table:put car-information "current-speed" current-speed
  table:put car-information "xcor" xcor
  table:put car-information "ycor" ycor
  ;; set desired-speed to negative number
  table:put car-information "desired-speed" -1
  ;; set desired-lane to non-existing lane
  table:put car-information "desired-lane" -10

  ;; Create table to be filled with surrounding cars data
  set surrounding-cars table:make

  ;; Make sure no two cars are on the same patch
  loop [ ifelse any? other turtles-here [ fd 1 ] [ stop ] ]
end

;; DRIVING LOOP, ADJUSTED TO NEW MESSAGE PASSING
to drive
  ;; first let all cars check surroundings and decide on action
  ask turtles [
    ;; car checks surroundings: speed, position and intention of other cars
    check-surroundings
    ;; car makes decision on speed and lane: change or keep the same
    make-decision
  ]
  ;; then let all cars act upon decisions and update public information
  ask turtles [
    ;; car acts based on decision
    move
    ;; car updates public information
    update-own-information
  ]
  tick
end

;; VEHICLE PROCEDURES - CHECK SURROUNDINGS
to check-surroundings
  ;; check if any cars are directly to the left of the current car and if so,
  ;; get their information
  ifelse (any? turtles-at relative-here relative-left) [
    set car-left [car-information] of (one-of turtles-at relative-here relative-left)
  ] [
    set car-left false
  ]
  ;; check if any cars are to the front-left of the current car and if so,
  ;; get their information
  ifelse (any? turtles-at relative-front relative-left) [
    set car-front-left [car-information] of (one-of turtles-at relative-front relative-left)
  ] [
    set car-front-left false
  ]
  ;; check if any cars are directly in front of the current car and if so,
  ;; get their information
  ifelse (any? turtles-at relative-front relative-here) [
    set car-front [car-information] of (one-of turtles-at relative-front relative-here)
  ] [
    set car-front false
  ]
  ;; check if any cars are to the front-right of the current car and if so,
  ;; get their information
  ifelse (any? turtles-at relative-front relative-right) [
    set car-front-right [car-information] of (one-of turtles-at relative-front relative-right)
  ] [
    set car-front-right false
  ]
  ;; check if any cars are directly to the right of the current car and if so,
  ;; get their information
  ifelse (any? turtles-at relative-here relative-right) [
    set car-right [car-information] of (one-of turtles-at relative-here relative-right)
  ] [
    set car-right false
  ]

  ;; fill table surrounding-cars with tables car-information of surrounding cars
  table:put surrounding-cars "car-left" car-left
  table:put surrounding-cars "car-front-left" car-front-left
  table:put surrounding-cars "car-front" car-front
  table:put surrounding-cars "car-front-right" car-front-right
  table:put surrounding-cars "car-right" car-right
end

;; VEHICLE PROCEDURES - MAKE DECISION
to make-decision
  ;; INPUT: table surrounding-cars containing 5 tables:
  ;; car-left, car-front-left, car-front, car-front-right, car-right

  ;; If a surrounding car has no specific desired speed or lane,
  ;; set to random or set to current speed and lane
  foreach (table:keys surrounding-cars) [
    if ((table:get car-information "desired-speed" = -1) and
            (table:get car-information "desired-lane" = -10)) [
      ifelse (decision-assume-random?) [
        table:put car-information "desired-speed" random 10
        table:put car-information "desired-speed" one-of [-4 0 4]
      ] [
        table:put car-information "desired-speed" (table:get car-information "current-speed")
        table:put car-information "desired-lane" (table:get car-information "ycor")
      ]
    ]
  ]
  ;; OUTPUT: set desired-speed, desired-lane for current car
end

;; VEHICLE PROCEDURES - MOVE
to move
  jump current-speed
  if (any? turtles-at relative-here relative-here) [
    set collision-count (collision-count + 1)
  ]
end

;; VEHICLE PROCEDURES - SPEED UP
to speed-up
  set current-speed (current-speed + (acceleration))
end

;; VEHICLE PROCEDURES - SLOW DOWN
to slow-down
  set current-speed (current-speed - (deceleration))
end

;; VEHICLE PROCEDURES - UPDATE OWN INFORMATION
to update-own-information
  table:put car-information "current-speed" current-speed
  table:put car-information "xcor" xcor
  table:put car-information "ycor" ycor
  table:put car-information "desired-speed" desired-speed
  table:put car-information "desired-lane" desired-lane
end

; Copyright 1998 Uri Wilensky (original model).
; See Info tab for full copyright and license.
; Edited 2016 by Jan Rezelman and Nousha van Dijk
; for the Collective Intelligence course at VU University, Amsterdam
; Edited 2017 by Jan Rezelman for Bachelor Project
@#$#@#$#@
GRAPHICS-WINDOW
181
14
729
245
-1
-1
10.6
1
10
1
1
1
0
1
0
1
-25
25
-10
10
1
1
1
ticks
30.0

BUTTON
6
35
87
68
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
7
74
87
107
go
drive
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
95
35
173
68
go once
drive
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

MONITOR
556
254
670
299
Average speed
mean [current-speed] of turtles
2
1
11

SLIDER
8
133
170
166
number
number
0
134
134.0
1
1
NIL
HORIZONTAL

SLIDER
9
218
171
251
deceleration
deceleration
0
100
78.0
1
1
NIL
HORIZONTAL

SLIDER
8
173
170
206
acceleration
acceleration
0
100
39.0
1
1
NIL
HORIZONTAL

PLOT
182
254
548
430
Car Speeds
Time
Speed
0.0
300.0
0.0
1.5
true
true
"set-plot-y-range 0 ((max [speed-limit] of turtles) + .5)" ""
PENS
"average" 1.0 0 -10899396 true "" "plot mean [current-speed] of turtles"
"max" 1.0 0 -11221820 true "" "plot max [current-speed] of turtles"
"min" 1.0 0 -13345367 true "" "plot min [current-speed] of turtles"
"selected-car" 1.0 0 -2674135 true "" "plot [current-speed] of selected-car"

SWITCH
10
263
170
296
decision-assume-random?
decision-assume-random?
0
1
-1000

MONITOR
556
302
670
347
Collision count
collision-count
0
1
11

TEXTBOX
9
115
159
133
Settings
11
0.0
1

TEXTBOX
7
16
163
34
Run commands
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This project is a more sophisticated two-lane version of the "Traffic Basic" model.  Much like the simpler model, this model demonstrates how traffic jams can form. In the two-lane version, drivers have a new option; they can react by changing lanes, although this often does little to solve their problem.

As in the traffic model, traffic may slow down and jam without any centralized cause.

## HOW TO USE IT

Click on the SETUP button to set up the cars. Click on DRIVE to start the cars moving. The STEP button drives the car for just one tick of the clock.

The NUMBER slider controls the number of cars on the road. The LOOK-AHEAD slider controls the distance that drivers look ahead (in deciding whether to slow down or change lanes). The SPEED-UP slider controls the rate at which cars accelerate when there are no cars ahead. The SLOW-DOWN slider controls the rate at which cars decelerate when there is a car close ahead.

You may wish to slow down the model with the speed slider to watch the behavior of certain cars more closely.

The SELECT-CAR button allows you to pick a car to watch. It turns the car red, so that it is easier to keep track of it. SELECT-CAR is best used while DRIVE is turned off. If the user does not select a car manually, a car is chosen at random to be the "selected car".

The AVERAGE-SPEED monitor displays the average speed of all the cars.

The CAR SPEEDS plot displays four quantities over time:
- the maximum speed of any car - CYAN
- the minimum speed of any car - BLUE
- the average speed of all cars - GREEN
- the speed of the selected car - RED

## THINGS TO NOTICE

Traffic jams can start from small "seeds." Cars start with random positions and random speeds. If some cars are clustered together, they will move slowly, causing cars behind them to slow down, and a traffic jam forms.

Even though all of the cars are moving forward, the traffic jams tend to move backwards. This behavior is common in wave phenomena: the behavior of the group is often very different from the behavior of the individuals that make up the group.

Just as each car has a current speed and a maximum speed, each driver has a current patience and a maximum patience. When a driver decides to change lanes, he may not always find an opening in the lane. When his patience expires, he tries to get back in the lane he was first in. If this fails, back he goes... As he gets more 'frustrated', his patience gradually decreases over time. When the number of cars in the model is high, watch to find cars that weave in and out of lanes in this manner. This phenomenon is called "snaking" and is common in congested highways.

Watch the AVERAGE-SPEED monitor, which computes the average speed of the cars. What happens to the speed over time? What is the relation between the speed of the cars and the presence (or absence) of traffic jams?

Look at the two plots. Can you detect discernible patterns in the plots?

## THINGS TO TRY

What could you change to minimize the chances of traffic jams forming, besides just the number of cars? What is the relationship between number of cars, number of lanes, and (in this case) the length of each lane?

Explore changes to the sliders SLOW-DOWN, SPEED-UP, and LOOK-AHEAD. How do these affect the flow of traffic? Can you set them so as to create maximal snaking?

## EXTENDING THE MODEL

Try to create a 'traffic-3 lanes', 'traffic-4 lanes', 'traffic-crossroads' (where two sets of cars might meet at a traffic light), or 'traffic-bottleneck' model (where two lanes might merge to form one lane).

Note that the cars never crash into each other- a car will never enter a patch or pass through a patch containing another car. Remove this feature, and have the turtles that collide die upon collision. What will happen to such a model over time?

## NETLOGO FEATURES

Note the use of `mouse-down?` and `mouse-xcor`/`mouse-ycor` to enable selecting a car for special attention.

Each turtle has a shape, unlike in some other models. NetLogo uses `set shape` to alter the shapes of turtles. You can, using the shapes editor in the Tools menu, create your own turtle shapes or modify existing ones. Then you can modify the code to use your own shapes.

## RELATED MODELS

Traffic Basic

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Traffic 2 Lanes model.  http://ccl.northwestern.edu/netlogo/models/Traffic2Lanes.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1998 2001 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
setup
repeat 50 [ drive ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

;; SETUP

breed [cars car]
breed [traces trace]

globals
[
  closed-lane          ;; the closed lane
  closed-lane?         ;; true if a lane is closed

  ;; lane densities for deciding what lane is most favorable, updated each tick
  left-lane-density
  middle-lane-density
  right-lane-density
]

cars-own               ;; These variables all apply to only one car
[
  speed                ;; the current speed of the car
  speed-limit          ;; the maximum speed of the car (different for all cars)
  global-speed-limit   ;; the maximum speed allowed when a lane is closed (if enabled)
  change?              ;; true if the car wants to change lanes (appears to be unused)
  open-lane-left?      ;; true if there is an open lane left of the vehicle
  open-lane-right?     ;; true if there is an open lane right of the vehicle
  left-moving?         ;; true if the cars in the lane left of the car are moving
  right-moving?        ;; true if the cars in the lane right of the car are moving
  has-switched?        ;; true if the car has switched lanes after a lane was closed
  ticks-since-switch   ;; number of ticks since car switched lanes: a car can only change lanes again after a number of ticks to make them less nervous and more realistic
  max-wait-ticks       ;; random number that dictates how long a car waits before it chooses a better lane
  current-position     ;; saves current position to compare to later position

  ;; surrounding cars. for all variables: true if a car is present at the indicated position
  car-to-side-left?
  car-to-side-right?
  car-in-front?
  car-in-front-left?
  car-in-front-right?
]

traces-own
[
  strength
]

to setup
  clear-all                            ;; clear area
  draw-environment                     ;; draw road and surroundings
  set-default-shape cars "car"         ;; give cars their shape
  set-default-shape traces "dot"
  create-cars number [ setup-cars ] ;; create cars
  reset-ticks
  set closed-lane? false
  set closed-lane -10
end

;; Function to draw road and surroundings
to draw-environment
  ask patches [
    set pcolor green                                                  ;; Color all patches green for grass
    if ((pycor > -6) and (pycor < 6)) [ set pcolor gray ]             ;; Color patches with -6 < ycor < 6 gray for road
    if ((pycor = 2) and ((pxcor mod 3) = 2)) [ set pcolor white ]     ;; Color every third patch with ycor 2 or -2 white
    if ((pycor = -2) and ((pxcor mod -3) = -2)) [ set pcolor white ]  ;;  for lane separators on road
    if ((pycor = 6) or (pycor = -6)) [ set pcolor black ]             ;; Color patches with ycor 6 or -6 black for borders of road
  ]
end

to setup-cars
  set color (random 140)                     ;; Give each car random color
  setxy random-xcor one-of [-4 0 4]          ;; Give each car xcor -4, 0 or 4 for different lanes
  set heading 90                             ;; Heading is 90, to the right
  set speed 0.1 + random 9.9                 ;; Initial speed for all cars is set to 0.1 plus a random number to make sure not all cars are driving the same speed
  set speed-limit (((random 11) / 10) + 1)   ;; Set speed limit for a car
  set global-speed-limit 0.5                 ;; Global speed limit for all cars (disabled by default)
  set ticks-since-switch 0                   ;; Reset counter for ticks since last lane switch
  set max-wait-ticks (random 20)             ;; Number of ticks a car waits before it chooses a better lane is a random number up to 20

  ;; all boolean values must have an initual value, set to false in setup
  set change? false
  set open-lane-left? false
  set open-lane-right? false
  set left-moving? false
  set right-moving? false
  set has-switched? false

  set car-to-side-left? false
  set car-to-side-right? false
  set car-in-front? false
  set car-in-front-left? false
  set car-in-front-right? false

  loop [ ifelse any? other cars-here [ fd 1 ] [ stop ] ] ;; Make sure no two cars are on the same patch
end

;; DRIVING LOOP

to drive
  ask cars [
    look-ahead      ;; vehicle surroundings are checked
    adjust-speed    ;; adjust speed
  ]
  ; Now that all speeds are adjusted, give cars a chance to change lanes
  calculate-lane-densities
  ask cars [
    ;; check if left and right lane are available to change to
    check-open-lane-left
    check-open-lane-right
    ;; vehicle surroundings are checked again
    look-around
    ;; decide what action should be performed based on whether or not a lane is closed
    ifelse closed-lane? and not has-switched? [ perform-closed-lane-actions ] [ perform-normal-situation-actions ] ;; if a lane has been closed and the car has not reacted to that yet, react to it. else, perform normal actions
    if ticks-since-switch > max-wait-ticks + 40 [ ;; every max-wait-ticks (depends on car) + 40 ticks, a car chooses the best lane it can be in
      choose-best-lane
      set ticks-since-switch 0
    ]
    set ticks-since-switch (ticks-since-switch + 1) ;; increase ticks since switch with 1
    jump speed
    hatch-traces 1 [ leave-trace ]
  ]

  ;; fade traces
  ask traces [
    set strength (strength - 5)
    if strength = 0 [ die ]
    if strength < 50 [ set color orange ]
    if strength < 25 [ set color yellow ]
    if strength < 10 [ set color green ]
  ]

  ;; TODO count total of trace strengths on each patch
  ask patches [

  ]

  tick
end

to leave-trace
  set color red
  set strength 100
end

;; VEHICLE PROCEDURES - MAKING DECISIONS

to perform-normal-situation-actions
  ;; Control for making sure no one crashes.
  ifelse (car-in-front?) and (xcor != min-pxcor - .5) [
    set speed [speed] of (one-of cars-at 1 0)           ;; if a car is directly in front of current car, set speed of current car to speed of car in front
  ]
  [
    if ((any? cars-at 2 0) and (speed > 1.0)) [         ;; if no car is directly in front, but there is a car 2 patches away and speed is already > 1, set speed of current car to speed of car in front
      set speed ([speed] of (one-of cars-at 2 0))
      fd 1
    ]
  ]
end

to perform-closed-lane-actions
  if ycor = closed-lane [
    move-out-of-closed-lane                                ;; if the lane the car is on is closed, move out of the lane
    if ycor != closed-lane [ set has-switched? true ]      ;; car has switched
    stop
  ]
  if ycor = 0 [
    make-room-for-merging-cars                             ;; the closed lane is always one of the outer lanes. Therefore, cars in the middle lane should make room for merging cars from the closed lane
    set has-switched? true                                 ;; car has switched
    stop
  ]
  if ycor = closed-lane - 8 or ycor = closed-lane + 8 [    ;; if the car is already on the lane farthest from the closed lane, do nothing
    set has-switched? true
  ]
end

to choose-best-lane
  ;; switch lanes based on whether or not the density on another lane is lower
  if ycor = -4 and middle-lane-density < right-lane-density and not car-in-front-left? [                               ;; if on right lane and middle lane is less busy and than current lane, move left
    move-left
    stop
  ]
  if ycor = 4 and middle-lane-density < left-lane-density and not car-in-front-right? [                                ;; if on left lane and middle lane is less busy and than current lane, move right
    move-right
    stop
  ]
  if ycor = 0 and left-lane-density < middle-lane-density and not car-in-front-left? and (not (closed-lane = 4)) [     ;; if on middle lane and left lane is less busy and than current lane, move left
    move-left
    stop
  ]
  if ycor = 0 and right-lane-density < middle-lane-density and not car-in-front-right? and (not (closed-lane = -4)) [  ;; if on middle lane and right lane is less busy and than current lane, move right
    move-right
    stop
  ]
end


;; VEHICLE PROCEDURES - MOVING

;; increase speed of cars
to accelerate  ;; car procedure
  set speed (speed + (speed-up / 1000))
end

;; reduce speed of cars
to decelerate  ;; car procedure
  set speed (speed - (slow-down / 1000))
end

;; move the vehicle to the lane left of the current lane
to move-left
  ;; check if there are no cars directly to the left and if car is not already in left outer lane
  look-left
  if (not car-to-side-left?) and (ycor + 4 <= 4) and (ycor + 4 != closed-lane) [ set ycor (ycor + 4) ]
end

;; move the vehicle to the lane right of the current lane
to move-right
  ;; check if there are no cars directly to the right and if car is not already in right outer lane
  look-right
  if (not car-to-side-right?) and (ycor - 4 >= -4) and (ycor - 4 != closed-lane) [ set ycor (ycor - 4) ]
end

;; move the vehicle to the lane right of the current lane and move one step forward
to move-front-right
  look-front-right
  if (not car-to-side-right?) and (ycor - 4 >= -4) and (ycor - 4 != closed-lane) [
    set xcor (xcor + 1)
    set ycor (ycor - 4)
  ]
end

;; move the vehicle to the lane left of the current lane and move one step forward
to move-front-left
  look-front-left
  if (not car-to-side-left?) and (ycor + 4 <= 4) and (ycor + 4 != closed-lane) [
    set xcor (xcor + 1)
    set ycor (ycor + 4)
  ]
end

;; moves car in closed lane out of it
to move-out-of-closed-lane
  set current-position (ycor)
  ifelse ycor = 4 [ move-front-right ] [ move-front-left ]
  if ycor = current-position [ jump speed ]
end

to make-room-for-merging-cars
  ifelse ycor = closed-lane - 4 [ move-right ] [ move-left ]
end

to adjust-speed
  ;; All cars look first to see if there is a car directly in front of it,
  ;; if so, set own speed to front car's speed and decelerate. If no front
  ;; cars are found, accelerate towards speed-limit
  ifelse (car-in-front?) [
    set speed ([speed] of (one-of (cars-at 1 0)))
    decelerate
  ]
  [
    accelerate
  ]
  ;; Keeps vehicles moving
  if (speed < 0.01) [ set speed 0.01 ]

  ;; If vehicles exceed the speed limit, their speed is set to the speed limit
  if (speed > speed-limit) [ set speed speed-limit ]

  ;; If the global speed limit is enabled, vehicles will maintain an adjusted maximum speed when a lane is closed, to make more room for merging cars
  if (global-speed-limit?) and (closed-lane?) and (speed > global-speed-limit) [ set speed global-speed-limit ]
end



;; VEHICLE PROCEDURES - CHECKING SURROUNDINGS

;; check if vehicles in lane right of vehicle are moving
to check-left-moving
  ifelse (([speed] of one-of (cars-at 1 4)) > 0.01) or (not any? cars-at 1 4) [ set left-moving? true ] [ set left-moving? false ]
end

;; check if vehicles in lane left of vehicle are moving
to check-right-moving
  ifelse (([speed] of one-of (cars-at 1 -4)) > 0.01) or (not any? cars-at 1 -4) [ set right-moving? true ] [ set right-moving? false ]
end

;; check lanes the vehicle can go to
;; example: if lane left of vehicle is closed or if vehicle is already in outer left lane, it cannot move left
to check-open-lane-left
  ifelse ((ycor + 4 > 4) or (ycor + 4 = closed-lane)) [ set open-lane-left? false ] [ set open-lane-left? true ]
end

to check-open-lane-right
  ifelse ((ycor - 4 < -4) or (ycor - 4 = closed-lane)) [ set open-lane-right? false ] [ set open-lane-right? true ]
end

;; determine presence of surrounding vehicles by checking relevant surrounding patches
to look-around
  look-ahead
  look-left
  look-right
  look-front-left
  look-front-right
end

to look-ahead
  ifelse (any? cars-at 1 0) [ set car-in-front? true ] [ set car-in-front? false]             ;; check if any cars are directly in front of the current car and set the corresponding boolean variable of the car
end

to look-left
  ifelse (any? cars-at 0 4) [ set car-to-side-left? true ] [ set car-to-side-left? false]     ;; check if any cars are directly to the left of the current car and set the corresponding boolean variable of the car
end

to look-right
  ifelse (any? cars-at 0 -4) [ set car-to-side-right? true ] [ set car-to-side-right? false]  ;; check if any cars are directly to the right of the current car and set the corresponding boolean variable of the car
end

to look-front-left
  ifelse (any? cars-at 1 4) [ set car-in-front-left? true ] [ set car-in-front-left? false]   ;; check if any cars are in the left front of the current car and set the corresponding boolean variable of the car
end

to look-front-right
  ifelse (any? cars-at 1 -4) [ set car-in-front-right? true ] [ set car-in-front-right? false];; check if any cars are in the right front of the current car and set the corresponding boolean variable of the car
end



;; PROCEDURES FOR CLOSING/OPENING LANES

;; close one of outer lanes
to close-lane
  if not closed-lane? [                                          ;; check if no lane has been closed already
    set closed-lane one-of [-4 4]                                ;; pick random lane to be closed, either left or right lane
    ask patches
    [ ifelse (closed-lane = -4)
      [ if ((pycor > -6) and (pycor < -2)) [ set pcolor red ]]   ;; if closed-lane has ycor -4, e.g. the right lane should be closed, colour that lane red
      [ if ((pycor < 6) and (pycor > 2)) [ set pcolor red ]]     ;; else, closed-lane must have ycor 4 e.g. left lane should be closed, colour that lane red
    ]
    set closed-lane? true                                        ;; global variable closed-lane? is set to true to indicate a lane is closed
  ]
end

;; re-open closed lane
to re-open-lane
  if closed-lane? [
    ask patches
    [ ifelse (closed-lane = -4)
      [ if ((pycor > -6) and (pycor < -2)) [ set pcolor gray ]] ;; if closed-lane has ycor -4, e.g. the right lane is closed, colour that lane gray again
      [ if ((pycor < 6) and (pycor > 2)) [ set pcolor gray ]]   ;; else, closed-lane must have ycor 4 e.g. left lane is closed, colour that lane gray again
    ]
    set closed-lane? false                                      ;; global variable closed-lane? is set to false to indicate no lane is closed
    set closed-lane -10                                         ;; closed-lane is set to -10, which is a beyond the range of the model so it will not interfere with anything
  ]
  ask cars [ set has-switched? false ]                       ;; for all cars that have switched lanes after the lane was closed, the has-switched? property should be reset
end



;; PROCEDURES FOR CALCULATING GLOBAL DATA

to calculate-lane-densities
  reset-lane-densities
  ask cars [
    ;; For each car on a lane, the density of that lane is increased by 1
    if ycor = 4 [ set left-lane-density (left-lane-density + 1) ]
    if ycor = 0 [ set middle-lane-density (middle-lane-density + 1) ]
    if ycor = -4 [ set right-lane-density (right-lane-density + 1) ]
  ]
end

to reset-lane-densities
  set left-lane-density 0
  set middle-lane-density 0
  set right-lane-density 0
end



;; TEST AREA FOR MODEL DEVELOPMENT

to move-all-right
  ask cars [ move-right ]
end

to move-all-left
  ask cars [ move-left ]
end

; Copyright 1998 Uri Wilensky (original model).
; See Info tab for full copyright and license.
; Edited 2016 by Jan Rezelman and Nousha van Dijk for the Collective Intelligence course at VU University, Amsterdam
@#$#@#$#@
GRAPHICS-WINDOW
271
21
819
252
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
9
36
84
69
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
121
86
154
go
drive
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
77
92
110
go once
drive
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
270
466
384
511
average speed
mean [speed] of turtles
2
1
11

SLIDER
104
36
266
69
number
number
0
134
3.0
1
1
NIL
HORIZONTAL

SLIDER
104
116
266
149
slow-down
slow-down
0
100
78.0
1
1
NIL
HORIZONTAL

SLIDER
104
75
266
108
speed-up
speed-up
0
100
38.0
1
1
NIL
HORIZONTAL

PLOT
271
282
637
458
Car Speeds
Time
Speed
0.0
300.0
0.0
2.5
true
true
"set-plot-y-range 0 ((max [speed-limit] of turtles) + .5)" ""
PENS
"average" 1.0 0 -10899396 true "" "plot mean [speed] of turtles"
"max" 1.0 0 -11221820 true "" "plot max [speed] of turtles"
"min" 1.0 0 -13345367 true "" "plot min [speed] of turtles"
"selected-car" 1.0 0 -2674135 true "" "plot [speed] of selected-car"

BUTTON
5
257
110
290
close lane
close-lane
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
3
297
127
330
re-open lane
re-open-lane
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
5
347
195
380
global-speed-limit?
global-speed-limit?
1
1
-1000

BUTTON
999
62
1100
95
NIL
move-all-left
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
999
100
1107
133
NIL
move-all-right
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
999
31
1149
59
Test area for model development
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

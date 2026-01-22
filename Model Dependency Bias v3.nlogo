globals [
  right-nutrition
  left-nutrition
  divider-x  ;; The x-coordinate of the dividing line between left and right sections
  deadwL
  deadwR

]

turtles-own [
  diet-level  ;; Turtles will have a property to represent their nutrition level
  steps-without-food  ;; Count how many steps the turtle takes without eating
  weight  ;; New variable to store the weight of each turtle
]

patches-own [
  has-food  ;; Each patch will have a boolean to indicate whether it has food
  originally-had-food  ;; Boolean: whether the patch originally had food during setup
  food-level         ;; A numeric value for the regrowth process (0 = no food, 1 = full food)

]

; This procedure sets up the world and the turtles
to setup
  clear-all

  ; Conditionally seed the random number generator
  if Repeatable-Run [ random-seed 12345 ]


  set deadwL[]
  set deadwR[]

  ; Set the dividing line in the center of the world
  set divider-x 0

  ; Initialize the nutrition levels using sliders
  set right-nutrition Habitat-B-nutrition-level
  set left-nutrition Habitat-A-nutrition-level

  ; Mark food patches in each habitat
  mark-food-patches-left
  mark-food-patches-right

  ; Create an identical list of weights for both groups
  let initial-weights n-values 50 [random-normal 100 15]  ;; Generate 50 weights

  ; Create turtles in the left section (xcor < divider-x) and set their diet to left-nutrition
  create-turtles 50 [
    setxy random-float (divider-x - min-pxcor) + min-pxcor random-ycor  ; Ensure turtle is on left
    set shape "sheep"
    set color red
    set diet-level left-nutrition

  ]

  ; Assign weights to left-side turtles
  let count-index 0
  ask turtles with [xcor < divider-x] [
    set weight item count-index initial-weights
    set count-index count-index + 1
  ]

  ; Create turtles in the right section (xcor >= divider-x) and set their diet to right-nutrition
  create-turtles 50 [
    setxy random-float (max-pxcor - divider-x) + divider-x random-ycor  ; Ensure turtle is on right
    set color blue
    set shape "sheep"
    set diet-level right-nutrition

  ]

  ; Reset index and assign identical weights to right-side turtles
  set count-index 0
  ask turtles with [xcor >= divider-x] [
    set weight item count-index initial-weights
    set count-index count-index + 1
  ]

  reset-ticks
end


; This updates the turtle sizes and restricts their movement
to go

  if count turtles with [xcor < divider-x] <= 2 or count turtles with [xcor >= divider-x] <= 1 [
    stop  ;; End the simulation if condition is met
  ]

  if ticks >= 1000 [
    stop
  ]

  ask turtles [
    if xcor < divider-x [  ; Left side turtles

      move-left-section  ; Move turtles in the left section
      eat-food ; Turtles consume food on the patches they step on
      check-if-dead  ; Check if the turtle has walked more than 5 steps without food

    ]
    if xcor >= divider-x [  ; Right side turtles

      move-right-section  ; Move turtles in the right section
      eat-food ; Turtles consume food on the patches they step on
      check-if-dead  ; Check if the turtle has walked more than 5 steps without food

    ]
  ]


  ; Plot the average weights only if there are turtles present
  let avg-weight-left (ifelse-value count turtles with [xcor < divider-x] > 0 [mean [weight] of turtles with [xcor < divider-x]] [0])
  let avg-weight-right (ifelse-value count turtles with [xcor >= divider-x] > 0 [mean [weight] of turtles with [xcor >= divider-x]] [0])


  set-current-plot "Average Weights"
  set-current-plot-pen "Habitat A"
  plot avg-weight-left

  set-current-plot-pen "Habitat B"
  plot avg-weight-right


  ; Calculate the cumulative weight * number of turtles for each section
  let cumulative-left sum [weight] of turtles with [xcor < divider-x]
  let cumulative-right sum [weight] of turtles with [xcor >= divider-x]

  ; Update plot for cumulative weight
  if Population-Weight [
    set-current-plot "Total Population Weight"
    set-current-plot-pen "Habitat A"
    plot sum [weight] of turtles with [xcor < divider-x]

    set-current-plot-pen "Habitat B"
    plot sum [weight] of turtles with [xcor >= divider-x]
  ]


  if Dead-Animals [
    set-current-plot "Dead Animals"
    set-current-plot-pen "Habitat A"
    plot 50 - count turtles with [xcor < divider-x]

    set-current-plot-pen "Habitat B"
    plot 50 - count turtles with [xcor > divider-x]
  ]


  ; Handle food regrowth in patches that originally had food
  ask patches with [originally-had-food and not has-food] [
    regrow-food
  ]

  tick
end

; Procedure to move turtles in the left section and restrict movement to that area
to move-left-section
  left random 360
  forward 1
  if xcor > divider-x [ set xcor divider-x - 0.1 ]  ; Prevent crossing to the right side
  if xcor < min-pxcor [ set xcor min-pxcor + 0.1 ]  ; Prevent crossing world boundary

  ;; Increment steps without food
  set steps-without-food steps-without-food + 1

end

; Procedure to move turtles in the right section and restrict movement to that area
to move-right-section
  left random 360
  forward 1
  if xcor < divider-x [ set xcor divider-x + 0.1 ]  ; Prevent crossing to the left side
  if xcor > max-pxcor [ set xcor max-pxcor - 0.1 ]  ; Prevent crossing world boundary

  ;; Increment steps without food
  set steps-without-food steps-without-food + 1

end

; Turtles consume food from the patches they step on
to eat-food

  if has-food-on-patch? [
    ;; Reset steps-without-food to 0 when food is found
    set steps-without-food 0

    ;; Increase the turtle's weight by 1 unit
    set weight weight + 0.01
  ]

  ask patch-here [
    if has-food [
      set has-food false  ; No more food on this patch
      set food-level 0    ; Food is fully consumed

      ; Change patch color based on its section
      if pxcor < divider-x [  ; If the patch is in the left section
        set pcolor brown - 2  ; Set patch color to brown - 2
      ]
      if pxcor >= divider-x [  ; If the patch is in the right section
        set pcolor brown       ; Set patch color to brown
      ]
    ]
  ]
end

; Helper procedure to check if there's food on the patch
to-report has-food-on-patch?
  report [has-food] of patch-here
end


to check-if-dead
  if steps-without-food > 10 [

    ; Compute growth quantiles separately for each habitat
    let all-growths-left [weight] of turtles with [xcor < divider-x]
    let all-growths-right [weight] of turtles with [xcor >= divider-x]

    ; Find the animal's growth rank in its habitat
    let my-quantile 0

    if xcor < divider-x [
      let sorted-growths sort all-growths-left
      let my-rank position weight sorted-growths
      set my-quantile my-rank / length sorted-growths  ;; Normalize rank to a 0-1 scale
    ]

    if xcor >= divider-x [
      let sorted-growths sort all-growths-right
      let my-rank position weight sorted-growths
      set my-quantile my-rank / length sorted-growths  ;; Normalize rank to a 0-1 scale
    ]

    ; Set death probability
    let death-probability 0.25 * (1 - my-quantile )

    ; Ensure probability stays between 0 and 1
    set death-probability max (list 0 (min (list 1 death-probability)))

    ; Determine if the turtle dies based on probability
    if random-float 1 < death-probability [
      if xcor < divider-x [
        set deadwL lput weight deadwL
      ]
      if xcor >= divider-x [
        set deadwR lput weight deadwR
      ]
      die  ;; The turtle dies
    ]

    ;; If the turtle survives, reset steps-without-food
    set steps-without-food 0
  ]
end

to-report show-left-turtle-count
  ifelse Dead-Animals [
    report count turtles with [xcor < divider-x]
  ] [
    report ""
  ]
end

to-report show-right-turtle-count
  ifelse Dead-Animals [
    report count turtles with [xcor > divider-x]
  ] [
    report ""
  ]
end


; Regrow food on patches that originally had food
to regrow-food
  ;; Increment the food-level based on the regrow-rate(10%)
  set food-level food-level + (1 / 10)

  ;; Once the food has fully regrown (reaches 1), set the patch as having food
  if food-level >= 1 [
    set food-level 1
    set has-food true
    set pcolor green  ;; Patch turns green when food regrows
  ]
end


; Procedure to mark food patches in the left section based on the Habitat-A-nutrition-level slider
to mark-food-patches-left
  let total-patches count patches with [pxcor < divider-x]
  let food-patches count patches with [pxcor < divider-x] * Habitat-A-nutrition-level / 100

  ask patches with [pxcor < divider-x] [
    set has-food false  ;; Clear previous food
    set pcolor brown - 2  ;; Reset patch color to default (brown)
    set originally-had-food false
    set food-level 0     ;; No food initially
    set pcolor brown - 2     ;; Reset patch color to default (brown)
  ]

  ; Randomly assign food to a percentage of patches in the left section
  ask n-of food-patches patches with [pxcor < divider-x] [
    set has-food true
    set originally-had-food true  ;; Mark these patches as originally having food
    set food-level 1  ;; Full food level initially
    set pcolor green  ;; Patches with food appear green
  ]
end

; Procedure to mark food patches in the right section based on the Habitat-B-nutrition-level slider
to mark-food-patches-right
  let total-patches count patches with [pxcor >= divider-x]
  let food-patches count patches with [pxcor >= divider-x] * Habitat-B-nutrition-level / 100

  ask patches with [pxcor >= divider-x] [
    set has-food false  ;; Clear previous food
    set originally-had-food false
    set food-level 0     ;; No food initially
    set pcolor brown  ;; Reset patch color to default (brown)
  ]

  ; Randomly assign food to a percentage of patches in the right section
  ask n-of food-patches patches with [pxcor >= divider-x] [
    set has-food true
    set originally-had-food true  ;; Mark these patches as originally having food
    set food-level 1  ;; Full food level initially
    set pcolor green  ;; Patches with food appear green
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
211
75
648
513
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

SLIDER
442
527
636
560
Habitat-B-nutrition-level
Habitat-B-nutrition-level
60
100
70.0
5
1
%
HORIZONTAL

SLIDER
220
527
414
560
Habitat-A-nutrition-level
Habitat-A-nutrition-level
0
50
50.0
5
1
%
HORIZONTAL

BUTTON
32
99
96
132
Setup
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
112
99
175
132
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
674
320
1044
581
Total Population Weight
Time
Population weight, lb
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Habitat A" 1.0 0 -5298144 true "" ""
"Habitat B" 1.0 0 -14070903 true "" ""

PLOT
674
47
1044
308
Average Weights
Time
Average Weight, lb
0.0
10.0
98.0
0.0
true
true
"" ""
PENS
"Habitat A" 1.0 0 -5298144 true "" "let avg-weight-left mean [weight] of turtles with [xcor < divider-x]"
"Habitat B" 1.0 0 -14070903 true "" "let avg-weight-right mean [weight] of turtles with [xcor >= divider-x]"

TEXTBOX
283
45
433
70
Habitat A
20
0.0
1

TEXTBOX
479
45
629
70
Habitat B
20
0.0
1

PLOT
1073
229
1444
490
Dead Animals
Time
Animals, n
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Habitat A" 1.0 0 -5298144 true "" ""
"Habitat B" 1.0 0 -13345367 true "" ""

SWITCH
1174
90
1324
123
Population-Weight
Population-Weight
1
1
-1000

SWITCH
1175
134
1324
167
Dead-Animals
Dead-Animals
1
1
-1000

TEXTBOX
1117
46
1380
96
Additional Information
20
0.0
1

TEXTBOX
1089
186
1414
225
Restart the simulation (press Setup > Go) before activating new plots for accurate data representation.
10
0.0
1

TEXTBOX
26
61
189
87
To start the simulation, press Setup, then Go
10
0.0
1

MONITOR
1272
512
1428
557
Alive animals in Habitat B
show-right-turtle-count
17
1
11

MONITOR
1103
512
1259
557
Alive animals in Habitat A
show-left-turtle-count
17
1
11

SWITCH
36
170
170
203
Repeatable-Run
Repeatable-Run
0
1
-1000

TEXTBOX
29
217
181
282
When on, the simulation runs the same for consistency; when off, each run is random.
10
0.0
1

@#$#@#$#@
## WHAT IS IT?

This NetLogo model simulates a population of turtles (representing animals) living in two distinct habitats (A and B), divided by a vertical boundary. The key goal is to explore how different nutrition levels in each section of the environment affect the animals' survival, weight changes, and population dynamics. Animals forage for food, gain weight when they find it, and die if they go too long without eating. The model also tracks and displays various metrics such as animal population, average weight, and cumulative weight over time in each habitat.

## HOW IT WORKS

The model operates based on the following rules:

**Habitat Division:** The world is divided into two sections, each representing a different habitat (A and B). Each section has a distinct nutritional level that influences the availability of food.

**Animal Behavior:** Fifty turtles (representing animals) are created in each habitat with an initial random weight, where the mean is 100 and the standard deviation is 10. Each habitat’s nutritional levels are established based on the inputs for Habitat-A-nutrition-level and Habitat-B-nutrition-level.

Turtles move randomly within their designated sections, consuming food when they encounter it and increasing their weight accordingly. Each turtle tracks the number of steps it takes without finding food. If this number exceeds a threshold of 10 steps, the turtle faces a risk of dying based on a probability that combines both starvation (with a 20% base probability of starvation) and weight factors (where lighter animals have a higher probability of death).

**Food Availability:** Patches of land are marked with food based on the nutritional levels defined by the user through sliders. The food can regrow over time, allowing for sustainable foraging.
When a turtle consumes food from a patch, it depletes that patch and changes its color to signify that it no longer has food.

**Population Dynamics:** The model tracks the number of turtles in each habitat, their average weights, and the cumulative weight of the populations over time, displaying these metrics in plots.

## HOW TO USE IT

To use the model, follow these instructions:

**Interface:**

**Sliders:** Adjust the Habitat-A-nutrition-level and Habitat-B-nutrition-level sliders to set the nutritional levels for each habitat. These levels influence how much food is available in each section.

**Run Button:** Click "setup" to initialize the environment and create turtles, then click "go" to start the simulation.

**Plots:** Observe the various plots tracking animal populations and average weights over time.

**Turtle and Patch Interactions:**

Turtles will forage for food on the patches. Observe how their weight changes as they find food and how their mortality rates vary based on food availability.

## THINGS TO NOTICE

While running the model, consider the following possibilities:

**Survivor Bias:** In Habitat A, where the food level is lower, you might observe higher mortality rates among turtles. However, those that do survive could be heavier. This phenomenon arises from the model's design, where lighter animals have a greater probability of dying in both habitats. Consequently, in Habitat A, the scarcity of nutrients leads to a disproportionate death rate among lighter turtles. As a result, the survivors may have a higher weight compared to their counterparts in Habitat B. Conversely, while Habitat B may have a larger total biomass (total weight of all turtles), the weight of the surviving turtles in Habitat A might be greater due to the selective pressure favoring heavier individuals.

**Competition for Food:** In Habitat A, reduced food availability can lead to increased mortality rates. However, the survivors face less competition for resources, potentially allowing them to grow more rapidly compared to turtles in Habitat B, where food is more abundant but so is the population density. This dynamic could lead to slower growth rates among turtles in Habitat B due to higher competition for available food.


## THINGS TO TRY

- Experiment by modifying model inputs. For instance, set the Habitat-B-nutrition-level to 100%. Observe how this change impacts the turtles’ weight gain. It may seem counterintuitive, but in a highly nutritious environment, increased competition for nutrients can hinder individual growth, as more turtles compete for the same food resources. Also, consider what happens if the regrow rate is set to 100%.

- Set the Habitat-A-nutrition-level to zero. Reflect on why not all animals in this habitat die. This scenario relates to the probability of dying established in the model's rules (see the HOW IT WORKS section).


## CONCEPTUAL FRAMEWORK

This NetLogo model has been developed as a learning tool in the context of systems thinking, specifically applied to livestock production. The model explores the dynamics of survivor bias—a bias that can skew our understanding of performance outcomes when only the surviving individuals are considered—within the context of animal growth and mortality. In livestock farming, where key metrics such as growth rates are often calculated as averages, survivor bias can significantly distort the interpretation of data. By focusing only on the surviving animals, averages may suggest that a certain treatment or management strategy is highly effective, when in reality it may have caused increased mortality or other adverse effects in a significant portion of the population.

For example, if a feed supplement leads to higher average weight gain but also causes animals to die from complications, the average performance of the surviving animals will look improved. This can lead to misleading conclusions about the overall effectiveness of the treatment. The treatment may appear to boost productivity, but in reality, the producer incurs higher losses due to mortality, which can outweigh the gains in individual growth rates.

This distortion occurs because the animals that did not survive are not included in the final calculation of averages. As a result, the remaining, healthier animals skew the data, masking the true cost of the treatment. Without taking into account both mortality and the average health of the entire population, farmers and researchers might implement strategies that seem beneficial in the short term but are detrimental to long-term sustainability and profitability.

## COPYRIGHT AND LICENSE

Copyright 2024 Christian Ramirez-Camba.


This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-nc-sa/4.0/).


To inquire about this model, please contact Christian Ramirez-Camba at ramir643@umn.edu.
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
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

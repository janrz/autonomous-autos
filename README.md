# Bachelor Project Lifestyle Informatics

Architecture in pseudo-code:

if ((no car-ahead and speed < max-speed) or (car-ahead and car-ahead-speed > own-speed)) {
    speed-up
} else if ((car-ahead and car-ahead-speed < own-speed) and car-left and car-right) {
    slow-down
} else if (car-ahead and car-left and no car-right) {
    if (no car-right-behind or (car-right-behind and car-right-behind-speed <= own-speed) and (no car-right-front or (car-right-front and car-right-front-speed > car-ahead-speed))) {
        move-right
    } else if (no car-right-behind or (car-right-behind and car-right-behind-speed > own-speed)) {
        slow-down
    }
} else if (car-ahead and no car-left and car-right) {
    if (no car-left-behind or (car-left-behind and car-left-behind-speed <= own-speed) and (no car-left-front or (car-left-front and car-left-front-speed > car-ahead-speed))) {
        move-left
    } else if (no car-left-behind or (car-left-behind and car-left-behind-speed > own-speed)) {
        slow-down
    }
} else if (car-ahead and no car-left and no car-right and (no car-left-behind or (car-left-behind and car-left-behind-speed <= own-speed))) {
    move-left
}

Jan Rezelman
VU University Amsterdam
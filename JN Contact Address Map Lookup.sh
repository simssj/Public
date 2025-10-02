X="4912 Lake Summer Loop
Moseley, VA, 23120"

X="10905 Harrison St
La Vista, NE, 68128
"

X=$(echo ${X}|tr [:blank:] '+')

echo ${X}

X="https://www.google.com/maps/place/${X}"

echo ${X}

/usr/bin/open -a "/Applications/Google Chrome.app" "${X}"

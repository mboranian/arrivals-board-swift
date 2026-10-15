# arrivals-board-swift
Trying to get some live transit arrival info


AC Transit Token:

    Your API Token is: BCCD22B34F9F2D933C4CAFF0D6AD492C

    In order to use the API, all requests must include this token in the query string i.e. ?token=BCCD22B34F9F2D933C4CAFF0D6AD492C, so please store this key in a safe place.

AC Transit API Documentation: https://api.actransit.org/transit/Help


BART Developer Program: https://www.bart.gov/about/developers

BART GTFS-Reatime: https://www.bart.gov/schedules/developers/gtfs-realtime

BART API Docs: https://api.bart.gov/docs/overview/index.aspx

BART API URLS(I think) : http://api.bart.gov/gtfsrt/tripupdate.aspx
                         http://api.bart.gov/gtfsrt/alerts.aspx

GTFS-Realtime Basic Docs: https://developers.google.com/transit/gtfs-realtime/#how_do_i_start

GTFS-Realtime Advanced Docs: https://gtfs.org/documentation/overview/
https://gtfs.org/documentation/realtime/feed-entities/trip-updates/

fetch() docs: https://developer.mozilla.org/en-US/docs/Web/API/Window/fetch

CSV Parser Docs: https://www.papaparse.com


Usage
    Install dependencies
        npm install
    Run in development mode-Runs the program directly from TypeScript (no build step).
        npm run dev
    Build the project-Compiles TypeScript files from src/ into JavaScript in dist/.
        npm run build
    Run the built program-Runs the compiled JavaScript output.
        npm start
    Clean build output (optional)-Removes generated files.
        rm -rf dist
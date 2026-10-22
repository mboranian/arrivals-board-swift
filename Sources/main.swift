// The Swift Programming Language
// https://docs.swift.org/swift-book
import CoreLocation
import Foundation
import TabularData

/*############Parse the local GTFS data for use throughout as DataFrames###########################################################################*/
let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try DataFrame(contentsOfCSVFile: stopsURL)

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let trips: DataFrame = try DataFrame(contentsOfCSVFile: tripsURL)

/*############Coordinates Constant to for testing. Make live later################################################################################*/
let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)

struct Departure {
    let station: String
    let platformID: String
    let platformNum: String
    let tripID: String
    let headsign: String
    let update: TransitRealtime_TripUpdate.StopTimeUpdate
}

struct DestinationGroup {
    let destination: String        // "SFO"
    let departures: [Departure]    // 4, 15, 24
}

struct PlatformGroup {
    let platform: String                     // "1"
    var destinations: [DestinationGroup]     // SFO group, Millbrae group
}

struct StationBoard {
    let stationName: String           // "San Bruno"
    var platforms: [PlatformGroup]    // Platform 1, Platform 2
}

/*############Helper Functions####################################################################################################################*/
func findHeadsignFromTripID(trips: DataFrame, tripID: Int) -> String {
    var headsign: String = ""
    for trip: DataFrame.Row in trips.rows {
        guard let id: Int = trip["trip_id", Int.self] else {
            print("Bad Trip ID")
            continue
        }
        if id == tripID {
            guard let sign: String = trip["trip_headsign", String.self] else {
                print("Bad Headsign")
                continue
            }
            headsign = sign
            break
        }
    }
    let splitHeadsign: [String] = headsign.components(separatedBy: " / ")
    headsign = splitHeadsign[splitHeadsign.count - 1]
    return headsign
}

func findNearestStation(stops: DataFrame, myCoords: (lon: Double, lat: Double)) -> DataFrame.Row {
    var closestDist: Double = Double.infinity
    var closestStop: DataFrame.Row? = nil
    let here: CLLocation = CLLocation(latitude: myCoords.lat, longitude: myCoords.lon)
    for station: DataFrame.Row in stops.rows {
        guard let stopType = station["location_type", Int.self] else {
            print("Bad Location Type")
            continue
        }
        if stopType == 1 {
            guard let thereLat: Double = station["stop_lat", Double.self] else {
                print("Bad Station Latitude")
                continue
            }
            guard let thereLon: Double = station["stop_lon", Double.self] else {
                print("Bad Station Longitude")
                continue
            }
            let there: CLLocation = CLLocation(latitude: thereLat, longitude: thereLon)
            let distanceInMeters: CLLocationDistance = here.distance(from: there)
            if distanceInMeters < closestDist {
                closestDist = distanceInMeters
                closestStop = station
            }
        }
    }
    if let closestStop: DataFrame.Row {
        return closestStop
    } else {
        fatalError("There is no closest stop")
    }
}

func findPlatformNumFromPlatFormCode(stops: DataFrame, platformCode: String) -> String {
    for stop: DataFrame.Row in stops.rows {
        guard let stopID: String = stop["stop_id", String.self] else { continue }
        if stopID == platformCode {
            guard let platformNum: Double = stop["platform_code", Double.self] else { continue }
            return String(Int(platformNum))
        }
    }
    return ""
}

func findPlatformIDsFromParentStopID(stops: DataFrame, stopID: String) -> [String] {
    var platformIDs: [String] = []
    for stop: DataFrame.Row in stops.rows {
        guard let locationType: Int = stop["location_type", Int.self] else {
            print("Bad Location Type")
            continue
        }
        guard let parentStation: String = stop["parent_station", String.self] else {
            print("Bad Parent Station")
            continue
        }
        if locationType == 0 && parentStation == stopID {
            guard let platformID: String = stop["stop_id", String.self] else {
                print("Bad Platform ID")
                continue
            }
            platformIDs.append(platformID)
        }
    }
    return platformIDs

}

func getMinutesAway(update: TransitRealtime_TripUpdate.StopTimeUpdate) -> Int {
    let time: Double = Double(update.departure.time)
    return Int(((time - Date.now.timeIntervalSince1970) / 60).rounded())
}

func getLiveFeedUpdate() async throws -> TransitRealtime_FeedMessage {
    //Get the live BART updates and store them in feed
    guard let url: URL = URL(string: "https://api.bart.gov/gtfsrt/tripupdate.aspx") else {
        print("Bad API URL")
        exit(1)
    }
    let (data, _) = try await URLSession.shared.data(from: url)
    let feed: TransitRealtime_FeedMessage = try TransitRealtime_FeedMessage(serializedBytes: data)

    return feed
}

/*############Setup Process: Find Closest Station and its Platfroms##################################################################################*/

func getClosestStationUpdates(
    trips: DataFrame, stops: DataFrame, coords: (lon: Double, lat: Double)
) async throws -> (name: String, departures: [Departure]) {
    //Get the closest station Data row
    let closestStation: DataFrame.Row = findNearestStation(stops: stops, myCoords: coords)

    //Get stop ID for closest Station
    guard let closestParentStopID: String = closestStation["stop_id", String.self] else {
        print("Bad Closest Parent Station Stop ID")
        exit(1)
    }
    //Get the name for the closest station
    guard let closestStationName: String = closestStation["stop_name", String.self] else {
        print("Bad Station Name")
        exit(1)
    }

    //Use the stop ID for the nearest station to get the stop ids for the platforms in that station(AKA the nearest platforms)
    let platformsAtClosestStation: [String] = findPlatformIDsFromParentStopID(
        stops: stops, stopID: closestParentStopID)

    //Initialize array of departures at the closest station
    var departuresAtClosestStation: [Departure] = []

    //Get the actual feed that we will be sifting through
    let feed: TransitRealtime_FeedMessage = try await getLiveFeedUpdate()

    //Go through all the trip updates and only keep the ones relevant to orur closest station
    for trip: TransitRealtime_FeedEntity in feed.entity {  // for everytrip in the feed
        guard trip.hasTripUpdate else { continue }  // if that trip exists
        for update: TransitRealtime_TripUpdate.StopTimeUpdate in trip.tripUpdate.stopTimeUpdate {  // look at every update for that trip
            guard update.hasDeparture else { continue }  // if that update exists
            if platformsAtClosestStation.contains(update.stopID)
                && Double(update.departure.time) > (Date().timeIntervalSince1970 - 40)
            {  // if it is an update for one of the platforms at the closest station
                guard let intTripID: Int = Int(trip.tripUpdate.trip.tripID) else { continue }  // create an Departure object to track all info
                let headsign: String = findHeadsignFromTripID(trips: trips, tripID: intTripID)
                let platNum: String = findPlatformNumFromPlatFormCode(
                    stops: stops, platformCode: update.stopID)
                departuresAtClosestStation.append(
                    Departure(
                        station: closestStationName, platformID: update.stopID,
                        platformNum: platNum,
                        tripID: trip.tripUpdate.trip.tripID, headsign: headsign, update: update))

            }
        }
    }
    return (closestStationName, departuresAtClosestStation)
}

/*############Output Formatter#####################################################################################################################*/
func getSortedDepartures(trips: DataFrame, stops: DataFrame, coords: (lon: Double, lat: Double)) async throws -> StationBoard{

    let (closestStationName, departuresAtClosestStation): (String, [Departure]) =
        try await getClosestStationUpdates(trips: trips, stops: stops, coords: coords)

    var stationBoard: StationBoard = StationBoard(stationName: closestStationName, platforms: [])

    print(closestStationName)

    //Seperate all departures from closest station by platform
    let departuresByPlatform: [(String, [Departure])] =
        (Dictionary(grouping: departuresAtClosestStation, by: { $0.platformNum })).sorted {
            $0.key < $1.key
        }

    //Go through and appropriately sort all the departures
    for (platform, var departures): (String, [Departure]) in departuresByPlatform {
        // for each platform, sort all the departures by departure time
        departures.sort { $0.update.departure.time < $1.update.departure.time }
        print("Platform " + platform)

        var platformGroup: PlatformGroup = PlatformGroup(platform: platform, destinations: [])
        
        //Within each platform, sort the departures into groups by destination, and sort the groups by where the very next train goes
        let departuresByDest: [(String, [Departure])] =
            (Dictionary(grouping: departures, by: { $0.headsign })).sorted {
                ($0.value[0].update.departure.time) < ($1.value[0].update.departure.time)
            }
        //Go through each destination on each platform and print the next three departure times for each desination
        for (dest, deps): (String, [Departure]) in departuresByDest {
            platformGroup.destinations.append(DestinationGroup(destination: dest, departures: deps))
            for dep: Departure in deps.prefix(3) {
                if getMinutesAway(update: dep.update) <= 1 {
                    print("Leaving --> " + dep.headsign)
                } else {
                    print("\(getMinutesAway(update: dep.update))" + " --> " + dep.headsign)
                }
            }
        }
        stationBoard.platforms.append(platformGroup)
    }
    return stationBoard

}

//TODO: Add loop
let test: StationBoard = try await getSortedDepartures(trips: trips, stops: stops, coords: currCoords)
print(test)
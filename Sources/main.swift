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

struct Arrival {
    let station: String
    let platformID: String
    let platformNum: String
    let tripID: String
    let headsign: String
    let update: TransitRealtime_TripUpdate.StopTimeUpdate
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
    let time: Double = Double(update.arrival.time)
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
//Get the closest station Data row
let closestStation: DataFrame.Row = findNearestStation(stops: stops, myCoords: currCoords)

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

//Initialize array of arrivals at the closest station
var arrivalsAtClosestStation: [Arrival] = []

//Get the actual feed that we will be sifting through
let feed: TransitRealtime_FeedMessage = try await getLiveFeedUpdate()

//Go through all the trip updates and only keep the ones relevant to orur closest station
for trip: TransitRealtime_FeedEntity in feed.entity {  // for everytrip in the feed
    guard trip.hasTripUpdate else { continue }  // if that trip exists
    for update: TransitRealtime_TripUpdate.StopTimeUpdate in trip.tripUpdate.stopTimeUpdate {  // look at every update for that trip
        guard update.hasArrival else { continue }  // if that update exists
        if platformsAtClosestStation.contains(update.stopID) {  // if it is an update for one of the platforms at the closest station
            guard let intTripID: Int = Int(trip.tripUpdate.trip.tripID) else { continue } // create an Arrival object to track all info
            let headsign: String = findHeadsignFromTripID(trips: trips, tripID: intTripID)
            let platNum: String = findPlatformNumFromPlatFormCode(
                stops: stops, platformCode: update.stopID)
            arrivalsAtClosestStation.append(
                Arrival(
                    station: closestStationName, platformID: update.stopID, platformNum: platNum,
                    tripID: trip.tripUpdate.trip.tripID, headsign: headsign, update: update))

        }
    }
}

/*############Output Formatter#####################################################################################################################*/

print(closestStationName)

//Seperate all arrivals to closest station by platform
let arrivalsByPlatform: [(String, [Arrival])] =
    (Dictionary(grouping: arrivalsAtClosestStation, by: { $0.platformNum })).sorted {
        $0.key < $1.key
    }

//Go through and appropriately sort all the arrivals
for (platform, var arrivals): (String, [Arrival]) in arrivalsByPlatform {
    // for each platform, sort all the arrivals by arrival time
    arrivals.sort { getMinutesAway(update: $0.update) < getMinutesAway(update: $1.update) }
    print("Platform " + platform)
    //Within each platform, sort the arrivals into groups by destination, and sort the groups by where the very next train goes
    let arrivalsByDest: [(String, [Arrival])] =
        (Dictionary(grouping: arrivals, by: { $0.headsign })).sorted {
            (getMinutesAway(update: $0.value[0].update)) < (getMinutesAway(update: $1.value[0].update))
        }
    //Go through each destination on each platform and print the next three arrival times for each desination
    for (_, arrs): (String, [Arrival]) in arrivalsByDest {
        for arr: Arrival in arrs.prefix(3) {
            if getMinutesAway(update: arr.update) <= 1 {
                print("Leaving --> " + arr.headsign)
            } else {
                print("\(getMinutesAway(update: arr.update))" + " --> " + arr.headsign)
            }
        }
    }

}

//TODO: Add loop
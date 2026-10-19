import CoreLocation
// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import TabularData

/*############Parse the local GTFS data for use throughout as DataFrames###########################################################################*/
let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try DataFrame(contentsOfCSVFile: stopsURL)

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let trips: DataFrame = try DataFrame(contentsOfCSVFile: tripsURL)

/*############Coordinates Constant to for testing. Make live later################################################################################*/
let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)

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
        guard let stopID: String = stop["stop_id", String.self] else {continue}
        if  stopID == platformCode {
            guard let platformNum: Double = stop["platform_code", Double.self] else {continue}
            return String(Int(platformNum))
        }
    }
    return "";
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
//Get the closest station and the Stop ID for it
let closestStation: DataFrame.Row = findNearestStation(stops: stops, myCoords: currCoords)
guard let closestParentStopID: String = closestStation["stop_id", String.self] else {
    print("Bad Closest Parent Station Stop ID")
    exit(1)
}

//Use the stop ID for the nearest station to get the stop ids for the platforms in that station(AKA the nearest platforms)
let platformsAtClosestStation: [String] = findPlatformIDsFromParentStopID(
    stops: stops, stopID: closestParentStopID)

//Get the actual feed that we will be sifting through
let feed: TransitRealtime_FeedMessage = try await getLiveFeedUpdate()

//Initialize the array that holds time updates about the closest platforms
var relevantTripUpdates: [TransitRealtime_TripUpdate.StopTimeUpdate] = []
//Initialize the dictionary that matched the relevant updates to their trip ids so we can find their route later
var relevantTripUpdatesTripIDs: [TransitRealtime_TripUpdate.StopTimeUpdate: String] = [:]

//Go through all the trip updates and only keep the ones relevant to orur closest station
for trip: TransitRealtime_FeedEntity in feed.entity {  // for everytrip in the feed
    guard trip.hasTripUpdate else { continue }  // if that trip exists
    for update: TransitRealtime_TripUpdate.StopTimeUpdate in trip.tripUpdate.stopTimeUpdate {  // look at every update for that trip
        guard update.hasArrival else { continue }  // if that update exists
        if platformsAtClosestStation.contains(update.stopID) {  // if it is an update for one of the platforms at the closest station
            relevantTripUpdates.append(update)  // add it to the array of updates that concern the closest station
            relevantTripUpdatesTripIDs[update] = trip.tripUpdate.trip.tripID  //Link this update to its trip id to find the route later
        }
    }
}
relevantTripUpdates.sort {$0.arrival.time < $1.arrival.time}

/*############Output Formatter#####################################################################################################################*/
guard let closestStationName: String = closestStation["stop_name", String.self] else {
    print("Bad Station Name")
    exit(1)
}
print(closestStationName)

/*This loop prints all departing trains in order along with it's destination - Start*/

// for update: TransitRealtime_TripUpdate.StopTimeUpdate in relevantTripUpdates {
//     let time: Double = Double(update.arrival.time)
//     let minutesAway: Int = Int(((time - Date.now.timeIntervalSince1970) / 60).rounded())
//     guard let stringRelevantTripUpdateTripID: String = relevantTripUpdatesTripIDs[update] else {continue}
//     guard let intRelevantTripUpdateTripID: Int = Int(stringRelevantTripUpdateTripID) else {continue}
//     let route: String = findHeadsignFromTripID(trips: trips, tripID: intRelevantTripUpdateTripID)
//     print(String(minutesAway) + " --> " + route)
// }
/*This loop prints all departing trains in order along with it's destination - End*/

let relevantTripUpdatesByPlatform: [String : [TransitRealtime_TripUpdate.StopTimeUpdate]] = Dictionary(grouping: relevantTripUpdates, by: {$0.stopID})


//let relevantPlatformUpdatesbyDest = Dictionary(grouping: relevantTripUpdatesByPlatform, by: {relevantTripUpdatesTripIDs[]})


for (platform, platformUpdates) in relevantTripUpdatesByPlatform {
    print("Platform " + (findPlatformNumFromPlatFormCode(stops: stops, platformCode: platform)))
    for update in platformUpdates {
        let time: Double = Double(update.arrival.time)
        let minutesAway: Int = Int(((time - Date.now.timeIntervalSince1970) / 60).rounded())
        guard let stringRelevantTripUpdateTripID: String = relevantTripUpdatesTripIDs[update] else {continue}
        guard let intRelevantTripUpdateTripID: Int = Int(stringRelevantTripUpdateTripID) else {continue}
        let route: String = findHeadsignFromTripID(trips: trips, tripID: intRelevantTripUpdateTripID)
        print(String(minutesAway) + " --> " + route)
    }
}

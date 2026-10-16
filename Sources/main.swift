import CoreLocation
// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import TabularData

let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try DataFrame(contentsOfCSVFile: stopsURL)

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let trips: DataFrame = try DataFrame(contentsOfCSVFile: tripsURL)

//print(stops.rows[1])
//print(trips.rows[1])

let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)

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
//print(findHeadsignFromTripID(trips: trips, tripID: 1965577))

// func findRouteIDFromTripID(trips: DataFrame, tripID: Int) -> String {
//     var routeID: String = ""
//     for trip: DataFrame.Row in trips.rows {
//         guard let id: Int = trip["trip_id", Int.self] else {
//             print("Bad Trip ID")
//             continue
//         }
//         if id == tripID {
//             guard let route: String = trip["route_id", String.self] else {
//                 print("Bad Route ID")
//                 continue
//             }
//             routeID = route
//             break
//         }
//     }
//     return routeID
// }
//print(findRouteIDFromTripID(trips: trips, tripID: 1_965_577))

//Finds the nearest Station. Will always return a parent station. Not a platform or exit
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
print(findNearestStation(stops: stops, myCoords: currCoords)

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

func getLiveFeedUpdate() -> {
    //Get the live BART updates and store them in feed
    guard let url: URL = URL(string: "https://api.bart.gov/gtfsrt/tripupdate.aspx") else {
        print("Bad API URL")
        exit(1)
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    let feed: TransitRealtime_FeedMessage = try TransitRealtime_FeedMessage(serializedBytes: data)

}

//print(feed.entity[1])

//example of unwrapping
// let dict: [String: String] = ["SBRN": "San Bruno"]
// let maybe: String? = dict["SBRN"]

// if let name =  maybe {
//     print(name)
// } else {
//     print("not found")
// }

//example of guard
// let dict: [String: String] = ["SBRN": "San Bruno"]
// let maybe: String? = dict["SBRN"]

// guard let name = maybe else {
//     print("not found")
//     exit(1)
// }
// print(name)

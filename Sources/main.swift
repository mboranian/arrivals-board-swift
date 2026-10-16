// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import TabularData

let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try DataFrame(contentsOfCSVFile: stopsURL)

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let trips: DataFrame = try DataFrame(contentsOfCSVFile: tripsURL)

//print(stops.rows[1]["stop_name", String.self])
print(stops.rows[1])
print(trips.rows[1])

let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)


func findHeadsignFromTripID(tripID: Int) {
    var headsign: String = ""
}
















//Get the live BART updates and store them in feed
guard let url: URL = URL(string: "https://api.bart.gov/gtfsrt/tripupdate.aspx") else {
    print("Bad API URL")
    exit(1)
}
let (data, response) = try await URLSession.shared.data(from: url)
let feed: TransitRealtime_FeedMessage = try TransitRealtime_FeedMessage(serializedBytes: data)

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
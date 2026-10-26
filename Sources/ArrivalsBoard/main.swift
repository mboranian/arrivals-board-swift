// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import TabularData
import ArrivalsCore

/*############Parse the local GTFS data for use throughout as DataFrames###########################################################################*/
let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try DataFrame(contentsOfCSVFile: stopsURL, types: ["platform_code": .string])

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let trips: DataFrame = try DataFrame(contentsOfCSVFile: tripsURL, types: ["trip_id": .string])
let headsignDict: [String : String] = buildTripIDToHeadsignDict(trips: trips)

/*############Coordinates Constant to for testing. Make live later###########################*/
let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)

//TODO: Add loop
let test: StationBoard = try await getDepartures(headsigns: headsignDict, stops: stops, coords: currCoords)

printStationBoard(board: test)

//
//  Swift_benchmarksTests.swift
//  Swift-benchmarksTests
//
//  Created by Tom Ebergen on 08/08/2023.
//
import Foundation
import XCTest
import RealmSwift
import DuckDB

@testable import Swift_benchmarks

class Trip : Object {
    @objc var vendor_name           : String = ""
    @objc var passenger_count       : Int = 0
    @objc var trip_distance         : Double = 0
    @objc var pickup_longitude      : Double = 0
    @objc var pickup_latitude       : Double = 0
    @objc var rate_code             : String = ""
    @objc var store_and_fwd         : String = ""
    @objc var dropoff_longitude     : Double = 0
    @objc var dropoff_latitude      : Double = 0
    @objc var payment_type          : String = ""
    @objc var fare_amount           : Double = 0
    @objc var extra                 : Double = 0
    @objc var mta_tax               : Double = 0
    @objc var tip_amount            : Double = 0
    @objc var tolls_amount          : Double = 0
    @objc var total_amount          : Double = 0
    @objc var improvement_surcharge : Double = 0
    @objc var congestion_surcharge  : Double = 0
    @objc var pickup_location_id    : Int = 0
    @objc var dropoff_location_id   : Int = 0
    @objc var year                  : String = ""
    @objc var month                 : String = ""
}

class Swift_benchmarksTests: XCTestCase {
    
    func GetTaxiFileName() -> String {
        return "/Users/tomebergen/Swift-benchmarks/taxi-one-month-subset.csv"
    }
    
    func readCSV(inputFile: String, separator: String) -> [String] {
         // split the filename
        do {
            let content = try String(contentsOfFile: inputFile)
            let parsedCSV: [String] = content.components(separatedBy: "\n")
            return parsedCSV
        }
        catch {
            return []
        }
    }
    
    override func setUpWithError() throws {
        // do nothing
    }

    func loadRealmData() throws -> [Trip] {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        var parsed_data : [Trip] = []
        let all_data = readCSV(inputFile: GetTaxiFileName(), separator: ",")
        for row in all_data {
            var trip = Trip()
            let parsed_row = row.components(separatedBy: ",")
            if (parsed_row.count < 24) {
                // empty row probably
                break
            }
            trip.vendor_name           = String(parsed_row[0])
//            trip.pickup_datetime       = Time.init(Date(parsed_row[1]))
//            trip.dropoff_datetime      = Time.init(Date(parsed_row[2]))
            trip.passenger_count       = Int(parsed_row[3]) ?? 0
            trip.trip_distance         = Double(parsed_row[4]) ?? 0
            trip.pickup_longitude      = Double(parsed_row[5]) ?? 0
            trip.pickup_latitude       = Double(parsed_row[6]) ?? 0
            trip.rate_code             = String(parsed_row[7])
            trip.store_and_fwd         = String(parsed_row[8])
            trip.dropoff_longitude     = Double(parsed_row[9]) ?? 0
            trip.dropoff_latitude      = Double(parsed_row[10]) ?? 0
            trip.payment_type          = String(parsed_row[11])
            trip.fare_amount           = Double(parsed_row[12]) ?? 0
            trip.extra                 = Double(parsed_row[13]) ?? 0
            trip.mta_tax               = Double(parsed_row[14]) ?? 0
            trip.tip_amount            = Double(parsed_row[15]) ?? 0
            trip.tolls_amount          = Double(parsed_row[16]) ?? 0
            trip.total_amount          = Double(parsed_row[17]) ?? 0
            trip.improvement_surcharge = Double(parsed_row[18]) ?? 0
            trip.congestion_surcharge  = Double(parsed_row[19]) ?? 0
            trip.pickup_location_id    = Int(parsed_row[20]) ?? 0
            trip.dropoff_location_id   = Int(parsed_row[21]) ?? 0
            trip.year                  = String(parsed_row[22])
            trip.month                 = String(parsed_row[23])
            parsed_data.append(trip)
        }
        
        // Setup Realm - Delete all previously used instances
        let realm_filename = "realm-benchmark"
        var config = Realm.Configuration.defaultConfiguration
        config.deleteRealmIfMigrationNeeded = true
        config.fileURL!.deleteLastPathComponent()
        config.fileURL!.appendPathComponent(realm_filename)
        config.fileURL!.appendPathExtension("realm")
        var realm_connection = try! Realm(configuration: config)
        
        if let realm_path_url = config.fileURL {
            print("saving realm config at " + realm_path_url.absoluteString)
        }
        
        // Delete the objects currenlty in the realm db
        let allTrips = realm_connection.objects(Trip.self)
        try! realm_connection.write {
            realm_connection.delete(allTrips)
        }
        
        return parsed_data
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    // test how fast
    func testRealmInsertRecords() throws {
        // Measure performance of reading the csv in swift
        // loading it into a realm db
        // then deleting it from the same realm db
        self.measure {
            let realm_filename = "realm-benchmark"
            var config = Realm.Configuration.defaultConfiguration
            config.deleteRealmIfMigrationNeeded = true
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent(realm_filename)
            config.fileURL!.appendPathExtension("realm")
            
            do {
                var parsed_data = try loadRealmData()
                // add the objects
                let realm_connection = try! Realm(configuration: config)
                try realm_connection.write {
                    realm_connection.add(parsed_data)
                }
                // delete the objects as well
                let allTrips = realm_connection.objects(Trip.self)
                if (allTrips.count != parsed_data.count) {
                    print("FAILURE")
                    exit(1)
                }
                try! realm_connection.write {
                    realm_connection.delete(allTrips)
                }
            }
            catch {
                print("realm error \(error)")
                exit(1)
            }
        }
    }
    
}


extension Swift_benchmarksTests {
    func testDuckdbCSVRead() throws {
        // Measure performance of inserting all parsed data into Realm database
        print("starting duckdb test")
        self.measure {
            // measure performance of reading a csv into a duckdb instance
            // and dropping all the records.
            do {
                let database = try Database(store: .inMemory)
                let connection = try database.connect()
                
                try connection.execute("Create Table trips as (select * from read_csv_auto('\(GetTaxiFileName())'))")
                // check amount
                let result = try connection.query("""
                  Select * from trips;
                """)
                
                let vendor_name = result[0].cast(to: String.self)
                let passenger_count   = result[1].cast(to: Int.self)
                let trip_distance   = result[2].cast(to: Double.self)
                let pickup_longitude   = result[3].cast(to: Double.self)
                let pickup_latitude   = result[4].cast(to: Double.self)
                let rate_code   = result[5].cast(to: String.self)
                let store_and_fwd   = result[6].cast(to: String.self)
                let dropoff_longitude   = result[7].cast(to: Double.self)
                let dropoff_latitude   = result[8].cast(to: Double.self)
                let payment_type   = result[9].cast(to: String.self)
                let fare_amount   = result[10].cast(to: Double.self)
                let extra   = result[11].cast(to: Double.self)
                let mta_tax   = result[12].cast(to: Double.self)
                let tip_amount   = result[13].cast(to: Double.self)
                let tolls_amount   = result[14].cast(to: Double.self)
                let total_amount   = result[15].cast(to: Double.self)
                let improvement_surcharge   = result[16].cast(to: Double.self)
                let congestion_surcharge   = result[17].cast(to: Double.self)
                let pickup_location_id   = result[18].cast(to: Int.self)
                let dropoff_location_id   = result[19].cast(to: Int.self)
                let year   = result[20].cast(to: String.self)
                let month   = result[21].cast(to: String.self)
                
                if (result.rowCount != 6873314) {
                    print("error during DUCKDB importing. Counts don't match")
                }
                try connection.execute("drop table trips;")
            } catch {
                print("duckdb error \(error)")
                exit(1)
            }
        }
    }
}

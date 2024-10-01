import XCTest
import Projection

final class EventDetailsTests: XCTestCase {
    func testDecodesJSON() throws {
        let event = Event(entity: Entity(id: "", type: ""), name: "", details: "{}", version: 0, position: 0)

        XCTAssertNotNil(try event.details(as: TestDetails.self))
    }
}

class TestDetails: Decodable {

}

/**
 * Copyright IBM Corporation 2016-2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

// swiftlint:disable function_body_length force_try force_unwrapping file_length

import XCTest
import RestKit
@testable import VisualRecognitionV3

class VisualRecognitionUnitTests: XCTestCase {

    let version = "2018-03-19"
    private var visualRecognition: VisualRecognition!

    override func setUp() {
        super.setUp()
        let accessToken = "my_access_token"
        visualRecognition = VisualRecognition(version: version, accessToken: accessToken)
        // Create mock session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)
        // Install mock session
        visualRecognition.session = mockSession
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func loadResource(name: String, ext: String) -> URL {
        #if os(Linux)
        return URL(fileURLWithPath: "Tests/VisualRecognitionV3Tests/Resources/" + name + "." + ext)
        #else
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            XCTFail("Unable to locate sample image files.")
            assert(false)
        }
        return url
        #endif
    }

    func testHeaders() throws {
        // Configure mock
        let mockResult: [String: Any] = ["custom_classes": 0, "images_processed": 0, "images": []]
        MockURLProtocol.requestHandler = { request in
            // Verify custom header is present
            XCTAssertNotNil(request.allHTTPHeaderFields)
            XCTAssertTrue(request.allHTTPHeaderFields?.keys.contains("x-foo") ?? false)
            XCTAssertEqual("bar", request.allHTTPHeaderFields?["x-foo"])

            // Setup mock result
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: mockResult, options: [])
            return (response, data)
        }

        let expectation = XCTestExpectation(description: "Classify an image with explicit headers.")
        let imageURL = "an-image-url"
        visualRecognition.classify(url: imageURL, headers: ["x-foo": "bar"]) {
            _, error in
            if error != nil {
                XCTFail("error return")
            } else {
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: errorResponseDecoder

    func testErrorResponseDecoder403() {
        let testJSON: [String: JSON] = [
            "status": JSON.string("403"),
            "statusInfo": JSON.string("forbidden"),
        ]
        let testData = try! JSONEncoder().encode(testJSON)
        let testResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!

        let error = visualRecognition.errorResponseDecoder(data: testData, response: testResponse)
        if case let .http(statusCode, message, metadata) = error {
            XCTAssertEqual(statusCode, 403)
            XCTAssertNotNil(message)
            XCTAssertNotNil(metadata)
            XCTAssertNotNil(metadata!["status"])
            XCTAssertNotNil(metadata!["statusInfo"])
        }
    }

    func testErrorResponseDecoder404() {
        let testJSON: [String: JSON] = [
            "error": JSON.object([
                "description": JSON.string("not found"),
                "error_id": JSON.string("42"),
            ]),
        ]
        let testData = try! JSONEncoder().encode(testJSON)
        let testResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!

        let error = visualRecognition.errorResponseDecoder(data: testData, response: testResponse)
        if case let .http(statusCode, message, metadata) = error {
            XCTAssertEqual(statusCode, 404)
            XCTAssertNotNil(message)
            XCTAssertNotNil(metadata?["description"])
            XCTAssertNotNil(metadata?["errorID"])
        }
    }

    func testErrorResponseDecoder413() {
        let testJSON: [String: JSON] = ["Error": JSON.string("failed")]
        let testData = try! JSONEncoder().encode(testJSON)
        let testResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 413, httpVersion: nil, headerFields: nil)!

        let error = visualRecognition.errorResponseDecoder(data: testData, response: testResponse)
        if case let .http(statusCode, message, _) = error {
            XCTAssertEqual(statusCode, 413)
            XCTAssertNotNil(message)
        }
    }

    func testErrorResponseDecoderDefault() {
        let testJSON: [String: JSON] = ["error": JSON.string("failed")]
        let testData = try! JSONEncoder().encode(testJSON)
        let testResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!

        let error = visualRecognition.errorResponseDecoder(data: testData, response: testResponse)
        if case let .http(statusCode, message, _) = error {
            XCTAssertEqual(statusCode, 500)
            XCTAssertNotNil(message)
        }
    }

    func testErrorResponseDecoderBadJSON() {
        let testData = Data()
        let testResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!

        let error = visualRecognition.errorResponseDecoder(data: testData, response: testResponse)
        if case let .http(statusCode, message, metadata) = error {
            XCTAssertEqual(statusCode, 500)
            XCTAssertNil(message)
            XCTAssertNil(metadata)
        }
    }

    func testClassifyReturns413() throws {
        // Configure mock
        let mockResult: [String: Any] = ["Error": "something bad happened"]
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 413, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: mockResult, options: [])
            return (response, data)
        }
        let carz = loadResource(name: "carz", ext: "zip")
        let expectation = XCTestExpectation(description: "Classify an image.")
        visualRecognition.classify(imagesFile: carz) {
            _, error in
            guard case let .some(.http(statusCode, _, _)) = error else {
                XCTFail("Unexpected type for error in completion handler")
                return
            }
            XCTAssertEqual(413, statusCode)
            XCTAssertEqual(mockResult["Error"] as? String, error?.localizedDescription)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

     func testUpdateClassifier() {
        let classifierID = "1234567890"
        let classifierName = "swift-sdk-unit-test"

        let cars = PositiveExample(name: "car", examples: loadResource(name: "cars", ext: "zip"))
        let trucks = PositiveExample(name: "truck", examples: loadResource(name: "trucks", ext: "zip"))

        // Configure mock
        let mockResult: [String: Any] = ["classifier_id": classifierID, "name": classifierName, "classes": [["class": "car"], ["class": "truck"]]]
        MockURLProtocol.requestHandler = { request in
            // Verify HTTP method
            XCTAssertEqual(request.httpMethod, "POST")
            // Verify URL path elements
            let endIndex = request.url?.pathComponents.endIndex ?? 0
            XCTAssertEqual("classifiers", request.url?.pathComponents[endIndex-2])
            XCTAssertEqual(classifierID, request.url?.pathComponents[endIndex-1])
            // Verify query parameters
            XCTAssertTrue(request.url?.query?.contains("version=\(self.version)") ?? false)
            // Verify post body
            XCTAssertNotNil(request.httpBodyStream)
            XCTAssertNotNil(request.allHTTPHeaderFields)

            let bodyFieldsCount = parseMultiPartFormBody(request: request)
            XCTAssertEqual(2, bodyFieldsCount)

            // Setup mock result
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: mockResult, options: [])
            return (response, data)
        }

        let expectation = XCTestExpectation(description: "updateClassifier")
        visualRecognition.updateClassifier(classifierID: classifierID, positiveExamples: [cars, trucks]) {
            response, error in
            if let error = error {
                XCTFail(unexpectedErrorMessage(error))
                return
            }
            guard let classifier = response?.result else {
                XCTFail(missingResultMessage)
                return
            }
            XCTAssertEqual(classifierName, classifier.name)
            XCTAssertEqual(classifierID, classifier.classifierID)
            XCTAssertNotNil(classifier.classes)
            XCTAssertEqual(classifier.classes?.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testDeleteClassifier() {
        let classifierID = "1234567890"

        // Configure mock
        let mockResult: [String: Any] = [:]
        MockURLProtocol.requestHandler = { request in
            XCTAssertNotNil(request.url)
            XCTAssertEqual(request.httpMethod, "DELETE")
            let endIndex = request.url?.pathComponents.endIndex ?? 0
            XCTAssertEqual("classifiers", request.url?.pathComponents[endIndex-2])
            XCTAssertEqual(classifierID, request.url?.pathComponents[endIndex-1])
            // Setup mock result
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: mockResult, options: [])
            return (response, data)
        }
        let expectation = XCTestExpectation(description: "deleteClassifier.")
        visualRecognition.deleteClassifier(classifierID: classifierID) {
            _, error in
            if let error = error {
                XCTFail(unexpectedErrorMessage(error))
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testDeleteUserData() {
        let customerID = "1234567890"

        // Configure mock
        let mockResult: [String: Any] = [:]
         MockURLProtocol.requestHandler = { request in
            XCTAssertNotNil(request.url)
            // Verify HTTP method
            XCTAssertEqual(request.httpMethod, "DELETE")
            // Verify URL path elements
            let endIndex = request.url?.pathComponents.endIndex ?? 0
            XCTAssertEqual("user_data", request.url?.pathComponents[endIndex-1])
            // Verify query parameters
            XCTAssertTrue(request.url?.query?.contains("version=\(self.version)") ?? false)

            // Setup mock result
            let response = HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: mockResult, options: [])
            return (response, data)
        }
        let expectation = XCTestExpectation(description: "deleteClassifier.")
        visualRecognition.deleteUserData(customerID: customerID) {
            response, error in
            if let error = error {
                XCTFail(unexpectedErrorMessage(error))
            }
            XCTAssertEqual(202, response?.statusCode)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

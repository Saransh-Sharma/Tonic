//
//  InputValidationTests.swift
//  TonicTests
//
//  Tests for input validation - form validation, field validators, error messages
//

import XCTest
@testable import Tonic

final class InputValidationTests: XCTestCase {

    // MARK: - Nonempty Validator Tests

    func testNonemptyValidatorAccepts() {
        let validator = NonemptyValidator(fieldName: "Test")

        do {
            let result = try validator.validate("valid input")
            XCTAssertEqual(result, "valid input")
        } catch {
            XCTFail("Should accept non-empty input")
        }
    }

    func testNonemptyValidatorRejects() {
        let validator = NonemptyValidator(fieldName: "Test")

        do {
            _ = try validator.validate("")
            XCTFail("Should reject empty input")
        } catch let error as TonicError {
            if case .emptyField = error {
                // Success
            } else {
                XCTFail("Should throw emptyField error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    func testNonemptyValidatorTrimsWhitespace() {
        let validator = NonemptyValidator(fieldName: "Test")

        do {
            _ = try validator.validate("   ")
            XCTFail("Should reject whitespace-only input")
        } catch let error as TonicError {
            if case .emptyField = error {
                // Success
            } else {
                XCTFail("Should throw emptyField error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    // MARK: - Email Validator Tests

    func testEmailValidatorValidEmails() {
        let validator = EmailValidator()
        let validEmails = [
            "user@example.com",
            "test.email@domain.co.uk",
            "name+tag@site.org",
        ]

        for email in validEmails {
            do {
                let result = try validator.validate(email)
                XCTAssertEqual(result, email)
            } catch {
                XCTFail("Should accept valid email: \(email)")
            }
        }
    }

    func testEmailValidatorInvalidEmails() {
        let validator = EmailValidator()
        let invalidEmails = [
            "notanemail",
            "@example.com",
            "user@",
            "user @example.com",
        ]

        for email in invalidEmails {
            do {
                _ = try validator.validate(email)
                XCTFail("Should reject invalid email: \(email)")
            } catch let error as TonicError {
                if case .invalidEmail = error {
                    // Success
                } else {
                    XCTFail("Should throw invalidEmail error")
                }
            } catch {
                XCTFail("Should throw TonicError")
            }
        }
    }

    // MARK: - URL Validator Tests

    func testURLValidatorValidURLs() {
        let validator = URLValidator()
        let validURLs = [
            "https://example.com",
            "http://example.com",
            "file:///Users/test",
        ]

        for url in validURLs {
            do {
                let result = try validator.validate(url)
                XCTAssertEqual(result, url)
            } catch {
                XCTFail("Should accept valid URL: \(url)")
            }
        }
    }

    func testURLValidatorInvalidURLs() {
        let validator = URLValidator()
        let invalidURLs = [
            "not a url",
            "example.com",
            "://invalid",
        ]

        for url in invalidURLs {
            do {
                _ = try validator.validate(url)
                XCTFail("Should reject invalid URL: \(url)")
            } catch let error as TonicError {
                if case .invalidURL = error {
                    // Success
                } else {
                    XCTFail("Should throw invalidURL error")
                }
            } catch {
                XCTFail("Should throw TonicError")
            }
        }
    }

    // MARK: - Length Validator Tests

    func testLengthValidatorValidLength() {
        let validator = LengthValidator(minLength: 5, maxLength: 10, fieldName: "Test")

        do {
            let result = try validator.validate("hello")
            XCTAssertEqual(result, "hello")
        } catch {
            XCTFail("Should accept valid length")
        }
    }

    func testLengthValidatorTooShort() {
        let validator = LengthValidator(minLength: 5, maxLength: 10, fieldName: "Test")

        do {
            _ = try validator.validate("hi")
            XCTFail("Should reject too short input")
        } catch let error as TonicError {
            if case .fieldTooShort = error {
                // Success
            } else {
                XCTFail("Should throw fieldTooShort error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    func testLengthValidatorTooLong() {
        let validator = LengthValidator(minLength: 5, maxLength: 10, fieldName: "Test")

        do {
            _ = try validator.validate("this is way too long")
            XCTFail("Should reject too long input")
        } catch let error as TonicError {
            if case .fieldTooLong = error {
                // Success
            } else {
                XCTFail("Should throw fieldTooLong error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    // MARK: - Numeric Validator Tests

    func testNumericValidatorValidNumbers() {
        let validator = NumericValidator(fieldName: "Test")
        let validNumbers = ["123", "45.67", "0", "-100"]

        for number in validNumbers {
            do {
                let result = try validator.validate(number)
                XCTAssertEqual(result, number)
            } catch {
                XCTFail("Should accept valid number: \(number)")
            }
        }
    }

    func testNumericValidatorInvalidInput() {
        let validator = NumericValidator(fieldName: "Test")
        let invalidInputs = ["abc", "12.34.56", ""]

        for input in invalidInputs {
            do {
                _ = try validator.validate(input)
                if !input.isEmpty {
                    XCTFail("Should reject invalid input: \(input)")
                }
            } catch let error as TonicError {
                if case .notNumeric = error {
                    // Success
                } else {
                    XCTFail("Should throw notNumeric error")
                }
            } catch {
                // Expected for empty input
            }
        }
    }

    // MARK: - Range Validator Tests

    func testRangeValidatorValidRange() {
        let validator = RangeValidator(fieldName: "Test", min: 0, max: 100)

        do {
            let result = try validator.validate("50")
            XCTAssertEqual(result, "50")
        } catch {
            XCTFail("Should accept value in range")
        }
    }

    func testRangeValidatorBelowMin() {
        let validator = RangeValidator(fieldName: "Test", min: 10, max: 100)

        do {
            _ = try validator.validate("5")
            XCTFail("Should reject value below minimum")
        } catch let error as TonicError {
            if case .valueOutOfRange = error {
                // Success
            } else {
                XCTFail("Should throw valueOutOfRange error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    func testRangeValidatorAboveMax() {
        let validator = RangeValidator(fieldName: "Test", min: 0, max: 100)

        do {
            _ = try validator.validate("150")
            XCTFail("Should reject value above maximum")
        } catch let error as TonicError {
            if case .valueOutOfRange = error {
                // Success
            } else {
                XCTFail("Should throw valueOutOfRange error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    // MARK: - Pattern Validator Tests

    func testPatternValidatorValidInput() {
        let validator = PatternValidator(fieldName: "Test", pattern: "[A-Z]{3}")

        do {
            let result = try validator.validate("ABC")
            XCTAssertEqual(result, "ABC")
        } catch {
            XCTFail("Should accept matching pattern")
        }
    }

    func testPatternValidatorInvalidInput() {
        let validator = PatternValidator(fieldName: "Test", pattern: "[A-Z]{3}")

        do {
            _ = try validator.validate("abc")
            XCTFail("Should reject non-matching pattern")
        } catch let error as TonicError {
            if case .invalidFormat = error {
                // Success
            } else {
                XCTFail("Should throw invalidFormat error")
            }
        } catch {
            XCTFail("Should throw TonicError")
        }
    }

    // MARK: - Multiple Validators Tests

    func testChainedValidators() {
        let validators = [
            NonemptyValidator(fieldName: "Email") as FieldValidator,
            EmailValidator(),
        ]

        do {
            let result = try validators.reduce("user@example.com") { value, validator in
                try validator.validate(value)
            }
            XCTAssertEqual(result, "user@example.com")
        } catch {
            XCTFail("Should accept valid email through chain")
        }
    }

    func testChainedValidatorsRejectsAtFirstFailure() {
        let validators = [
            NonemptyValidator(fieldName: "Email") as FieldValidator,
            EmailValidator(),
        ]

        do {
            _ = try validators.reduce("invalid") { value, validator in
                try validator.validate(value)
            }
            XCTFail("Should reject invalid email through chain")
        } catch {
            // Success
        }
    }

    // MARK: - Form Validator Tests

    func testFormValidatorRegistration() {
        let formValidator = FormValidator()

        formValidator.registerField("email", validators: [EmailValidator()])
        formValidator.registerField("password", validators: [LengthValidator(minLength: 8, maxLength: 50, fieldName: "Password")])

        XCTAssertEqual(formValidator.fields.count, 2)
    }

    func testFormValidatorValidateField() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])

        formValidator.validateField("email", value: "user@example.com")

        if let result = formValidator.fields["email"] {
            XCTAssertTrue(result.isValid)
        } else {
            XCTFail("Field should exist")
        }
    }

    func testFormValidatorInvalidateField() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])

        formValidator.validateField("email", value: "invalid")

        if let result = formValidator.fields["email"] {
            XCTAssertFalse(result.isValid)
            XCTAssertNotNil(result.error)
        } else {
            XCTFail("Field should exist")
        }
    }

    func testFormValidatorFormValidity() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])
        formValidator.registerField("name", validators: [NonemptyValidator(fieldName: "Name")])

        formValidator.validateField("email", value: "user@example.com")
        formValidator.validateField("name", value: "John")

        XCTAssertTrue(formValidator.isFormValid)
    }

    func testFormValidatorFormInvalidity() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])

        formValidator.validateField("email", value: "invalid")

        XCTAssertFalse(formValidator.isFormValid)
    }

    func testFormValidatorGetErrors() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])
        formValidator.registerField("password", validators: [LengthValidator(minLength: 8, maxLength: 50, fieldName: "Password")])

        formValidator.validateField("email", value: "invalid")
        formValidator.validateField("password", value: "short")

        let errors = formValidator.getFormErrors()
        XCTAssertEqual(errors.count, 2)
    }

    func testFormValidatorClearField() {
        let formValidator = FormValidator()
        formValidator.registerField("email", validators: [EmailValidator()])

        formValidator.validateField("email", value: "user@example.com")
        XCTAssertTrue(formValidator.fields["email"]?.isValid ?? false)

        formValidator.clearField("email")
        XCTAssertTrue(formValidator.fields["email"]?.isValid ?? false)
    }

    // MARK: - String Extension Tests

    func testStringIsValidEmail() {
        XCTAssertTrue("user@example.com".isValidEmail)
        XCTAssertFalse("invalid".isValidEmail)
    }

    func testStringIsValidURL() {
        XCTAssertTrue("https://example.com".isValidURL)
        XCTAssertFalse("not a url".isValidURL)
    }

    func testStringIsNumeric() {
        XCTAssertTrue("123".isNumeric)
        XCTAssertTrue("45.67".isNumeric)
        XCTAssertFalse("abc".isNumeric)
    }

    func testStringIsNonEmpty() {
        XCTAssertTrue("hello".isNonEmpty)
        XCTAssertFalse("".isNonEmpty)
        XCTAssertFalse("   ".isNonEmpty)
    }

    // MARK: - Validation Result Tests

    func testValidationResultSuccess() {
        let result = ValidationResult.success("test")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.value, "test")
    }

    func testValidationResultFailure() {
        let error = TonicError.invalidEmail(email: "test")
        let result = ValidationResult.failure(error)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Performance Tests

    func testValidatorPerformance() {
        let validator = EmailValidator()
        let email = "user@example.com"

        let startTime = Date()
        for _ in 0..<1000 {
            _ = try? validator.validate(email)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(duration, 0.1, "Validation should be fast")
    }

    func testFormValidatorPerformance() {
        let formValidator = FormValidator()
        let startTime = Date()

        for i in 0..<100 {
            formValidator.registerField("field\(i)", validators: [EmailValidator()])
        }

        for i in 0..<100 {
            formValidator.validateField("field\(i)", value: "user\(i)@example.com")
        }

        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.5, "Form validation should be fast")
    }
}

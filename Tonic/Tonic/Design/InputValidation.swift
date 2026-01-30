//
//  InputValidation.swift
//  Tonic
//
//  Input validation components with error handling - form validation, field validators, error display
//

import SwiftUI

// MARK: - Field Validator Protocol

protocol FieldValidator {
    func validate(_ value: String) throws -> String
    var errorMessage: String? { get }
}

// MARK: - Built-in Validators

struct NonemptyValidator: FieldValidator {
    let fieldName: String
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TonicError.emptyField(fieldName: fieldName)
        }
        return value
    }
}

struct EmailValidator: FieldValidator {
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)

        guard emailPredicate.evaluate(with: trimmed) else {
            throw TonicError.invalidEmail(email: value)
        }
        return trimmed
    }
}

struct URLValidator: FieldValidator {
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespaces)),
              url.scheme != nil else {
            throw TonicError.invalidURL(url: value)
        }
        return value
    }
}

struct LengthValidator: FieldValidator {
    let minLength: Int
    let maxLength: Int
    let fieldName: String
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        let length = value.count
        guard length >= minLength else {
            throw TonicError.fieldTooShort(fieldName: fieldName, minimum: minLength)
        }
        guard length <= maxLength else {
            throw TonicError.fieldTooLong(fieldName: fieldName, maximum: maxLength)
        }
        return value
    }
}

struct NumericValidator: FieldValidator {
    let fieldName: String
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        guard !value.isEmpty, Double(value) != nil else {
            throw TonicError.notNumeric(fieldName: fieldName)
        }
        return value
    }
}

struct RangeValidator: FieldValidator {
    let fieldName: String
    let min: Double
    let max: Double
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        guard let number = Double(value) else {
            throw TonicError.notNumeric(fieldName: fieldName)
        }
        guard number >= min, number <= max else {
            throw TonicError.valueOutOfRange(field: fieldName, min: String(min), max: String(max))
        }
        return value
    }
}

struct PatternValidator: FieldValidator {
    let fieldName: String
    let pattern: String
    var errorMessage: String?

    func validate(_ value: String) throws -> String {
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        guard predicate.evaluate(with: value) else {
            throw TonicError.invalidFormat(fieldName: fieldName, expectedFormat: pattern)
        }
        return value
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let error: TonicError?
    let value: String

    init(isValid: Bool, error: TonicError? = nil, value: String = "") {
        self.isValid = isValid
        self.error = error
        self.value = value
    }

    static func success(_ value: String) -> ValidationResult {
        ValidationResult(isValid: true, error: nil, value: value)
    }

    static func failure(_ error: TonicError) -> ValidationResult {
        ValidationResult(isValid: false, error: error, value: "")
    }
}

// MARK: - Validated TextField Component

struct ValidatedTextField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    let validators: [FieldValidator]
    @State private var validationResult: ValidationResult = .success("")
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Label
            Text(label)
                .font(DesignTokens.Typography.captionEmphasized)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // TextField with validation
            TextField(placeholder, text: $value)
                .font(DesignTokens.Typography.body)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                        .stroke(
                            validationResult.isValid ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.error,
                            lineWidth: 1
                        )
                )
                .onChange(of: value) { oldValue, newValue in
                    validateInput(newValue)
                }
                .onReceive(Just(value)) { _ in
                    if !isFocused {
                        validateInput(value)
                    }
                }
                .focused($isFocused)

            // Error message
            if !validationResult.isValid, let error = validationResult.error {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.error)

                    Text(error.errorDescription ?? "Invalid input")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.error)

                    Spacer()
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.error.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.medium)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private func validateInput(_ input: String) {
        for validator in validators {
            do {
                let validated = try validator.validate(input)
                validationResult = .success(validated)
            } catch let error as TonicError {
                validationResult = .failure(error)
                break
            } catch {
                validationResult = .failure(
                    .validationFailed(fieldName: label, reason: error.localizedDescription)
                )
                break
            }
        }
    }
}

// MARK: - Form Validator

class FormValidator: ObservableObject {
    @Published var fields: [String: ValidationResult] = [:]
    @Published var isFormValid: Bool = false

    private var fieldValidators: [String: [FieldValidator]] = [:]

    func registerField(_ fieldName: String, validators: [FieldValidator]) {
        fieldValidators[fieldName] = validators
        fields[fieldName] = .success("")
    }

    func validateField(_ fieldName: String, value: String) {
        guard let validators = fieldValidators[fieldName] else { return }

        for validator in validators {
            do {
                let validated = try validator.validate(value)
                fields[fieldName] = .success(validated)
            } catch let error as TonicError {
                fields[fieldName] = .failure(error)
                break
            } catch {
                fields[fieldName] = .failure(
                    .validationFailed(fieldName: fieldName, reason: error.localizedDescription)
                )
                break
            }
        }

        updateFormValidity()
    }

    func validateForm(_ formData: [String: String]) -> Bool {
        var allValid = true

        for (fieldName, value) in formData {
            validateField(fieldName, value: value)
            if let result = fields[fieldName], !result.isValid {
                allValid = false
            }
        }

        return allValid
    }

    private func updateFormValidity() {
        isFormValid = fields.allSatisfy { _, result in result.isValid }
    }

    func getFieldError(_ fieldName: String) -> TonicError? {
        fields[fieldName]?.error
    }

    func getFormErrors() -> [String: TonicError] {
        fields.compactMapValues { result in
            result.isValid ? nil : result.error
        }
    }

    func clearField(_ fieldName: String) {
        fields[fieldName] = .success("")
        updateFormValidity()
    }

    func clearAll() {
        fields.removeAll()
        isFormValid = false
    }
}

// MARK: - Validation Helper Extensions

extension String {
    func validate(with validators: [FieldValidator]) throws -> String {
        var result = self
        for validator in validators {
            result = try validator.validate(result)
        }
        return result
    }

    var isValidEmail: Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: self)
    }

    var isValidURL: Bool {
        URL(string: self) != nil
    }

    var isNumeric: Bool {
        Double(self) != nil
    }

    var isNonEmpty: Bool {
        !trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Preview

#if DEBUG
struct InputValidation_Previews: PreviewProvider {
    @State static var email = ""
    @State static var password = ""

    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ValidatedTextField(
                label: "Email",
                placeholder: "user@example.com",
                value: $email,
                validators: [
                    NonemptyValidator(fieldName: "Email"),
                    EmailValidator(),
                ]
            )

            ValidatedTextField(
                label: "Password",
                placeholder: "At least 8 characters",
                value: $password,
                validators: [
                    NonemptyValidator(fieldName: "Password"),
                    LengthValidator(minLength: 8, maxLength: 100, fieldName: "Password"),
                ]
            )

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.background)
    }
}
#endif

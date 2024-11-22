# Personalized Medicine Smart Contract

## Overview
The Personalized Medicine Smart Contract is a blockchain-based solution built on Clarity for managing medical records, prescriptions, and healthcare provider authorizations. This system enables secure, transparent, and efficient management of personalized medical data while maintaining patient privacy and regulatory compliance.

## Features
- **Patient Record Management**
  - Comprehensive medical history storage
  - Genetic profile data management
  - Current prescription tracking
  - Healthcare provider authorization control

- **Healthcare Provider Management**
  - Provider registration and verification
  - Specialization and licensing documentation
  - Active status tracking
  - Authorization-based access control

- **Prescription System**
  - Secure prescription creation and management
  - Dosage and medication tracking
  - Time-bound prescription validity
  - Active/inactive status management

## Technical Architecture

### Data Structures

#### 1. Patient Medical Records
```clarity
{
    comprehensive-medical-history: (string-ascii 256),
    genetic-profile-data: (string-ascii 256),
    current-prescriptions: (list 10 uint),
    approved-healthcare-providers: (list 5 principal)
}
```

#### 2. Healthcare Provider Registry
```clarity
{
    medical-specialization: (string-ascii 64),
    medical-license-identifier: (string-ascii 32),
    provider-active-status: bool
}
```

#### 3. Prescription Records
```clarity
{
    patient-wallet-address: principal,
    prescribing-provider: principal,
    prescribed-medication: (string-ascii 64),
    medication-dosage-instructions: (string-ascii 32),
    prescription-start-timestamp: uint,
    prescription-end-timestamp: uint,
    prescription-active-status: bool
}
```

## Functions

### Patient Management

#### `register-new-patient`
- **Description**: Registers a new patient in the system
- **Parameters**:
  - comprehensive-medical-history: (string-ascii 256)
  - genetic-profile-data: (string-ascii 256)
- **Returns**: Success/Error response
- **Access**: Public

#### `authorize-healthcare-provider`
- **Description**: Authorizes a healthcare provider to access patient records
- **Parameters**:
  - provider-wallet-address: principal
- **Returns**: Success/Error response
- **Access**: Public (patient only)

### Healthcare Provider Management

#### `register-healthcare-provider`
- **Description**: Registers a new healthcare provider
- **Parameters**:
  - medical-specialization: (string-ascii 64)
  - medical-license-identifier: (string-ascii 32)
- **Returns**: Success/Error response
- **Access**: Public

#### `verify-provider-credentials`
- **Description**: Verifies the active status of a healthcare provider
- **Parameters**:
  - provider-wallet-address: principal
- **Returns**: Boolean
- **Access**: Read-only

### Prescription Management

#### `create-new-prescription`
- **Description**: Creates a new prescription for a patient
- **Parameters**:
  - patient-wallet-address: principal
  - prescribed-medication: (string-ascii 64)
  - medication-dosage-instructions: (string-ascii 32)
  - prescription-start-timestamp: uint
  - prescription-end-timestamp: uint
- **Returns**: Success/Error response
- **Access**: Public (authorized providers only)

## Error Codes
- `ERR-UNAUTHORIZED-ACCESS (u1)`: Unauthorized access attempt
- `ERR-DUPLICATE-PATIENT-RECORD (u2)`: Patient already registered
- `ERR-PATIENT-RECORD-NOT-FOUND (u3)`: Patient record doesn't exist
- `ERR-INVALID-PRESCRIPTION-DATA (u4)`: Invalid prescription parameters
- `ERR-DUPLICATE-HEALTHCARE-PROVIDER (u5)`: Provider already registered
- `ERR-HEALTHCARE-PROVIDER-NOT-FOUND (u6)`: Provider not found in registry

## Security Considerations
1. **Access Control**
   - Only authorized healthcare providers can access patient records
   - Patients control provider authorization
   - Prescription management restricted to authorized providers

2. **Data Privacy**
   - Sensitive data stored with appropriate access controls
   - Limited list sizes to prevent overflow attacks
   - Status tracking for all entities

3. **Input Validation**
   - Comprehensive error checking
   - Date validation for prescriptions
   - Authorization verification

## Contributing
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Create pull request
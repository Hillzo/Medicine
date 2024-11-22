;; Personalized Medicine Contract
;; Handles patient medical records, prescriptions, and healthcare provider authorizations

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-DUPLICATE-PATIENT-RECORD (err u2))
(define-constant ERR-PATIENT-RECORD-NOT-FOUND (err u3))
(define-constant ERR-INVALID-PRESCRIPTION-DATA (err u4))
(define-constant ERR-DUPLICATE-HEALTHCARE-PROVIDER (err u5))
(define-constant ERR-HEALTHCARE-PROVIDER-NOT-FOUND (err u6))

;; Data structures
(define-map patient-medical-records 
    { patient-wallet-address: principal }
    {
        comprehensive-medical-history: (string-ascii 256),
        genetic-profile-data: (string-ascii 256),
        current-prescriptions: (list 10 uint),
        approved-healthcare-providers: (list 5 principal)
    }
)

(define-map healthcare-provider-registry
    { provider-wallet-address: principal }
    {
        medical-specialization: (string-ascii 64),
        medical-license-identifier: (string-ascii 32),
        provider-active-status: bool
    }
)

(define-map prescription-records
    { prescription-identifier: uint }
    {
        patient-wallet-address: principal,
        prescribing-provider: principal,
        prescribed-medication: (string-ascii 64),
        medication-dosage-instructions: (string-ascii 32),
        prescription-start-timestamp: uint,
        prescription-end-timestamp: uint,
        prescription-active-status: bool
    }
)

;; Authorization verification
(define-private (verify-provider-authorization (patient-wallet-address principal) (provider-wallet-address principal))
    (let ((patient-record (get-patient-medical-record patient-wallet-address)))
        (match patient-record
            record (is-some (index-of (get approved-healthcare-providers record) provider-wallet-address))
            false
        )
    )
)

;; Patient management functions
(define-public (register-new-patient (comprehensive-medical-history (string-ascii 256)) (genetic-profile-data (string-ascii 256)))
    (let ((requesting-wallet tx-sender))
        (if (is-some (get-patient-medical-record requesting-wallet))
            ERR-DUPLICATE-PATIENT-RECORD
            (ok (map-set patient-medical-records
                { patient-wallet-address: requesting-wallet }
                {
                    comprehensive-medical-history: comprehensive-medical-history,
                    genetic-profile-data: genetic-profile-data,
                    current-prescriptions: (list),
                    approved-healthcare-providers: (list)
                }
            ))
        )
    )
)

(define-read-only (get-patient-medical-record (patient-wallet-address principal))
    (map-get? patient-medical-records { patient-wallet-address: patient-wallet-address })
)

(define-public (authorize-healthcare-provider (provider-wallet-address principal))
    (let (
        (requesting-wallet tx-sender)
        (patient-record (get-patient-medical-record requesting-wallet))
        )
        (match patient-record
            existing-record (
                (ok (map-set patient-medical-records
                    { patient-wallet-address: requesting-wallet }
                    (merge existing-record
                        { approved-healthcare-providers: (unwrap! (as-max-len? (append (get approved-healthcare-providers existing-record) provider-wallet-address) u5) ERR-UNAUTHORIZED-ACCESS) }
                    )
                ))
            )
            ERR-PATIENT-RECORD-NOT-FOUND
        )
    )
)

;; Healthcare provider functions
(define-public (register-healthcare-provider (medical-specialization (string-ascii 64)) (medical-license-identifier (string-ascii 32)))
    (let ((requesting-wallet tx-sender))
        (if (is-some (map-get? healthcare-provider-registry { provider-wallet-address: requesting-wallet }))
            ERR-DUPLICATE-HEALTHCARE-PROVIDER
            (ok (map-set healthcare-provider-registry
                { provider-wallet-address: requesting-wallet }
                {
                    medical-specialization: medical-specialization,
                    medical-license-identifier: medical-license-identifier,
                    provider-active-status: true
                }
            ))
        )
    )
)

(define-read-only (get-provider-details (provider-wallet-address principal))
    (map-get? healthcare-provider-registry { provider-wallet-address: provider-wallet-address })
)

;; Prescription management functions
(define-data-var global-prescription-counter uint u0)

(define-private (generate-prescription-identifier)
    (let ((current-counter (var-get global-prescription-counter)))
        (var-set global-prescription-counter (+ current-counter u1))
        current-counter
    )
)

(define-public (create-new-prescription 
    (patient-wallet-address principal)
    (prescribed-medication (string-ascii 64))
    (medication-dosage-instructions (string-ascii 32))
    (prescription-start-timestamp uint)
    (prescription-end-timestamp uint)
)
    (let (
        (prescribing-provider tx-sender)
        (prescription-identifier (generate-prescription-identifier))
        )
        (asserts! (verify-provider-authorization patient-wallet-address prescribing-provider) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (< prescription-start-timestamp prescription-end-timestamp) ERR-INVALID-PRESCRIPTION-DATA)
        
        (ok (map-set prescription-records
            { prescription-identifier: prescription-identifier }
            {
                patient-wallet-address: patient-wallet-address,
                prescribing-provider: prescribing-provider,
                prescribed-medication: prescribed-medication,
                medication-dosage-instructions: medication-dosage-instructions,
                prescription-start-timestamp: prescription-start-timestamp,
                prescription-end-timestamp: prescription-end-timestamp,
                prescription-active-status: true
            }
        ))
    )
)

(define-read-only (get-prescription-details (prescription-identifier uint))
    (map-get? prescription-records { prescription-identifier: prescription-identifier })
)

(define-public (deactivate-existing-prescription (prescription-identifier uint))
    (let (
        (requesting-wallet tx-sender)
        (prescription-record (get-prescription-details prescription-identifier))
        )
        (match prescription-record
            existing-prescription (
                (asserts! (or
                    (is-eq requesting-wallet (get prescribing-provider existing-prescription))
                    (is-eq requesting-wallet (get patient-wallet-address existing-prescription))
                ) ERR-UNAUTHORIZED-ACCESS)
                (ok (map-set prescription-records
                    { prescription-identifier: prescription-identifier }
                    (merge existing-prescription { prescription-active-status: false })
                ))
            )
            ERR-INVALID-PRESCRIPTION-DATA
        )
    )
)

;; Utility functions
(define-read-only (get-patient-active-prescriptions (patient-wallet-address principal))
    (filter prescription-records
        (lambda (prescription)
            (and
                (is-eq (get patient-wallet-address prescription) patient-wallet-address)
                (get prescription-active-status prescription)
            )
        )
    )
)

(define-read-only (verify-provider-credentials (provider-wallet-address principal))
    (match (get-provider-details provider-wallet-address)
        provider-record (get provider-active-status provider-record)
        false
    )
)
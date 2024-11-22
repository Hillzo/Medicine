;; Personalized Medicine Contract
;; Handles patient medical records, prescriptions, and healthcare provider authorizations

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-DUPLICATE-PATIENT-RECORD (err u2))
(define-constant ERR-PATIENT-RECORD-NOT-FOUND (err u3))
(define-constant ERR-INVALID-PRESCRIPTION-DATA (err u4))
(define-constant ERR-DUPLICATE-HEALTHCARE-PROVIDER (err u5))
(define-constant ERR-HEALTHCARE-PROVIDER-NOT-FOUND (err u6))
(define-constant ERR-PRESCRIPTION-LIST-OVERFLOW (err u7))
(define-constant ERR-INVALID-INPUT (err u8))
(define-constant ERR-PROVIDER-ALREADY-AUTHORIZED (err u9))
(define-constant ERR-MAX-PROVIDERS-REACHED (err u10))

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

;; Global variables
(define-data-var global-prescription-counter uint u0)
(define-data-var all-prescription-ids (list 100 uint) (list))

;; Helper functions for input validation
(define-private (is-valid-ascii-string (input (string-ascii 256)))
    (and 
        (is-eq (len input) (len (concat input "")))
        (>= (len input) u1)
        (<= (len input) u256)
    )
)

(define-private (is-valid-ascii-string-64 (input (string-ascii 64)))
    (and 
        (is-eq (len input) (len (concat input "")))
        (>= (len input) u1)
        (<= (len input) u64)
    )
)

(define-private (is-valid-ascii-string-32 (input (string-ascii 32)))
    (and 
        (is-eq (len input) (len (concat input "")))
        (>= (len input) u1)
        (<= (len input) u32)
    )
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
        (asserts! (is-valid-ascii-string comprehensive-medical-history) ERR-INVALID-INPUT)
        (asserts! (is-valid-ascii-string genetic-profile-data) ERR-INVALID-INPUT)
        (asserts! (is-none (get-patient-medical-record requesting-wallet)) ERR-DUPLICATE-PATIENT-RECORD)
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

(define-read-only (get-patient-medical-record (patient-wallet-address principal))
    (map-get? patient-medical-records { patient-wallet-address: patient-wallet-address })
)

(define-public (authorize-healthcare-provider (provider-wallet-address principal))
    (let (
        (requesting-wallet tx-sender)
        (patient-record (get-patient-medical-record requesting-wallet))
        )
        (asserts! (is-some patient-record) ERR-PATIENT-RECORD-NOT-FOUND)
        (let ((existing-record (unwrap-panic patient-record)))
            (asserts! (< (len (get approved-healthcare-providers existing-record)) u5) ERR-MAX-PROVIDERS-REACHED)
            (asserts! (is-none (index-of (get approved-healthcare-providers existing-record) provider-wallet-address)) ERR-PROVIDER-ALREADY-AUTHORIZED)
            (ok (map-set patient-medical-records
                { patient-wallet-address: requesting-wallet }
                (merge existing-record
                    { approved-healthcare-providers: 
                        (unwrap! (as-max-len? 
                            (append (get approved-healthcare-providers existing-record) provider-wallet-address)
                            u5
                        ) ERR-MAX-PROVIDERS-REACHED)
                    }
                )
            ))
        )
    )
)

;; Healthcare provider functions
(define-public (register-healthcare-provider (medical-specialization (string-ascii 64)) (medical-license-identifier (string-ascii 32)))
    (let ((requesting-wallet tx-sender))
        (asserts! (is-valid-ascii-string-64 medical-specialization) ERR-INVALID-INPUT)
        (asserts! (is-valid-ascii-string-32 medical-license-identifier) ERR-INVALID-INPUT)
        (asserts! (is-none (get-provider-details requesting-wallet)) ERR-DUPLICATE-HEALTHCARE-PROVIDER)
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

(define-read-only (get-provider-details (provider-wallet-address principal))
    (map-get? healthcare-provider-registry { provider-wallet-address: provider-wallet-address })
)

;; Prescription management functions
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
        (asserts! (is-valid-ascii-string-64 prescribed-medication) ERR-INVALID-INPUT)
        (asserts! (is-valid-ascii-string-32 medication-dosage-instructions) ERR-INVALID-INPUT)

        ;; Add prescription record
        (map-set prescription-records
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
        )

        ;; Add prescription ID to global list
        (match (as-max-len? (append (var-get all-prescription-ids) prescription-identifier) u100)
            success (ok (var-set all-prescription-ids success))
            ERR-PRESCRIPTION-LIST-OVERFLOW
        )
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
        (asserts! (is-some prescription-record) ERR-INVALID-PRESCRIPTION-DATA)
        (let ((existing-prescription (unwrap-panic prescription-record)))
            (asserts! (or
                (is-eq requesting-wallet (get prescribing-provider existing-prescription))
                (is-eq requesting-wallet (get patient-wallet-address existing-prescription))
            ) ERR-UNAUTHORIZED-ACCESS)
            (ok (map-set prescription-records
                { prescription-identifier: prescription-identifier }
                (merge existing-prescription { prescription-active-status: false })
            ))
        )
    )
)

;; function to correctly use fold
(define-read-only (get-patient-active-prescriptions (patient-wallet-address principal))
    (ok (fold filter-active-prescription-fold (var-get all-prescription-ids) (list)))
)

(define-private (filter-active-prescription-fold 
    (prescription-id uint) 
    (filtered-list (list 100 uint))
)
    (let ((patient-wallet-address tx-sender))
        (if (is-active-prescription patient-wallet-address prescription-id)
            (unwrap! (as-max-len? (append filtered-list prescription-id) u100) filtered-list)
            filtered-list
        )
    )
)

(define-private (is-active-prescription (patient-wallet-address principal) (prescription-identifier uint))
    (is-active-prescription-for-patient prescription-identifier patient-wallet-address)
)

(define-private (is-active-prescription-for-patient (prescription-identifier uint) (patient-wallet-address principal))
    (match (get-prescription-details prescription-identifier)
        prescription 
            (and 
                (is-eq (get patient-wallet-address prescription) patient-wallet-address)
                (get prescription-active-status prescription)
            )
        false
    )
)

(define-read-only (verify-provider-credentials (provider-wallet-address principal))
    (match (get-provider-details provider-wallet-address)
        provider-record (get provider-active-status provider-record)
        false
    )
)
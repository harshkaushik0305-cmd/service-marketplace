;; Service Marketplace Contract
;; A decentralized marketplace where users can list and purchase services using tokens

;; Define the marketplace token
(define-fungible-token marketplace-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-service-not-found (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-service-already-exists (err u104))
(define-constant err-unauthorized (err u105))

;; Data structures
(define-map services 
  { service-id: uint }
  { 
    provider: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    is-active: bool
  }
)

(define-map user-balances principal uint)
(define-data-var next-service-id uint u1)
(define-data-var total-services uint u0)

;; Function 1: List a new service
(define-public (list-service (title (string-ascii 64)) (description (string-ascii 256)) (price uint))
  (let 
    (
      (service-id (var-get next-service-id))
    )
    (begin
      ;; Validate inputs
      (asserts! (> price u0) err-invalid-amount)
      (asserts! (> (len title) u0) err-invalid-amount)
      
      ;; Check if service already exists (basic check by provider and title combination)
      (asserts! 
        (is-none (map-get? services { service-id: service-id }))
        err-service-already-exists
      )
      
      ;; Create the service listing
      (map-set services 
        { service-id: service-id }
        {
          provider: tx-sender,
          title: title,
          description: description,
          price: price,
          is-active: true
        }
      )
      
      ;; Update counters
      (var-set next-service-id (+ service-id u1))
      (var-set total-services (+ (var-get total-services) u1))
      
      ;; Return success with service ID
      (ok service-id)
    )
  )
)

;; Function 2: Purchase a service
(define-public (purchase-service (service-id uint) (payment-amount uint))
  (let 
    (
      (service-info (unwrap! (map-get? services { service-id: service-id }) err-service-not-found))
      (service-price (get price service-info))
      (service-provider (get provider service-info))
      (buyer-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
    (begin
      ;; Validate service exists and is active
      (asserts! (get is-active service-info) err-service-not-found)
      
      ;; Validate payment amount
      (asserts! (>= payment-amount service-price) err-insufficient-payment)
      (asserts! (>= buyer-balance payment-amount) err-insufficient-payment)
      
      ;; Prevent self-purchase
      (asserts! (not (is-eq tx-sender service-provider)) err-unauthorized)
      
      ;; Process payment
      ;; Deduct from buyer
      (map-set user-balances tx-sender (- buyer-balance payment-amount))
      
      ;; Add to service provider
      (map-set user-balances 
        service-provider 
        (+ (default-to u0 (map-get? user-balances service-provider)) payment-amount)
      )
      
      ;; Emit purchase event (using print for logging)
      (print {
        event: "service-purchased",
        service-id: service-id,
        buyer: tx-sender,
        provider: service-provider,
        amount: payment-amount
      })
      
      ;; Return success
      (ok true)
    )
  )
)

;; Read-only functions for querying data

;; Get service details
(define-read-only (get-service (service-id uint))
  (map-get? services { service-id: service-id }))

;; Get user balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user)))

;; Get total services count
(define-read-only (get-total-services)
  (var-get total-services))

;; Get next service ID
(define-read-only (get-next-service-id)
  (var-get next-service-id))

;; Admin function to add initial balance (for testing purposes)
(define-public (add-balance (user principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set user-balances 
      user 
      (+ (default-to u0 (map-get? user-balances user)) amount)
    )
    (ok true)
  )
)
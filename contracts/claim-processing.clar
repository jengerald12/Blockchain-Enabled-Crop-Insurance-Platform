;; Automated Claim Processing Contract
;; Triggers payouts based on weather events

(define-map claims
  { id: uint }
  {
    policy-id: uint,
    event-type: (string-ascii 20),
    event-date: uint,
    location: (string-ascii 50),
    damage-amount: uint,
    status: (string-ascii 10),
    payout-amount: uint,
    timestamp: uint
  }
)

(define-map policy-claims
  { policy-id: uint }
  { claim-ids: (list 10 uint) }
)

(define-map event-thresholds
  { event-type: (string-ascii 20) }
  {
    rainfall-min: uint,
    temperature-max: int,
    wind-speed-min: uint
  }
)

(define-data-var last-id uint u0)
(define-constant admin tx-sender)

;; Set event thresholds
(define-public (set-event-threshold
              (event-type (string-ascii 20))
              (rainfall-min uint)
              (temperature-max int)
              (wind-speed-min uint))
  (begin
    ;; Only admin can set thresholds
    (asserts! (is-eq tx-sender admin) (err u1))

    ;; Set the event threshold
    (ok (map-set event-thresholds
      { event-type: event-type }
      {
        rainfall-min: rainfall-min,
        temperature-max: temperature-max,
        wind-speed-min: wind-speed-min
      }
    ))
  )
)

;; File a claim
(define-public (file-claim
              (policy-id uint)
              (event-type (string-ascii 20))
              (event-date uint)
              (location (string-ascii 50))
              (damage-amount uint))
  (let
    (
      (new-id (+ (var-get last-id) u1))
      (policy-claim-data (default-to { claim-ids: (list) }
                        (map-get? policy-claims { policy-id: policy-id })))
    )
    ;; Update claim counter
    (var-set last-id new-id)

    ;; Update policy claims
    (map-set policy-claims
      { policy-id: policy-id }
      { claim-ids: (append (get claim-ids policy-claim-data) new-id) }
    )

    ;; Create the claim
    (ok (map-set claims
      { id: new-id }
      {
        policy-id: policy-id,
        event-type: event-type,
        event-date: event-date,
        location: location,
        damage-amount: damage-amount,
        status: "pending",
        payout-amount: u0,
        timestamp: block-height
      }
    ))
  )
)

;; Process a claim
(define-public (process-claim (claim-id uint))
  (let
    (
      (claim (unwrap! (get-claim claim-id) (err u404)))
    )
    ;; Only admin can process claims
    (asserts! (is-eq tx-sender admin) (err u1))
    ;; Only pending claims can be processed
    (asserts! (is-eq (get status claim) "pending") (err u2))

    ;; Calculate payout amount (simplified)
    ;; In a real system, this would check weather data against thresholds
    (let
      (
        (payout-amount (get damage-amount claim))
      )
      ;; Update claim status and payout
      (ok (map-set claims
        { id: claim-id }
        (merge claim {
          status: "approved",
          payout-amount: payout-amount
        })
      ))
    )
  )
)

;; Get claim details
(define-read-only (get-claim (id uint))
  (map-get? claims { id: id })
)

;; Get policy claims
(define-read-only (get-policy-claims (policy-id uint))
  (map-get? policy-claims { policy-id: policy-id })
)

;; Get event threshold
(define-read-only (get-event-threshold (event-type (string-ascii 20)))
  (map-get? event-thresholds { event-type: event-type })
)

;; Get total claims count
(define-read-only (get-total-claims)
  (var-get last-id)
)


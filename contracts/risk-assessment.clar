;; Risk Assessment Contract
;; Adjusts premiums based on historical data and predictions

(define-map risk-profiles
  { location: (string-ascii 50), crop: (string-ascii 20) }
  {
    base-risk: uint,
    historical-loss: uint,
    climate-factor: uint,
    soil-quality: uint,
    last-updated: uint
  }
)

(define-map location-history
  { location: (string-ascii 50) }
  {
    drought-count: uint,
    flood-count: uint,
    frost-count: uint,
    last-event: uint
  }
)

(define-constant admin tx-sender)

;; Update risk profile
(define-public (update-risk-profile
              (location (string-ascii 50))
              (crop (string-ascii 20))
              (base-risk uint)
              (historical-loss uint)
              (climate-factor uint)
              (soil-quality uint))
  (begin
    ;; Only admin can update risk profiles
    (asserts! (is-eq tx-sender admin) (err u1))

    ;; Update the risk profile
    (ok (map-set risk-profiles
      { location: location, crop: crop }
      {
        base-risk: base-risk,
        historical-loss: historical-loss,
        climate-factor: climate-factor,
        soil-quality: soil-quality,
        last-updated: block-height
      }
    ))
  )
)

;; Record weather event
(define-public (record-weather-event
              (location (string-ascii 50))
              (event-type (string-ascii 10)))
  (let
    (
      (history (default-to
               { drought-count: u0, flood-count: u0, frost-count: u0, last-event: u0 }
               (map-get? location-history { location: location })))
      (updated-history (update-event-count history event-type))
    )
    ;; Only admin can record events
    (asserts! (is-eq tx-sender admin) (err u1))

    ;; Update location history
    (ok (map-set location-history
      { location: location }
      (merge updated-history { last-event: block-height })
    ))
  )
)

;; Update event count based on type
(define-private (update-event-count (history { drought-count: uint, flood-count: uint, frost-count: uint, last-event: uint }) (event-type (string-ascii 10)))
  (if (is-eq event-type "drought")
    (merge history { drought-count: (+ (get drought-count history) u1) })
    (if (is-eq event-type "flood")
      (merge history { flood-count: (+ (get flood-count history) u1) })
      (if (is-eq event-type "frost")
        (merge history { frost-count: (+ (get frost-count history) u1) })
        history
      )
    )
  )
)

;; Calculate risk factor
(define-public (calculate-risk-factor
              (location (string-ascii 50))
              (crop (string-ascii 20)))
  (let
    (
      (profile (unwrap! (get-risk-profile location crop) (err u404)))
      (history (default-to
               { drought-count: u0, flood-count: u0, frost-count: u0, last-event: u0 }
               (map-get? location-history { location: location })))
      (base-risk (get base-risk profile))
      (historical-factor (+ u100 (get historical-loss profile)))
      (climate-factor (get climate-factor profile))
      (event-factor (calculate-event-factor history))
    )
    ;; Calculate combined risk factor
    (ok (/ (* base-risk (+ historical-factor climate-factor event-factor)) u300))
  )
)

;; Calculate factor based on event history
(define-private (calculate-event-factor (history { drought-count: uint, flood-count: uint, frost-count: uint, last-event: uint }))
  (+ u100
     (* (get drought-count history) u10)
     (* (get flood-count history) u15)
     (* (get frost-count history) u20))
)

;; Get risk profile
(define-read-only (get-risk-profile (location (string-ascii 50)) (crop (string-ascii 20)))
  (map-get? risk-profiles { location: location, crop: crop })
)

;; Get location history
(define-read-only (get-location-history (location (string-ascii 50)))
  (map-get? location-history { location: location })
)


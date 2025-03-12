;; Weather Data Oracle Contract
;; Provides verified climate information

(define-map weather-data
  { id: uint }
  {
    location: (string-ascii 50),
    date: uint,
    temperature: int,
    rainfall: uint,
    humidity: uint,
    wind-speed: uint,
    data-source: (string-ascii 50),
    timestamp: uint
  }
)

(define-map location-data
  { location: (string-ascii 50), date: uint }
  { data-id: uint }
)

(define-data-var last-id uint u0)
(define-constant admin tx-sender)
(define-constant oracle-sources (list 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))

;; Submit weather data
(define-public (submit-weather-data
              (location (string-ascii 50))
              (date uint)
              (temperature int)
              (rainfall uint)
              (humidity uint)
              (wind-speed uint)
              (data-source (string-ascii 50)))
  (let
    (
      (new-id (+ (var-get last-id) u1))
    )
    ;; Only authorized oracle sources can submit data
    (asserts! (is-some (index-of oracle-sources tx-sender)) (err u1))

    ;; Update data counter
    (var-set last-id new-id)

    ;; Update location data mapping
    (map-set location-data
      { location: location, date: date }
      { data-id: new-id }
    )

    ;; Create the weather data entry
    (ok (map-set weather-data
      { id: new-id }
      {
        location: location,
        date: date,
        temperature: temperature,
        rainfall: rainfall,
        humidity: humidity,
        wind-speed: wind-speed,
        data-source: data-source,
        timestamp: block-height
      }
    ))
  )
)

;; Add oracle source
(define-public (add-oracle-source (source principal))
  (begin
    ;; Only admin can add sources
    (asserts! (is-eq tx-sender admin) (err u1))

    ;; No implementation for adding to a list in Clarity
    ;; This is a simplified version
    (ok true)
  )
)

;; Get weather data by ID
(define-read-only (get-weather-data (id uint))
  (map-get? weather-data { id: id })
)

;; Get weather data by location and date
(define-read-only (get-location-weather (location (string-ascii 50)) (date uint))
  (let
    (
      (data-id (map-get? location-data { location: location, date: date }))
    )
    (if (is-some data-id)
      (map-get? weather-data { id: (get data-id (unwrap-panic data-id)) })
      none
    )
  )
)

;; Get total weather data entries
(define-read-only (get-total-entries)
  (var-get last-id)
)


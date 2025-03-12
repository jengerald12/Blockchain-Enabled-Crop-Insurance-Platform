;; Policy Issuance Contract
;; Manages insurance terms for different crops

(define-map policies
  { id: uint }
  {
    farmer: principal,
    crop: (string-ascii 20),
    location: (string-ascii 50),
    area: uint,
    premium: uint,
    coverage: uint,
    start-date: uint,
    end-date: uint,
    status: (string-ascii 10)
  }
)

(define-map crop-terms
  { crop: (string-ascii 20) }
  {
    base-premium: uint,
    coverage-limit: uint,
    risk-factor: uint
  }
)

(define-data-var last-id uint u0)
(define-constant admin tx-sender)

;; Add or update crop terms
(define-public (set-crop-terms
              (crop (string-ascii 20))
              (base-premium uint)
              (coverage-limit uint)
              (risk-factor uint))
  (begin
    ;; Only admin can set terms
    (asserts! (is-eq tx-sender admin) (err u1))

    ;; Set the crop terms
    (ok (map-set crop-terms
      { crop: crop }
      {
        base-premium: base-premium,
        coverage-limit: coverage-limit,
        risk-factor: risk-factor
      }
    ))
  )
)

;; Purchase a policy
(define-public (purchase-policy
              (crop (string-ascii 20))
              (location (string-ascii 50))
              (area uint)
              (start-date uint)
              (end-date uint))
  (let
    (
      (new-id (+ (var-get last-id) u1))
      (terms (unwrap! (get-crop-terms crop) (err u404)))
      (premium (calculate-premium area (get base-premium terms) (get risk-factor terms)))
      (coverage (calculate-coverage area (get coverage-limit terms)))
    )
    ;; Validate inputs
    (asserts! (> area u0) (err u2))
    (asserts! (< start-date end-date) (err u3))

    ;; Update policy counter
    (var-set last-id new-id)

    ;; Create the policy
    (ok (map-set policies
      { id: new-id }
      {
        farmer: tx-sender,
        crop: crop,
        location: location,
        area: area,
        premium: premium,
        coverage: coverage,
        start-date: start-date,
        end-date: end-date,
        status: "active"
      }
    ))
  )
)

;; Calculate premium based on area and risk
(define-private (calculate-premium (area uint) (base-premium uint) (risk-factor uint))
  (* area (/ (* base-premium risk-factor) u100))
)

;; Calculate coverage based on area and limit
(define-private (calculate-coverage (area uint) (coverage-limit uint))
  (* area coverage-limit)
)

;; Cancel a policy
(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy (unwrap! (get-policy policy-id) (err u404)))
    )
    ;; Only policy owner can cancel
    (asserts! (is-eq tx-sender (get farmer policy)) (err u1))
    ;; Only active policies can be cancelled
    (asserts! (is-eq (get status policy) "active") (err u4))

    ;; Update policy status
    (ok (map-set policies
      { id: policy-id }
      (merge policy { status: "cancelled" })
    ))
  )
)

;; Get policy details
(define-read-only (get-policy (id uint))
  (map-get? policies { id: id })
)

;; Get crop terms
(define-read-only (get-crop-terms (crop (string-ascii 20)))
  (map-get? crop-terms { crop: crop })
)

;; Get total policies count
(define-read-only (get-total-policies)
  (var-get last-id)
)


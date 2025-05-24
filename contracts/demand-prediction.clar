;; Demand Prediction Contract
;; Forecasts transportation needs using historical data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_ZONE (err u201))
(define-constant ERR_INVALID_TIME (err u202))

(define-data-var prediction-window uint u24) ;; hours

(define-map demand-history
  { zone: (string-ascii 20), time-slot: uint }
  {
    actual-demand: uint,
    predicted-demand: uint,
    accuracy: uint,
    recorded-at: uint
  }
)

(define-map zone-patterns
  { zone: (string-ascii 20) }
  {
    peak-hours: (list 10 uint),
    base-demand: uint,
    surge-multiplier: uint,
    last-updated: uint
  }
)

(define-map current-predictions
  { zone: (string-ascii 20), hour: uint }
  {
    predicted-demand: uint,
    confidence: uint,
    factors: (string-ascii 100),
    created-at: uint
  }
)

(define-public (record-actual-demand
  (zone (string-ascii 20))
  (time-slot uint)
  (actual-demand uint))
  (let ((existing-prediction (map-get? demand-history { zone: zone, time-slot: time-slot })))
    (match existing-prediction
      prediction-data
      (map-set demand-history
        { zone: zone, time-slot: time-slot }
        (merge prediction-data {
          actual-demand: actual-demand,
          recorded-at: block-height
        })
      )
      (map-set demand-history
        { zone: zone, time-slot: time-slot }
        {
          actual-demand: actual-demand,
          predicted-demand: u0,
          accuracy: u0,
          recorded-at: block-height
        }
      )
    )
    (ok true)
  )
)

(define-public (create-prediction
  (zone (string-ascii 20))
  (hour uint)
  (predicted-demand uint)
  (confidence uint)
  (factors (string-ascii 100)))
  (begin
    (asserts! (< hour u24) ERR_INVALID_TIME)
    (asserts! (<= confidence u100) ERR_INVALID_ZONE)
    (map-set current-predictions
      { zone: zone, hour: hour }
      {
        predicted-demand: predicted-demand,
        confidence: confidence,
        factors: factors,
        created-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-zone-pattern
  (zone (string-ascii 20))
  (peak-hours (list 10 uint))
  (base-demand uint)
  (surge-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set zone-patterns
      { zone: zone }
      {
        peak-hours: peak-hours,
        base-demand: base-demand,
        surge-multiplier: surge-multiplier,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-read-only (get-prediction (zone (string-ascii 20)) (hour uint))
  (map-get? current-predictions { zone: zone, hour: hour })
)

(define-read-only (get-zone-pattern (zone (string-ascii 20)))
  (map-get? zone-patterns { zone: zone })
)

(define-read-only (calculate-demand-score (zone (string-ascii 20)) (hour uint))
  (match (map-get? zone-patterns { zone: zone })
    pattern-data
    (let ((base (get base-demand pattern-data))
          (multiplier (get surge-multiplier pattern-data))
          (is-peak (is-some (index-of (get peak-hours pattern-data) hour))))
      (if is-peak
        (* base multiplier)
        base
      )
    )
    u0
  )
)

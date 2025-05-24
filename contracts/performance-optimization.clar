;; Performance Optimization Contract
;; Improves service efficiency through metrics and incentives

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_METRIC (err u501))
(define-constant ERR_PROVIDER_NOT_FOUND (err u502))

(define-data-var optimization-cycle uint u1008) ;; ~1 week in blocks

(define-map performance-metrics
  { provider-id: uint, period: uint }
  {
    response-time: uint,
    completion-rate: uint,
    customer-rating: uint,
    fuel-efficiency: uint,
    route-optimization: uint,
    uptime: uint,
    recorded-at: uint
  }
)

(define-map optimization-targets
  { zone: (string-ascii 20) }
  {
    target-response-time: uint,
    target-completion-rate: uint,
    target-rating: uint,
    efficiency-threshold: uint,
    last-updated: uint
  }
)

(define-map performance-scores
  { provider-id: uint }
  {
    overall-score: uint,
    efficiency-score: uint,
    reliability-score: uint,
    customer-score: uint,
    trend: (string-ascii 10),
    last-calculated: uint
  }
)

(define-map optimization-rewards
  { provider-id: uint, period: uint }
  {
    performance-bonus: uint,
    efficiency-bonus: uint,
    reliability-bonus: uint,
    total-reward: uint,
    claimed: bool
  }
)

(define-public (record-performance-metrics
  (provider-id uint)
  (response-time uint)
  (completion-rate uint)
  (customer-rating uint)
  (fuel-efficiency uint)
  (route-optimization uint)
  (uptime uint))
  (let ((current-period (/ block-height (var-get optimization-cycle))))
    (asserts! (<= completion-rate u100) ERR_INVALID_METRIC)
    (asserts! (<= customer-rating u100) ERR_INVALID_METRIC)
    (asserts! (<= uptime u100) ERR_INVALID_METRIC)

    (map-set performance-metrics
      { provider-id: provider-id, period: current-period }
      {
        response-time: response-time,
        completion-rate: completion-rate,
        customer-rating: customer-rating,
        fuel-efficiency: fuel-efficiency,
        route-optimization: route-optimization,
        uptime: uptime,
        recorded-at: block-height
      }
    )

    ;; Calculate and update performance scores
    (calculate-performance-score provider-id)

    (ok true)
  )
)

(define-public (set-optimization-targets
  (zone (string-ascii 20))
  (target-response-time uint)
  (target-completion-rate uint)
  (target-rating uint)
  (efficiency-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set optimization-targets
      { zone: zone }
      {
        target-response-time: target-response-time,
        target-completion-rate: target-completion-rate,
        target-rating: target-rating,
        efficiency-threshold: efficiency-threshold,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-public (calculate-rewards (provider-id uint))
  (let ((current-period (/ block-height (var-get optimization-cycle))))
    (match (map-get? performance-metrics { provider-id: provider-id, period: current-period })
      metrics-data
      (let ((performance-bonus (calculate-performance-bonus metrics-data))
            (efficiency-bonus (calculate-efficiency-bonus metrics-data))
            (reliability-bonus (calculate-reliability-bonus metrics-data))
            (total-reward (+ performance-bonus efficiency-bonus reliability-bonus)))

        (map-set optimization-rewards
          { provider-id: provider-id, period: current-period }
          {
            performance-bonus: performance-bonus,
            efficiency-bonus: efficiency-bonus,
            reliability-bonus: reliability-bonus,
            total-reward: total-reward,
            claimed: false
          }
        )

        (ok total-reward)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

(define-private (calculate-performance-score (provider-id uint))
  (let ((current-period (/ block-height (var-get optimization-cycle))))
    (match (map-get? performance-metrics { provider-id: provider-id, period: current-period })
      metrics-data
      (let ((efficiency-score (/ (+ (get fuel-efficiency metrics-data) (get route-optimization metrics-data)) u2))
            (reliability-score (/ (+ (get completion-rate metrics-data) (get uptime metrics-data)) u2))
            (customer-score (get customer-rating metrics-data))
            (overall-score (/ (+ efficiency-score reliability-score customer-score) u3)))

        (map-set performance-scores
          { provider-id: provider-id }
          {
            overall-score: overall-score,
            efficiency-score: efficiency-score,
            reliability-score: reliability-score,
            customer-score: customer-score,
            trend: "stable",
            last-calculated: block-height
          }
        )

        overall-score
      )
      u0
    )
  )
)

(define-private (calculate-performance-bonus (metrics {
  response-time: uint,
  completion-rate: uint,
  customer-rating: uint,
  fuel-efficiency: uint,
  route-optimization: uint,
  uptime: uint,
  recorded-at: uint
}))
  (let ((rating-bonus (if (>= (get customer-rating metrics) u90) u500 u0))
        (completion-bonus (if (>= (get completion-rate metrics) u95) u300 u0)))
    (+ rating-bonus completion-bonus)
  )
)

(define-private (calculate-efficiency-bonus (metrics {
  response-time: uint,
  completion-rate: uint,
  customer-rating: uint,
  fuel-efficiency: uint,
  route-optimization: uint,
  uptime: uint,
  recorded-at: uint
}))
  (let ((fuel-bonus (if (>= (get fuel-efficiency metrics) u85) u400 u0))
        (route-bonus (if (>= (get route-optimization metrics) u80) u200 u0)))
    (+ fuel-bonus route-bonus)
  )
)

(define-private (calculate-reliability-bonus (metrics {
  response-time: uint,
  completion-rate: uint,
  customer-rating: uint,
  fuel-efficiency: uint,
  route-optimization: uint,
  uptime: uint,
  recorded-at: uint
}))
  (if (>= (get uptime metrics) u98) u600 u0)
)

(define-read-only (get-performance-metrics (provider-id uint) (period uint))
  (map-get? performance-metrics { provider-id: provider-id, period: period })
)

(define-read-only (get-performance-score (provider-id uint))
  (map-get? performance-scores { provider-id: provider-id })
)

(define-read-only (get-optimization-targets (zone (string-ascii 20)))
  (map-get? optimization-targets { zone: zone })
)

(define-read-only (get-current-period)
  (/ block-height (var-get optimization-cycle))
)

(define-read-only (get-provider-ranking (provider-id uint))
  (match (map-get? performance-scores { provider-id: provider-id })
    score-data
    (let ((overall (get overall-score score-data)))
      (if (>= overall u90)
        "excellent"
        (if (>= overall u75)
          "good"
          (if (>= overall u60)
            "average"
            "needs-improvement"
          )
        )
      )
    )
    "unrated"
  )
)

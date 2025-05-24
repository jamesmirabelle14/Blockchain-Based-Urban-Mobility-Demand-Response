;; Capacity Allocation Contract
;; Manages service deployment and resource allocation

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSUFFICIENT_CAPACITY (err u301))
(define-constant ERR_ALLOCATION_NOT_FOUND (err u302))
(define-constant ERR_INVALID_PROVIDER (err u303))

(define-data-var next-allocation-id uint u1)

(define-map capacity-allocations
  { allocation-id: uint }
  {
    provider-id: uint,
    zone: (string-ascii 20),
    vehicle-count: uint,
    start-time: uint,
    end-time: uint,
    status: (string-ascii 10),
    utilization: uint,
    created-at: uint
  }
)

(define-map zone-capacity
  { zone: (string-ascii 20) }
  {
    total-capacity: uint,
    allocated-capacity: uint,
    available-capacity: uint,
    last-updated: uint
  }
)

(define-map provider-allocations
  { provider-id: uint, zone: (string-ascii 20) }
  {
    active-vehicles: uint,
    total-allocations: uint,
    performance-score: uint
  }
)

(define-public (allocate-capacity
  (provider-id uint)
  (zone (string-ascii 20))
  (vehicle-count uint)
  (duration-hours uint))
  (let ((allocation-id (var-get next-allocation-id))
        (start-time block-height)
        (end-time (+ block-height (* duration-hours u144)))) ;; assuming ~10min blocks

    ;; Check if zone has available capacity
    (match (map-get? zone-capacity { zone: zone })
      zone-data
      (asserts! (>= (get available-capacity zone-data) vehicle-count) ERR_INSUFFICIENT_CAPACITY)
      true ;; If zone doesn't exist, allow allocation
    )

    ;; Create allocation
    (map-set capacity-allocations
      { allocation-id: allocation-id }
      {
        provider-id: provider-id,
        zone: zone,
        vehicle-count: vehicle-count,
        start-time: start-time,
        end-time: end-time,
        status: "active",
        utilization: u0,
        created-at: block-height
      }
    )

    ;; Update zone capacity
    (update-zone-capacity zone vehicle-count true)

    ;; Update provider allocation tracking
    (update-provider-allocation provider-id zone vehicle-count)

    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

(define-public (release-capacity (allocation-id uint))
  (match (map-get? capacity-allocations { allocation-id: allocation-id })
    allocation-data
    (let ((provider-id (get provider-id allocation-data))
          (zone (get zone allocation-data))
          (vehicle-count (get vehicle-count allocation-data)))

      ;; Update allocation status
      (map-set capacity-allocations
        { allocation-id: allocation-id }
        (merge allocation-data { status: "completed" })
      )

      ;; Release zone capacity
      (update-zone-capacity zone vehicle-count false)

      (ok true)
    )
    ERR_ALLOCATION_NOT_FOUND
  )
)

(define-public (update-utilization (allocation-id uint) (utilization-rate uint))
  (begin
    (asserts! (<= utilization-rate u100) ERR_INSUFFICIENT_CAPACITY)
    (match (map-get? capacity-allocations { allocation-id: allocation-id })
      allocation-data
      (begin
        (map-set capacity-allocations
          { allocation-id: allocation-id }
          (merge allocation-data { utilization: utilization-rate })
        )
        (ok true)
      )
      ERR_ALLOCATION_NOT_FOUND
    )
  )
)

(define-private (update-zone-capacity (zone (string-ascii 20)) (vehicle-count uint) (is-allocation bool))
  (let ((current-data (default-to
                        { total-capacity: u0, allocated-capacity: u0, available-capacity: u0, last-updated: u0 }
                        (map-get? zone-capacity { zone: zone }))))
    (if is-allocation
      ;; Adding allocation
      (map-set zone-capacity
        { zone: zone }
        {
          total-capacity: (get total-capacity current-data),
          allocated-capacity: (+ (get allocated-capacity current-data) vehicle-count),
          available-capacity: (- (get available-capacity current-data) vehicle-count),
          last-updated: block-height
        }
      )
      ;; Releasing allocation
      (map-set zone-capacity
        { zone: zone }
        {
          total-capacity: (get total-capacity current-data),
          allocated-capacity: (- (get allocated-capacity current-data) vehicle-count),
          available-capacity: (+ (get available-capacity current-data) vehicle-count),
          last-updated: block-height
        }
      )
    )
  )
)

(define-private (update-provider-allocation (provider-id uint) (zone (string-ascii 20)) (vehicle-count uint))
  (let ((current-data (default-to
                        { active-vehicles: u0, total-allocations: u0, performance-score: u0 }
                        (map-get? provider-allocations { provider-id: provider-id, zone: zone }))))
    (map-set provider-allocations
      { provider-id: provider-id, zone: zone }
      {
        active-vehicles: (+ (get active-vehicles current-data) vehicle-count),
        total-allocations: (+ (get total-allocations current-data) u1),
        performance-score: (get performance-score current-data)
      }
    )
  )
)

(define-read-only (get-allocation (allocation-id uint))
  (map-get? capacity-allocations { allocation-id: allocation-id })
)

(define-read-only (get-zone-capacity (zone (string-ascii 20)))
  (map-get? zone-capacity { zone: zone })
)

(define-read-only (get-provider-allocation (provider-id uint) (zone (string-ascii 20)))
  (map-get? provider-allocations { provider-id: provider-id, zone: zone })
)

;; StreamVault - Decentralized Creator Support Streaming Contract
;; Allows fans to create payment streams to support creators with automatic micropayments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-STREAM-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-STREAM-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-INVALID-DURATION (err u105))
(define-constant ERR-STREAM-ENDED (err u106))
(define-constant MIN-STREAM-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-STREAM-DURATION u525600) ;; ~1 year in blocks

;; Data Variables
(define-data-var next-stream-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% (250 basis points)

;; Data Maps
(define-map streams
  uint
  {
    supporter: principal,
    creator: principal,
    total-amount: uint,
    amount-per-block: uint,
    start-block: uint,
    end-block: uint,
    withdrawn-amount: uint,
    is-active: bool
  }
)

(define-map user-stream-count principal uint)
(define-map creator-earnings principal uint)

;; Read-only functions
(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

(define-read-only (get-user-stream-count (user principal))
  (default-to u0 (map-get? user-stream-count user))
)

(define-read-only (get-creator-earnings (creator principal))
  (default-to u0 (map-get? creator-earnings creator))
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (calculate-withdrawable-amount (stream-id uint))
  (match (map-get? streams stream-id)
    stream-data
    (let
      (
        (current-block burn-block-height)
        (blocks-elapsed (- current-block (get start-block stream-data)))
        (total-blocks (- (get end-block stream-data) (get start-block stream-data)))
        (amount-per-block (get amount-per-block stream-data))
        (withdrawn (get withdrawn-amount stream-data))
      )
      (if (get is-active stream-data)
        (if (>= current-block (get end-block stream-data))
          ;; Stream has ended, return remaining amount
          (- (get total-amount stream-data) withdrawn)
          ;; Stream is active, calculate based on elapsed blocks
          (let
            (
              (earned-amount (* blocks-elapsed amount-per-block))
            )
            (if (> earned-amount withdrawn)
              (- earned-amount withdrawn)
              u0
            )
          )
        )
        u0
      )
    )
    u0
  )
)

;; Public functions
(define-public (create-stream (creator principal) (total-amount uint) (duration-blocks uint))
  (let
    (
      (stream-id (var-get next-stream-id))
      (amount-per-block (/ total-amount duration-blocks))
      (current-block burn-block-height)
      (end-block (+ current-block duration-blocks))
    )
    (asserts! (is-standard creator) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq creator tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (>= total-amount MIN-STREAM-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (and (> duration-blocks u0) (<= duration-blocks MAX-STREAM-DURATION)) ERR-INVALID-DURATION)
    (asserts! (>= (stx-get-balance tx-sender) total-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Create stream record
    (map-set streams stream-id
      {
        supporter: tx-sender,
        creator: creator,
        total-amount: total-amount,
        amount-per-block: amount-per-block,
        start-block: current-block,
        end-block: end-block,
        withdrawn-amount: u0,
        is-active: true
      }
    )
    
    ;; Update counters
    (var-set next-stream-id (+ stream-id u1))
    (map-set user-stream-count tx-sender (+ (get-user-stream-count tx-sender) u1))
    
    (ok stream-id)
  )
)

(define-public (withdraw-stream (stream-id uint))
  (match (map-get? streams stream-id)
    stream-data
    (let
      (
        (withdrawable (calculate-withdrawable-amount stream-id))
        (platform-fee (/ (* withdrawable (var-get platform-fee-rate)) u10000))
        (creator-amount (- withdrawable platform-fee))
        (creator (get creator stream-data))
      )
      (asserts! (is-eq tx-sender creator) ERR-NOT-AUTHORIZED)
      (asserts! (get is-active stream-data) ERR-STREAM-ENDED)
      (asserts! (> withdrawable u0) ERR-INSUFFICIENT-BALANCE)
      
      ;; Transfer to creator
      (try! (as-contract (stx-transfer? creator-amount tx-sender creator)))
      
      ;; Transfer platform fee to contract owner
      (if (> platform-fee u0)
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
        true
      )
      
      ;; Update stream data
      (map-set streams stream-id
        (merge stream-data { withdrawn-amount: (+ (get withdrawn-amount stream-data) withdrawable) })
      )
      
      ;; Update creator earnings
      (map-set creator-earnings creator (+ (get-creator-earnings creator) creator-amount))
      
      (ok withdrawable)
    )
    ERR-STREAM-NOT-FOUND
  )
)

(define-public (cancel-stream (stream-id uint))
  (match (map-get? streams stream-id)
    stream-data
    (let
      (
        (supporter (get supporter stream-data))
        (creator (get creator stream-data))
        (withdrawable-by-creator (calculate-withdrawable-amount stream-id))
        (remaining-amount (- (get total-amount stream-data) (get withdrawn-amount stream-data) withdrawable-by-creator))
      )
      (asserts! (is-eq tx-sender supporter) ERR-NOT-AUTHORIZED)
      (asserts! (get is-active stream-data) ERR-STREAM-ENDED)
      
      ;; If there's amount for creator, transfer it
      (if (> withdrawable-by-creator u0)
        (let
          (
            (platform-fee (/ (* withdrawable-by-creator (var-get platform-fee-rate)) u10000))
            (creator-amount (- withdrawable-by-creator platform-fee))
          )
          (try! (as-contract (stx-transfer? creator-amount tx-sender creator)))
          (if (> platform-fee u0)
            (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
            true
          )
          (map-set creator-earnings creator (+ (get-creator-earnings creator) creator-amount))
        )
        true
      )
      
      ;; Return remaining amount to supporter
      (if (> remaining-amount u0)
        (try! (as-contract (stx-transfer? remaining-amount tx-sender supporter)))
        true
      )
      
      ;; Mark stream as inactive
      (map-set streams stream-id
        (merge stream-data { is-active: false })
      )
      
      (ok true)
    )
    ERR-STREAM-NOT-FOUND
  )
)

;; Admin functions
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)
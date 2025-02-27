;; DEX Smart Contract for Stacks Blockchain
;; This implements a basic Automated Market Maker (AMM) DEX

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-zero-amount (err u103))
(define-constant err-pool-exists (err u104))
(define-constant err-pool-not-found (err u105))
(define-constant err-slippage-too-high (err u106))
(define-constant err-invalid-swap-fee (err u107))
(define-constant err-invalid-token (err u108))

;; Pool data structure
(define-map pools 
  { token-x: (string-ascii 32), token-y: (string-ascii 32) }
  { 
    liquidity: uint,
    reserves-x: uint,
    reserves-y: uint,
    swap-fee: uint  ;; Fee in basis points (e.g., 30 = 0.3%)
  }
)

;; Liquidity provider balances
(define-map liquidity-positions
  { provider: principal, token-x: (string-ascii 32), token-y: (string-ascii 32) }
  { liquidity: uint }
)

;; Non-recursive square root function using Newton's method with fixed iterations
(define-private (sqrt-uint (n uint))
  (let (
    (n-plus-1 (+ n u1))
    (div-2 (/ n-plus-1 u2))
    
    ;; Make 10 iterations of Newton's method with a fixed approach
    (guess1 div-2)
    (new-guess1 (/ (+ guess1 (/ n guess1)) u2))
    
    (guess2 (if (is-eq guess1 new-guess1) new-guess1 new-guess1))
    (new-guess2 (/ (+ guess2 (/ n guess2)) u2))
    
    (guess3 (if (is-eq guess2 new-guess2) new-guess2 new-guess2))
    (new-guess3 (/ (+ guess3 (/ n guess3)) u2))
    
    (guess4 (if (is-eq guess3 new-guess3) new-guess3 new-guess3))
    (new-guess4 (/ (+ guess4 (/ n guess4)) u2))
    
    (guess5 (if (is-eq guess4 new-guess4) new-guess4 new-guess4))
    (new-guess5 (/ (+ guess5 (/ n guess5)) u2))
    
    (guess6 (if (is-eq guess5 new-guess5) new-guess5 new-guess5))
    (new-guess6 (/ (+ guess6 (/ n guess6)) u2))
    
    (guess7 (if (is-eq guess6 new-guess6) new-guess6 new-guess6))
    (new-guess7 (/ (+ guess7 (/ n guess7)) u2))
    
    (guess8 (if (is-eq guess7 new-guess7) new-guess7 new-guess7))
    (new-guess8 (/ (+ guess8 (/ n guess8)) u2))
    
    (guess9 (if (is-eq guess8 new-guess8) new-guess8 new-guess8))
    (new-guess9 (/ (+ guess9 (/ n guess9)) u2))
    
    (guess10 (if (is-eq guess9 new-guess9) new-guess9 new-guess9))
    (new-guess10 (/ (+ guess10 (/ n guess10)) u2))
  )
    (if (is-eq n u0)
        u0
        new-guess10
    )
  )
)

;; Create a min function to return the minimum of two values
(define-private (min-of (a uint) (b uint))
  (if (<= a b) a b)
)

;; Validate token string is not empty
(define-private (validate-token (token (string-ascii 32)))
  (> (len token) u0)
)

;; Validate swap fee is in reasonable range (0-1000 basis points = 0-10%)
(define-private (validate-swap-fee (fee uint))
  (and (>= fee u0) (<= fee u1000))
)

;; Get pool information
(define-read-only (get-pool-info (token-x (string-ascii 32)) (token-y (string-ascii 32)))
  (map-get? pools { token-x: token-x, token-y: token-y })
)

;; Get quote for how much Y you'll get for X
(define-read-only (quote-x-for-y 
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32))
    (amount-in uint))
  (let (
    (pool (unwrap! (map-get? pools { token-x: token-x, token-y: token-y }) err-pool-not-found))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (fee-rate (get swap-fee pool))
    
    (amount-in-with-fee (* amount-in (- u10000 fee-rate)))
    (numerator (* amount-in-with-fee reserves-y))
    (denominator (+ (* reserves-x u10000) amount-in-with-fee))
  )
    (ok (/ numerator denominator))
  )
)

;; Create a new liquidity pool
(define-public (create-pool 
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32)) 
    (amount-x uint) 
    (amount-y uint)
    (swap-fee uint))
  (let ((pool-key { token-x: token-x, token-y: token-y }))
    (asserts! (> amount-x u0) err-zero-amount)
    (asserts! (> amount-y u0) err-zero-amount)
    (asserts! (validate-token token-x) err-invalid-token)
    (asserts! (validate-token token-y) err-invalid-token)
    (asserts! (validate-swap-fee swap-fee) err-invalid-swap-fee)
    (asserts! (is-none (map-get? pools pool-key)) err-pool-exists)
    
    ;; Transfer tokens to contract
    ;; In a real implementation, this would call the respective token contracts
    ;; For example: (contract-call? .token-x transfer amount-x tx-sender (as-contract tx-sender))
    
    ;; Initialize pool
    (map-set pools pool-key {
      liquidity: (sqrt-uint (* amount-x amount-y)),
      reserves-x: amount-x,
      reserves-y: amount-y,
      swap-fee: swap-fee
    })
    
    ;; Record liquidity position
    (map-set liquidity-positions 
      { provider: tx-sender, token-x: token-x, token-y: token-y }
      { liquidity: (sqrt-uint (* amount-x amount-y)) }
    )
    
    (ok true)
  )
)

;; Add liquidity to an existing pool
(define-public (add-liquidity
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32))
    (amount-x uint)
    (amount-y uint)
    (min-liquidity uint))
  (let (
    (pool-key { token-x: token-x, token-y: token-y })
    (pool (unwrap! (map-get? pools pool-key) err-pool-not-found))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (total-liquidity (get liquidity pool))
    
    ;; Calculate liquidity tokens to mint using our min-of function
    (liquidity-minted (min-of 
      (/ (* amount-x total-liquidity) reserves-x)
      (/ (* amount-y total-liquidity) reserves-y)
    ))
  )
    (asserts! (validate-token token-x) err-invalid-token)
    (asserts! (validate-token token-y) err-invalid-token)
    (asserts! (>= liquidity-minted min-liquidity) err-slippage-too-high)
    
    ;; Transfer tokens to contract
    ;; In a real implementation, this would call the respective token contracts
    
    ;; Update pool
    (map-set pools pool-key {
      liquidity: (+ total-liquidity liquidity-minted),
      reserves-x: (+ reserves-x amount-x),
      reserves-y: (+ reserves-y amount-y),
      swap-fee: (get swap-fee pool)
    })
    
    ;; Update user's liquidity position
    (let (
      (position-key { provider: tx-sender, token-x: token-x, token-y: token-y })
      (current-position (default-to { liquidity: u0 } (map-get? liquidity-positions position-key)))
    )
      (map-set liquidity-positions position-key {
        liquidity: (+ (get liquidity current-position) liquidity-minted)
      })
    )
    
    (ok liquidity-minted)
  )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32))
    (liquidity-amount uint)
    (min-amount-x uint)
    (min-amount-y uint))
  (let (
    (pool-key { token-x: token-x, token-y: token-y })
    (pool (unwrap! (map-get? pools pool-key) err-pool-not-found))
    (total-liquidity (get liquidity pool))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    
    ;; Calculate tokens to return
    (amount-x (/ (* liquidity-amount reserves-x) total-liquidity))
    (amount-y (/ (* liquidity-amount reserves-y) total-liquidity))
    
    ;; Get user's position
    (position-key { provider: tx-sender, token-x: token-x, token-y: token-y })
    (current-position (unwrap! (map-get? liquidity-positions position-key) err-not-token-owner))
  )
    (asserts! (validate-token token-x) err-invalid-token)
    (asserts! (validate-token token-y) err-invalid-token)
    (asserts! (>= (get liquidity current-position) liquidity-amount) err-insufficient-balance)
    (asserts! (>= amount-x min-amount-x) err-slippage-too-high)
    (asserts! (>= amount-y min-amount-y) err-slippage-too-high)
    
    ;; Update pool
    (map-set pools pool-key {
      liquidity: (- total-liquidity liquidity-amount),
      reserves-x: (- reserves-x amount-x),
      reserves-y: (- reserves-y amount-y),
      swap-fee: (get swap-fee pool)
    })
    
    ;; Update user's position
    (map-set liquidity-positions position-key {
      liquidity: (- (get liquidity current-position) liquidity-amount)
    })
    
    ;; Transfer tokens to user
    ;; In a real implementation, this would call the respective token contracts
    
    (ok { amount-x: amount-x, amount-y: amount-y })
  )
)

;; Swap tokens
(define-public (swap-x-for-y
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32))
    (amount-in uint)
    (min-amount-out uint))
  (let (
    (pool-key { token-x: token-x, token-y: token-y })
    (pool (unwrap! (map-get? pools pool-key) err-pool-not-found))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (fee-rate (get swap-fee pool))
    
    ;; Calculate output amount with fee
    (amount-in-with-fee (* amount-in (- u10000 fee-rate)))
    (numerator (* amount-in-with-fee reserves-y))
    (denominator (+ (* reserves-x u10000) amount-in-with-fee))
    (amount-out (/ numerator denominator))
  )
    (asserts! (validate-token token-x) err-invalid-token)
    (asserts! (validate-token token-y) err-invalid-token)
    (asserts! (> amount-in u0) err-zero-amount)
    (asserts! (>= amount-out min-amount-out) err-slippage-too-high)
    
    ;; Transfer input tokens from user to contract
    ;; In a real implementation, this would call the respective token contracts
    
    ;; Update pool
    (map-set pools pool-key {
      liquidity: (get liquidity pool),
      reserves-x: (+ reserves-x amount-in),
      reserves-y: (- reserves-y amount-out),
      swap-fee: fee-rate
    })
    
    ;; Transfer output tokens to user
    ;; In a real implementation, this would call the respective token contracts
    
    (ok amount-out)
  )
)

(define-public (swap-y-for-x
    (token-x (string-ascii 32)) 
    (token-y (string-ascii 32))
    (amount-in uint)
    (min-amount-out uint))
  (let (
    (pool-key { token-x: token-x, token-y: token-y })
    (pool (unwrap! (map-get? pools pool-key) err-pool-not-found))
    (reserves-x (get reserves-x pool))
    (reserves-y (get reserves-y pool))
    (fee-rate (get swap-fee pool))
    
    ;; Calculate output amount with fee
    (amount-in-with-fee (* amount-in (- u10000 fee-rate)))
    (numerator (* amount-in-with-fee reserves-x))
    (denominator (+ (* reserves-y u10000) amount-in-with-fee))
    (amount-out (/ numerator denominator))
  )
    (asserts! (validate-token token-x) err-invalid-token)
    (asserts! (validate-token token-y) err-invalid-token)
    (asserts! (> amount-in u0) err-zero-amount)
    (asserts! (>= amount-out min-amount-out) err-slippage-too-high)
    
    ;; Transfer input tokens from user to contract
    ;; In a real implementation, this would call the respective token contracts
    
    ;; Update pool
    (map-set pools pool-key {
      liquidity: (get liquidity pool),
      reserves-x: (- reserves-x amount-out),
      reserves-y: (+ reserves-y amount-in),
      swap-fee: fee-rate
    })
    
    ;; Transfer output tokens to user
    ;; In a real implementation, this would call the respective token contracts
    
    (ok amount-out)
  )
)
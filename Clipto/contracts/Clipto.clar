;; Define the NFT
(define-non-fungible-token artwork-token uint)

;; Define the listings map
(define-map market-listings
  {token-id: uint}
  {owner: principal, listing-price: uint})

;; Define the royalties map
(define-map creator-royalties
  {token-id: uint}
  {artist: principal, royalty-rate: uint})

;; Define constants
(define-constant MIN_PRICE u1)
(define-constant MAX_PRICE u1000000000) ;; 1 billion microSTX
(define-constant MAX_ROYALTY_RATE u20) ;; 20%
(define-constant ERROR_NOT_LISTED (err u103))
(define-constant ERROR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERROR_TRANSFER_FAILED (err u108))
(define-constant ERROR_INVALID_ROYALTY (err u110))

;; Mint a new NFT with royalty
(define-public (mint-artwork (token-id uint) (royalty-rate uint))
  (begin
    (asserts! (is-none (nft-get-owner? artwork-token token-id)) (err u100))
    (asserts! (<= royalty-rate MAX_ROYALTY_RATE) ERROR_INVALID_ROYALTY)
    (try! (nft-mint? artwork-token token-id tx-sender))
    (map-set creator-royalties
      {token-id: token-id}
      {artist: tx-sender, royalty-rate: royalty-rate})
    (ok true)
  )
)

;; List an NFT for sale
(define-public (list-artwork (token-id uint) (listing-price uint))
  (let ((current-owner (nft-get-owner? artwork-token token-id)))
    (begin
      (asserts! (is-some current-owner) (err u105))
      (asserts! (is-eq (some tx-sender) current-owner) (err u101))
      (asserts! (and (>= listing-price MIN_PRICE) (<= listing-price MAX_PRICE)) (err u107))
      (ok (map-set market-listings
        {token-id: token-id}
        {owner: tx-sender, listing-price: listing-price}))
    )
  )
)

;; Helper function to calculate royalty
(define-read-only (calculate-royalty-amount (price uint) (royalty-rate uint))
  (/ (* price royalty-rate) u100)
)

;; Purchase an NFT from the marketplace
(define-public (purchase-artwork (token-id uint))
  (let (
    (listing (unwrap! (map-get? market-listings {token-id: token-id}) ERROR_NOT_LISTED))
    (royalty-info (default-to {artist: tx-sender, royalty-rate: u0} (map-get? creator-royalties {token-id: token-id})))
    (purchaser tx-sender)
  )
    (let (
      (current-owner (get owner listing))
      (sale-price (get listing-price listing))
      (royalty-payment (calculate-royalty-amount sale-price (get royalty-rate royalty-info)))
      (owner-payment (- sale-price royalty-payment))
    )
      (begin
        (asserts! (is-some (nft-get-owner? artwork-token token-id)) (err u109))
        (asserts! (>= (stx-get-balance purchaser) sale-price) ERROR_INSUFFICIENT_BALANCE)
        ;; Transfer royalty to artist
        (if (> royalty-payment u0)
          (try! (stx-transfer? royalty-payment purchaser (get artist royalty-info)))
          true
        )
        ;; Transfer remaining amount to current owner
        (try! (stx-transfer? owner-payment purchaser current-owner))
        (match (nft-transfer? artwork-token token-id current-owner purchaser)
          success (begin
            (map-delete market-listings {token-id: token-id})
            (ok true))
          error (begin
            (try! (stx-transfer? sale-price current-owner purchaser))
            ERROR_TRANSFER_FAILED))
      )
    )
  )
)

;; Transfer an NFT to another user
(define-public (transfer-artwork (token-id uint) (new-owner principal))
  (let ((current-owner (nft-get-owner? artwork-token token-id)))
    (begin
      (asserts! (is-some current-owner) (err u106))
      (asserts! (is-eq (some tx-sender) current-owner) (err u104))
      (nft-transfer? artwork-token token-id tx-sender new-owner)
    )
  )
)

;; Get royalty information for an NFT
(define-read-only (get-artwork-royalty (token-id uint))
  (default-to {artist: tx-sender, royalty-rate: u0}
    (map-get? creator-royalties {token-id: token-id}))
)
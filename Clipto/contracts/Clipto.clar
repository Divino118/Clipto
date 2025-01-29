;; Define the Clipto NFT
(define-non-fungible-token clipto-id uint)

;; Define the listings map
(define-map clipto-listings
  {clipto-id: uint}
  {seller: principal, price: uint, listed-at: uint})

;; Define the royalties map
(define-map clipto-royalties
  {clipto-id: uint}
  {creator: principal, percentage: uint})

;; Define the contract admin
(define-data-var contract-admin principal tx-sender)

;; Define contract state (for pause functionality)
(define-data-var contract-paused bool false)

;; Define constants
(define-constant CLIPTO_MIN_PRICE u1)
(define-constant CLIPTO_MAX_PRICE u1000000000) ;; 1 billion microSTX
(define-constant CLIPTO_MAX_ROYALTY_PERCENTAGE u20) ;; 20%
(define-constant PRICE_CHANGE_COOLDOWN u86400) ;; 24 hours in seconds
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_TOKEN_ID u1000000) ;; Maximum allowed token ID

;; Error codes
(define-constant ERR_CLIPTO_NOT_LISTED (err u103))
(define-constant ERR_CLIPTO_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_CLIPTO_TRANSFER_FAILED (err u108))
(define-constant ERR_CLIPTO_INVALID_ROYALTY (err u110))
(define-constant ERR_CLIPTO_UNAUTHORIZED (err u111))
(define-constant ERR_CLIPTO_SELF_TRANSFER (err u112))
(define-constant ERR_CLIPTO_INVALID_PRICE (err u113))
(define-constant ERR_CLIPTO_COOLDOWN_ACTIVE (err u114))
(define-constant ERR_CLIPTO_CONTRACT_PAUSED (err u115))
(define-constant ERR_CLIPTO_ALREADY_LISTED (err u116))
(define-constant ERR_CLIPTO_INVALID_TOKEN_ID (err u117))
(define-constant ERR_CLIPTO_INVALID_ADMIN (err u118))

;; Helper function to validate token ID
(define-private (validate-token-id (token-id uint))
  (and 
    (>= token-id u0)
    (<= token-id MAX_TOKEN_ID)))

;; Helper function to validate admin
(define-private (validate-admin (new-admin principal))
  (and 
    (not (is-eq new-admin CONTRACT_OWNER))  ;; Can't set admin to contract owner
    (not (is-eq new-admin (var-get contract-admin))))) ;; Can't set to current admin

;; Administrative Functions

(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_CLIPTO_UNAUTHORIZED)
    (asserts! (validate-admin new-admin) ERR_CLIPTO_INVALID_ADMIN)
    (var-set contract-admin new-admin)
    (print {event: "admin-changed", new-admin: new-admin})
    (ok true)))

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_CLIPTO_UNAUTHORIZED)
    (ok (var-set contract-paused (not (var-get contract-paused))))))

;; Helper Functions

(define-read-only (clipto-is-listed (token-id uint))
  (is-some (map-get? clipto-listings {clipto-id: token-id})))

(define-read-only (clipto-get-listing (token-id uint))
  (map-get? clipto-listings {clipto-id: token-id}))

(define-read-only (clipto-calculate-royalty (price uint) (percentage uint))
  (/ (* price percentage) u100))

(define-read-only (clipto-get-royalty (token-id uint))
  (default-to {creator: tx-sender, percentage: u0}
    (map-get? clipto-royalties {clipto-id: token-id})))

;; Core Functions

(define-public (clipto-mint (token-id uint) (royalty-percentage uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
    (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
    (asserts! (is-none (nft-get-owner? clipto-id token-id)) (err u100))
    (asserts! (<= royalty-percentage CLIPTO_MAX_ROYALTY_PERCENTAGE) ERR_CLIPTO_INVALID_ROYALTY)
    (try! (nft-mint? clipto-id token-id tx-sender))
    (map-set clipto-royalties
      {clipto-id: token-id}
      {creator: tx-sender, percentage: royalty-percentage})
    (print {event: "nft-minted", token-id: token-id, creator: tx-sender})
    (ok true)))

(define-public (clipto-list (token-id uint) (price uint))
  (let ((owner (nft-get-owner? clipto-id token-id)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
      (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
      (asserts! (is-some owner) (err u105))
      (asserts! (is-eq (some tx-sender) owner) (err u101))
      (asserts! (and (>= price CLIPTO_MIN_PRICE) (<= price CLIPTO_MAX_PRICE)) ERR_CLIPTO_INVALID_PRICE)
      (asserts! (not (clipto-is-listed token-id)) ERR_CLIPTO_ALREADY_LISTED)
      (map-set clipto-listings
        {clipto-id: token-id}
        {seller: tx-sender, price: price, listed-at: stacks-block-height})
      (print {event: "nft-listed", token-id: token-id, price: price, seller: tx-sender})
      (ok true))))

(define-public (clipto-update-price (token-id uint) (new-price uint))
  (let (
    (listing (unwrap! (map-get? clipto-listings {clipto-id: token-id}) ERR_CLIPTO_NOT_LISTED))
    (current-height stacks-block-height)
  )
    (begin
      (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
      (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
      (asserts! (is-eq tx-sender (get seller listing)) ERR_CLIPTO_UNAUTHORIZED)
      (asserts! (and (>= new-price CLIPTO_MIN_PRICE) (<= new-price CLIPTO_MAX_PRICE)) ERR_CLIPTO_INVALID_PRICE)
      (asserts! (>= (- current-height (get listed-at listing)) PRICE_CHANGE_COOLDOWN) ERR_CLIPTO_COOLDOWN_ACTIVE)
      (map-set clipto-listings
        {clipto-id: token-id}
        {seller: tx-sender, price: new-price, listed-at: current-height})
      (print {event: "price-updated", token-id: token-id, new-price: new-price})
      (ok true))))

(define-public (clipto-delist (token-id uint))
  (let ((listing (unwrap! (map-get? clipto-listings {clipto-id: token-id}) ERR_CLIPTO_NOT_LISTED)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
      (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
      (asserts! (is-eq tx-sender (get seller listing)) ERR_CLIPTO_UNAUTHORIZED)
      (map-delete clipto-listings {clipto-id: token-id})
      (print {event: "nft-delisted", token-id: token-id})
      (ok true))))

(define-public (clipto-purchase (token-id uint))
  (let (
    (listing (unwrap! (map-get? clipto-listings {clipto-id: token-id}) ERR_CLIPTO_NOT_LISTED))
    (royalty-info (default-to {creator: tx-sender, percentage: u0} 
      (map-get? clipto-royalties {clipto-id: token-id})))
    (buyer tx-sender)
    (seller (get seller listing))
  )
    (begin
      (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
      (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
      (asserts! (not (is-eq buyer seller)) ERR_CLIPTO_SELF_TRANSFER)
      (asserts! (is-some (nft-get-owner? clipto-id token-id)) (err u109))
      (let (
        (price (get price listing))
        (royalty-amount (clipto-calculate-royalty price (get percentage royalty-info)))
        (seller-amount (- price royalty-amount))
      )
        (asserts! (>= (stx-get-balance buyer) price) ERR_CLIPTO_INSUFFICIENT_FUNDS)
        ;; Transfer royalty to creator if applicable
        (if (> royalty-amount u0)
          (try! (stx-transfer? royalty-amount buyer (get creator royalty-info)))
          true)
        ;; Transfer remaining amount to seller
        (try! (stx-transfer? seller-amount buyer seller))
        ;; Transfer NFT to buyer
        (match (nft-transfer? clipto-id token-id seller buyer)
          success (begin
            (map-delete clipto-listings {clipto-id: token-id})
            (print {
              event: "nft-purchased",
              token-id: token-id,
              buyer: buyer,
              seller: seller,
              price: price,
              royalty: royalty-amount
            })
            (ok true))
          error (begin
            (try! (stx-transfer? price seller buyer))
            ERR_CLIPTO_TRANSFER_FAILED))))))

(define-public (clipto-transfer (token-id uint) (recipient principal))
  (let ((owner (nft-get-owner? clipto-id token-id)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR_CLIPTO_CONTRACT_PAUSED)
      (asserts! (validate-token-id token-id) ERR_CLIPTO_INVALID_TOKEN_ID)
      (asserts! (is-some owner) (err u106))
      (asserts! (is-eq (some tx-sender) owner) (err u104))
      (asserts! (not (is-eq recipient tx-sender)) ERR_CLIPTO_SELF_TRANSFER)
      (try! (nft-transfer? clipto-id token-id tx-sender recipient))
      (print {event: "nft-transferred", token-id: token-id, from: tx-sender, to: recipient})
      (ok true))))
module Pharma.Api.Models

open System

// ── Application error type ────────────────────────────────────

type ApiError =
    | NotFound   of string
    | BadRequest of string
    | DbError    of string

// ── Persistence / Dapper records ─────────────────────────────

[<CLIMutable>]
type TodayRecord =
    { Id        : int
      Title     : string
      Content   : string
      Value     : decimal
      CreatedAt : DateTime
      UpdatedAt : DateTime }

// ── Pharmacy domain ──────────────────────────────────────────

[<CLIMutable>]
type Pharmacy =
    { Id      : int
      Name    : string
      Address : string
      City    : string }

[<CLIMutable>]
type Medication =
    { Id          : int
      Name        : string
      GenericName : string
      PriceEur    : decimal }

[<CLIMutable>]
type MedicationStock =
    { PharmacyId   : int
      MedicationId : int
      StockLevel   : int
      LastSyncedAt : DateTime }

// ── Reservation status ────────────────────────────────────────

type ReservationStatus = Pending | Ready | PickedUp

module ReservationStatus =
    let parse = function
        | "Pending"  -> Ok Pending
        | "Ready"    -> Ok Ready
        | "PickedUp" -> Ok PickedUp
        | s          -> Error (BadRequest $"Invalid status '{s}'. Valid: Pending, Ready, PickedUp")

    let toString = function
        | Pending  -> "Pending"
        | Ready    -> "Ready"
        | PickedUp -> "PickedUp"

[<CLIMutable>]
type Reservation =
    { Id            : int
      PharmacyId    : int
      MedicationId  : int
      PatientNhifId : string
      Timestamp     : DateTime
      Status        : ReservationStatus }

[<CLIMutable>]
type Prescription =
    { Id            : int
      PatientNhifId : string
      MedicationId  : int
      IssuedBy      : string
      IssuedAt      : DateTime
      ValidUntil    : DateTime
      Status        : string }

[<CLIMutable>]
type ShortageBroadcast =
    { Id             : int
      FromPharmacyId : int
      MedicationId   : int
      QuantityNeeded : int
      BroadcastAt    : DateTime
      Resolved       : bool }

// ── Request / response DTOs ──────────────────────────────────

type PrescriptionValidateRequest = { PatientNhifId : string; MedicationId : int }
type ValidationResult            = { IsValid : bool; Reason : string }
type UpdateStockRequest          = { StockLevel : int }
type CreateReservationRequest    = { PharmacyId : int; MedicationId : int; PatientNhifId : string }
type UpdateStatusRequest         = { Status : string }
type CreateShortageRequest       = { FromPharmacyId : int; MedicationId : int; QuantityNeeded : int }

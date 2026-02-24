module Types exposing (..)

import Http


-- ── RemoteData ─────────────────────────────────────────────────

type RemoteData e a
    = NotAsked
    | Loading
    | Failure e
    | Success a


-- ── Pharmacy domain ───────────────────────────────────────────

type alias Pharmacy =
    { id : Int
    , name : String
    , address : String
    , city : String
    }


type alias Medication =
    { id : Int
    , name : String
    , genericName : String
    , priceEur : Float
    }


type alias StockEntry =
    { pharmacyId : Int
    , medicationId : Int
    , stockLevel : Int
    , lastSyncedAt : String
    }


type alias ShortageBroadcast =
    { id : Int
    , fromPharmacyId : Int
    , medicationId : Int
    , quantityNeeded : Int
    , broadcastAt : String
    , resolved : Bool
    }


type alias ValidationResult =
    { isValid : Bool
    , reason : String
    }


-- ── Tab ───────────────────────────────────────────────────────

type Tab
    = StockTab
    | ShortagesTab
    | ValidateTab


-- ── Model ─────────────────────────────────────────────────────

type alias Model =
    { tab                : Tab
    , selectedPharmacyId : Int
    , pharmacies         : RemoteData Http.Error (List Pharmacy)
    , medications        : RemoteData Http.Error (List Medication)
    , stock              : RemoteData Http.Error (List StockEntry)
    , shortages          : RemoteData Http.Error (List ShortageBroadcast)
    , validation         : RemoteData Http.Error ValidationResult
    , nhifInput          : String
    , medIdInput         : String
    , formError          : Maybe String
    }


-- ── Msg ───────────────────────────────────────────────────────

type Msg
    = SelectTab Tab
    | SelectPharmacy String
    | GotPharmacies (Result Http.Error (List Pharmacy))
    | GotMedications (Result Http.Error (List Medication))
    | FetchStock Int
    | GotStock (Result Http.Error (List StockEntry))
    | FetchShortages
    | GotShortages (Result Http.Error (List ShortageBroadcast))
    | SetNhifInput String
    | SetMedIdInput String
    | SubmitValidation
    | GotValidation (Result Http.Error ValidationResult)

module Api exposing
    ( fetchPharmacies
    , fetchMedications
    , fetchStock
    , fetchShortages
    , validatePrescription
    )

import Http
import Json.Decode as D
import Json.Decode.Pipeline exposing (required)
import Json.Encode as E
import Types exposing (..)


apiBase : String
apiBase =
    "http://localhost:5000"


-- ── Decoders ─────────────────────────────────────────────────

pharmacyDecoder : D.Decoder Pharmacy
pharmacyDecoder =
    D.succeed Pharmacy
        |> required "id" D.int
        |> required "name" D.string
        |> required "address" D.string
        |> required "city" D.string


medicationDecoder : D.Decoder Medication
medicationDecoder =
    D.succeed Medication
        |> required "id" D.int
        |> required "name" D.string
        |> required "genericName" D.string
        |> required "priceEur" D.float


stockEntryDecoder : D.Decoder StockEntry
stockEntryDecoder =
    D.succeed StockEntry
        |> required "pharmacyId" D.int
        |> required "medicationId" D.int
        |> required "stockLevel" D.int
        |> required "lastSyncedAt" D.string


shortageBroadcastDecoder : D.Decoder ShortageBroadcast
shortageBroadcastDecoder =
    D.succeed ShortageBroadcast
        |> required "id" D.int
        |> required "fromPharmacyId" D.int
        |> required "medicationId" D.int
        |> required "quantityNeeded" D.int
        |> required "broadcastAt" D.string
        |> required "resolved" D.bool


validationResultDecoder : D.Decoder ValidationResult
validationResultDecoder =
    D.succeed ValidationResult
        |> required "isValid" D.bool
        |> required "reason" D.string


-- ── HTTP calls ────────────────────────────────────────────────

fetchPharmacies : Cmd Msg
fetchPharmacies =
    Http.get
        { url = apiBase ++ "/api/pharmacies"
        , expect = Http.expectJson GotPharmacies (D.list pharmacyDecoder)
        }


fetchMedications : Cmd Msg
fetchMedications =
    Http.get
        { url = apiBase ++ "/api/medications"
        , expect = Http.expectJson GotMedications (D.list medicationDecoder)
        }


fetchStock : Int -> Cmd Msg
fetchStock pharmacyId =
    Http.get
        { url = apiBase ++ "/api/pharmacies/" ++ String.fromInt pharmacyId ++ "/stock"
        , expect = Http.expectJson GotStock (D.list stockEntryDecoder)
        }


fetchShortages : Cmd Msg
fetchShortages =
    Http.get
        { url = apiBase ++ "/api/shortages"
        , expect = Http.expectJson GotShortages (D.list shortageBroadcastDecoder)
        }


validatePrescription : String -> Int -> Cmd Msg
validatePrescription nhifId medicationId =
    Http.post
        { url = apiBase ++ "/api/prescriptions/validate"
        , body =
            Http.jsonBody
                (E.object
                    [ ( "patientNhifId", E.string nhifId )
                    , ( "medicationId", E.int medicationId )
                    ]
                )
        , expect = Http.expectJson GotValidation validationResultDecoder
        }

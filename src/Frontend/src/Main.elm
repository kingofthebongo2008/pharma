module Main exposing (main)

import Api
import Browser
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { tab                = StockTab
      , selectedPharmacyId = 1
      , pharmacies         = Loading
      , medications        = Loading
      , stock              = Loading
      , shortages          = NotAsked
      , validation         = NotAsked
      , nhifInput          = ""
      , medIdInput         = ""
      , formError          = Nothing
      }
    , Cmd.batch
        [ Api.fetchPharmacies
        , Api.fetchMedications
        , Api.fetchStock 1
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectTab tab ->
            case tab of
                StockTab ->
                    ( { model | tab = tab, stock = Loading }
                    , Api.fetchStock model.selectedPharmacyId
                    )

                ShortagesTab ->
                    ( { model | tab = tab, shortages = Loading }
                    , Api.fetchShortages
                    )

                ValidateTab ->
                    ( { model | tab = tab }, Cmd.none )

        SelectPharmacy str ->
            case String.toInt str of
                Just id ->
                    ( { model | selectedPharmacyId = id, stock = Loading }
                    , Api.fetchStock id
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotPharmacies (Ok list) ->
            ( { model | pharmacies = Success list }, Cmd.none )

        GotPharmacies (Err e) ->
            ( { model | pharmacies = Failure e }, Cmd.none )

        GotMedications (Ok list) ->
            ( { model | medications = Success list }, Cmd.none )

        GotMedications (Err e) ->
            ( { model | medications = Failure e }, Cmd.none )

        FetchStock id ->
            ( { model | stock = Loading }, Api.fetchStock id )

        GotStock (Ok list) ->
            ( { model | stock = Success list }, Cmd.none )

        GotStock (Err e) ->
            ( { model | stock = Failure e }, Cmd.none )

        FetchShortages ->
            ( { model | shortages = Loading }, Api.fetchShortages )

        GotShortages (Ok list) ->
            ( { model | shortages = Success list }, Cmd.none )

        GotShortages (Err e) ->
            ( { model | shortages = Failure e }, Cmd.none )

        SetNhifInput val ->
            ( { model | nhifInput = val, validation = NotAsked, formError = Nothing }
            , Cmd.none
            )

        SetMedIdInput val ->
            ( { model | medIdInput = val, validation = NotAsked, formError = Nothing }
            , Cmd.none
            )

        SubmitValidation ->
            if String.isEmpty (String.trim model.nhifInput) then
                ( { model | formError = Just "Patient NHIF ID is required" }, Cmd.none )

            else
                case String.toInt model.medIdInput of
                    Just medId ->
                        ( { model | validation = Loading, formError = Nothing }
                        , Api.validatePrescription model.nhifInput medId
                        )

                    Nothing ->
                        ( { model | formError = Just "Please select a medication" }, Cmd.none )

        GotValidation (Ok result) ->
            ( { model | validation = Success result }, Cmd.none )

        GotValidation (Err e) ->
            ( { model | validation = Failure e }, Cmd.none )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body


formatEur : Float -> String
formatEur f =
    let
        cents =
            round (f * 100)

        euros =
            cents // 100

        centsPart =
            abs (remainderBy 100 cents)
    in
    "€" ++ String.fromInt euros ++ "." ++ String.padLeft 2 '0' (String.fromInt centsPart)


-- ── View ─────────────────────────────────────────────────────

view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ header []
            [ h1 [] [ text "Pharma Dashboard" ]
            , p [ class "subtitle" ] [ text "Sofia MVP – 5 Pilot Pharmacies" ]
            ]
        , viewFormError model.formError
        , nav [ class "tab-nav" ]
            [ tabButton model.tab StockTab "Stock Sync"
            , tabButton model.tab ShortagesTab "Shortage Broadcasts"
            , tabButton model.tab ValidateTab "E-Prescription"
            ]
        , main_ []
            [ case model.tab of
                StockTab ->
                    viewStockTab model

                ShortagesTab ->
                    viewShortagesTab model

                ValidateTab ->
                    viewValidateTab model
            ]
        ]


tabButton : Tab -> Tab -> String -> Html Msg
tabButton current target label =
    button
        [ classList [ ( "tab-btn", True ), ( "active", current == target ) ]
        , onClick (SelectTab target)
        ]
        [ text label ]


viewFormError : Maybe String -> Html Msg
viewFormError maybeErr =
    case maybeErr of
        Nothing ->
            text ""

        Just err ->
            div [ class "status error" ]
                [ p [] [ text "Error: " ]
                , p [ class "error-msg" ] [ text err ]
                ]


-- ── Stock tab ─────────────────────────────────────────────────

viewStockTab : Model -> Html Msg
viewStockTab model =
    div []
        [ div [ class "controls" ]
            [ label [ for "pharmacy-select" ] [ text "Pharmacy: " ]
            , select
                [ id "pharmacy-select"
                , onInput SelectPharmacy
                ]
                (case model.pharmacies of
                    Success list ->
                        List.map (viewPharmacyOption model.selectedPharmacyId) list

                    _ ->
                        []
                )
            ]
        , case model.stock of
            NotAsked ->
                text ""

            Loading ->
                div [ class "status loading" ] [ text "Loading stock..." ]

            Failure e ->
                div [ class "status error" ] [ text (httpErrorToString e) ]

            Success entries ->
                viewStockTable model.medications entries
        ]


viewPharmacyOption : Int -> Pharmacy -> Html Msg
viewPharmacyOption selectedId p =
    option
        [ value (String.fromInt p.id)
        , selected (p.id == selectedId)
        ]
        [ text p.name ]


viewStockTable : RemoteData Http.Error (List Medication) -> List StockEntry -> Html Msg
viewStockTable medsRd entries =
    let
        medDict =
            case medsRd of
                Success meds ->
                    Dict.fromList (List.map (\m -> ( m.id, m )) meds)

                _ ->
                    Dict.empty
    in
    if List.isEmpty entries then
        div [ class "status" ] [ text "No stock data." ]

    else
        table [ class "stock-table" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Medication" ]
                    , th [] [ text "Generic Name" ]
                    , th [] [ text "Price (EUR)" ]
                    , th [] [ text "Stock Level" ]
                    ]
                ]
            , tbody []
                (List.filterMap (viewStockRow medDict) entries)
            ]


viewStockRow : Dict.Dict Int Medication -> StockEntry -> Maybe (Html Msg)
viewStockRow medDict entry =
    case Dict.get entry.medicationId medDict of
        Nothing ->
            Nothing

        Just med ->
            Just
                (tr
                    [ classList
                        [ ( "low-stock", entry.stockLevel > 0 && entry.stockLevel < 15 )
                        , ( "out-of-stock", entry.stockLevel == 0 )
                        ]
                    ]
                    [ td [] [ text med.name ]
                    , td [] [ text med.genericName ]
                    , td [] [ text (formatEur med.priceEur) ]
                    , td [] [ text (String.fromInt entry.stockLevel) ]
                    ]
                )


-- ── Shortages tab ─────────────────────────────────────────────

viewShortagesTab : Model -> Html Msg
viewShortagesTab model =
    let
        pharmacyDict =
            case model.pharmacies of
                Success list ->
                    Dict.fromList (List.map (\p -> ( p.id, p )) list)

                _ ->
                    Dict.empty

        medDict =
            case model.medications of
                Success list ->
                    Dict.fromList (List.map (\m -> ( m.id, m )) list)

                _ ->
                    Dict.empty
    in
    div []
        [ div [ class "controls" ]
            [ button [ class "refresh-btn", onClick FetchShortages ] [ text "Refresh" ] ]
        , case model.shortages of
            NotAsked ->
                text ""

            Loading ->
                div [ class "status loading" ] [ text "Loading shortages..." ]

            Failure e ->
                div [ class "status error" ] [ text (httpErrorToString e) ]

            Success [] ->
                div [ class "status" ] [ text "No active shortage broadcasts." ]

            Success entries ->
                table [ class "stock-table" ]
                    [ thead []
                        [ tr []
                            [ th [] [ text "From Pharmacy" ]
                            , th [] [ text "Medication" ]
                            , th [] [ text "Qty Needed" ]
                            , th [] [ text "Broadcast At" ]
                            ]
                        ]
                    , tbody []
                        (List.map (viewShortageRow pharmacyDict medDict) entries)
                    ]
        ]


viewShortageRow : Dict.Dict Int Pharmacy -> Dict.Dict Int Medication -> ShortageBroadcast -> Html Msg
viewShortageRow pharmacyDict medDict s =
    let
        pharmacyName =
            Dict.get s.fromPharmacyId pharmacyDict
                |> Maybe.map .name
                |> Maybe.withDefault (String.fromInt s.fromPharmacyId)

        medName =
            Dict.get s.medicationId medDict
                |> Maybe.map .name
                |> Maybe.withDefault (String.fromInt s.medicationId)
    in
    tr []
        [ td [] [ text pharmacyName ]
        , td [] [ text medName ]
        , td [] [ text (String.fromInt s.quantityNeeded) ]
        , td [] [ text s.broadcastAt ]
        ]


-- ── Validate tab ──────────────────────────────────────────────

viewValidateTab : Model -> Html Msg
viewValidateTab model =
    div [ class "validate-form" ]
        [ h2 [] [ text "E-Prescription Validation" ]
        , div [ class "form-group" ]
            [ label [] [ text "Patient NHIF ID" ]
            , input
                [ type_ "text"
                , placeholder "e.g. BG-001-2025"
                , value model.nhifInput
                , onInput SetNhifInput
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Medication" ]
            , select [ onInput SetMedIdInput ]
                (option [ value "" ] [ text "— select —" ]
                    :: (case model.medications of
                            Success meds ->
                                List.map
                                    (\m ->
                                        option [ value (String.fromInt m.id) ]
                                            [ text (m.name ++ " (ID " ++ String.fromInt m.id ++ ")") ]
                                    )
                                    meds

                            _ ->
                                []
                       )
                )
            ]
        , button
            [ class "refresh-btn"
            , onClick SubmitValidation
            ]
            [ text "Validate" ]
        , viewValidationResult model.validation
        ]


viewValidationResult : RemoteData Http.Error ValidationResult -> Html Msg
viewValidationResult rd =
    case rd of
        NotAsked ->
            text ""

        Loading ->
            div [ class "status loading" ] [ text "Validating..." ]

        Failure e ->
            div [ class "status error" ] [ text (httpErrorToString e) ]

        Success r ->
            div
                [ classList
                    [ ( "validation-badge", True )
                    , ( "valid", r.isValid )
                    , ( "invalid", not r.isValid )
                    ]
                ]
                [ strong [] [ text (if r.isValid then "VALID" else "INVALID") ]
                , span [] [ text (" — " ++ r.reason) ]
                ]

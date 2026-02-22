module Main exposing (main)

import Api
import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
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
    ( { response = Loading, refreshCount = 0 }, Api.fetchLatest )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchLatest ->
            ( { model | response = Loading }, Api.fetchLatest )

        GotRecord (Ok record) ->
            ( { model | response = Success record, refreshCount = model.refreshCount + 1 }, Cmd.none )

        GotRecord (Err err) ->
            ( { model | response = Failure (httpErrorToString err) }, Cmd.none )


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


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ header []
            [ h1 [] [ text "Pharma Dashboard" ]
            , p [ class "subtitle" ] [ text "Latest Today Record" ]
            ]
        , main_ []
            [ viewResponse model.response
            , div [ class "refresh-row" ]
                [ button [ onClick FetchLatest, class "refresh-btn" ] [ text "Refresh" ]
                , if model.refreshCount > 0 then
                    span [ class "refresh-count" ] [ text ("Refreshed " ++ String.fromInt model.refreshCount ++ "x") ]
                  else
                    text ""
                ]
            ]
        ]


viewResponse : ApiResponse -> Html Msg
viewResponse response =
    case response of
        NotAsked ->
            div [ class "status" ] [ text "Press Refresh to load data." ]

        Loading ->
            div [ class "status loading" ] [ text "Loading..." ]

        Failure err ->
            div [ class "status error" ]
                [ p [] [ text "Error fetching data:" ]
                , p [ class "error-msg" ] [ text err ]
                ]

        Success record ->
            div [ class "record-card" ]
                [ div [ class "record-field" ]
                    [ span [ class "label" ] [ text "ID" ]
                    , span [ class "value" ] [ text (String.fromInt record.id) ]
                    ]
                , div [ class "record-field" ]
                    [ span [ class "label" ] [ text "Title" ]
                    , span [ class "value" ] [ text record.title ]
                    ]
                , div [ class "record-field" ]
                    [ span [ class "label" ] [ text "Content" ]
                    , span [ class "value" ] [ text record.content ]
                    ]
                , div [ class "record-field" ]
                    [ span [ class "label" ] [ text "Value" ]
                    , span [ class "value" ] [ text (String.fromFloat record.value) ]
                    ]
                , div [ class "record-field" ]
                    [ span [ class "label" ] [ text "Created At" ]
                    , span [ class "value" ] [ text record.createdAt ]
                    ]
                ]

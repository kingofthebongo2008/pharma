module Api exposing (fetchLatest)

import Http
import Json.Decode as D
import Json.Decode.Pipeline exposing (required)
import Types exposing (Msg(..), TodayRecord)


apiBase : String
apiBase =
    "http://localhost:5000"


todayRecordDecoder : D.Decoder TodayRecord
todayRecordDecoder =
    D.succeed TodayRecord
        |> required "Id" D.int
        |> required "Title" D.string
        |> required "Content" D.string
        |> required "Value" D.float
        |> required "CreatedAt" D.string
        |> required "UpdatedAt" D.string


fetchLatest : Cmd Msg
fetchLatest =
    Http.get
        { url = apiBase ++ "/api/today/latest"
        , expect = Http.expectJson GotRecord todayRecordDecoder
        }

module Types exposing (..)

import Http


type alias TodayRecord =
    { id : Int
    , title : String
    , content : String
    , value : Float
    , createdAt : String
    , updatedAt : String
    }


type ApiResponse
    = NotAsked
    | Loading
    | Success TodayRecord
    | Failure String


type alias Model =
    { response : ApiResponse
    , refreshCount : Int
    }


type Msg
    = FetchLatest
    | GotRecord (Result Http.Error TodayRecord)

module Pharma.Api.Models

open System

[<CLIMutable>]
type TodayRecord =
    { Id        : int
      Title     : string
      Content   : string
      Value     : decimal
      CreatedAt : DateTime
      UpdatedAt : DateTime }

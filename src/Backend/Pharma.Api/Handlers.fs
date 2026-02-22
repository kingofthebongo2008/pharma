module Pharma.Api.Handlers

open System
open System.Text.Json
open Microsoft.AspNetCore.Http
open Falco
open Models
open Database

let private jsonOptions =
    let opts = JsonSerializerOptions()
    opts.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
    opts

let health : HttpHandler =
    Response.ofJson {| status = "ok"; timestamp = DateTime.UtcNow |}

let todayLatest (connectionString: string) : HttpHandler =
    fun ctx ->
        task {
            use conn = createConnection connectionString
            match getLatestTodayRecord conn with
            | Some record ->
                return! Response.ofJson record ctx
            | None ->
                ctx.Response.StatusCode <- 404
                return! Response.ofJson {| error = "No records found" |} ctx
        }

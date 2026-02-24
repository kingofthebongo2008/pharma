module Pharma.Api.Helpers

open System
open System.Data
open System.Text.Json
open System.Text.Json.Serialization
open Microsoft.AspNetCore.Http
open Falco
open Models
open Database   // compiles before this file; provides createConnection

// ── ReservationStatus JSON converter ─────────────────────────

type ReservationStatusJsonConverter() =
    inherit JsonConverter<ReservationStatus>()
    override _.Read(reader, _, _) =
        reader.GetString() |> Option.ofObj |> Option.defaultValue "" |> ReservationStatus.parse |> Result.defaultValue Pending
    override _.Write(writer, value, _) =
        writer.WriteStringValue(ReservationStatus.toString value)

// ── result {} computation expression ─────────────────────────

type ResultBuilder() =
    member _.Return x      = Ok x
    member _.ReturnFrom x  = x
    member _.Bind(m, f)    = Result.bind f m
    member _.Zero()        = Ok ()

let result = ResultBuilder()

// ── withDb ────────────────────────────────────────────────────

/// Open a connection, run f, dispose the connection, and wrap any
/// exception as DbError. Replaces the repeated `use conn = …` in handlers.
let withDb (connStr: string) (f: IDbConnection -> 'a) : Result<'a, ApiError> =
    try
        use conn = createConnection connStr
        Ok (f conn)
    with ex ->
        Error (DbError ex.Message)

// ── someOrError ───────────────────────────────────────────────

/// Convert an option to a Result, using the supplied error for None.
let someOrError (err: ApiError) (opt: 'a option) : Result<'a, ApiError> =
    match opt with
    | Some v -> Ok v
    | None   -> Error err

// ── routeInt ─────────────────────────────────────────────────

/// Safely parse a named route segment as int.
/// Returns BadRequest on failure instead of throwing FormatException.
let routeInt (name: string) (ctx: HttpContext) : Result<int, ApiError> =
    let s = Request.getRoute ctx |> fun r -> r.GetString name
    match Int32.TryParse s with
    | true,  n -> Ok n
    | false, _ -> Error (BadRequest $"Route parameter '{name}' must be an integer")

// ── respond / respondCreated ──────────────────────────────────

// WriteAsJsonAsync (unlike Falco's Response.ofJson) resolves JsonSerializerOptions
// from DI, so the camelCase policy registered in Program.fs is applied.
let private writeJson (value: 'a) (ctx: HttpContext) =
    ctx.Response.WriteAsJsonAsync(value)

/// Map a Result to an HTTP response: Ok → 200 JSON, errors → 4xx/5xx JSON.
let respond (r: Result<'a, ApiError>) : HttpHandler =
    fun ctx ->
        task {
            match r with
            | Ok v ->
                return! writeJson v ctx
            | Error (NotFound msg) ->
                ctx.Response.StatusCode <- 404
                return! writeJson {| error = msg |} ctx
            | Error (BadRequest msg) ->
                ctx.Response.StatusCode <- 400
                return! writeJson {| error = msg |} ctx
            | Error (DbError msg) ->
                ctx.Response.StatusCode <- 500
                return! writeJson {| error = msg |} ctx
        }

/// Like respond but uses 201 Created on success.
let respondCreated (r: Result<'a, ApiError>) : HttpHandler =
    fun ctx ->
        task {
            match r with
            | Ok v ->
                ctx.Response.StatusCode <- 201
                return! writeJson v ctx
            | Error err ->
                return! respond (Error err) ctx
        }

// ── dbHandler ────────────────────────────────────────────────

/// Point-free helper for GET handlers that only run a DB query and respond.
let dbHandler (connStr: string) (f: IDbConnection -> 'a) : HttpHandler =
    fun ctx -> withDb connStr f |> respond <| ctx

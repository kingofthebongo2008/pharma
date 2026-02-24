module Pharma.Api.Handlers

open System
open Microsoft.AspNetCore.Http
open Falco
open Models
open Database
open Helpers

// ── Health ────────────────────────────────────────────────────

let health : HttpHandler =
    Response.ofJson {| status = "ok"; timestamp = DateTime.UtcNow |}

// ── Legacy today endpoint ─────────────────────────────────────

let todayLatest (connStr: string) : HttpHandler =
    fun ctx ->
        withDb connStr getLatestTodayRecord
        |> Result.bind (someOrError (NotFound "No records found"))
        |> respond
        <| ctx

// ── Stock_Sync (P0) ──────────────────────────────────────────

let getPharmacies  (connStr: string) : HttpHandler = dbHandler connStr Database.getPharmacies
let getMedications (connStr: string) : HttpHandler = dbHandler connStr Database.getMedications
let syncAllStock   (connStr: string) : HttpHandler = dbHandler connStr getAllStock

let getPharmacyStock (connStr: string) : HttpHandler =
    fun ctx ->
        routeInt "id" ctx
        |> Result.bind (fun pharmacyId ->
            withDb connStr (fun c -> getStockByPharmacy c pharmacyId))
        |> respond
        <| ctx

let updatePharmacyStock (connStr: string) : HttpHandler =
    Request.mapJson (fun (body: UpdateStockRequest) ctx ->
        task {
            let r =
                result {
                    let! pharmacyId   = routeInt "id"    ctx
                    let! medicationId = routeInt "medId" ctx
                    return!
                        withDb connStr (fun c ->
                            upsertStock c pharmacyId medicationId body.StockLevel
                            getStockByPharmacy c pharmacyId
                            |> List.tryFind (fun s -> s.MedicationId = medicationId))
                        |> Result.bind (someOrError (NotFound "Stock entry not found after upsert"))
                }
            return! respond r ctx
        })

// ── Reservations ─────────────────────────────────────────────

let createReservationHandler (connStr: string) : HttpHandler =
    Request.mapJson (fun (body: CreateReservationRequest) ctx ->
        withDb connStr (fun c -> createReservation c body)
        |> respondCreated
        <| ctx)

let getReservationHandler (connStr: string) : HttpHandler =
    fun ctx ->
        routeInt "id" ctx
        |> Result.bind (fun id ->
            withDb connStr (fun c -> getReservationById c id)
            |> Result.bind (someOrError (NotFound $"Reservation {id} not found")))
        |> respond
        <| ctx

let updateReservationHandler (connStr: string) : HttpHandler =
    Request.mapJson (fun (body: UpdateStatusRequest) ctx ->
        task {
            let r =
                result {
                    let! id     = routeInt "id" ctx
                    let! status = ReservationStatus.parse body.Status
                    do! withDb connStr (fun c ->
                            updateReservationStatus c id status)
                    return {| ok = true |}
                }
            return! respond r ctx
        })

// ── E_Prescription_Validation (P0) ───────────────────────────

let validatePrescriptionHandler (connStr: string) : HttpHandler =
    Request.mapJson (fun (body: PrescriptionValidateRequest) ctx ->
        withDb connStr (fun c ->
            match findActivePrescription c body.PatientNhifId body.MedicationId with
            | None ->
                { IsValid = false; Reason = "No active prescription found" }
            | Some p when p.ValidUntil < DateTime.UtcNow ->
                { IsValid = false; Reason = "Prescription expired" }
            | Some p ->
                markPrescriptionUsed c p.Id
                { IsValid = true; Reason = "OK" })
        |> respond
        <| ctx)

// ── B2B_Shortage_Broadcast (P1) ──────────────────────────────

let getShortagesHandler (connStr: string) : HttpHandler = dbHandler connStr getActiveShortages

let createShortageHandler (connStr: string) : HttpHandler =
    Request.mapJson (fun (body: CreateShortageRequest) ctx ->
        withDb connStr (fun c -> createShortageBroadcast c body)
        |> respondCreated
        <| ctx)

let resolveShortageHandler (connStr: string) : HttpHandler =
    fun ctx ->
        routeInt "id" ctx
        |> Result.bind (fun id ->
            withDb connStr (fun c ->
                resolveShortage c id
                {| ok = true |}))
        |> respond
        <| ctx

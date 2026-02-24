module Pharma.Api.Program

open System.Text.Json
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Cors.Infrastructure
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Configuration
open Falco
open Falco.Routing
open Helpers
open Handlers

[<EntryPoint>]
let main args =
    let builder = WebApplication.CreateBuilder(args)

    let defaultConnStr = "Host=localhost;Port=5432;Database=pharmadb;Username=pharma;Password=pharma123"
    let connStr =
        builder.Configuration.GetConnectionString("Default")
        |> Option.ofObj
        |> Option.filter (fun s -> s.Length > 0)
        |> Option.defaultValue defaultConnStr

    builder.Services.ConfigureHttpJsonOptions(fun opts ->
        opts.SerializerOptions.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        opts.SerializerOptions.Converters.Add(ReservationStatusJsonConverter())) |> ignore

    builder.Services.AddCors(fun (options: CorsOptions) ->
        options.AddDefaultPolicy(fun policy ->
            policy
                .AllowAnyOrigin()
                .AllowAnyMethod()
                .AllowAnyHeader()
            |> ignore)) |> ignore

    let app = builder.Build()

    app.UseCors() |> ignore

    app.UseFalco([
        get  "/api/health"                      health
        get  "/api/today/latest"                (todayLatest connStr)

        // Stock_Sync (P0)
        get  "/api/pharmacies"                  (getPharmacies connStr)
        get  "/api/medications"                 (getMedications connStr)
        get  "/api/pharmacies/{id}/stock"       (getPharmacyStock connStr)
        put  "/api/pharmacies/{id}/stock/{medId}" (updatePharmacyStock connStr)
        get  "/api/stock/sync"                  (syncAllStock connStr)

        // Reservations
        post "/api/reservations"                (createReservationHandler connStr)
        get  "/api/reservations/{id}"           (getReservationHandler connStr)
        put  "/api/reservations/{id}/status"    (updateReservationHandler connStr)

        // E_Prescription_Validation (P0)
        post "/api/prescriptions/validate"      (validatePrescriptionHandler connStr)

        // B2B_Shortage_Broadcast (P1)
        get  "/api/shortages"                   (getShortagesHandler connStr)
        post "/api/shortages"                   (createShortageHandler connStr)
        put  "/api/shortages/{id}/resolve"      (resolveShortageHandler connStr)
    ]) |> ignore

    app.Run()
    0

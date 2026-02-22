module Pharma.Api.Program

open System.Text.Json
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Cors.Infrastructure
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Configuration
open Falco
open Falco.Routing
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
        opts.SerializerOptions.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase) |> ignore

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
        get "/api/health"        health
        get "/api/today/latest"  (todayLatest connStr)
    ]) |> ignore

    app.Run()
    0

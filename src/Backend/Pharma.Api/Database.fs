module Pharma.Api.Database

open System.Data
open Dapper
open Npgsql
open Models

let createConnection (connectionString: string) : IDbConnection =
    new NpgsqlConnection(connectionString) :> IDbConnection

let getLatestTodayRecord (conn: IDbConnection) : TodayRecord option =
    let sql = """
        SELECT id, title, content, value,
               created_at AS "CreatedAt",
               updated_at AS "UpdatedAt"
        FROM today
        ORDER BY id DESC
        LIMIT 1
    """
    conn.QueryFirstOrDefault<TodayRecord>(sql)
    |> Option.ofObj

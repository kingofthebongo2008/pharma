module Pharma.Api.Database

open System
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

// ── Pharmacies ───────────────────────────────────────────────

let getPharmacies (conn: IDbConnection) : Pharmacy list =
    conn.Query<Pharmacy>("SELECT id, name, address, city FROM pharmacy ORDER BY id")
    |> Seq.toList

// ── Medications ──────────────────────────────────────────────

let getMedications (conn: IDbConnection) : Medication list =
    conn.Query<Medication>(
        """SELECT id, name, generic_name AS "GenericName", price_eur AS "PriceEur"
           FROM medication ORDER BY id""")
    |> Seq.toList

// ── Stock_Sync ───────────────────────────────────────────────

let getStockByPharmacy (conn: IDbConnection) (pharmacyId: int) : MedicationStock list =
    let sql = """
        SELECT pharmacy_id   AS "PharmacyId",
               medication_id AS "MedicationId",
               stock_level   AS "StockLevel",
               last_synced_at AS "LastSyncedAt"
        FROM medication_stock
        WHERE pharmacy_id = @PharmacyId
        ORDER BY medication_id
    """
    conn.Query<MedicationStock>(sql, {| PharmacyId = pharmacyId |})
    |> Seq.toList

let getAllStock (conn: IDbConnection) : MedicationStock list =
    let sql = """
        SELECT pharmacy_id   AS "PharmacyId",
               medication_id AS "MedicationId",
               stock_level   AS "StockLevel",
               last_synced_at AS "LastSyncedAt"
        FROM medication_stock
        ORDER BY pharmacy_id, medication_id
    """
    conn.Query<MedicationStock>(sql) |> Seq.toList

let upsertStock (conn: IDbConnection) (pharmacyId: int) (medicationId: int) (level: int) : unit =
    let sql = """
        INSERT INTO medication_stock (pharmacy_id, medication_id, stock_level, last_synced_at)
        VALUES (@PharmacyId, @MedicationId, @StockLevel, NOW())
        ON CONFLICT (pharmacy_id, medication_id)
        DO UPDATE SET stock_level = @StockLevel, last_synced_at = NOW()
    """
    conn.Execute(sql, {| PharmacyId = pharmacyId; MedicationId = medicationId; StockLevel = level |})
    |> ignore

// ── Reservations ─────────────────────────────────────────────

// Private Dapper-compatible row — Dapper cannot map a string column
// directly to ReservationStatus, so we project to this type first.
[<CLIMutable>]
type private ReservationRow =
    { Id            : int
      PharmacyId    : int
      MedicationId  : int
      PatientNhifId : string
      Timestamp     : DateTime
      Status        : string }

let private rowToReservation (row: ReservationRow) : Reservation =
    { Id            = row.Id
      PharmacyId    = row.PharmacyId
      MedicationId  = row.MedicationId
      PatientNhifId = row.PatientNhifId
      Timestamp     = row.Timestamp
      Status        = ReservationStatus.parse row.Status
                      |> Result.defaultValue Pending }

let createReservation (conn: IDbConnection) (req: CreateReservationRequest) : Reservation =
    let sql = """
        INSERT INTO reservation (pharmacy_id, medication_id, patient_nhif_id)
        VALUES (@PharmacyId, @MedicationId, @PatientNhifId)
        RETURNING id, pharmacy_id AS "PharmacyId", medication_id AS "MedicationId",
                  patient_nhif_id AS "PatientNhifId", timestamp AS "Timestamp", status
    """
    conn.QueryFirst<ReservationRow>(sql, req) |> rowToReservation

let getReservationById (conn: IDbConnection) (id: int) : Reservation option =
    let sql = """
        SELECT id, pharmacy_id AS "PharmacyId", medication_id AS "MedicationId",
               patient_nhif_id AS "PatientNhifId", timestamp AS "Timestamp", status
        FROM reservation WHERE id = @Id
    """
    conn.QueryFirstOrDefault<ReservationRow>(sql, {| Id = id |})
    |> Option.ofObj
    |> Option.map rowToReservation

let updateReservationStatus (conn: IDbConnection) (id: int) (status: ReservationStatus) : unit =
    conn.Execute(
        "UPDATE reservation SET status = @Status WHERE id = @Id",
        {| Id = id; Status = ReservationStatus.toString status |}) |> ignore

// ── E-Prescription_Validation ────────────────────────────────

let findActivePrescription (conn: IDbConnection) (nhifId: string) (medicationId: int) : Prescription option =
    let sql = """
        SELECT id, patient_nhif_id AS "PatientNhifId", medication_id AS "MedicationId",
               issued_by AS "IssuedBy", issued_at AS "IssuedAt", valid_until AS "ValidUntil", status
        FROM prescription
        WHERE patient_nhif_id = @NhifId
          AND medication_id   = @MedicationId
          AND status = 'Active'
        LIMIT 1
    """
    conn.QueryFirstOrDefault<Prescription>(sql, {| NhifId = nhifId; MedicationId = medicationId |})
    |> Option.ofObj

let markPrescriptionUsed (conn: IDbConnection) (id: int) : unit =
    conn.Execute(
        "UPDATE prescription SET status = 'Used' WHERE id = @Id",
        {| Id = id |}) |> ignore

// ── B2B_Shortage_Broadcast ───────────────────────────────────

let getActiveShortages (conn: IDbConnection) : ShortageBroadcast list =
    let sql = """
        SELECT id, from_pharmacy_id AS "FromPharmacyId", medication_id AS "MedicationId",
               quantity_needed AS "QuantityNeeded", broadcast_at AS "BroadcastAt", resolved
        FROM shortage_broadcast
        WHERE resolved = false
        ORDER BY broadcast_at DESC
    """
    conn.Query<ShortageBroadcast>(sql) |> Seq.toList

let createShortageBroadcast (conn: IDbConnection) (req: CreateShortageRequest) : ShortageBroadcast =
    let sql = """
        INSERT INTO shortage_broadcast (from_pharmacy_id, medication_id, quantity_needed)
        VALUES (@FromPharmacyId, @MedicationId, @QuantityNeeded)
        RETURNING id, from_pharmacy_id AS "FromPharmacyId", medication_id AS "MedicationId",
                  quantity_needed AS "QuantityNeeded", broadcast_at AS "BroadcastAt", resolved
    """
    conn.QueryFirst<ShortageBroadcast>(sql, req)

let resolveShortage (conn: IDbConnection) (id: int) : unit =
    conn.Execute(
        "UPDATE shortage_broadcast SET resolved = true WHERE id = @Id",
        {| Id = id |}) |> ignore

# Pharma App Plan - F#/Elm/PostgreSQL Stack

## Overview
Full-stack web app that connects to PostgreSQL, fetches the last record from "today" table, and displays it via Elm frontend.

## Tech Stack
- **Backend**: F# with Falco web framework (chosen over Giraffe/Saturn for active maintenance and performance)
- **Frontend**: Elm 0.19.1
- **Database**: PostgreSQL 16
- **Dev environment**: Docker for PostgreSQL, .NET 8 SDK, Elm compiler

## Project Structure
```
D:\code\pharma\
├── pharma.sln
├── src/
│   ├── Backend/
│   │   └── Pharma.Api/
│   │       ├── Pharma.Api.fsproj
│   │       ├── Program.fs          # Entry point, CORS, routes
│   │       ├── Handlers.fs         # HTTP handlers
│   │       ├── Database.fs         # PostgreSQL queries
│   │       ├── Models.fs           # Domain types
│   │       └── appsettings.*.json  # Environment configs
│   └── Frontend/
│       ├── elm.json
│       ├── src/
│       │   ├── Main.elm            # Main app (Model-View-Update)
│       │   ├── Api.elm             # HTTP calls & JSON decoders
│       │   └── Types.elm           # Type definitions
│       └── public/
│           ├── index.html
│           └── styles.css
├── scripts/
│   ├── setup-db.sql                # Schema + dummy data
│   ├── dev-windows.ps1
│   └── dev-linux.sh
└── docker/
    └── docker-compose.yml          # PostgreSQL container
```

## Database Schema
```sql
CREATE TABLE today (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    content         TEXT,
    value           DECIMAL(10, 2),
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Dummy data
INSERT INTO today (title, content, value) VALUES
    ('Morning Report', 'Initial system check completed successfully.', 100.50),
    ('Inventory Update', 'Stock levels adjusted for Q1 medications.', 2500.00),
    ('Patient Summary', 'Daily patient intake: 45 new registrations.', 45.00),
    ('Lab Results', 'Pending lab analyses: 12 samples awaiting processing.', 12.00),
    ('Evening Summary', 'All systems operational. Ready for next day.', 999.99);
```

## API Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/today/latest` | Get last record from today table |

## Implementation Order

### Step 1: Project Setup
- Create solution: `dotnet new sln -n pharma`
- Create F# project: `dotnet new console -lang F# -n Pharma.Api`
- Add NuGet packages: Falco, Npgsql, Dapper, Dapper.FSharp
- Initialize Elm: `elm init`
- Install Elm packages: elm/http, elm/json, NoRedInk/elm-json-decode-pipeline

### Step 2: Database Setup
- Create docker-compose.yml for PostgreSQL
- Create setup-db.sql with schema and dummy data
- Start PostgreSQL: `docker-compose up -d`

### Step 3: Backend Implementation
1. Models.fs - TodayRecord type with CLIMutable attribute
2. Database.fs - NpgsqlConnectionFactory, queries using Dapper
3. Handlers.fs - HTTP handlers for health check and fetching data
4. Program.fs - Falco host with CORS configuration

### Step 4: Frontend Implementation
1. Types.elm - TodayRecord, ApiResponse, Model, Msg types
2. Api.elm - fetchLatest function with JSON decoders
3. Main.elm - Browser.element app with init, update, view
4. index.html + styles.css - HTML shell and basic styling

### Step 5: Scripts & Configuration
- Development scripts for Windows (PowerShell) and Linux (bash)
- appsettings.Development.json - local connection string
- appsettings.Production.json - environment variable placeholder

## Critical Files
- `src/Backend/Pharma.Api/Program.fs` - Entry point with CORS and routes
- `src/Backend/Pharma.Api/Database.fs` - PostgreSQL connection and queries
- `src/Frontend/src/Main.elm` - Main Elm application
- `src/Frontend/src/Api.elm` - HTTP communication with backend
- `scripts/setup-db.sql` - Database schema and seed data

## Key Dependencies

### F# (NuGet)
- Falco 4.0.*
- Npgsql 8.0.*
- Dapper 2.1.*
- Dapper.FSharp 4.10.*

### Elm (elm.json)
- elm/browser 1.0.2
- elm/http 2.0.0
- elm/json 1.1.3
- NoRedInk/elm-json-decode-pipeline 1.0.1

## Development Workflow
```powershell
# Terminal 1: Start PostgreSQL
docker-compose -f docker/docker-compose.yml up -d

# Terminal 2: Run backend (port 5000)
cd src/Backend/Pharma.Api
dotnet watch run

# Terminal 3: Run frontend (port 8000)
cd src/Frontend
elm make src/Main.elm --output=public/elm.js --debug
python -m http.server 8000 --directory public
```

## Verification
1. Start PostgreSQL container and verify dummy data inserted
2. Start F# backend, test with: `curl http://localhost:5000/api/today/latest`
3. Start Elm frontend, open http://localhost:8000 in browser
4. Verify the last record ("Evening Summary") displays correctly
5. Click "Refresh" button to confirm data fetching works

# AeroGo MySQL

This folder contains the local MySQL database initialization scripts for AeroGo.

## Files

- `01_schema.sql`: Creates tables, indexes, constraints, and foreign keys.
- `02_seed.sql`: Inserts development admin/user accounts and default settings.
- `03_email_auth_upgrade.sql`: Adds email verification fields/tables for existing databases.
- `04_public_game_records_seed.sql`: Inserts 500 public professional Go record metadata rows.

## Tables

- `users`: Admin and normal user accounts.
- `email_verification_tokens`: Signup confirmation and future email-change tokens.
- `system_settings`: Global game, AI, and visual settings.
- `game_records`: One row per saved game or imported SGF.
- `game_moves`: Move-by-move game history.
- `ai_analysis`: AI analysis output per game or move.
- `training_datasets`: Registered SGF/text datasets for future training.
- `admin_audit_logs`: Administrator action history.

## Local Startup

Copy the example environment file:

```powershell
Copy-Item .env.example .env
```

Edit `.env` and replace the default passwords.

Start MySQL and the API:

```powershell
docker compose up -d mysql api
```

Check container status:

```powershell
docker compose ps
```

Connect as the app user:

```powershell
docker compose exec mysql mysql -u aerogo_app -p aerogo
```

Connect as root:

```powershell
docker compose exec mysql mysql -u root -p
```

## Important

Flutter should not connect directly to MySQL in production. Use this flow:

```text
Flutter app -> API server -> MySQL
```

The API server should own authentication, authorization, SQL access, and password hashing.

## Signup Email Verification

Normal users register with an email address as their login ID.

```text
POST /auth/register
-> users.status = pending_email
-> users.email_verified = false
-> email_verification_tokens row is created
-> verification email is sent
-> GET /auth/confirm-email?token=...
-> users.status = active
-> users.email_verified = true
```

If SMTP is not configured, the API prints the verification link to its logs for local development.

## Public Game Record Seed

`04_public_game_records_seed.sql` inserts 500 metadata rows into `game_records`.

Source:

```text
https://github.com/yenw/computer-go-dataset/tree/master/Professional
```

The seed was generated from the Professional `pro2000+` collection. It stores metadata only:

- title
- black player name
- white player name
- result text
- winner
- board size
- komi
- started date when available
- source name, URL, and source record ID

The SGF move text is intentionally not embedded in the seed. Verify source terms before redistributing full SGF records.

If your MySQL volume already existed before this seed was added, run it manually:

```powershell
docker compose exec -T mysql mysql -u aerogo_app -p aerogo < database/mysql/04_public_game_records_seed.sql
```

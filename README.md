# Database Migration Manager

**Version: 1.1.0**

## Overview

**Database Migration Manager** is a containerized, interactive database migration tool designed to simplify the process of moving data between database servers. Whether you're migrating between different hosts, creating database backups, or replicating databases for testing environments, this tool provides a unified, user-friendly interface for managing migrations across multiple database engines.

Built entirely with Bash and Dialog, the tool runs inside a Docker container with a text-based user interface (TUI), eliminating the need for complex installations or dependencies on your host system. All database operations are executed using official Docker images (MySQL, PostgreSQL, SQL Server), ensuring consistency and reliability across different environments.

The tool handles the complete migration workflow: connecting to source and destination databases, exporting data in appropriate formats, and importing it safely with proper validation at each step. All dump files are stored in a persistent Docker volume, ensuring your data remains safe even after container restarts.

## Key Features

- **Multi-Database Engine Support**: MySQL 8.0, PostgreSQL 16, and SQL Server (via SqlPackage)
- **Interactive TUI**: User-friendly dialog-based interface for configuration and operation
- **Docker-First Architecture**: Runs entirely in containers, no local database tools required
- **Persistent Storage**: Dumps stored in named Docker volumes for data safety
- **Complete Migration Workflow**: One-click dump and restore operations
- **Connection Testing**: Validate database credentials before migration
- **Configuration Management**: Save and reuse database connection profiles
- **Cross-Platform**: Works on Linux, macOS, and Windows (via Git Bash or WSL)

## Architecture

The tool uses a nested Docker architecture:

1. **Main Container** (`database-migration-manager`): Runs the TUI application and orchestrates migrations
2. **Database Containers**: Spawned dynamically for each operation (dump/load) using official images
3. **Shared Resources**:
   - `/dumps` volume: Persistent storage for database dumps
   - Docker socket: Allows main container to spawn database containers
   - Host networking: Direct access to database servers

## Requirements

- **Docker**: Version 20.10 or higher
- **Docker Compose** (optional): For advanced setups
- **Operating System**:
  - Linux/Unix: Native support
  - Windows: Git Bash, WSL, or MSYS2
  - macOS: Native support

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd Database-Migration-Manager
   ```

2. **Ensure Docker is running**:
   ```bash
   docker --version
   docker ps
   ```

3. **Set up SQL Server dependencies** (if using SQL Server migrations):
   - Download SqlPackage from [Microsoft's official site](https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage-download)
   - Extract to `dependencies/sqlpackage/` directory
   - The structure should be: `dependencies/sqlpackage/sqlpackage.dll`

4. **Make scripts executable**:
   ```bash
   chmod +x run-docker-unix.sh
   chmod +x db-manager.sh
   ```

## Usage

### Linux/Unix/macOS

```bash
./run-docker-unix.sh
```

### Windows

Using Git Bash or similar:
```bash
./run-docker-windows.sh
```

### First Run

On first execution, the tool will:
1. Build the Docker image (takes 2-3 minutes)
2. Create the `db-migration-dumps` volume
3. Launch the interactive TUI

## Main Menu Options

### 1. MIGRATE - Complete Migration

Performs a full database migration (dump + restore) in one operation:

1. Select source database type (MySQL, PostgreSQL, SQL Server)
2. Enter source connection details (host, port, user, password, database)
3. Select destination database type
4. Enter destination connection details
5. Tool automatically:
   - Exports source database to dump file
   - Imports dump into destination database
   - Reports success/failure

**Use case**: Quick migration between two servers

### 2. DUMP - Export Database

Exports a database to a dump file:

- **MySQL**: Creates `.sql` dump using `mysqldump`
- **PostgreSQL**: Creates custom format dump using `pg_dump -F c`
- **SQL Server**: Creates `.bacpac` file using SqlPackage

Dumps are stored in `/dumps` (Docker volume `db-migration-dumps`)

**Use case**: Backup, versioning, or preparing for later import

### 3. LOAD - Import Database

Imports a previously created dump file:

- Select dump file from list
- Choose destination database type
- Enter destination connection details
- Tool imports data safely

**Use case**: Restore backup, clone database, or import to different engine

### 4. TEST - Test Connection

Validates database credentials without performing any operations:

- Tests network connectivity
- Verifies authentication
- Lists available databases (for PostgreSQL/MySQL)

**Use case**: Debugging connection issues before migration

### 5. CONFIG - Configuration

Manages database connection settings:

- **Database Type**: Choose MySQL, PostgreSQL, or SQL Server
- **SOURCE Configuration**: Connection details for source database
- **DESTINATION Configuration**: Connection details for destination database
- **Complete Setup**: Step-by-step wizard for all settings
- **View Configuration**: Display current settings

**Note**: Dump files are automatically stored in `/dumps` (fixed Docker volume location) and cannot be changed. Files are auto-named as `<db-engine>-<timestamp>.txt`.

## Configuration File

Settings are stored in `.config` file (automatically created):

```bash
DB_TYPE=mysql
SRC_HOST=localhost
SRC_PORT=3306
SRC_USER=root
SRC_PASS=password
SRC_DB=mydb
DST_HOST=localhost
DST_PORT=3306
DST_USER=root
DST_PASS=password
DST_DB=mydb_copy
```

**Important**: The dump directory is **always** `/dumps` and is not stored in the configuration file. This is the Docker volume mount point and ensures all dumps persist in the `db-migration-dumps` volume.

## Dump File Formats

### MySQL
- **Format**: SQL text file (`.sql`)
- **Tool**: `mysqldump`
- **Features**: Includes routines, triggers, events, uses single-transaction

### PostgreSQL
- **Format**: Custom format (`.dump`)
- **Tool**: `pg_dump -F c`
- **Features**: Binary format, includes `--clean` and `--if-exists` on restore

### SQL Server
- **Format**: BACPAC (`.bacpac`)
- **Tool**: SqlPackage
- **Features**: Schema + data, portable across SQL Server versions
- **Note**: Creates `.txt` reference file containing path to actual `.bacpac`

## Volume Management

### List Dumps
```bash
docker volume inspect db-migration-dumps
docker run --rm -v db-migration-dumps:/dumps alpine ls -lh /dumps
```

### Backup Volume
```bash
docker run --rm -v db-migration-dumps:/dumps -v $(pwd):/backup alpine \
  tar czf /backup/dumps-backup.tar.gz /dumps
```

### Restore Volume
```bash
docker run --rm -v db-migration-dumps:/dumps -v $(pwd):/backup alpine \
  tar xzf /backup/dumps-backup.tar.gz -C /
```

### Delete Volume
```bash
docker volume rm db-migration-dumps
```

## Troubleshooting

### "Docker not found"
- Ensure Docker is installed and running
- Check with: `docker ps`

### "Permission denied on /var/run/docker.sock"
- Add your user to docker group: `sudo usermod -aG docker $USER`
- Log out and back in

### "SQLPACKAGE_DIR environment variable not set"
- Ensure SqlPackage is in `dependencies/sqlpackage/`
- Check `run-docker-*.sh` passes `-e SQLPACKAGE_DIR`

### "Dump directory must be /dumps"
- Configuration auto-corrects on load
- Never manually set `DUMP_DIR` to non-volume paths

### MySQL/PostgreSQL connection fails
- Verify `--network host` is working
- Test connection from host: `mysql -h <host> -P <port> -u <user> -p`
- Check firewall rules

### SQL Server BACPAC import fails
- Ensure destination server has sufficient space
- Check SQL Server edition compatibility
- Review error logs in container output

## Project Structure

```
Database-Migration-Manager/
├── db-manager.sh              # Main TUI application
├── Dockerfile                 # Container build definition
├── run-docker-unix.sh         # Linux/macOS launcher
├── run-docker-windows.sh      # Windows launcher
├── lib/
│   └── log.lib.sh            # Logging functions
├── operation/
│   ├── mysql-dump.operation.sh
│   ├── mysql-load.operation.sh
│   ├── postgres-dump.operation.sh
│   ├── postgres-load.operation.sh
│   ├── sqlserver-dump.operation.sh
│   └── sqlserver-load.operation.sh
├── dependencies/
│   ├── dialog/                # Dialog binary (bundled)
│   └── sqlpackage/            # SqlPackage (user-provided)
└── README.md
```

## Environment Variables

The following environment variables are automatically set by launch scripts:

- `DUMPS_VOLUME`: Name of Docker volume for dumps (`db-migration-dumps`)
- `SQLPACKAGE_DIR`: Host path to SqlPackage directory (SQL Server only)
- `LANG=C.UTF-8`: Ensures proper character encoding
- `LC_ALL=C.UTF-8`: Locale settings for internationalization

## Security Considerations

- **Passwords**: Passed via environment variables to containers (not stored on disk)
- **Network**: Uses `--network host` for database access (consider VPN in production)
- **Docker Socket**: Main container has full Docker access (run only trusted code)
- **Volumes**: Dumps stored in named volume (backed up separately)

## Limitations

- **Large Databases**: Very large dumps (>10GB) may be slow via stdout/stdin
- **SQL Server**: Requires SqlPackage download (not bundled due to licensing)
- **Windows Paths**: Use Git Bash/WSL, avoid cmd.exe
- **Network**: Requires direct network access to database servers

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Follow existing code style (Bash best practices)
4. Test with all three database engines
5. Submit pull request with clear description

## License

[Specify your license here - MIT, Apache 2.0, GPL, etc.]

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Provide Docker version, OS, and error logs
- Include `.config` file contents (redact passwords)

## Acknowledgments

- Built with [Dialog](https://invisible-island.net/dialog/) for TUI
- Uses official Docker images: [MySQL](https://hub.docker.com/_/mysql), [PostgreSQL](https://hub.docker.com/_/postgres), [.NET Runtime](https://hub.docker.com/_/microsoft-dotnet-runtime)
- SqlPackage by [Microsoft](https://learn.microsoft.com/sql/tools/sqlpackage/)

---

**Happy Migrating! 🚀**

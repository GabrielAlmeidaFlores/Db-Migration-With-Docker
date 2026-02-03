# 🗄️ DB Migration Manager with Docker

> **Professional database migration tool with interactive terminal UI**  
> Supports MySQL, PostgreSQL, and SQL Server using Docker - no local database tools required!

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker)](https://www.docker.com/)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg?logo=gnu-bash)](https://www.gnu.org/software/bash/)

---

## 📖 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Architecture](#-architecture)
- [Configuration](#-configuration)
- [Examples](#-examples)
- [Security](#-security)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🎯 About

**DB Migration Manager** is a powerful command-line tool designed to simplify database operations. Built with DevOps and system administrators in mind, it provides an intuitive terminal interface for managing database dumps, loads, and migrations across multiple database systems.

### Why Use This Tool?

- 🚀 **Zero Installation**: Dialog binary included - works out of the box!
- 🐳 **No Database Tools**: Uses Docker containers - no need to install MySQL, PostgreSQL, or SQL Server tools
- 🎨 **User-Friendly Interface**: Beautiful dialog-based TUI that's easy to navigate
- 🔄 **Multi-Database Support**: Works seamlessly with MySQL, PostgreSQL, and SQL Server
- 💾 **Persistent Configuration**: Saves your settings for quick access next time
- 🔒 **Safe Operations**: Confirms dangerous operations and handles errors gracefully
- 🌍 **Production Ready**: Designed for real-world database migration scenarios

---

## ✨ Features

### Core Capabilities

- **🗄️ Database Configuration**
  - Support for MySQL/MariaDB, PostgreSQL, and SQL Server
  - Separate source and destination configuration
  - Persistent configuration storage

- **💾 Dump Operations (Export)**
  - Export databases to compressed dump files
  - Includes stored procedures, triggers, and events
  - Progress indicators and detailed logging

- **📥 Load Operations (Import)**
  - Import dump files to target databases
  - Automatic database creation if needed
  - Clean import with conflict resolution

- **🔄 Migration (Dump + Load)**
  - One-step migration from source to destination
  - Automatic cleanup and validation
  - Comprehensive error handling

- **⚙️ Configuration Management**
  - View current settings
  - Edit individual components
  - Step-by-step complete setup wizard

### Technical Features

- ✅ Interactive TUI using `dialog`
- ✅ Docker-based execution (no local DB tools needed)
- ✅ Custom logging with colored output
- ✅ Graceful error handling
- ✅ ESC/Cancel never exits the application
- ✅ Automatic terminal cleanup on exit

---

## 📋 Prerequisites

Only **one** tool is required on your system:

### System Requirements

- **OS**: 
  - ✅ Linux (any distribution) - **Works perfectly with bundled dialog**
  - ✅ macOS - Requires: `brew install dialog` (or use Docker mode)
  - ✅ **Windows - Use Docker Mode** (`./run-docker.sh`) - **Works out of the box!**
  - ⚠️ Windows Git Bash (direct) - Requires manual dialog installation (not recommended)
- **Architecture**: x86_64/amd64 (for bundled dialog), or any architecture with system dialog installed
- **Bash**: Version 4.0 or higher

### Docker

Docker is used to run database commands without installing database clients.

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

For other operating systems, visit: [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

### Dialog (Included!)

The `dialog` binary is **included** in the project under `dependencies/dialog/` for **Linux x86_64** systems (Ubuntu, Debian, Fedora, CentOS, etc.).

**Compatibility:**
- ✅ Linux x86_64 (amd64) - **Bundled binary included**
- ⚠️ Other systems (macOS, ARM, etc.) - Install dialog manually

The script automatically detects if the bundled binary works on your system. If not, it falls back to your system's dialog installation.

**Manual Installation (if needed):**
```bash
# Ubuntu/Debian
sudo apt-get install dialog

# RedHat/CentOS/Fedora
sudo yum install dialog
# or: sudo dnf install dialog

# Arch Linux
sudo pacman -S dialog

# macOS (via Homebrew)
brew install dialog
```

---

## 🚀 Installation

### Option A: Direct Mode (Linux/macOS/WSL)

**Step 1:** Clone or Download

```bash
# Clone this repository (if using git)
git clone <repository-url>
cd Database-Migration-Manager

# Or simply download and extract the files
```

**Step 2:** Make Scripts Executable

```bash
chmod +x db-manager.sh
chmod +x operations/*.sh
```

**Step 3:** Run

```bash
./db-manager.sh
```

### Option B: Docker Mode (Windows/Any OS) ⭐ **Recommended for Windows**

**Step 1:** Clone or Download (same as above)

**Step 2:** Make run-docker.sh Executable

```bash
chmod +x run-docker.sh
```

**Step 3:** Run in Docker Mode

```bash
./run-docker.sh
```

✅ First run builds the image automatically (one time only)  
✅ All dependencies pre-installed  
✅ Works on **any OS**!

---

## 🎮 Quick Start

### Choose Your Mode

**Direct Mode (Linux/macOS/WSL):**
```bash
./db-manager.sh
```

**Docker Mode (Windows/Any OS):**
```bash
./run-docker.sh
```

### First Time Setup

1. **Start the application** (choose your mode above)

2. **Configure your database** (Option 1)
   - Choose database type (MySQL/PostgreSQL/SQL Server)
   - Enter source database credentials
   - Enter destination database credentials
   - Set dump file location

3. **Perform your first migration** (Option 4)
   - The tool will dump from source
   - Then load to destination
   - All automated!

### Subsequent Usage

Your configuration is saved! Just run `./db-manager.sh` and choose your operation.

---

## 📚 Usage Guide

### Main Menu Options

When you start the application, you'll see these options:

```
┌─────────────────────────────────────────┐
│            Main Menu                    │
├─────────────────────────────────────────┤
│ 1. 🗄️  Configure Database              │
│ 2. 💾 Dump (Export)                     │
│ 3. 📥 Load (Import)                     │
│ 4. 🔄 Migrate (Dump + Load)            │
│ 5. ⚙️  View Configuration               │
│ 6. 🚪 Exit                              │
└─────────────────────────────────────────┘
```

#### 1. Configure Database

Opens a submenu with options:

- **Database Type**: Choose MySQL, PostgreSQL, or SQL Server
- **SOURCE Configuration**: Set up the source database (where data comes from)
- **DESTINATION Configuration**: Set up the target database (where data goes to)
- **Dump File**: Set the path for dump files
- **Complete Setup**: Step-by-step wizard for first-time configuration
- **View Configuration**: See your current settings

#### 2. Dump (Export)

Exports your source database to a file:

- Uses the configured source database
- Creates a compressed dump file
- Includes all database objects (tables, views, procedures, triggers)
- Shows progress and file size upon completion

#### 3. Load (Import)

Imports a dump file into your destination database:

- Uses the configured destination database
- Automatically creates the database if it doesn't exist
- Cleans existing data (be careful!)
- Validates successful import

#### 4. Migrate (Dump + Load)

Complete migration in one operation:

1. Dumps from source database
2. Loads into destination database
3. Shows progress for each step
4. Confirms completion

#### 5. View Configuration

Displays your current settings:

- Database type
- Source connection details
- Destination connection details
- Dump file location

#### 6. Exit

Cleanly exits the application and resets terminal colors.

---

## 🏗️ Architecture

### Project Structure

```
Database-Migration-Manager/
│
├── db-manager.sh              # Main application entry point
├── run-docker.sh              # Docker mode wrapper ⭐ NEW
├── Dockerfile                 # Docker image definition ⭐ NEW
├── .config                    # Configuration file (auto-generated)
├── .gitignore                # Git ignore rules
├── README.md                  # This file
├── CHANGELOG.md              # Version history
│
├── dependencies/             # Bundled dependencies
│   └── dialog/              # Dialog binary (included!)
│       └── dialog           # Dialog executable
│
├── dumps/                    # Default location for dump files
│
└── operations/               # Database-specific operation scripts
    ├── mysql-dump.sh         # MySQL export
    ├── mysql-load.sh         # MySQL import
    ├── postgres-dump.sh      # PostgreSQL export
    ├── postgres-load.sh      # PostgreSQL import
    ├── sqlserver-dump.sh     # SQL Server export
    └── sqlserver-load.sh     # SQL Server import
```

### How It Works

**Direct Mode:**
```
┌─────────────┐
│   User      │
│  Interface  │
│  (Dialog)   │
└──────┬──────┘
       │
       v
┌─────────────┐
│ db-manager  │
│   .sh       │
└──────┬──────┘
       │
       v
┌─────────────┐
│  Operation  │
│   Scripts   │
└──────┬──────┘
       │
       v
┌─────────────┐      ┌──────────────┐
│   Docker    │ ---> │  Database    │
│ Containers  │ <--- │  Servers     │
└─────────────┘      └──────────────┘
```

**Docker Mode (run-docker.sh):**
```
┌──────────────────────────────────────┐
│      Docker Container                │
│  ┌─────────────┐                    │      ┌──────────────┐
│  │   Dialog    │                    │      │  Database    │
│  │     TUI     │                    │      │  Servers     │
│  └──────┬──────┘                    │      └──────┬───────┘
│         │                            │             │
│         v                            │             │
│  ┌─────────────┐                    │             │
│  │ db-manager  │                    │             │
│  │   .sh       │                    │             │
│  └──────┬──────┘                    │             │
│         │                            │             │
│         v                            │             │
│  ┌─────────────┐                    │             │
│  │  Operation  │ ────────────────────────────────>│
│  │   Scripts   │ <───────────────────────────────│
│  └─────────────┘   Docker socket   │             │
└──────────────────────────────────────┘
```

### Database-Specific Implementations

#### MySQL/MariaDB
- **Dump**: `mysqldump` with `--single-transaction`, `--routines`, `--triggers`, `--events`
- **Load**: `mysql` client with automatic database creation
- **Docker Image**: `mysql:8.0`

#### PostgreSQL
- **Dump**: `pg_dump` with custom format (`-F c`) for compression
- **Load**: `pg_restore` with `--clean`, `--if-exists`, `--no-owner`, `--no-acl`
- **Docker Image**: `postgres:15-alpine`

#### SQL Server
- **Dump**: `sqlcmd` with `BACKUP DATABASE` command
- **Load**: `sqlcmd` with `RESTORE DATABASE` command
- **Docker Image**: `mcr.microsoft.com/mssql-tools`
- **Note**: Backup files must be accessible on the SQL Server host

---

## ⚙️ Configuration

### Configuration File (`.config`)

The tool stores settings in `.config` (auto-created on first configuration):

```bash
DB_TYPE=mysql
SRC_HOST=source.server.com
SRC_PORT=3306
SRC_USER=root
SRC_PASS=password123
SRC_DB=production_db
DST_HOST=localhost
DST_PORT=3306
DST_USER=root
DST_PASS=devpassword
DST_DB=development_db
DUMP_FILE=/home/user/backups/database.dump
```

### Environment Variables

You can also use environment variables (they override `.config`):

```bash
export DB_TYPE=postgres
export SRC_HOST=prod.example.com
./db-manager.sh
```

---

## 💡 Examples

### Example 1: Backup Production MySQL to Local File

```bash
# 1. Run the tool
./db-manager.sh

# 2. Configure Database → SOURCE Configuration
#    Host: prod.mycompany.com
#    Port: 3306
#    User: backup_user
#    Password: ******
#    Database: main_prod_db

# 3. Configure Database → Dump File
#    /home/user/backups/prod-backup-2026-02-03.sql

# 4. Select: Dump (Export)
# 5. Wait for completion
# ✅ Dump successful: /home/user/backups/prod-backup-2026-02-03.sql (234MB)
```

### Example 2: Clone Database from Staging to Development

```bash
# 1. Run the tool
./db-manager.sh

# 2. Configure Database → Complete Setup
#    Type: PostgreSQL
#    Source: staging.example.com:5432/staging_db
#    Destination: localhost:5432/dev_db
#    Dump File: /tmp/migration.dump

# 3. Select: Migrate (Dump + Load)
# 4. Confirm migration
# 5. Wait for completion
# ✅ Migration completed!
```

### Example 3: Restore Backup to New Server

```bash
# 1. Ensure you have the backup file
ls -lh /backups/production-2026-01-15.sql

# 2. Run the tool
./db-manager.sh

# 3. Configure Database → DESTINATION Configuration
#    Host: newserver.example.com
#    Port: 3306
#    Database: production_db

# 4. Configure Database → Dump File
#    /backups/production-2026-01-15.sql

# 5. Select: Load (Import)
# 6. Wait for completion
# ✅ Import successful!
```

### Example 4: Regular Migration Script

Create a script for regular migrations:

```bash
#!/bin/bash
# migrate-daily.sh

# Set configuration
export DB_TYPE=mysql
export SRC_HOST=prod.example.com
export SRC_PORT=3306
export SRC_USER=backup_user
export SRC_PASS=secure_password
export SRC_DB=production

export DST_HOST=localhost
export DST_PORT=3306
export DST_USER=root
export DST_PASS=local_password
export DST_DB=development

export DUMP_FILE="/backups/daily-$(date +%Y%m%d).sql"

# Run migration (requires automation)
# Note: For fully automated runs, you'd need to modify the script
# to accept command-line arguments instead of using dialog
```

---

## 🔒 Security

### Important Security Considerations

⚠️ **WARNING**: The `.config` file contains passwords in plain text!

### Best Practices

1. **Protect Configuration File**
   ```bash
   chmod 600 .config
   ```

2. **Never Commit Credentials**
   - `.config` is already in `.gitignore`
   - Double-check before committing

3. **Use Restricted Database Users**
   - Create dedicated users with minimal permissions
   - For dumps: `SELECT`, `SHOW VIEW`, `TRIGGER`, `LOCK TABLES`
   - For loads: `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`

4. **Production Environments**
   - Consider using secret management tools
   - Use SSH tunnels for remote connections
   - Enable SSL/TLS for database connections

5. **Audit Trail**
   - Log all migration activities
   - Review dump files before restoring to production

### Network Security

```bash
# Example: Use SSH tunnel for secure connection
ssh -L 3307:localhost:3306 user@production-server

# Then configure tool to use localhost:3307
```

---

## 🐛 Troubleshooting

### Common Issues and Solutions

#### Issue: Dialog not working

**Solution:**
The bundled dialog binary works on **Linux x86_64** systems. If you're on a different system (macOS, ARM, etc.), install dialog:

```bash
# Test if bundled binary works
./dependencies/dialog/dialog --version

# If not, install for your system:
sudo apt-get install dialog  # Ubuntu/Debian
sudo yum install dialog      # RedHat/CentOS
sudo dnf install dialog      # Fedora
sudo pacman -S dialog        # Arch Linux
brew install dialog          # macOS
```

The script will automatically use your system's dialog if the bundled one doesn't work.

#### Issue: Running on Windows

**Problem:** The bundled dialog binary is Linux-only and won't work on Windows.

**Solutions:**

1. **Use WSL2 (Recommended)**
   ```bash
   # Install WSL2 with Ubuntu
   wsl --install
   
   # Run the script inside WSL
   cd /mnt/c/your/path/Database-Migration-Manager
   ./db-manager.sh
   ```
   ✅ Bundled dialog works perfectly in WSL2!

2. **Docker Desktop with WSL2 Backend**
   - Install Docker Desktop for Windows
   - Enable WSL2 integration
   - Run scripts from WSL2 terminal

3. **Git Bash (Not Recommended)**
   - Dialog binary won't work
   - Would need to install Windows-compatible dialog
   - Better to use WSL2 instead

#### Issue: `docker: command not found`

**Solution:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in
```

#### Issue: Permission denied on Docker

**Solution:**
```bash
sudo usermod -aG docker $USER
# Log out and log back in, or:
newgrp docker
```

#### Issue: Cannot connect to database

**Solution:**
- Verify host and port are correct
- Check firewall rules allow connections
- Ensure database server is running
- Test credentials manually:
  ```bash
  mysql -h HOST -P PORT -u USER -p
  ```

#### Issue: Dump file is empty

**Solution:**
- Check source database has data
- Verify user has sufficient permissions
- Check disk space on destination

#### Issue: Purple/colored terminal after exit

**Solution:**
This is fixed in the latest version. Update your script or manually reset:
```bash
tput sgr0
clear
```

#### Issue: Script exits on ESC/Cancel

**Solution:**
This is fixed in the latest version (removed `set -e`).

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

### Reporting Bugs

1. Check if the issue already exists
2. Provide detailed steps to reproduce
3. Include your OS, Docker version, and database type
4. Share relevant error messages

### Feature Requests

1. Describe the feature and use case
2. Explain why it would be useful
3. Provide examples if possible

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request with clear description

---

## 📝 License

This project is licensed under the MIT License - feel free to use it in your projects!

---

## 🙏 Acknowledgments

- Built with ❤️ using Bash, Dialog, and Docker
- Inspired by the need for simple, reliable database migrations
- Thanks to the open-source community

---

## 📞 Support

Having issues? Need help?

- 📖 Check the [Troubleshooting](#-troubleshooting) section
- 💬 Open an issue on GitHub
- 📧 Contact the maintainers

---

**Happy Migrating! 🚀**

---

## 🔗 Quick Links

- **Project Directory**: `Database-Migration-Manager/`
- **Direct Mode**: `./db-manager.sh` (Linux/macOS/WSL)
- **Docker Mode**: `./run-docker.sh` (Windows/Any OS)
- **Configuration**: `.config` (auto-generated)
- **Operations**: `operations/*.sh`

## 📊 Version

**Current Version**: 3.0  
**Last Updated**: February 2026  
**Status**: Production Ready ✅  
**New in 3.0**: Docker mode support for Windows! 🎉

---

- **Interface Interativa**: Interface TUI (Text User Interface) usando Dialog
- **Multi-Database**: Suporte para MySQL, PostgreSQL e SQL Server
- **Docker-Based**: Todas as operações usam Docker - não precisa instalar ferramentas de banco
- **Configuração Persistente**: Salva configurações entre sessões
- **Operações Completas**: Dump, Load e Migrate (Dump + Load)

## 📋 Pré-requisitos

Apenas duas ferramentas são necessárias:

1. **Docker**: Para executar comandos de banco de dados
   ```bash
   # Instalar Docker (Ubuntu/Debian)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Dialog**: Para a interface do terminal
   ```bash
   # Ubuntu/Debian
   sudo apt-get install dialog
   
   # RedHat/CentOS
   sudo yum install dialog
   
   # Arch Linux
   sudo pacman -S dialog
   ```

## 🚀 Como Usar

### Iniciar o gerenciador

```bash
cd Database-Migration-Manager
chmod +x db-manager.sh
./db-manager.sh
```

### Menu Principal

O sistema apresenta um menu com as seguintes opções:

1. **🗄️ Configurar Banco de Dados**
   - Escolha o tipo: MySQL, PostgreSQL ou SQL Server
   - Configure origem (host, porta, usuário, senha, database)
   - Configure destino (host, porta, usuário, senha, database)
   - Defina o caminho do arquivo de dump

2. **💾 Dump (Exportar)**
   - Exporta o banco de dados de origem para um arquivo
   - Usa Docker para executar o comando apropriado

3. **📥 Load (Importar)**
   - Importa um arquivo de dump para o banco de destino
   - Cria o database automaticamente se não existir

4. **🔄 Migrate (Dump + Load)**
   - Executa dump da origem
   - Depois executa load no destino
   - Migração completa em uma operação

5. **⚙️ Visualizar Configuração**
   - Mostra as configurações atuais

6. **🚪 Sair**

## 🗂️ Estrutura de Arquivos

```
Database-Migration-Manager/
├── db-manager.sh              # Script principal com interface Dialog
├── .config                    # Arquivo de configuração (criado automaticamente)
├── operations/                # Scripts de operação por banco
│   ├── mysql-dump.sh
│   ├── mysql-load.sh
│   ├── postgres-dump.sh
│   ├── postgres-load.sh
│   ├── sqlserver-dump.sh
│   └── sqlserver-load.sh
└── README.md
```

## 🔧 Configuração

As configurações são salvas automaticamente em `.config` e incluem:

- Tipo de banco de dados
- Credenciais de origem (host, porta, usuário, senha, database)
- Credenciais de destino (host, porta, usuário, senha, database)
- Caminho do arquivo de dump

## 💡 Exemplos de Uso

### Exemplo 1: Migrar MySQL de produção para desenvolvimento

1. Execute `./db-manager.sh`
2. Escolha "Configurar Banco de Dados"
3. Selecione "MySQL/MariaDB"
4. Configure:
   - Origem: `prod.server.com:3306`, user `root`, db `production_db`
   - Destino: `localhost:3306`, user `root`, db `dev_db`
5. Escolha "Migrate" no menu principal
6. Aguarde a conclusão

### Exemplo 2: Fazer backup de PostgreSQL

1. Execute `./db-manager.sh`
2. Escolha "Configurar Banco de Dados"
3. Selecione "PostgreSQL"
4. Configure origem e arquivo de dump
5. Escolha "Dump" no menu principal

### Exemplo 3: Restaurar backup em novo servidor

1. Execute `./db-manager.sh`
2. Escolha "Configurar Banco de Dados"
3. Configure destino e arquivo de dump existente
4. Escolha "Load" no menu principal

## 🐳 Como Funciona

### MySQL
- **Dump**: Usa `mysql:8.0` Docker image com `mysqldump`
- **Load**: Usa `mysql:8.0` Docker image com `mysql client`
- Inclui: transactions, routines, triggers, events

### PostgreSQL
- **Dump**: Usa `postgres:15-alpine` com `pg_dump` (formato custom)
- **Load**: Usa `postgres:15-alpine` com `pg_restore`
- Opções: `--clean`, `--if-exists`, `--no-owner`, `--no-acl`

### SQL Server
- **Dump**: Usa `mssql-tools` com `sqlcmd` para BACKUP DATABASE
- **Load**: Usa `mssql-tools` com `sqlcmd` para RESTORE DATABASE
- Nota: Requer que arquivos estejam acessíveis no servidor SQL Server

## 🔒 Segurança

⚠️ **Importante**: 
- O arquivo `.config` contém senhas em texto plano
- Adicione `.config` ao `.gitignore`
- Use permissões apropriadas: `chmod 600 .config`
- Em produção, considere usar secrets management

## 🐛 Troubleshooting

### Erro: "docker: command not found"
- Instale o Docker seguindo as instruções em https://docs.docker.com/get-docker/

### Erro: "dialog: command not found"
- Instale dialog: `sudo apt-get install dialog`

### Erro de conexão
- Verifique se o host está acessível
- Use `--network host` para permitir acesso a localhost
- Verifique firewalls e portas

### Permissão negada ao executar script
- Execute: `chmod +x db-manager.sh`
- Certifique-se que os scripts em `operations/` também são executáveis

## 📝 Notas

- Os scripts usam `--network host` no Docker para facilitar acesso a databases locais
- Dumps são salvos no caminho especificado no host
- SQL Server requer que os arquivos de backup estejam no servidor
- PostgreSQL usa formato custom por padrão (mais eficiente e permite restauração parcial)

## 🎨 Personalização

Você pode personalizar:

- Portas padrão em cada script
- Imagens Docker (versões dos bancos)
- Opções de dump/restore
- Cores e mensagens na interface

## 📄 Licença

Uso livre para projetos pessoais e comerciais.

## 🤝 Contribuições

Contribuições são bem-vindas! Sinta-se livre para melhorar o código.

---

**Desenvolvido com ❤️ usando Bash, Dialog e Docker**

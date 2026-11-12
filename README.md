## Deployment

**Stack:** React · Django · PostgreSQL · Supabase · Docker

This repo is the deployment copy, configured for containerized hosting:

|   Layer  | Platform |                    Notes                |
|----------|----------|-----------------------------------------|
| Frontend |  Vercel  |     React frontend    
|  Backend |  Render  |     Docker image, gunicorn, port 8000 
| Database | Supabase |     Managed PostgreSQL 

Backend Dockerfile included (`python:3.12-slim` + poppler for PDF processing, gunicorn entry).

## Run with Docker

> **Note:** Deployment setup lives on the `docker-setup` branch — switch to it (`git checkout docker-setup`) before following the steps below.

1. Copy `.env.example` to `.env.docker` and fill in your values
2. Build the image:
```bash
   docker build -t pygrounds-backend .
   docker run --env-file .env.docker -p 8000:8000 pygrounds-backend
```

# Pygrounds Backend Team Documentation

This document covers backend seeding tasks you may need during development: achievements and reading content.

## Prerequisites
- Run these commands from the backend project root (the folder that contains `manage.py`).
- Ensure your Python environment is active and dependencies from `requirements.txt` are installed.

### System Dependencies
**Poppler** is required by `pdf2image` / `unstructured` for PDF processing.

| OS | Install command |
|---|---|
| **Windows (winget)** | `winget install oschwartz10612.Poppler` |
| **Windows (scoop)** | `scoop install poppler` |
| **Windows (choco)** | `choco install poppler` |
| **macOS (Homebrew)** | `brew install poppler` |
| **Linux (apt)** | `sudo apt install poppler-utils` |

After installing, restart your terminal so the `PATH` picks up the binaries.

## Seed Achievements
The achievements seeder is an idempotent Django management command. It will create any missing default achievements by code and can optionally update existing ones.

Common commands (PowerShell):

```powershell
# Initial seed (creates any missing achievements; leaves existing ones unchanged)
python manage.py seed_achievements

# Update existing achievements' title/description/unlocked_zone to match defaults
python manage.py seed_achievements --update

# Preview what would change without writing to the database
python manage.py seed_achievements --update --dry-run

# Destructive reset: delete ALL user achievement unlocks and ALL achievements, then reseed
python manage.py seed_achievements --reset
```

Notes:
- `--update` only modifies title, description, and unlocked_zone for existing codes; it never creates duplicates.
- `--dry-run` prints what would be created/updated and is safe to use in any environment.
- `--reset` is destructive. It removes all `UserAchievement` rows first, then all `Achievement` rows, and reseeds the defaults.
- After running, check the console summary: `Seed complete. Created: X. Updated: Y. Total in DB: Z`.

## Seed Reading Content
Reading content can be seeded via a small script executed inside the Django shell.

Commands (PowerShell):

```powershell
# Open a Django shell from the backend project root
python manage.py shell
```

Then in the interactive shell:

```python
# Execute the seeding script (path relative to manage.py)
exec(open('reading/seed_reading.py').read())
```

Tips:
- The path `reading/seed_reading.py` is relative to the project root containing `manage.py`.
- If your file lives elsewhere, adjust the relative path accordingly.
- The script should be idempotent or handle duplicate data gracefully; rerun as needed during development.

## Verification
- Use Django admin to confirm results:
  - Achievements: titles/descriptions updated and expected entries present.
  - Reading content: new entries visible and linked as expected.

## Troubleshooting
- If you see "Skipped existing achievement (use --update to modify)", rerun with `--update`.
- To safely inspect planned changes before applying, use `--dry-run`.
- Ensure you’re in the correct directory (where `manage.py` is) when running commands.

## ML Difficulty Checker Setup

The coding question difficulty checker uses a trained ML model (TF-IDF + XGBoost). The model file is excluded from git (too large), so each developer needs to generate it locally.

### First-time setup

**1. Install required packages:**
```bash
pip install xgboost imbalanced-learn
```

**2. Create the models directory:**
```bash
mkdir -p question_generation/models
```

**3. Train and save the coding model:**
```bash
python question_generation/helpers/minigame_train_coding.py
```

This will generate `question_generation/models/minigame_coding_model.pkl`.

### Notes
- The model only needs to be trained once per machine.
- If the model file is missing, the system will automatically fall back to the rule-based engine — the Check Difficulty feature will still work, just without ML.
- `minigame_train_non_coding.py` does NOT need to be run — non-coding difficulty uses the rule engine directly in this branch.


## Scripts
Setup scripts live in the `scripts/` folder and must be run in the order below before processing any PDFs.
### 1. Download Embedding Models (`scripts/download_models.py`)
Downloads the MiniLM (`all-MiniLM-L6-v2`) and CodeBERT (`codebert-base`) embedding models into a local `models/` folder. Running this first avoids Hugging Face Hub rate limits while `populate_zones.py` generates embeddings.
```powershell
python scripts/download_models.py
```
### 2. Populate Zones (`scripts/populate_zones.py`)
Populates the database with the predefined learning structure: game zones, topics, and subtopics (each with a concept intent and a code intent), then generates dual MiniLM + CodeBERT embeddings for every subtopic.
```powershell
python scripts/populate_zones.py
```
**Why this must run before any PDF is processed:** the retrieval pipeline matches every document chunk against the subtopic embeddings to place content inside the curriculum. Without zones, topics, and subtopics (and their embeddings), PDF processing and question generation have no topics to retrieve against.
Notes:
- The script **deletes all existing zones, topics, and subtopics** (and their embeddings) before reseeding — it is a full overwrite, not an incremental seed.
- If the embedding system is unavailable, subtopics are still created without embeddings; they can be generated later from the admin interface.


### PDF processing → Chunking → Retrieval → LLM generation

500-1,000-page textbook PDFs → cleaned and chunked (works with or without a table of contents) → retrieval → LLM generates graded questions per topic and difficulty → parallel generation with multithreading, live progress, job cancellation, and a status API for long-running jobs. Admin dashboard reviews the output.



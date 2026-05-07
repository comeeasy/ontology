import subprocess
import sys
from pathlib import Path


def run_etl(script_path: str) -> dict:
    if not Path(script_path).exists():
        return {"success": False, "error": f"ETL 스크립트 없음: {script_path}"}

    result = subprocess.run(
        [sys.executable, script_path],
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        return {"success": True, "output": result.stdout}
    else:
        return {"success": False, "error": result.stderr}

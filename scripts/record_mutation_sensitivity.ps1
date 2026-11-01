$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$readmePath = Join-Path $repo "README_UVM_SETUP.md"
$mutantRtl = Join-Path $repo "experiments\mutation_sub_carry\alu8_pipeline.sv"
$mutantReadme = Join-Path $repo "experiments\mutation_sub_carry\README.md"
$mutantTcl = Join-Path $PSScriptRoot "run_mutation_sensitivity.tcl"

foreach ($path in @($readmePath, $mutantRtl, $mutantReadme, $mutantTcl)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path. Extract the mutation-sensitivity ZIP into the project root first."
    }
}

$staged = @(git -C $repo diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw "Could not inspect the Git index." }
if ($staged.Count -gt 0) {
    $staged | ForEach-Object { Write-Host "Already staged: $_" }
    throw "Commit or unstage existing changes first; this script will not include unrelated staged files."
}

$readme = [System.IO.File]::ReadAllText($readmePath)
$marker = "## Mutation sensitivity result"
if ($readme.Contains($marker)) {
    throw "The mutation sensitivity result is already documented. No README changes made."
}

$section = @'
## Mutation sensitivity result

A deliberate SUB carry mutation changed the ALU to report unsigned borrow instead of the documented no-borrow flag. The UVM scoreboard detected the directed `SUB 09 - 04` case (`got carry=0`, `expected carry=1`) and reported 14 scoreboard errors followed by one test fatal. This intentional failure confirms the checker is sensitive to an arithmetic flag defect; it is not a failure of the clean design.

After the mutation run, the baseline RTL was run again and passed: 121 responses checked, no pending requests, 40 idle cycles, 2 reset pulses, 1 in-flight request flushed by reset, and 100% opcode/flag cross coverage. The clean run ended with 0 UVM warnings, errors, or fatals.

The faulty RTL is isolated under `experiments/mutation_sub_carry/` and is not used by the normal regression or synthesis flow.
'@

[System.IO.File]::WriteAllText(
    $readmePath,
    $readme.TrimEnd() + "`r`n`r`n" + $section.Trim() + "`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

git -C $repo add -- README_UVM_SETUP.md `
    experiments/mutation_sub_carry/README.md `
    experiments/mutation_sub_carry/alu8_pipeline.sv `
    scripts/run_mutation_sensitivity.tcl `
    scripts/record_mutation_sensitivity.ps1
if ($LASTEXITCODE -ne 0) { throw "Could not stage the mutation-sensitivity documentation and files." }

git -C $repo diff --cached --check
if ($LASTEXITCODE -ne 0) { throw "Staged changes failed Git whitespace checks." }

git -C $repo diff --cached --stat
git -C $repo commit -m "Document UVM mutation sensitivity check"
if ($LASTEXITCODE -ne 0) { throw "Commit failed. Review Git output and repository identity." }

Write-Host "`nCommitted UVM mutation sensitivity evidence. Review the commit before pushing."
git -C $repo log -1 --oneline
git -C $repo status --short

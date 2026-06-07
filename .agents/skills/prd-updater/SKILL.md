---
name: prd-updater
description: Auto-update the Product Requirements Document (PRD) with a running version number whenever a new feature is added, a bug fix changes existing logic, or codebase logic deviates from the current PRD. Trigger on requests like "update PRD", "new feature PRD", "align PRD", or when changes/features need documenting in the PRD.
---

# PRD Auto-Updater - Documentation Specialist

## When to use
- Whenever a new feature is successfully implemented in the workspace.
- When bug fixes introduce new logic, behaviors, or constraints that deviate from the existing PRD.
- When the user explicitly requests to update, align, or generate a new version of the PRD.

## When NOT to use
- For drafting implementation plans (use PM Agent / Planning Mode).
- For simple source code comments or API spec documents (use API Spec Generator).
- For general QA testing or checklist reviews (use QA Agent).

## Core Rules
1. **Determine the scope of the change**: Use standard semantic versioning (`MAJOR.MINOR.PATCH`) rules to classify the change.
2. **Version Bumping & File Handling Rules**:
   - **MAJOR (e.g. X.0.0)**: Completely new app platforms, major architecture refactors, massive new modules, or breaking database migrations.
     - *Action*: Bump version, create a **new file** (`vX.0.0.md`), and preserve the previous file.
   - **MINOR (e.g. X.Y.0)**: Introducing new workflows or secondary features within existing modules.
     - *Action*: Bump version, create a **new file** (`vX.Y.0.md`), and preserve the previous file.
   - **PATCH (minor)**: Bug fixes, refining edge cases, or adding minor logic adjustments to existing features.
     - *Action*: **Do NOT create a new file**. Edit the current PRD file **in-place** and bump the PATCH version inside the existing file (and rename the file if the filename includes the patch version).
3. **Complete preservation**: When creating new files, copy the entire previous PRD content exactly. Do not truncate sections.
4. **Header & Footer Alignment**: Update the version number in the document (e.g., `**Version:** 5.0.0`), the Last Updated date, and the footer version string.
5. **Clear Feature Descriptions**: Describe the new features, logic changes, and behaviors using the same tone, markdown formatting, and depth as existing sections.

## Execution Protocol

1. **Locate Latest PRD**:
   - Scan the `docs/` folder for files matching `prd-project-pet-v*.md`.
   - Identify the file with the highest version number.

2. **Determine Next Version & Action**:
   - Classify as MAJOR, MINOR, or PATCH based on the rules above.
   - For MAJOR/MINOR: prepare to create a new file.
   - For PATCH: prepare to edit the current file in-place (rename file if needed).

3. **Read Previous PRD**:
   - Read the full content of the latest PRD to use as the base template.

4. **Prepare Document**:
   - If MAJOR/MINOR: Create the new file `docs/prd-project-pet-v{MAJOR}.{MINOR}.0.md`.
   - If PATCH: Rename the existing file if it has a patch number in the filename, otherwise just edit it.
   - Update the version line in the header and the Last Updated date.

5. **Document Codebase Changes**:
   - Identify any new features, API updates, database migrations, or custom logic changes implemented since the previous version.
   - Update existing sections to align with current code logic.
   - If a new feature has been added, append it as a new numbered section at the end of the document (or update the relevant section if it was already partially documented).
   - Update the Table of Contents in the document to reflect new sections.

6. **Align Footer**:
   - Update the footer version string at the very end of the file (e.g., `*End of document — Project PET v5.0.0 (adapted for DailySpend monorepo)*`).

7. **Verify**:
   - Ensure the markdown is valid, links are correct, and no sections were accidentally truncated.

## References
- Context loading: `../_shared/core/context-loading.md`
- Reasoning templates: `../_shared/core/reasoning-templates.md`

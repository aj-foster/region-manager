# Changelog

Notable changes to this project will be documented in this file.
Because this project does not utilize tagged releases, changes will be roughly grouped by date.

## 2024-02-13

_Region Manager_ now understands leagues based on data from the FTC Events API.
This data can be updated on-demand using a button in the same import interface as team data.
Team assignments to leagues is also filled in automatically.

Behind the scenes (not yet available in the interface) the application also understands events from the FTC Events API and has basic event registration settings.

## 2024-01-06

This is the start of change tracking.
In this initial release, _Region Manager_ supports basic identity-related tasks (login, logout, password reset, 2FA, email settings and confirmation).
It also allows importing team data using CSV exports from Tableau.

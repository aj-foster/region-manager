# Changelog

Notable changes to this project will be documented in this file.
Because this project does not utilize tagged releases, changes will be roughly grouped by date.

## 2024-05-31

Teams can now register for events.
Registration does not yet support capacity, waitlists, or the ability to revoke a registration.

## 2024-05-24

Coaches and admins of a team can now see basic information about their team.
This includes details about the event readiness of the team, with explanations and (preliminary) links to correct common issues.

## 2024-04-29

Leagues and events now have registration settings attached to them.
The first setting available in the user interface allows league leaders to control whether teams can sign up for new events in _Region Manager_.
Behind the scenes, additional settings allow changing registration deadlines, creating a waitlist, and controlling the number of teams in attendance.

## 2024-02-13

_Region Manager_ now understands leagues based on data from the FTC Events API.
This data can be updated on-demand using a button in the same import interface as team data.
Team assignments to leagues is also filled in automatically.

Behind the scenes (not yet available in the interface) the application also understands events from the FTC Events API and has basic event registration settings.

## 2024-01-06

This is the start of change tracking.
In this initial release, _Region Manager_ supports basic identity-related tasks (login, logout, password reset, 2FA, email settings and confirmation).
It also allows importing team data using CSV exports from Tableau.

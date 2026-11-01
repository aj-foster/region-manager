#set page(
  paper: "us-letter",
  // flipped: true,
  margin: (top: 0.75in, left: 0.5in, right: 0.5in, bottom: 0.6in),
  header: context align(center)[
    #text(size: 14pt, weight: "bold")[Team Check-in List]
    #h(1fr)
    #text(size: 10pt, fill: luma(128))[#event_name]
  ],
  footer: context align(center)[
    #set text(size: 9pt, fill: luma(128))
    Generated: #generated_at
    #h(1fr)
    Last team import: #last_team_import
  ],
)

#set text(size: 10pt, font: "Montserrat")
#set table.cell(align: horizon)

#if registered.len() > 0 {
  table(
    align: (left, center, center, center),
    columns: (1fr, auto, auto, auto),
    fill: (x, y) => if calc.odd(y) { luma(245) } else { white },
    inset: (x: 6pt, y: 5pt),
    stroke: 0.5pt,
    table.header(
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#strong[Registered Teams]],
      table.cell(fill: rgb("#fcd5b8"), inset: (x: 6pt, y: 4pt))[#text(
        size: 7pt,
        weight: "bold",
      )[Event#linebreak()Ready]],
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#text(size: 8pt, weight: "bold")[Present]],
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#text(size: 8pt, weight: "bold")[Roster]],
    ),
    ..registered
      .map(team => (
        [
          #text(font: "DejaVu Sans Mono")[#team.number]
          #h(0.5em)
          #team.name
        ],
        table.cell(inset: 0pt)[#if team.event_ready [#text(fill: green, weight: "light")[✓]] else [#text(
          fill: red,
          weight: "bold",
        )[✗]]],
        [],
        [],
      ))
      .flatten(),
  )
}

#if unregistered.len() > 0 {
  table(
    align: (left, center, center, center),
    columns: (1fr, auto, auto, auto),
    fill: (x, y) => if calc.odd(y) { luma(245) } else { white },
    inset: (x: 6pt, y: 5pt),
    stroke: 0.5pt,
    table.header(
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#strong[Unregistered League Teams]],
      table.cell(fill: rgb("#fcd5b8"), inset: (x: 6pt, y: 4pt))[#text(
        size: 7pt,
        weight: "bold",
      )[Event#linebreak()Ready]],
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#text(size: 8pt, weight: "bold")[Present]],
      table.cell(fill: rgb("#fcd5b8"), inset: 6pt)[#text(size: 8pt, weight: "bold")[Roster]],
    ),
    ..unregistered
      .map(team => (
        [
          #text(font: "DejaVu Sans Mono")[#team.number]
          #h(0.5em)
          #team.name
        ],
        table.cell(inset: 0pt)[#if team.event_ready [#text(fill: green, size: 12pt, weight: "light")[✓]] else [#text(
          fill: red,
          size: 12pt,
          weight: "bold",
        )[✗]]],
        [],
        [],
      ))
      .flatten(),
  )
}

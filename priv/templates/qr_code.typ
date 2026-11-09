#import "@preview/cades:0.3.1": qr-code
#set text(font: "Montserrat", size: 18pt)

#set page(
  paper: "us-letter",
  margin: (top: 2in, left: 0.5in, right: 0.5in, bottom: 0.6in),
  header-ascent: 0in,
  header: context align(center + horizon)[
    #box(text(size: 20pt, weight: "bold")[#title], height: 0.5in)
    #h(1fr)
    #box(image("static/images/ftc-horizontal.svg", height: 0.5in, width: 2in))
  ],
  footer: context align(center)[
    #set text(size: 9pt, fill: luma(128))
    #event.name
    #h(1fr)
    Generated #generated_at
  ],
)

#align(center)[
  // #v(0.5in)
  #qr-code(url, width: 6in)
  #v(0.75in)
  #text(weight: "bold")[#description]
]

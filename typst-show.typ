#set page(
  fill: white
)

#show heading: it => block(width: 100%)[
  #set text(weight: "extrabold", font: ("Noto Sans KR"))
  #(it.body)
]


#align(center)[
    #text("Seoncheol Park", font: ("Noto Sans KR"), weight:"black", size:30pt)
  ]

#set text(font: ("IBM Plex Sans", "IBM Plex Sans KR"))
